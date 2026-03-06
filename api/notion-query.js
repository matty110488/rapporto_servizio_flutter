const ALLOWED_ORIGIN = 'https://matty110488.github.io';

function setCorsHeaders(req, res) {
  if (req.headers.origin === ALLOWED_ORIGIN) {
    res.setHeader('Access-Control-Allow-Origin', ALLOWED_ORIGIN);
  }
  res.setHeader('Vary', 'Origin');
  res.setHeader('Access-Control-Allow-Methods', 'POST, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type, Authorization');
}

module.exports = async function handler(req, res) {
  setCorsHeaders(req, res);

  if (req.method === 'OPTIONS') {
    return res.status(204).end();
  }

  if (req.method !== 'POST') {
    return res.status(405).json({ error: 'Method not allowed' });
  }

  const { NOTION_TOKEN, DATABASE_ID } = process.env;
  if (!NOTION_TOKEN || !DATABASE_ID) {
    return res.status(500).json({ error: 'Missing NOTION_TOKEN or DATABASE_ID' });
  }

  try {
    const notionUrl = `https://api.notion.com/v1/databases/${DATABASE_ID}/query`;
    const body =
      typeof req.body === 'string' ? req.body : JSON.stringify(req.body ?? {});

    const notionResponse = await fetch(notionUrl, {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${NOTION_TOKEN}`,
        'Notion-Version': '2022-06-28',
        'Content-Type': 'application/json',
      },
      body,
    });

    const data = await notionResponse.json();
    return res.status(notionResponse.status).json(data);
  } catch (error) {
    return res.status(500).json({
      error: 'Failed to query Notion API',
      details: error instanceof Error ? error.message : String(error),
    });
  }
};
