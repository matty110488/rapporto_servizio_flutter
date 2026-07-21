import { createHmac, timingSafeEqual } from 'node:crypto';
import {
  allowedRaceDatabaseIds,
  NOTION_RACE_PROPERTIES,
} from './notion-config.js';

export const config = {
  api: {
    bodyParser: false,
  },
};

const NOTION_VERSION = '2026-03-11';
const MAX_PDF_BYTES = 4_500_000;
const DEFAULT_ALLOWED_ORIGINS = [
  'https://matty110488.github.io',
  'https://rapporto-servizio-flutter.vercel.app',
  'https://appkronos-1d181.web.app',
  'https://appkronos-1d181.firebaseapp.com',
];

function normalizedId(value) {
  return String(value || '').replace(/-/g, '').toLowerCase();
}

function allowedOrigins() {
  return [
    ...DEFAULT_ALLOWED_ORIGINS,
    ...(process.env.ALLOWED_ORIGINS || '')
      .split(',')
      .map((origin) => origin.trim())
      .filter(Boolean),
  ];
}

function isAllowedOrigin(origin) {
  if (!origin) return true;
  if (allowedOrigins().includes(origin)) return true;
  try {
    const parsed = new URL(origin);
    return parsed.hostname === 'localhost' || parsed.hostname === '127.0.0.1';
  } catch {
    return false;
  }
}

function setCorsHeaders(req, res) {
  const origin = req.headers.origin;
  if (isAllowedOrigin(origin)) {
    res.setHeader('Access-Control-Allow-Origin', origin || '*');
  }
  res.setHeader('Vary', 'Origin');
  res.setHeader('Access-Control-Allow-Methods', 'POST, OPTIONS');
  res.setHeader(
    'Access-Control-Allow-Headers',
    'Content-Type, Authorization, X-Notion-Page-Ids, X-Report-Filename',
  );
}

function verifySession(authorization, secret) {
  if (typeof authorization !== 'string' || !authorization.startsWith('Bearer ')) return null;
  const token = authorization.slice('Bearer '.length).trim();
  const [payload, signature, extra] = token.split('.');
  if (!payload || !signature || extra) return null;
  const expected = createHmac('sha256', secret).update(payload).digest('base64url');
  const actualBuffer = Buffer.from(signature);
  const expectedBuffer = Buffer.from(expected);
  if (
    actualBuffer.length !== expectedBuffer.length ||
    !timingSafeEqual(actualBuffer, expectedBuffer)
  ) {
    return null;
  }
  try {
    const decoded = JSON.parse(Buffer.from(payload, 'base64url').toString('utf8'));
    if (
      !decoded ||
      typeof decoded.sub !== 'string' ||
      typeof decoded.exp !== 'number' ||
      decoded.exp <= Math.floor(Date.now() / 1000)
    ) {
      return null;
    }
    return decoded;
  } catch {
    return null;
  }
}

function decodeFilename(value) {
  if (typeof value !== 'string' || !value) return 'Rapporto servizio.pdf';
  try {
    const decoded = Buffer.from(value, 'base64url').toString('utf8').trim();
    const safe = decoded
      .replace(/[\\/:*?"<>|\u0000-\u001f]/g, '-')
      .replace(/\s+/g, ' ')
      .slice(0, 180);
    if (!safe) return 'Rapporto servizio.pdf';
    return safe.toLowerCase().endsWith('.pdf') ? safe : `${safe}.pdf`;
  } catch {
    return 'Rapporto servizio.pdf';
  }
}

async function readPdfBody(req) {
  if (Buffer.isBuffer(req.body)) return req.body;
  if (req.body instanceof Uint8Array) return Buffer.from(req.body);
  const chunks = [];
  let length = 0;
  for await (const chunk of req) {
    const buffer = Buffer.isBuffer(chunk) ? chunk : Buffer.from(chunk);
    length += buffer.length;
    if (length > MAX_PDF_BYTES) {
      const error = new Error('PDF exceeds upload limit');
      error.statusCode = 413;
      throw error;
    }
    chunks.push(buffer);
  }
  return Buffer.concat(chunks);
}

async function notionJsonRequest(token, url, method, payload) {
  const response = await fetch(url, {
    method,
    headers: {
      Authorization: `Bearer ${token}`,
      'Notion-Version': NOTION_VERSION,
      'Content-Type': 'application/json',
    },
    body: method === 'GET' ? undefined : JSON.stringify(payload ?? {}),
  });
  const data = await response.json();
  return { status: response.status, data };
}

export function filesWithReport(existingFiles, filename, uploadId) {
  const retained = (Array.isArray(existingFiles) ? existingFiles : [])
    .filter((entry) => entry?.name !== filename)
    .slice(0, 99);
  return [
    ...retained,
    {
      name: filename,
      type: 'file_upload',
      file_upload: { id: uploadId },
    },
  ];
}

export default async function handler(req, res) {
  setCorsHeaders(req, res);
  if (req.method === 'OPTIONS') return res.status(204).end();
  if (req.method !== 'POST') return res.status(405).json({ error: 'Method not allowed' });
  if (!isAllowedOrigin(req.headers.origin)) {
    return res.status(403).json({ error: 'Origin not allowed' });
  }

  const { NOTION_TOKEN, DATABASE_ID } = process.env;
  if (!NOTION_TOKEN || !DATABASE_ID) {
    return res.status(500).json({ error: 'Missing server configuration' });
  }
  const session = verifySession(
    req.headers.authorization,
    process.env.SESSION_SECRET || NOTION_TOKEN,
  );
  if (!session) return res.status(401).json({ error: 'Authentication required' });

  const pageIds = String(req.headers['x-notion-page-ids'] || '')
    .split(',')
    .map((id) => id.trim())
    .filter(Boolean);
  if (pageIds.length === 0 || pageIds.length > 20) {
    return res.status(400).json({ error: 'Invalid race page list' });
  }
  if (pageIds.some((id) => !/^[0-9a-f-]{32,36}$/i.test(id))) {
    return res.status(400).json({ error: 'Invalid race page ID' });
  }

  try {
    const pdf = await readPdfBody(req);
    if (pdf.length === 0 || pdf.length > MAX_PDF_BYTES) {
      return res.status(413).json({ error: 'PDF exceeds upload limit' });
    }
    if (pdf.subarray(0, 5).toString('ascii') !== '%PDF-') {
      return res.status(400).json({ error: 'Invalid PDF file' });
    }

    const allowedDatabaseIds = new Set(
      allowedRaceDatabaseIds(process.env.ALLOWED_DATABASE_IDS).map(normalizedId),
    );
    const pages = [];
    for (const pageId of [...new Set(pageIds)]) {
      const page = await notionJsonRequest(
        NOTION_TOKEN,
        `https://api.notion.com/v1/pages/${pageId}`,
        'GET',
      );
      if (page.status !== 200) return res.status(page.status).json(page.data);
      if (!allowedDatabaseIds.has(normalizedId(page.data?.parent?.database_id))) {
        return res.status(403).json({ error: 'Race page not allowed' });
      }
      const propertyName = Object.keys(page.data?.properties || {}).find(
        (key) => key.trim().toLowerCase() === NOTION_RACE_PROPERTIES.files.toLowerCase(),
      );
      if (!propertyName || page.data.properties[propertyName]?.type !== 'files') {
        return res.status(422).json({ error: 'Files & media property not found' });
      }
      pages.push({ pageId, propertyName, property: page.data.properties[propertyName] });
    }

    const filename = decodeFilename(req.headers['x-report-filename']);
    const created = await notionJsonRequest(
      NOTION_TOKEN,
      'https://api.notion.com/v1/file_uploads',
      'POST',
      { mode: 'single_part', filename, content_type: 'application/pdf' },
    );
    if (created.status !== 200 || typeof created.data?.id !== 'string') {
      return res.status(created.status).json(created.data);
    }

    const form = new FormData();
    form.append('file', new Blob([pdf], { type: 'application/pdf' }), filename);
    const sentResponse = await fetch(
      `https://api.notion.com/v1/file_uploads/${created.data.id}/send`,
      {
        method: 'POST',
        headers: {
          Authorization: `Bearer ${NOTION_TOKEN}`,
          'Notion-Version': NOTION_VERSION,
        },
        body: form,
      },
    );
    const sent = await sentResponse.json();
    if (!sentResponse.ok) return res.status(sentResponse.status).json(sent);

    for (const page of pages) {
      const updated = await notionJsonRequest(
        NOTION_TOKEN,
        `https://api.notion.com/v1/pages/${page.pageId}`,
        'PATCH',
        {
          properties: {
            [page.propertyName]: {
              type: 'files',
              files: filesWithReport(page.property.files, filename, created.data.id),
            },
          },
        },
      );
      if (updated.status !== 200) return res.status(updated.status).json(updated.data);
    }

    return res.status(200).json({ uploaded: true, attached: pages.length });
  } catch (error) {
    const status = Number.isInteger(error?.statusCode) ? error.statusCode : 500;
    return res.status(status).json({ error: error instanceof Error ? error.message : String(error) });
  }
}
