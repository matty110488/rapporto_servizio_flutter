import { createHmac, timingSafeEqual } from 'node:crypto';
import {
  allowedInventoryDatabaseIds,
  NOTION_INVENTORY_PROPERTIES,
} from './notion-config.js';

export const config = { api: { bodyParser: false } };

const NOTION_VERSION = '2026-03-11';
const MAX_BYTES = 4_500_000;
const ALLOWED_TYPES = new Set([
  'application/pdf',
  'image/jpeg',
  'image/png',
  'image/webp',
  'image/heic',
  'application/msword',
  'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
  'application/vnd.ms-excel',
  'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
]);
const DEFAULT_ALLOWED_ORIGINS = [
  'https://matty110488.github.io',
  'https://rapporto-servizio-flutter.vercel.app',
  'https://appkronos-1d181.web.app',
  'https://appkronos-1d181.firebaseapp.com',
];

function normalizedId(value) {
  return String(value || '').replace(/-/g, '').toLowerCase();
}

function normalizedName(value) {
  return String(value || '').normalize('NFD').replace(/[\u0300-\u036f]/g, '')
    .replace(/[^a-z0-9]/gi, '').toLowerCase();
}

function isAllowedOrigin(origin) {
  if (!origin) return true;
  const allowed = [
    ...DEFAULT_ALLOWED_ORIGINS,
    ...(process.env.ALLOWED_ORIGINS || '').split(',').map((value) => value.trim()).filter(Boolean),
  ];
  if (allowed.includes(origin)) return true;
  try {
    const hostname = new URL(origin).hostname;
    return hostname === 'localhost' || hostname === '127.0.0.1';
  } catch {
    return false;
  }
}

function verifySession(authorization, secret) {
  if (typeof authorization !== 'string' || !authorization.startsWith('Bearer ')) return null;
  const [payload, signature, extra] = authorization.slice(7).trim().split('.');
  if (!payload || !signature || extra) return null;
  const expected = createHmac('sha256', secret).update(payload).digest('base64url');
  const left = Buffer.from(signature);
  const right = Buffer.from(expected);
  if (left.length !== right.length || !timingSafeEqual(left, right)) return null;
  try {
    const decoded = JSON.parse(Buffer.from(payload, 'base64url').toString('utf8'));
    return decoded?.sub && decoded.exp > Math.floor(Date.now() / 1000) ? decoded : null;
  } catch {
    return null;
  }
}

function decodeFilename(value) {
  try {
    const decoded = Buffer.from(String(value || ''), 'base64url').toString('utf8').trim();
    return decoded.replace(/[\\/:*?"<>|\u0000-\u001f]/g, '-').replace(/\s+/g, ' ').slice(0, 180) || 'Allegato';
  } catch {
    return 'Allegato';
  }
}

async function readBody(req) {
  if (Buffer.isBuffer(req.body)) return req.body;
  if (req.body instanceof Uint8Array) return Buffer.from(req.body);
  const chunks = [];
  let size = 0;
  for await (const chunk of req) {
    const buffer = Buffer.isBuffer(chunk) ? chunk : Buffer.from(chunk);
    size += buffer.length;
    if (size > MAX_BYTES) throw Object.assign(new Error('Attachment exceeds upload limit'), { statusCode: 413 });
    chunks.push(buffer);
  }
  return Buffer.concat(chunks);
}

async function notionRequest(token, url, method, payload) {
  const response = await fetch(url, {
    method,
    headers: {
      Authorization: `Bearer ${token}`,
      'Notion-Version': NOTION_VERSION,
      'Content-Type': 'application/json',
    },
    body: method === 'GET' ? undefined : JSON.stringify(payload ?? {}),
  });
  return { status: response.status, data: await response.json() };
}

export default async function handler(req, res) {
  const origin = req.headers.origin;
  if (isAllowedOrigin(origin)) res.setHeader('Access-Control-Allow-Origin', origin || '*');
  res.setHeader('Vary', 'Origin');
  res.setHeader('Access-Control-Allow-Methods', 'POST, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type, Authorization, X-Notion-Page-Id, X-File-Name');
  if (req.method === 'OPTIONS') return res.status(204).end();
  if (req.method !== 'POST') return res.status(405).json({ error: 'Method not allowed' });
  if (!isAllowedOrigin(origin)) return res.status(403).json({ error: 'Origin not allowed' });

  const token = process.env.NOTION_TOKEN;
  if (!token) return res.status(500).json({ error: 'Missing server configuration' });
  const session = verifySession(
    req.headers.authorization,
    process.env.SESSION_SECRET || token,
  );
  if (!session) return res.status(401).json({ error: 'Authentication required' });
  if (session.admin !== true) return res.status(403).json({ error: 'Administrator access required' });

  const pageId = String(req.headers['x-notion-page-id'] || '').trim();
  const contentType = String(req.headers['content-type'] || '').split(';')[0].trim().toLowerCase();
  if (!/^[0-9a-f-]{32,36}$/i.test(pageId) || !ALLOWED_TYPES.has(contentType)) {
    return res.status(400).json({ error: 'Invalid inventory attachment' });
  }

  try {
    const page = await notionRequest(token, `https://api.notion.com/v1/pages/${pageId}`, 'GET');
    if (page.status !== 200) return res.status(page.status).json(page.data);
    const parentId = page.data?.parent?.database_id || page.data?.parent?.data_source_id;
    const allowedIds = allowedInventoryDatabaseIds(process.env.ALLOWED_INVENTORY_DATABASE_IDS)
      .map(normalizedId);
    if (!allowedIds.includes(normalizedId(parentId))) {
      return res.status(403).json({ error: 'Inventory page not allowed' });
    }
    const candidates = new Set(NOTION_INVENTORY_PROPERTIES.documentation.map(normalizedName));
    const propertyName = Object.keys(page.data?.properties || {})
      .find((name) => candidates.has(normalizedName(name)));
    const property = propertyName ? page.data.properties[propertyName] : null;
    if (!propertyName || property?.type !== 'files') {
      return res.status(422).json({ error: 'Documentation property not found' });
    }

    const bytes = await readBody(req);
    if (!bytes.length || bytes.length > MAX_BYTES) {
      return res.status(413).json({ error: 'Attachment exceeds upload limit' });
    }
    const filename = decodeFilename(req.headers['x-file-name']);
    const created = await notionRequest(
      token,
      'https://api.notion.com/v1/file_uploads',
      'POST',
      { mode: 'single_part', filename, content_type: contentType },
    );
    if (created.status !== 200 || typeof created.data?.id !== 'string') {
      return res.status(created.status).json(created.data);
    }
    const form = new FormData();
    form.append('file', new Blob([bytes], { type: contentType }), filename);
    const sentResponse = await fetch(
      `https://api.notion.com/v1/file_uploads/${created.data.id}/send`,
      { method: 'POST', headers: { Authorization: `Bearer ${token}`, 'Notion-Version': NOTION_VERSION }, body: form },
    );
    const sent = await sentResponse.json();
    if (!sentResponse.ok) return res.status(sentResponse.status).json(sent);

    const retained = (Array.isArray(property.files) ? property.files : []).slice(-99);
    const updated = await notionRequest(token, `https://api.notion.com/v1/pages/${pageId}`, 'PATCH', {
      properties: {
        [propertyName]: {
          type: 'files',
          files: [...retained, { name: filename, type: 'file_upload', file_upload: { id: created.data.id } }],
        },
      },
    });
    return res.status(updated.status).json(updated.status === 200 ? { uploaded: true } : updated.data);
  } catch (error) {
    const status = Number.isInteger(error?.statusCode) ? error.statusCode : 500;
    return res.status(status).json({ error: error instanceof Error ? error.message : String(error) });
  }
}
