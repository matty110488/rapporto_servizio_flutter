import assert from 'node:assert/strict';
import { createHmac } from 'node:crypto';
import test from 'node:test';

import handler, {
  DEFAULT_REPORT_NOTIFICATION_EMAIL,
  hideAllNotificationRecords,
  hideNotificationRecord,
  isReportReceivedTransition,
  notificationAlreadyRecorded,
  canViewRaceReports,
  reportFilesFromPage,
  visibleNotificationRecords,
  withoutRaceReportFiles,
} from '../api/notion-query.js';

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

function signedSession({ sub, admin = false }) {
  const payload = Buffer.from(
    JSON.stringify({
      sub,
      admin,
      exp: Math.floor(Date.now() / 1000) + 300,
    }),
  ).toString('base64url');
  const signature = createHmac('sha256', process.env.SESSION_SECRET)
    .update(payload)
    .digest('base64url');
  return `${payload}.${signature}`;
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

test('creates passkey authentication options for the TEST web origin', async () => {
  const req = {
    method: 'POST',
    headers: { origin: 'https://appkronos-1d181.web.app' },
    body: { action: 'passkeyAuthenticationOptions' },
  };
  const res = responseRecorder();

  await handler(req, res);

  assert.equal(res.statusCode, 200);
  assert.equal(res.body.options.rpId, 'appkronos-1d181.web.app');
  assert.equal(res.headers['Access-Control-Allow-Origin'], req.headers.origin);
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

test('hiding a notification preserves its delivery key for deduplication', () => {
  const records = [
    {
      id: 'notice-1',
      type: 'designation',
      garaId: 'gara-1',
      eventKey: 'designation:gara-1:edit-1',
      read: false,
      hidden: false,
    },
  ];

  const hiddenRecords = hideNotificationRecord(records, 'notice-1');

  assert.equal(hiddenRecords[0].hidden, true);
  assert.equal(hiddenRecords[0].read, true);
  assert.deepEqual(visibleNotificationRecords(hiddenRecords), []);
  assert.equal(
    notificationAlreadyRecorded(hiddenRecords, {
      type: 'designation',
      garaId: 'gara-1',
      eventKey: 'designation:gara-1:edit-1',
    }),
    true,
  );
});

test('clearing notifications hides records without losing delivery history', () => {
  const records = [
    { id: 'notice-1', eventKey: 'event-1', read: false },
    { id: 'notice-2', eventKey: 'event-2', read: true },
  ];

  const hiddenRecords = hideAllNotificationRecords(records);

  assert.equal(hiddenRecords.every((entry) => entry.hidden), true);
  assert.equal(hiddenRecords.every((entry) => entry.read), true);
  assert.deepEqual(visibleNotificationRecords(hiddenRecords), []);
  assert.deepEqual(
    hiddenRecords.map((entry) => entry.eventKey),
    ['event-1', 'event-2'],
  );
});

test('report notification targets Mattia only on a real received-status transition', () => {
  assert.equal(DEFAULT_REPORT_NOTIFICATION_EMAIL, 'tognoli.mt@gmail.com');
  assert.equal(
    isReportReceivedTransition('IN PROGRESS', 'RAPPORTINO RICEVUTO'),
    true,
  );
  assert.equal(
    isReportReceivedTransition(
      'RAPPORTINO RICEVUTO',
      'RAPPORTINO RICEVUTO',
    ),
    false,
  );
  assert.equal(
    isReportReceivedTransition('IN PROGRESS', 'GARA COMPLETATA'),
    false,
  );
});

test('report archive access is limited to the race DSC and admins', () => {
  const page = {
    properties: {
      DSC: {
        relation: [{ id: 'aaaa-bbbb-cccc-dddd' }],
      },
    },
  };

  assert.equal(canViewRaceReports(page, { sub: 'aaaabbbbccccdddd' }), true);
  assert.equal(canViewRaceReports(page, { sub: 'another-user' }), false);
  assert.equal(canViewRaceReports(page, { sub: 'another-user', admin: true }), true);
});

test('only generated report PDFs are exposed by the archive', () => {
  const page = {
    properties: {
      'Files & media': {
        files: [
          {
            name: 'Rapporto servizio - Gara.pdf',
            file: { url: 'https://notion.test/report' },
          },
          { name: 'Foto.jpg', file: { url: 'https://notion.test/photo' } },
          { name: 'Rapporto servizio - incompleto.pdf', file: {} },
        ],
      },
    },
  };

  assert.deepEqual(reportFilesFromPage(page), [
    {
      name: 'Rapporto servizio - Gara.pdf',
      file: { url: 'https://notion.test/report' },
    },
  ]);
  assert.equal(
    Object.hasOwn(withoutRaceReportFiles(page).properties, 'Files & media'),
    false,
  );
});

test('report archive endpoint returns Notion PDFs only to an authorized DSC', async () => {
  const originalFetch = global.fetch;
  global.fetch = async () => ({
    status: 200,
    async json() {
      return {
        results: [
          {
            id: 'race-page',
            properties: {
              DSC: { relation: [{ id: 'race-dsc' }] },
              'Files & media': {
                files: [
                  {
                    name: 'Rapporto servizio - Gara.pdf',
                    file: { url: 'https://notion.test/report' },
                  },
                ],
              },
            },
          },
        ],
        has_more: false,
      };
    },
  });

  try {
    const request = (sub) => ({
      method: 'POST',
      headers: {
        origin: 'https://matty110488.github.io',
        authorization: `Bearer ${signedSession({ sub })}`,
      },
      body: {
        action: 'queryReportArchive',
        databaseId: '2b1de089ef9580729622ff9543046cbc',
      },
    });

    const dscResponse = responseRecorder();
    await handler(request('race-dsc'), dscResponse);
    assert.equal(dscResponse.statusCode, 200);
    assert.equal(dscResponse.body.results.length, 1);

    const otherResponse = responseRecorder();
    await handler(request('another-user'), otherResponse);
    assert.equal(otherResponse.statusCode, 200);
    assert.deepEqual(otherResponse.body.results, []);
  } finally {
    global.fetch = originalFetch;
  }
});
