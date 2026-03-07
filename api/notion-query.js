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
  if (!origin) return false;
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
    res.setHeader('Access-Control-Allow-Origin', origin);
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

  const { NOTION_TOKEN, DATABASE_ID } = process.env;
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

    let notionUrl = '';
    let notionMethod = 'POST';
    let notionPayload;

    if (action === 'queryDatabase') {
      const requestedDatabaseId =
        typeof safeBody.databaseId === 'string' ? safeBody.databaseId.trim() : '';
      const { action: _action, databaseId, ...queryPayload } = safeBody;
      const targetDatabaseId = requestedDatabaseId || DATABASE_ID;
      notionUrl = `https://api.notion.com/v1/databases/${targetDatabaseId}/query`;
      notionPayload = queryPayload;
    } else if (action === 'retrievePage') {
      const pageId = typeof safeBody.pageId === 'string' ? safeBody.pageId.trim() : '';
      if (!pageId) {
        return res.status(400).json({ error: 'Missing pageId for retrievePage' });
      }
      notionUrl = `https://api.notion.com/v1/pages/${pageId}`;
      notionMethod = 'GET';
    } else if (action === 'updatePage') {
      const pageId = typeof safeBody.pageId === 'string' ? safeBody.pageId.trim() : '';
      const payload =
        safeBody.payload && typeof safeBody.payload === 'object' && !Array.isArray(safeBody.payload)
          ? safeBody.payload
          : null;
      if (!pageId || payload == null) {
        return res.status(400).json({ error: 'Missing pageId or payload for updatePage' });
      }
      notionUrl = `https://api.notion.com/v1/pages/${pageId}`;
      notionMethod = 'PATCH';
      notionPayload = payload;
    } else {
      return res.status(400).json({ error: `Unsupported action: ${action}` });
    }

    const notionResponse = await fetch(notionUrl, {
      method: notionMethod,
      headers: {
        Authorization: `Bearer ${NOTION_TOKEN}`,
        'Notion-Version': '2022-06-28',
        'Content-Type': 'application/json',
      },
      body: notionMethod === 'GET' ? undefined : JSON.stringify(notionPayload ?? {}),
    });

    const data = await notionResponse.json();
    return res.status(notionResponse.status).json(data);
  } catch (error) {
    return res.status(500).json({
      error: 'Failed to query Notion API',
      details: error instanceof Error ? error.message : String(error),
    });
  }
}
