import assert from 'node:assert/strict';
import { createHmac } from 'node:crypto';
import test from 'node:test';

import handler, { filesWithReport } from '../api/notion-file-upload.js';

process.env.NOTION_TOKEN = 'test-notion-token';
process.env.DATABASE_ID = 'test-users-database';
process.env.SESSION_SECRET = 'test-session-secret-with-enough-entropy';

function responseRecorder() {
  return {
    statusCode: 200,
    headers: {},
    body: null,
    setHeader(name, value) {
      this.headers[name] = value;
    },
    status(code) {
      this.statusCode = code;
      return this;
    },
    json(value) {
      this.body = value;
      return this;
    },
    end() {
      return this;
    },
  };
}

function signedSession() {
  const payload = Buffer.from(
    JSON.stringify({ sub: 'user-page', exp: Math.floor(Date.now() / 1000) + 300 }),
  ).toString('base64url');
  const signature = createHmac('sha256', process.env.SESSION_SECRET)
    .update(payload)
    .digest('base64url');
  return `${payload}.${signature}`;
}

test('replaces only a report with the same name and preserves other files', () => {
  const result = filesWithReport(
    [
      { name: 'Verbale.pdf', type: 'external', external: { url: 'https://example.test' } },
      { name: 'Rapporto servizio.pdf', type: 'file', file: { url: 'https://notion.test' } },
    ],
    'Rapporto servizio.pdf',
    'upload-id',
  );

  assert.equal(result.length, 2);
  assert.equal(result[0].name, 'Verbale.pdf');
  assert.deepEqual(result[1], {
    name: 'Rapporto servizio.pdf',
    type: 'file_upload',
    file_upload: { id: 'upload-id' },
  });
});

test('uploads one PDF and appends it to the race Files & media property', async () => {
  const originalFetch = global.fetch;
  const calls = [];
  global.fetch = async (url, options) => {
    calls.push({ url: String(url), options });
    if (String(url).includes('/pages/') && options.method === 'GET') {
      return {
        status: 200,
        async json() {
          return {
            parent: { database_id: '2b1de089ef9580729622ff9543046cbc' },
            properties: {
              'Files & media': {
                type: 'files',
                files: [{ name: 'Altro.pdf', type: 'external', external: { url: 'https://x' } }],
              },
            },
          };
        },
      };
    }
    if (String(url).endsWith('/file_uploads')) {
      return { status: 200, async json() { return { id: 'upload-id' }; } };
    }
    return { status: 200, ok: true, async json() { return { ok: true }; } };
  };

  try {
    const filename = Buffer.from('Rapporto servizio - Gara.pdf').toString('base64url');
    const req = {
      method: 'POST',
      headers: {
        origin: 'https://appkronos-1d181.web.app',
        authorization: `Bearer ${signedSession()}`,
        'x-notion-page-ids': '123456781234123412341234567890ab',
        'x-report-filename': filename,
      },
      body: Buffer.from('%PDF-test'),
    };
    const res = responseRecorder();
    await handler(req, res);

    assert.equal(res.statusCode, 200);
    assert.deepEqual(res.body, { uploaded: true, attached: 1 });
    assert.equal(calls.filter((call) => call.url.includes('/file_uploads')).length, 2);
    const patchCall = calls.find((call) => call.options.method === 'PATCH');
    const patchBody = JSON.parse(patchCall.options.body);
    assert.equal(patchBody.properties['Files & media'].files[0].name, 'Altro.pdf');
    assert.equal(
      patchBody.properties['Files & media'].files[1].file_upload.id,
      'upload-id',
    );
  } finally {
    global.fetch = originalFetch;
  }
});
