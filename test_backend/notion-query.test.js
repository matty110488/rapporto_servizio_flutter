import assert from 'node:assert/strict';
import test from 'node:test';

import handler from '../api/notion-query.js';

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

test('creates passkey authentication options for the production web origin', async () => {
  const req = {
    method: 'POST',
    headers: { origin: 'https://matty110488.github.io' },
    body: { action: 'passkeyAuthenticationOptions' },
  };
  const res = responseRecorder();

  await handler(req, res);

  assert.equal(res.statusCode, 200);
  assert.equal(res.body.options.rpId, 'matty110488.github.io');
  assert.equal(res.body.options.userVerification, 'required');
  assert.equal(typeof res.body.options.challenge, 'string');
  assert.ok(res.body.options.challenge.length > 20);
  assert.equal(typeof res.body.challengeToken, 'string');
});

test('keeps data actions unavailable without a signed session', async () => {
  const req = {
    method: 'POST',
    headers: { origin: 'https://matty110488.github.io' },
    body: {
      action: 'queryDatabase',
      databaseId: '2afde089ef9580e2b0e7d19d44f3a3f6',
    },
  };
  const res = responseRecorder();

  await handler(req, res);

  assert.equal(res.statusCode, 401);
  assert.deepEqual(res.body, { error: 'Authentication required' });
});

test('first access stays generic when username and email do not match', async () => {
  const originalFetch = global.fetch;
  global.fetch = async () => ({
    status: 200,
    async json() {
      return {
        results: [
          {
            id: 'notion-user-id',
            properties: {
              USERNAME: { rich_text: [{ plain_text: 'mario' }] },
              EMAIL: { email: 'mario@example.com' },
            },
          },
        ],
        has_more: false,
      };
    },
  });

  try {
    const req = {
      method: 'POST',
      headers: { origin: 'https://matty110488.github.io' },
      body: {
        action: 'startFirstAccess',
        username: 'utente-errato',
        email: 'mario@example.com',
      },
    };
    const res = responseRecorder();
    await handler(req, res);

    assert.equal(res.statusCode, 200);
    assert.deepEqual(res.body, { ok: true, canSendEmail: false });
  } finally {
    global.fetch = originalFetch;
  }
});
