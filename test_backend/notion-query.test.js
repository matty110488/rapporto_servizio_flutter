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
  forecastDayOffset,
  reportFilesFromPage,
  visibleNotificationRecords,
  weatherCodeLabel,
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

test('weather forecasts are limited to today and the following seven days', () => {
  const now = new Date('2026-07-24T18:30:00Z');
  assert.equal(forecastDayOffset('2026-07-24', now), 0);
  assert.equal(forecastDayOffset('2026-07-31', now), 7);
  assert.equal(forecastDayOffset('2026-08-01', now), 8);
  assert.equal(
    forecastDayOffset('2026-07-25', new Date('2026-07-24T22:30:00Z')),
    0,
  );
  assert.equal(forecastDayOffset('not-a-date', now), null);
  assert.equal(weatherCodeLabel(0), 'Sereno');
  assert.equal(weatherCodeLabel(63), 'Pioggia');
  assert.equal(weatherCodeLabel(96), 'Temporali');
  assert.equal(weatherCodeLabel(null), 'Variabile');
});

test('returns a compact race weather summary for an authenticated user', async () => {
  const originalFetch = global.fetch;
  const forecastDate = new Date();
  forecastDate.setUTCDate(forecastDate.getUTCDate() + 3);
  const date = forecastDate.toISOString().slice(0, 10);
  const requestedUrls = [];
  global.fetch = async (url) => {
    requestedUrls.push(String(url));
    if (String(url).includes('geocoding-api.open-meteo.com')) {
      return {
        ok: true,
        async json() {
          return {
            results: [
              {
                name: 'Sondrio',
                admin1: 'Lombardia',
                country: 'Italia',
                latitude: 46.17,
                longitude: 9.87,
              },
            ],
          };
        },
      };
    }
    return {
      ok: true,
      async json() {
        return {
          daily: {
            time: [date],
            weather_code: [2],
            temperature_2m_min: [9.4],
            temperature_2m_max: [18.7],
            precipitation_probability_max: [20],
            wind_speed_10m_max: [13.2],
          },
        };
      },
    };
  };

  try {
    const req = {
      method: 'POST',
      headers: {
        origin: 'https://matty110488.github.io',
        authorization: `Bearer ${signedSession({ sub: 'weather-user' })}`,
      },
      body: {
        action: 'getRaceWeather',
        location: 'Sondrio weather test',
        date,
      },
    };
    const res = responseRecorder();

    await handler(req, res);

    assert.equal(res.statusCode, 200);
    assert.equal(res.body.weather.description, 'Parzialmente nuvoloso');
    assert.equal(res.body.weather.precipitationProbability, 20);
    assert.equal(res.body.weather.location, 'Sondrio, Lombardia, Italia');
    assert.equal(requestedUrls.length, 2);
  } finally {
    global.fetch = originalFetch;
  }
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
              'NOTA SPESE APP': {
                rich_text: [{ plain_text: '{"total":100}' }],
              },
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
    assert.equal(
      Object.hasOwn(
        dscResponse.body.results[0].properties,
        'NOTA SPESE APP',
      ),
      false,
    );

    const otherResponse = responseRecorder();
    await handler(request('another-user'), otherResponse);
    assert.equal(otherResponse.statusCode, 200);
    assert.deepEqual(otherResponse.body.results, []);
  } finally {
    global.fetch = originalFetch;
  }
});

test('private expense snapshots are stripped from ordinary race reads', () => {
  const page = {
    properties: {
      GARA: { title: [{ plain_text: 'Gara' }] },
      'NOTA SPESE APP': { rich_text: [{ plain_text: '{"total":100}' }] },
    },
  };

  const sanitized = withoutRaceReportFiles(page);

  assert.equal(Object.hasOwn(sanitized.properties, 'GARA'), true);
  assert.equal(Object.hasOwn(sanitized.properties, 'NOTA SPESE APP'), false);
});

test('expense report summaries are restricted to administrators', async () => {
  const req = {
    method: 'POST',
    headers: {
      origin: 'https://appkronos-1d181.web.app',
      authorization: `Bearer ${signedSession({ sub: 'ordinary-user' })}`,
    },
    body: {
      action: 'queryAdminExpenseReports',
      databaseId: '2b1de089ef9580729622ff9543046cbc',
    },
  };
  const res = responseRecorder();

  await handler(req, res);

  assert.equal(res.statusCode, 403);
  assert.equal(res.body.error, 'Administrator access required');
});

test('expense estimates are calculated for administrators without Notion writes', async () => {
  const originalFetch = global.fetch;
  let fetchCalled = false;
  global.fetch = async () => {
    fetchCalled = true;
    throw new Error('Notion should not be called while calculating an estimate');
  };
  try {
    const req = {
      method: 'POST',
      headers: {
        origin: 'https://appkronos-1d181.web.app',
        authorization: `Bearer ${signedSession({ sub: 'admin-user', admin: true })}`,
      },
      body: {
        action: 'calculateExpenseEstimate',
        report: {
          gara: { nome: 'Preventivo corsa', sport: 'Corsa' },
          cronometristi: [
            {
              nome: 'Cronometrista 1',
              segreteria: 'NO',
              giorni: [
                { data: '2026-08-01', ore: 4, km: 10, spese: 0 },
              ],
            },
          ],
          pacchetto: { giornate: ['2026-08-01'] },
          apparecchiature: [],
        },
      },
    };
    const res = responseRecorder();

    await handler(req, res);

    assert.equal(res.statusCode, 200);
    assert.equal(res.body.estimate.total, 83.6);
    assert.equal(res.body.estimate.race.title, 'Preventivo corsa');
    assert.equal(fetchCalled, false);
  } finally {
    global.fetch = originalFetch;
  }
});

test('expense estimates are restricted to administrators', async () => {
  const req = {
    method: 'POST',
    headers: {
      origin: 'https://appkronos-1d181.web.app',
      authorization: `Bearer ${signedSession({ sub: 'ordinary-user' })}`,
    },
    body: { action: 'calculateExpenseEstimate', report: {} },
  };
  const res = responseRecorder();

  await handler(req, res);

  assert.equal(res.statusCode, 403);
  assert.equal(res.body.error, 'Administrator access required');
});

test('freezes a server-calculated expense snapshot on the primary race', async () => {
  const originalFetch = global.fetch;
  const originalTariffs = process.env.EXPENSE_TARIFFS_JSON;
  const calls = [];
  process.env.EXPENSE_TARIFFS_JSON = JSON.stringify({
    versions: [
      {
        id: 'test-2026',
        validFrom: '2026-04-01',
        kmRate: 0.36,
        ordinary: { baseHours: 4, baseAmount: 30, additionalHourly: 6 },
        specialist: { baseHours: 4, baseAmount: 40, additionalHourly: 10 },
        dataProcessingDaily: 70,
        equipment: {},
        sports: { nuoto: { dailyOrganization: 50 } },
      },
    ],
  });
  global.fetch = async (url, options) => {
    calls.push({ url: String(url), options });
    if (String(url).includes('/pages/') && options.method === 'GET') {
      return {
        status: 200,
        async json() {
          return {
            parent: { database_id: '2b1de089ef9580729622ff9543046cbc' },
            properties: { DSC: { relation: [] } },
          };
        },
      };
    }
    if (String(url).includes('/databases/') && options.method === 'GET') {
      return { status: 200, async json() { return { properties: {} }; } };
    }
    return { status: 200, async json() { return { ok: true }; } };
  };

  try {
    const req = {
      method: 'POST',
      headers: {
        origin: 'https://appkronos-1d181.web.app',
        authorization: `Bearer ${signedSession({ sub: 'report-author' })}`,
      },
      body: {
        action: 'saveExpenseReport',
        pageIds: ['race-page'],
        report: {
          gara: { nome: 'Nuoto test', sport: 'Nuoto' },
          cronometristi: [
            {
              nome: 'Mario Rossi',
              segreteria: 'NO',
              giorni: [
                { data: '2026-08-01', ore: '4', km: '10', spese: '' },
              ],
            },
          ],
          apparecchiature: [],
        },
      },
    };
    const res = responseRecorder();
    await handler(req, res);

    assert.equal(res.statusCode, 200);
    assert.equal(res.body.expense.total, 83.6);
    const pagePatch = calls.find(
      (call) => call.url.includes('/pages/') && call.options.method === 'PATCH',
    );
    assert.ok(pagePatch);
    const body = JSON.parse(pagePatch.options.body);
    assert.ok(body.properties['NOTA SPESE APP'].rich_text.length > 0);
  } finally {
    global.fetch = originalFetch;
    if (originalTariffs == null) {
      delete process.env.EXPENSE_TARIFFS_JSON;
    } else {
      process.env.EXPENSE_TARIFFS_JSON = originalTariffs;
    }
  }
});
