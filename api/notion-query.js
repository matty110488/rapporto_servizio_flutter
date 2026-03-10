import { createSign } from 'node:crypto';

const DEFAULT_ALLOWED_ORIGINS = [
  'https://matty110488.github.io',
  'https://rapporto-servizio-flutter.vercel.app',
];

const ALLOWED_ORIGINS = [
  ...DEFAULT_ALLOWED_ORIGINS,
  ...(process.env.ALLOWED_ORIGINS || '')
    .split(',')
    .map((origin) => origin.trim())
    .filter(Boolean),
];

function isAllowedOrigin(origin) {
  // Requests from mobile/non-browser clients may not have Origin.
  if (!origin) return true;
  if (ALLOWED_ORIGINS.includes(origin)) return true;

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
    if (origin) {
      res.setHeader('Access-Control-Allow-Origin', origin);
    } else {
      res.setHeader('Access-Control-Allow-Origin', '*');
    }
  }
  res.setHeader('Vary', 'Origin');
  res.setHeader('Access-Control-Allow-Methods', 'POST, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type');
}

export default async function handler(req, res) {
  setCorsHeaders(req, res);

  if (req.method === 'OPTIONS') {
    return res.status(204).end();
  }

  if (req.method !== 'POST') {
    return res.status(405).json({ error: 'Method not allowed' });
  }

  if (!isAllowedOrigin(req.headers.origin)) {
    return res.status(403).json({ error: 'Origin not allowed' });
  }

  const {
    NOTION_TOKEN,
    DATABASE_ID,
    FIREBASE_PROJECT_ID,
    FIREBASE_CLIENT_EMAIL,
    FIREBASE_PRIVATE_KEY,
  } = process.env;
  if (!NOTION_TOKEN || !DATABASE_ID) {
    return res.status(500).json({ error: 'Missing NOTION_TOKEN or DATABASE_ID' });
  }

  try {
    const rawBody = typeof req.body === 'string'
      ? (req.body ? JSON.parse(req.body) : {})
      : req.body ?? {};
    const safeBody =
      rawBody && typeof rawBody === 'object' && !Array.isArray(rawBody) ? rawBody : {};
    const action = typeof safeBody.action === 'string' ? safeBody.action.trim() : 'queryDatabase';

    const toBase64Url = (value) =>
      Buffer.from(value)
        .toString('base64')
        .replace(/=/g, '')
        .replace(/\+/g, '-')
        .replace(/\//g, '_');

    const getFirebaseAccessToken = async () => {
      if (!FIREBASE_PROJECT_ID || !FIREBASE_CLIENT_EMAIL || !FIREBASE_PRIVATE_KEY) {
        throw new Error(
          'Missing FIREBASE_PROJECT_ID, FIREBASE_CLIENT_EMAIL, or FIREBASE_PRIVATE_KEY',
        );
      }

      const now = Math.floor(Date.now() / 1000);
      const jwtHeader = toBase64Url(JSON.stringify({ alg: 'RS256', typ: 'JWT' }));
      const jwtPayload = toBase64Url(
        JSON.stringify({
          iss: FIREBASE_CLIENT_EMAIL,
          sub: FIREBASE_CLIENT_EMAIL,
          aud: 'https://oauth2.googleapis.com/token',
          scope: 'https://www.googleapis.com/auth/firebase.messaging',
          iat: now,
          exp: now + 3600,
        }),
      );

      const unsignedJwt = `${jwtHeader}.${jwtPayload}`;
      const signer = createSign('RSA-SHA256');
      signer.update(unsignedJwt);
      signer.end();
      const privateKey = FIREBASE_PRIVATE_KEY.replace(/\\n/g, '\n');
      const signature = signer
        .sign(privateKey, 'base64')
        .replace(/=/g, '')
        .replace(/\+/g, '-')
        .replace(/\//g, '_');
      const assertion = `${unsignedJwt}.${signature}`;

      const tokenRes = await fetch('https://oauth2.googleapis.com/token', {
        method: 'POST',
        headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
        body: new URLSearchParams({
          grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer',
          assertion,
        }),
      });
      const tokenData = await tokenRes.json();
      if (!tokenRes.ok || !tokenData.access_token) {
        throw new Error(`OAuth token error: ${JSON.stringify(tokenData)}`);
      }
      return tokenData.access_token;
    };

    const notionRequest = async (url, method, payload) => {
      const notionResponse = await fetch(url, {
        method,
        headers: {
          Authorization: `Bearer ${NOTION_TOKEN}`,
          'Notion-Version': '2022-06-28',
          'Content-Type': 'application/json',
        },
        body: method === 'GET' ? undefined : JSON.stringify(payload ?? {}),
      });
      const data = await notionResponse.json();
      return { status: notionResponse.status, data };
    };

    const extractRichText = (field) => {
      if (!field || typeof field !== 'object') return '';
      const list = Array.isArray(field.rich_text) ? field.rich_text : [];
      if (list.length === 0) return '';
      return list
        .map((entry) =>
          entry && typeof entry === 'object' && typeof entry.plain_text === 'string'
            ? entry.plain_text
            : '',
        )
        .join('')
        .trim();
    };

    const findKeyByCandidates = (props, candidates) => {
      for (const key of candidates) {
        if (props && typeof props === 'object' && props[key]) return key;
      }
      return '';
    };

    const isAdminFromProperties = (props) => {
      if (!props || typeof props !== 'object') return false;
      const adminKeys = ['ADMIN', 'Admin', 'admin', 'RUOLO', 'Ruolo', 'ROLE', 'Role', 'role'];
      const isAdminText = (value) => {
        if (typeof value !== 'string') return false;
        const lower = value.trim().toLowerCase();
        return lower === 'admin' || lower === 'amministratore';
      };

      for (const key of adminKeys) {
        const field = props[key];
        if (!field || typeof field !== 'object') continue;
        if (field.checkbox === true) return true;

        if (field.select && typeof field.select === 'object' && isAdminText(field.select.name)) {
          return true;
        }

        if (Array.isArray(field.multi_select)) {
          for (const entry of field.multi_select) {
            if (entry && typeof entry === 'object' && isAdminText(entry.name)) {
              return true;
            }
          }
        }

        if (Array.isArray(field.rich_text)) {
          for (const entry of field.rich_text) {
            if (entry && typeof entry === 'object' && isAdminText(entry.plain_text)) {
              return true;
            }
          }
        }
      }
      return false;
    };

    const queryAllDatabasePages = async (databaseId, filter) => {
      const all = [];
      let cursor = '';
      while (true) {
        const payload = { page_size: 100 };
        if (cursor) payload.start_cursor = cursor;
        if (filter) payload.filter = filter;

        const { status, data } = await notionRequest(
          `https://api.notion.com/v1/databases/${databaseId}/query`,
          'POST',
          payload,
        );
        if (status !== 200) {
          throw new Error(`Notion query failed (${status}): ${JSON.stringify(data)}`);
        }
        const results = Array.isArray(data.results) ? data.results : [];
        all.push(...results);
        if (data.has_more !== true || !data.next_cursor) break;
        cursor = String(data.next_cursor);
      }
      return all;
    };

    if (action === 'queryDatabase') {
      const requestedDatabaseId =
        typeof safeBody.databaseId === 'string' ? safeBody.databaseId.trim() : '';
      const { action: _action, databaseId, ...queryPayload } = safeBody;
      const targetDatabaseId = requestedDatabaseId || DATABASE_ID;
      const response = await notionRequest(
        `https://api.notion.com/v1/databases/${targetDatabaseId}/query`,
        'POST',
        queryPayload,
      );
      return res.status(response.status).json(response.data);
    }

    if (action === 'retrievePage') {
      const pageId = typeof safeBody.pageId === 'string' ? safeBody.pageId.trim() : '';
      if (!pageId) {
        return res.status(400).json({ error: 'Missing pageId for retrievePage' });
      }
      const response = await notionRequest(`https://api.notion.com/v1/pages/${pageId}`, 'GET');
      return res.status(response.status).json(response.data);
    }

    if (action === 'updatePage') {
      const pageId = typeof safeBody.pageId === 'string' ? safeBody.pageId.trim() : '';
      const payload =
        safeBody.payload && typeof safeBody.payload === 'object' && !Array.isArray(safeBody.payload)
          ? safeBody.payload
          : null;
      if (!pageId || payload == null) {
        return res.status(400).json({ error: 'Missing pageId or payload for updatePage' });
      }
      const response = await notionRequest(
        `https://api.notion.com/v1/pages/${pageId}`,
        'PATCH',
        payload,
      );
      return res.status(response.status).json(response.data);
    }

    if (action === 'registerPushToken') {
      const userId = typeof safeBody.userId === 'string' ? safeBody.userId.trim() : '';
      const token = typeof safeBody.token === 'string' ? safeBody.token.trim() : '';
      if (!userId || !token) {
        return res.status(400).json({ error: 'Missing userId or token for registerPushToken' });
      }

      const page = await notionRequest(`https://api.notion.com/v1/pages/${userId}`, 'GET');
      if (page.status !== 200) {
        return res.status(page.status).json(page.data);
      }
      const props = page.data && typeof page.data === 'object' ? page.data.properties : {};
      const tokenKey = findKeyByCandidates(props, [
        'FCM_TOKEN',
        'PUSH_TOKEN',
        'TOKEN_PUSH',
      ]);
      if (!tokenKey) {
        return res.status(400).json({
          error: 'Missing token property on user page',
          details: 'Create a rich_text property named FCM_TOKEN in Cronometristi DB',
        });
      }

      const updatePayload = {
        properties: {
          [tokenKey]: {
            rich_text: [
              {
                type: 'text',
                text: { content: token },
              },
            ],
          },
        },
      };

      const updated = await notionRequest(
        `https://api.notion.com/v1/pages/${userId}`,
        'PATCH',
        updatePayload,
      );
      return res.status(updated.status).json(updated.data);
    }

    if (action === 'notifyAdminsAvailability') {
      if (!FIREBASE_PROJECT_ID || !FIREBASE_CLIENT_EMAIL || !FIREBASE_PRIVATE_KEY) {
        return res.status(500).json({
          error:
            'Missing FIREBASE_PROJECT_ID, FIREBASE_CLIENT_EMAIL, or FIREBASE_PRIVATE_KEY',
        });
      }

      const userId = typeof safeBody.userId === 'string' ? safeBody.userId.trim() : '';
      const userName = typeof safeBody.userName === 'string' ? safeBody.userName.trim() : 'Un utente';
      const garaTitolo =
        typeof safeBody.garaTitolo === 'string' ? safeBody.garaTitolo.trim() : 'una gara';

      const users = await queryAllDatabasePages(DATABASE_ID);
      const tokenCandidates = ['FCM_TOKEN', 'PUSH_TOKEN', 'TOKEN_PUSH'];
      const tokens = new Set();

      for (const row of users) {
        if (!row || typeof row !== 'object') continue;
        if (typeof row.id === 'string' && row.id === userId) continue;

        const props = row.properties && typeof row.properties === 'object' ? row.properties : {};
        if (!isAdminFromProperties(props)) continue;

        const tokenKey = findKeyByCandidates(props, tokenCandidates);
        if (!tokenKey) continue;
        const token = extractRichText(props[tokenKey]);
        if (token) tokens.add(token);
      }

      const tokenList = [...tokens];
      if (tokenList.length === 0) {
        return res.status(200).json({
          ok: true,
          sent: 0,
          reason: 'No admin tokens available',
        });
      }

      const accessToken = await getFirebaseAccessToken();
      const bodyText = `${userName} si e reso disponibile per ${garaTitolo}`;
      const fcmUrl = `https://fcm.googleapis.com/v1/projects/${FIREBASE_PROJECT_ID}/messages:send`;
      const results = await Promise.allSettled(
        tokenList.map((token) =>
          fetch(fcmUrl, {
            method: 'POST',
            headers: {
              Authorization: `Bearer ${accessToken}`,
              'Content-Type': 'application/json',
            },
            body: JSON.stringify({
              message: {
                token,
                notification: {
                  title: 'Nuova disponibilita',
                  body: bodyText,
                },
                data: {
                  type: 'availability',
                  garaTitolo,
                  userName,
                },
              },
            }),
          }),
        ),
      );

      let sent = 0;
      const errors = [];
      for (const result of results) {
        if (result.status === 'rejected') {
          errors.push(String(result.reason));
          continue;
        }
        const response = result.value;
        const data = await response.json();
        if (response.ok) {
          sent += 1;
        } else {
          errors.push(JSON.stringify(data));
        }
      }

      return res.status(200).json({
        ok: true,
        sent,
        attempted: tokenList.length,
        errors,
      });
    }

    return res.status(400).json({ error: `Unsupported action: ${action}` });
  } catch (error) {
    return res.status(500).json({
      error: 'Failed to query Notion API',
      details: error instanceof Error ? error.message : String(error),
    });
  }
}
