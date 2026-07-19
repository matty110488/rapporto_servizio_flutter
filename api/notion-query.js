import { createHmac, createSign, timingSafeEqual } from 'node:crypto';
import {
  generateAuthenticationOptions,
  generateRegistrationOptions,
  verifyAuthenticationResponse,
  verifyRegistrationResponse,
} from '@simplewebauthn/server';

const DEFAULT_ALLOWED_ORIGINS = [
  'https://matty110488.github.io',
  'https://rapporto-servizio-flutter.vercel.app',
  'https://appkronos-1d181.web.app',
  'https://appkronos-1d181.firebaseapp.com',
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
  res.setHeader('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type, Authorization');
}

export default async function handler(req, res) {
  setCorsHeaders(req, res);

  if (req.method === 'OPTIONS') {
    return res.status(204).end();
  }

  if (req.method !== 'POST' && req.method !== 'GET') {
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
    PUBLIC_APP_URL,
    CRON_SECRET,
  } = process.env;
  if (!NOTION_TOKEN || !DATABASE_ID) {
    return res.status(500).json({ error: 'Missing NOTION_TOKEN or DATABASE_ID' });
  }

  try {
    const rawBody = req.method === 'GET'
      ? {
          action: 'notifyDesignationsForSentStatus',
          recentHours: 1,
          source: 'cron',
        }
      : typeof req.body === 'string'
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

    const extractPushTokens = (field) => {
      const raw = extractRichText(field);
      if (!raw) return [];
      try {
        const decoded = JSON.parse(raw);
        if (Array.isArray(decoded)) {
          return decoded
            .map((entry) => {
              if (typeof entry === 'string') return entry.trim();
              if (entry && typeof entry === 'object' && typeof entry.token === 'string') {
                if (entry.enabled === false) return '';
                return entry.token.trim();
              }
              return '';
            })
            .filter(Boolean);
        }
      } catch {
        // Legacy field format: a single raw token.
      }
      return [raw];
    };

    const extractPushTokenRecords = (field) => {
      const raw = extractRichText(field);
      if (!raw) return [];
      try {
        const decoded = JSON.parse(raw);
        if (Array.isArray(decoded)) {
          return decoded
            .map((entry) => {
              if (typeof entry === 'string') {
                const token = entry.trim();
                return token ? { token, legacy: true } : null;
              }
              if (entry && typeof entry === 'object' && typeof entry.token === 'string') {
                const token = entry.token.trim();
                if (!token) return null;
                return {
                  token,
                  deviceId: typeof entry.deviceId === 'string' ? entry.deviceId.trim() : '',
                  updatedAt: typeof entry.updatedAt === 'string' ? entry.updatedAt : '',
                  enabled: entry.enabled !== false,
                };
              }
              return null;
            })
            .filter(Boolean);
        }
      } catch {
        // Legacy field format: a single raw token.
      }
      return [{ token: raw, legacy: true }];
    };

    const pushTokenRichText = (records) => {
      const serialized = JSON.stringify(records);
      const chunks = serialized.match(/.{1,1900}/gs) || [];
      return chunks.map((content) => ({
        type: 'text',
        text: { content },
      }));
    };

    const extractNotificationRecords = (field) => {
      const raw = extractRichText(field);
      if (!raw) return [];
      try {
        const decoded = JSON.parse(raw);
        if (!Array.isArray(decoded)) return [];
        return decoded
          .map((entry) => {
            if (!entry || typeof entry !== 'object') return null;
            return {
              id:
                typeof entry.id === 'string' && entry.id.trim()
                  ? entry.id.trim()
                  : `${Date.now()}-${Math.random().toString(16).slice(2)}`,
              title: typeof entry.title === 'string' ? entry.title : 'Notifica',
              body: typeof entry.body === 'string' ? entry.body : '',
              type: typeof entry.type === 'string' ? entry.type : '',
              garaId: typeof entry.garaId === 'string' ? entry.garaId : '',
              eventKey: typeof entry.eventKey === 'string' ? entry.eventKey : '',
              createdAt:
                typeof entry.createdAt === 'string'
                  ? entry.createdAt
                  : new Date().toISOString(),
              read: entry.read === true,
            };
          })
          .filter(Boolean);
      } catch {
        return [];
      }
    };

    const notificationRichText = (records) => {
      const serialized = JSON.stringify(records);
      const chunks = serialized.match(/.{1,1900}/gs) || [];
      return chunks.map((content) => ({
        type: 'text',
        text: { content },
      }));
    };

    const appBaseUrl =
      typeof PUBLIC_APP_URL === 'string' && PUBLIC_APP_URL.trim()
        ? PUBLIC_APP_URL.trim().replace(/\/$/, '')
        : 'https://matty110488.github.io/rapporto_servizio_flutter';

    const notificationLinkForData = (data = {}) => {
      const garaId = typeof data.garaId === 'string' ? data.garaId.trim() : '';
      if (!garaId) return appBaseUrl;
      return `${appBaseUrl}/?garaId=${encodeURIComponent(garaId)}`;
    };

    const sendFcmMessages = async ({ tokens, title, body, data = {} }) => {
      if (!FIREBASE_PROJECT_ID || !FIREBASE_CLIENT_EMAIL || !FIREBASE_PRIVATE_KEY) {
        throw new Error(
          'Missing FIREBASE_PROJECT_ID, FIREBASE_CLIENT_EMAIL, or FIREBASE_PRIVATE_KEY',
        );
      }

      const tokenList = [...new Set(tokens.filter(Boolean))];
      if (tokenList.length === 0) {
        return { sent: 0, attempted: 0, errors: [] };
      }

      const accessToken = await getFirebaseAccessToken();
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
                notification: { title, body },
                webpush: {
                  headers: {
                    Urgency: 'high',
                  },
                  notification: {
                    title,
                    body,
                    icon: 'icons/Icon-192.png',
                  },
                  fcm_options: {
                    link: notificationLinkForData(data),
                  },
                },
                data: Object.fromEntries(
                  Object.entries({
                    ...data,
                    title,
                    body,
                  }).map(([key, value]) => [key, value == null ? '' : String(value)]),
                ),
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
        const text = await response.text();
        let responseData = {};
        try {
          responseData = text ? JSON.parse(text) : {};
        } catch {
          responseData = { raw: text };
        }
        if (response.ok) {
          sent += 1;
        } else {
          errors.push(JSON.stringify(responseData));
        }
      }

      return { sent, attempted: tokenList.length, errors };
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

    const sessionSecret = process.env.SESSION_SECRET || NOTION_TOKEN;
    const signPayload = (value) => {
      const payload = toBase64Url(JSON.stringify(value));
      const signature = createHmac('sha256', sessionSecret)
        .update(payload)
        .digest('base64url');
      return `${payload}.${signature}`;
    };
    const verifyPayload = (token) => {
      if (typeof token !== 'string') return null;
      const [payload, signature, extra] = token.split('.');
      if (!payload || !signature || extra) return null;
      const expected = createHmac('sha256', sessionSecret)
        .update(payload)
        .digest('base64url');
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
          typeof decoded.exp !== 'number' ||
          decoded.exp <= Math.floor(Date.now() / 1000)
        ) {
          return null;
        }
        return decoded;
      } catch {
        return null;
      }
    };
    const signSession = (userId, isAdmin) => {
      return signPayload({
        sub: userId,
        admin: isAdmin === true,
        exp: Math.floor(Date.now() / 1000) + 60 * 60 * 24 * 7,
      });
    };

    const verifySession = (authorization) => {
      if (typeof authorization !== 'string' || !authorization.startsWith('Bearer ')) return null;
      const decoded = verifyPayload(authorization.slice('Bearer '.length).trim());
      return decoded && typeof decoded.sub === 'string' && decoded.sub.length > 0
        ? decoded
        : null;
    };

    const sanitizeUserPage = (page) => {
      if (!page || typeof page !== 'object') return null;
      const properties =
        page.properties && typeof page.properties === 'object' ? page.properties : {};
      const privatePropertyNames = new Set([
        'PASSWORD',
        'PASSKEYS',
        'FCM_TOKEN',
        'FCM_NOTIFICATIONS',
        'PUSH_TOKEN',
        'PUSH_NOTIFICATIONS',
        'TOKEN_PUSH',
        'NOTIFICHE_PUSH',
      ]);
      const safeProperties = Object.fromEntries(
        Object.entries(properties).filter(
          ([key]) => !privatePropertyNames.has(key.trim().toUpperCase()),
        ),
      );
      return { ...page, properties: safeProperties };
    };

    const extractPropertyText = (field) => {
      if (!field || typeof field !== 'object') return '';
      if (typeof field.email === 'string') return field.email.trim();
      for (const key of ['rich_text', 'title']) {
        const list = Array.isArray(field[key]) ? field[key] : [];
        const value = list.map((entry) => entry?.plain_text || '').join('').trim();
        if (value) return value;
      }
      return '';
    };

    const extractStatusName = (field) => {
      if (!field || typeof field !== 'object') return '';
      const status = field.status;
      if (status && typeof status === 'object' && typeof status.name === 'string') {
        return status.name.trim();
      }
      const select = field.select;
      if (select && typeof select === 'object' && typeof select.name === 'string') {
        return select.name.trim();
      }
      return '';
    };

    const statusNameFromPayload = (properties) => {
      if (!properties || typeof properties !== 'object') return '';
      return extractStatusName(properties.STATUS);
    };

    const extractRelationIds = (field) => {
      if (!field || typeof field !== 'object' || !Array.isArray(field.relation)) return [];
      return field.relation
        .map((entry) =>
          entry && typeof entry === 'object' && typeof entry.id === 'string'
            ? entry.id.trim()
            : '',
        )
        .filter(Boolean);
    };

    const extractPageTitle = (page) => {
      const props = page && typeof page === 'object' ? page.properties : {};
      if (!props || typeof props !== 'object') return 'la gara';
      for (const value of Object.values(props)) {
        if (!value || typeof value !== 'object') continue;
        if (value.type === 'title') {
          const text = extractPropertyText(value);
          if (text) return text;
        }
      }
      return 'la gara';
    };

    const extractDateRangeText = (field) => {
      const date = field && typeof field === 'object' ? field.date : null;
      if (!date || typeof date !== 'object') return '';
      const formatDate = (value) => {
        if (typeof value !== 'string' || !value) return '';
        const [year, month, day] = value.slice(0, 10).split('-');
        if (!year || !month || !day) return value;
        return `${day}/${month}/${year}`;
      };
      const start = formatDate(date.start);
      const end = formatDate(date.end);
      if (start && end && start !== end) return `${start} - ${end}`;
      return start || end || '';
    };

    const extractGaraDateText = (page) => {
      const props = page && typeof page === 'object' ? page.properties : {};
      const key = findKeyByCandidates(props, ['DATA GARA', 'DATA', 'DATE']);
      return key ? extractDateRangeText(props[key]) : '';
    };

    const extractGaraPlaceText = (page) => {
      const props = page && typeof page === 'object' ? page.properties : {};
      const key = findKeyByCandidates(props, [
        "LOCALITA'",
        'LOCALITA',
        'LOCALITÀ',
        'LUOGO',
      ]);
      return key ? extractPropertyText(props[key]) : '';
    };

    const designationBodyForGara = (garaPage) => {
      const garaTitolo = extractPageTitle(garaPage);
      const dateText = extractGaraDateText(garaPage);
      const placeText = extractGaraPlaceText(garaPage);
      const details = [dateText, placeText].filter(Boolean).join(' - ');
      return details
        ? `${garaTitolo}\n${details}`
        : garaTitolo;
    };

    const findProperty = (props, candidates) => {
      if (!props || typeof props !== 'object') return null;
      const wanted = new Set(candidates.map((value) => value.replace(/[^a-z0-9]/gi, '').toLowerCase()));
      for (const [key, value] of Object.entries(props)) {
        const normalized = key.replace(/[^a-z0-9]/gi, '').toLowerCase();
        if (wanted.has(normalized)) return value;
      }
      return null;
    };

    const emailFromUser = (page) =>
      extractPropertyText(findProperty(page?.properties, ['EMAIL', 'E-MAIL', 'MAIL']));

    const usernameFromUser = (page) =>
      extractPropertyText(findProperty(page?.properties, ['USERNAME', 'USER NAME']));

    const firebaseAuth = async () => {
      if (!FIREBASE_PROJECT_ID || !FIREBASE_CLIENT_EMAIL || !FIREBASE_PRIVATE_KEY) {
        throw new Error('Firebase Admin credentials are not configured');
      }
      const [{ cert, getApps, initializeApp }, { getAuth }] = await Promise.all([
        import('firebase-admin/app'),
        import('firebase-admin/auth'),
      ]);
      if (getApps().length === 0) {
        initializeApp({
          credential: cert({
            projectId: FIREBASE_PROJECT_ID,
            clientEmail: FIREBASE_CLIENT_EMAIL,
            privateKey: FIREBASE_PRIVATE_KEY.replace(/\\n/g, '\n'),
          }),
        });
      }
      return getAuth();
    };

    const getPasskeys = (page) => {
      const props = page && typeof page === 'object' ? page.properties : null;
      const key = findKeyByCandidates(props, ['PASSKEYS', 'Passkeys', 'passkeys']);
      if (!key) return [];
      const raw = extractRichText(props[key]);
      if (!raw) return [];
      try {
        const decoded = JSON.parse(raw);
        return Array.isArray(decoded) ? decoded.filter((item) => item && typeof item === 'object') : [];
      } catch {
        return [];
      }
    };

    const ensurePasskeysProperty = async () => {
      const database = await notionRequest(
        `https://api.notion.com/v1/databases/${DATABASE_ID}`,
        'GET',
      );
      if (database.status !== 200) return database;
      if (database.data?.properties?.PASSKEYS) return database;
      return notionRequest(
        `https://api.notion.com/v1/databases/${DATABASE_ID}`,
        'PATCH',
        { properties: { PASSKEYS: { rich_text: {} } } },
      );
    };

    const ensurePushTokenProperty = async () => {
      const database = await notionRequest(
        `https://api.notion.com/v1/databases/${DATABASE_ID}`,
        'GET',
      );
      if (database.status !== 200) return database;
      const props = database.data?.properties;
      const existingKey = findKeyByCandidates(props, [
        'FCM_TOKEN',
        'PUSH_TOKEN',
        'TOKEN_PUSH',
      ]);
      if (existingKey) return database;
      return notionRequest(
        `https://api.notion.com/v1/databases/${DATABASE_ID}`,
        'PATCH',
        { properties: { FCM_TOKEN: { rich_text: {} } } },
      );
    };

    const ensurePushNotificationsProperty = async () => {
      const database = await notionRequest(
        `https://api.notion.com/v1/databases/${DATABASE_ID}`,
        'GET',
      );
      if (database.status !== 200) return database;
      const props = database.data?.properties;
      const existingKey = findKeyByCandidates(props, [
        'FCM_NOTIFICATIONS',
        'PUSH_NOTIFICATIONS',
        'NOTIFICHE_PUSH',
      ]);
      if (existingKey) {
        return { status: 200, data: { key: existingKey } };
      }
      const created = await notionRequest(
        `https://api.notion.com/v1/databases/${DATABASE_ID}`,
        'PATCH',
        { properties: { FCM_NOTIFICATIONS: { rich_text: {} } } },
      );
      if (created.status !== 200) return created;
      return { status: 200, data: { key: 'FCM_NOTIFICATIONS' } };
    };

    const saveNotificationRecords = async (userId, nextRecords) => {
      const ensured = await ensurePushNotificationsProperty();
      if (ensured.status !== 200) return ensured;
      const key = ensured.data?.key || 'FCM_NOTIFICATIONS';
      return notionRequest(
        `https://api.notion.com/v1/pages/${userId}`,
        'PATCH',
        {
          properties: {
            [key]: {
              rich_text: notificationRichText(nextRecords.slice(0, 50)),
            },
          },
        },
      );
    };

    const appendUserNotification = async (userId, notification) => {
      const page = await notionRequest(`https://api.notion.com/v1/pages/${userId}`, 'GET');
      if (page.status !== 200) return page;
      const props = page.data && typeof page.data === 'object' ? page.data.properties : {};
      const notificationKey = findKeyByCandidates(props, [
        'FCM_NOTIFICATIONS',
        'PUSH_NOTIFICATIONS',
        'NOTIFICHE_PUSH',
      ]);
      const existingRecords = notificationKey
        ? extractNotificationRecords(props[notificationKey])
        : [];
      if (notification.eventKey) {
        const alreadyExists = existingRecords.some(
          (entry) => entry.eventKey === notification.eventKey,
        );
        if (alreadyExists) {
          return { status: 200, data: { ok: true, deduped: true } };
        }
      } else if (notification.type === 'designation' && notification.garaId) {
        const alreadyExists = existingRecords.some(
          (entry) =>
            entry.type === notification.type &&
            entry.garaId === notification.garaId,
        );
        if (alreadyExists) {
          return { status: 200, data: { ok: true, deduped: true } };
        }
      }
      const record = {
        id: `${Date.now()}-${Math.random().toString(16).slice(2)}`,
        title: notification.title || 'Notifica',
        body: notification.body || '',
        type: notification.type || '',
        garaId: notification.garaId || '',
        eventKey: notification.eventKey || '',
        createdAt: new Date().toISOString(),
        read: false,
      };
      return saveNotificationRecords(userId, [record, ...existingRecords]);
    };

    const notifyDesignatedCronos = async (garaPage) => {
      const props =
        garaPage && typeof garaPage === 'object' && garaPage.properties
          ? garaPage.properties
          : {};
      const relationKey = findKeyByCandidates(props, [
        'KRONOS DESIGNATI',
        'KRONOS_DESIGNATI',
        'CRONOMETRISTI DESIGNATI',
      ]);
      const kronosIds = relationKey ? extractRelationIds(props[relationKey]) : [];
      const uniqueKronosIds = [...new Set(kronosIds)];
      if (uniqueKronosIds.length === 0) {
        return {
          sent: 0,
          attempted: 0,
          recipients: 0,
          reason: 'No designated cronos',
        };
      }

      const garaTitolo = extractPageTitle(garaPage);
      const garaId = typeof garaPage.id === 'string' ? garaPage.id : '';
      const eventKey = [
        'designation',
        garaId,
        typeof garaPage.last_edited_time === 'string' ? garaPage.last_edited_time : '',
      ].join(':');
      const title = 'Designazione inviata';
      const body = designationBodyForGara(garaPage);
      const tokenCandidates = ['FCM_TOKEN', 'PUSH_TOKEN', 'TOKEN_PUSH'];
      const tokens = new Set();
      let recipients = 0;

      await Promise.allSettled(
        uniqueKronosIds.map(async (cronoId) => {
          const user = await notionRequest(`https://api.notion.com/v1/pages/${cronoId}`, 'GET');
          if (user.status !== 200) return;
          const saved = await appendUserNotification(cronoId, {
            title,
            body,
            type: 'designation',
            garaId,
            eventKey,
          });
          if (saved.status !== 200) return;
          if (saved.data?.deduped === true) return;
          recipients += 1;
          const userProps =
            user.data && typeof user.data === 'object' && user.data.properties
              ? user.data.properties
              : {};
          const tokenKey = findKeyByCandidates(userProps, tokenCandidates);
          if (!tokenKey) return;
          for (const token of extractPushTokens(userProps[tokenKey])) {
            tokens.add(token);
          }
        }),
      );

      const tokenList = [...tokens];
      if (tokenList.length === 0) {
        return {
          sent: 0,
          attempted: 0,
          recipients,
          reason: 'No crono tokens available',
        };
      }

      const result = await sendFcmMessages({
        tokens: tokenList,
        title,
        body,
        data: {
          type: 'designation',
          garaId,
          garaTitolo,
          garaData: extractGaraDateText(garaPage),
          garaLuogo: extractGaraPlaceText(garaPage),
        },
      });
      return {
        ...result,
        recipients,
      };
    };

    const savePasskeys = async (pageId, passkeys) => {
      const propertyResult = await ensurePasskeysProperty();
      if (propertyResult.status !== 200) return propertyResult;
      const serialized = JSON.stringify(passkeys);
      const chunks = serialized.match(/.{1,1900}/gs) || [];
      return notionRequest(
        `https://api.notion.com/v1/pages/${pageId}`,
        'PATCH',
        {
          properties: {
            PASSKEYS: {
              rich_text: chunks.map((content) => ({
                type: 'text',
                text: { content },
              })),
            },
          },
        },
      );
    };

    const displayNameFromUser = (page) => {
      const props = page?.properties;
      if (!props || typeof props !== 'object') return 'Cronometrista';
      const username = extractRichText(props.USERNAME);
      if (username) return username;
      for (const value of Object.values(props)) {
        if (!value || typeof value !== 'object' || !Array.isArray(value.title)) continue;
        const title = value.title.map((entry) => entry?.plain_text || '').join('').trim();
        if (title) return title;
      }
      return 'Cronometrista';
    };

    const relyingPartyForRequest = () => {
      const requestOrigin = typeof req.headers.origin === 'string' ? req.headers.origin : '';
      if (requestOrigin && isAllowedOrigin(requestOrigin)) {
        const parsedOrigin = new URL(requestOrigin);
        return { rpID: parsedOrigin.hostname, origin: parsedOrigin.origin };
      }
      return {
        rpID: 'matty110488.github.io',
        origin: 'https://matty110488.github.io',
      };
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

    const retrieveUserPage = async (pageId) => {
      const result = await notionRequest(`https://api.notion.com/v1/pages/${pageId}`, 'GET');
      if (result.status !== 200 || !result.data || typeof result.data !== 'object') {
        throw new Error(`Notion user lookup failed (${result.status})`);
      }
      return result.data;
    };

    if (action === 'startFirstAccess') {
      const username = typeof safeBody.username === 'string' ? safeBody.username.trim() : '';
      const email = typeof safeBody.email === 'string' ? safeBody.email.trim().toLowerCase() : '';
      if (!username || !email || !email.includes('@')) {
        return res.status(400).json({ error: 'Invalid first access request' });
      }

      const users = await queryAllDatabasePages(DATABASE_ID);
      const user = users.find(
        (candidate) =>
          usernameFromUser(candidate).toLowerCase() === username.toLowerCase() &&
          emailFromUser(candidate).toLowerCase() === email,
      );

      if (user && typeof user.id === 'string') {
        const auth = await firebaseAuth();
        let firebaseUser;
        try {
          firebaseUser = await auth.getUserByEmail(email);
        } catch (error) {
          if (error?.code !== 'auth/user-not-found') throw error;
          firebaseUser = await auth.createUser({
            email,
            displayName: displayNameFromUser(user),
          });
        }
        await auth.setCustomUserClaims(firebaseUser.uid, {
          notionPageId: user.id,
          admin: isAdminFromProperties(user.properties),
        });
      }

      return res.status(200).json({ ok: true, canSendEmail: Boolean(user) });
    }

    if (action === 'firebaseLogin') {
      const idToken = typeof safeBody.idToken === 'string' ? safeBody.idToken : '';
      if (!idToken) return res.status(400).json({ error: 'Missing Firebase ID token' });

      const auth = await firebaseAuth();
      const decoded = await auth.verifyIdToken(idToken);
      let notionPageId = typeof decoded.notionPageId === 'string' ? decoded.notionPageId : '';

      if (!notionPageId && typeof decoded.email === 'string') {
        const email = decoded.email.trim().toLowerCase();
        const users = await queryAllDatabasePages(DATABASE_ID);
        const user = users.find((candidate) => emailFromUser(candidate).toLowerCase() === email);
        if (user && typeof user.id === 'string') {
          notionPageId = user.id;
          await auth.setCustomUserClaims(decoded.uid, {
            notionPageId,
            admin: isAdminFromProperties(user.properties),
          });
        }
      }

      if (!notionPageId) return res.status(403).json({ error: 'User profile not linked' });
      const user = await retrieveUserPage(notionPageId);
      const isAdmin = isAdminFromProperties(user.properties);
      return res.status(200).json({
        user: sanitizeUserPage(user),
        sessionToken: signSession(user.id, isAdmin),
      });
    }

    if (action === 'login') {
      const username = typeof safeBody.username === 'string' ? safeBody.username.trim() : '';
      const password = typeof safeBody.password === 'string' ? safeBody.password : '';
      if (!username || !password) {
        return res.status(400).json({ error: 'Missing credentials' });
      }
      const users = await queryAllDatabasePages(DATABASE_ID, {
        and: [
          { property: 'USERNAME', rich_text: { equals: username } },
          { property: 'PASSWORD', rich_text: { equals: password } },
        ],
      });
      const user = users[0];
      if (!user || typeof user.id !== 'string') {
        return res.status(401).json({ error: 'Invalid credentials' });
      }
      const isAdmin = isAdminFromProperties(user.properties);
      return res.status(200).json({
        user: sanitizeUserPage(user),
        sessionToken: signSession(user.id, isAdmin),
      });
    }

    if (action === 'passkeyAuthenticationOptions') {
      const { rpID, origin } = relyingPartyForRequest();
      const options = await generateAuthenticationOptions({
        rpID,
        userVerification: 'required',
        allowCredentials: [],
      });
      return res.status(200).json({
        options,
        challengeToken: signPayload({
          kind: 'passkey-authentication',
          challenge: options.challenge,
          rpID,
          origin,
          exp: Math.floor(Date.now() / 1000) + 5 * 60,
        }),
      });
    }

    if (action === 'passkeyAuthenticationVerify') {
      const challenge = verifyPayload(safeBody.challengeToken);
      const response = safeBody.response;
      if (
        !challenge ||
        challenge.kind !== 'passkey-authentication' ||
        !response ||
        typeof response !== 'object' ||
        typeof response.id !== 'string'
      ) {
        return res.status(400).json({ error: 'Invalid passkey authentication request' });
      }
      const users = await queryAllDatabasePages(DATABASE_ID);
      let matchedUser = null;
      let matchedPasskey = null;
      let matchedPasskeys = [];
      for (const user of users) {
        const passkeys = getPasskeys(user);
        const found = passkeys.find((passkey) => passkey.id === response.id);
        if (found) {
          matchedUser = user;
          matchedPasskey = found;
          matchedPasskeys = passkeys;
          break;
        }
      }
      if (!matchedUser || !matchedPasskey) {
        return res.status(401).json({ error: 'Passkey not recognized' });
      }
      const verification = await verifyAuthenticationResponse({
        response,
        expectedChallenge: challenge.challenge,
        expectedOrigin: challenge.origin,
        expectedRPID: challenge.rpID,
        requireUserVerification: true,
        credential: {
          id: matchedPasskey.id,
          publicKey: Buffer.from(matchedPasskey.publicKey, 'base64url'),
          counter: Number(matchedPasskey.counter) || 0,
          transports: Array.isArray(matchedPasskey.transports)
            ? matchedPasskey.transports
            : undefined,
        },
      });
      if (!verification.verified) {
        return res.status(401).json({ error: 'Passkey verification failed' });
      }
      matchedPasskey.counter = verification.authenticationInfo.newCounter;
      const saved = await savePasskeys(matchedUser.id, matchedPasskeys);
      if (saved.status !== 200) {
        return res.status(saved.status).json(saved.data);
      }
      const isAdmin = isAdminFromProperties(matchedUser.properties);
      return res.status(200).json({
        user: sanitizeUserPage(matchedUser),
        sessionToken: signSession(matchedUser.id, isAdmin),
      });
    }

    const secureEquals = (left, right) => {
      if (!left || !right) return false;
      const leftBuffer = Buffer.from(String(left));
      const rightBuffer = Buffer.from(String(right));
      if (leftBuffer.length !== rightBuffer.length) return false;
      return timingSafeEqual(leftBuffer, rightBuffer);
    };

    const isVercelCronRequest =
      req.method === 'GET' &&
      typeof req.headers['user-agent'] === 'string' &&
      req.headers['user-agent'].includes('vercel-cron/1.0') &&
      typeof req.headers['x-vercel-cron-schedule'] === 'string';
    const isSecretCronRequest =
      action === 'notifyDesignationsForSentStatus' &&
      secureEquals(req.headers['x-cron-secret'], CRON_SECRET);
    const session = isVercelCronRequest || isSecretCronRequest
      ? { sub: isVercelCronRequest ? 'vercel-cron' : 'github-cron', admin: true }
      : verifySession(req.headers.authorization);
    if (!session) {
      return res.status(401).json({ error: 'Authentication required' });
    }

    if (action === 'passkeyRegistrationOptions') {
      const user = await notionRequest(
        `https://api.notion.com/v1/pages/${session.sub}`,
        'GET',
      );
      if (user.status !== 200) return res.status(user.status).json(user.data);
      const passkeys = getPasskeys(user.data);
      const { rpID, origin } = relyingPartyForRequest();
      const options = await generateRegistrationOptions({
        rpName: 'Crono Valtellinesi',
        rpID,
        userID: Buffer.from(session.sub),
        userName: displayNameFromUser(user.data),
        attestationType: 'none',
        supportedAlgorithmIDs: [-7, -257],
        excludeCredentials: passkeys.map((passkey) => ({
          id: passkey.id,
          transports: Array.isArray(passkey.transports) ? passkey.transports : undefined,
        })),
        authenticatorSelection: {
          residentKey: 'required',
          userVerification: 'required',
        },
      });
      return res.status(200).json({
        options,
        challengeToken: signPayload({
          kind: 'passkey-registration',
          sub: session.sub,
          challenge: options.challenge,
          rpID,
          origin,
          exp: Math.floor(Date.now() / 1000) + 5 * 60,
        }),
      });
    }

    if (action === 'passkeyStatus') {
      const user = await notionRequest(
        `https://api.notion.com/v1/pages/${session.sub}`,
        'GET',
      );
      if (user.status !== 200) return res.status(user.status).json(user.data);
      return res.status(200).json({ enabled: getPasskeys(user.data).length > 0 });
    }

    if (action === 'disablePasskeys') {
      const saved = await savePasskeys(session.sub, []);
      if (saved.status !== 200) return res.status(saved.status).json(saved.data);
      return res.status(200).json({ ok: true });
    }

    if (action === 'passkeyRegistrationVerify') {
      const challenge = verifyPayload(safeBody.challengeToken);
      const response = safeBody.response;
      if (
        !challenge ||
        challenge.kind !== 'passkey-registration' ||
        challenge.sub !== session.sub ||
        !response ||
        typeof response !== 'object'
      ) {
        return res.status(400).json({ error: 'Invalid passkey registration request' });
      }
      const verification = await verifyRegistrationResponse({
        response,
        expectedChallenge: challenge.challenge,
        expectedOrigin: challenge.origin,
        expectedRPID: challenge.rpID,
        requireUserVerification: true,
      });
      if (!verification.verified || !verification.registrationInfo) {
        return res.status(400).json({ error: 'Passkey registration failed' });
      }
      const user = await notionRequest(
        `https://api.notion.com/v1/pages/${session.sub}`,
        'GET',
      );
      if (user.status !== 200) return res.status(user.status).json(user.data);
      const passkeys = getPasskeys(user.data).filter(
        (passkey) => passkey.id !== verification.registrationInfo.credential.id,
      );
      const credential = verification.registrationInfo.credential;
      passkeys.push({
        id: credential.id,
        publicKey: Buffer.from(credential.publicKey).toString('base64url'),
        counter: credential.counter,
        transports: credential.transports || [],
        deviceType: verification.registrationInfo.credentialDeviceType,
        backedUp: verification.registrationInfo.credentialBackedUp,
        createdAt: new Date().toISOString(),
      });
      const saved = await savePasskeys(session.sub, passkeys);
      if (saved.status !== 200) return res.status(saved.status).json(saved.data);
      return res.status(200).json({ ok: true });
    }

    const allowedDataDatabaseIds = new Set([
      '2afde089ef9580e2b0e7d19d44f3a3f6',
      '2b1de089ef9580729622ff9543046cbc',
      
      ...(process.env.ALLOWED_DATABASE_IDS || '')
        .split(',')
        .map((id) => id.trim())
        .filter(Boolean),
    ]);
    const isAllowedPage = (page) => {
      const parent = page && typeof page === 'object' ? page.parent : null;
      const databaseId =
        parent && typeof parent === 'object' && typeof parent.database_id === 'string'
          ? parent.database_id.replace(/-/g, '')
          : '';
      const normalizedUserDatabaseId = DATABASE_ID.replace(/-/g, '');
      const normalizedDataIds = new Set(
        [...allowedDataDatabaseIds].map((id) => id.replace(/-/g, '')),
      );
      return databaseId === normalizedUserDatabaseId || normalizedDataIds.has(databaseId);
    };
    const isUserDatabasePage = (page) => {
      const databaseId = page?.parent?.database_id;
      return (
        typeof databaseId === 'string' &&
        databaseId.replace(/-/g, '') === DATABASE_ID.replace(/-/g, '')
      );
    };

    if (action === 'queryDatabase') {
      const requestedDatabaseId =
        typeof safeBody.databaseId === 'string' ? safeBody.databaseId.trim() : '';
      const { action: _action, databaseId, ...queryPayload } = safeBody;
      const targetDatabaseId = requestedDatabaseId || DATABASE_ID;
      if (!allowedDataDatabaseIds.has(targetDatabaseId)) {
        return res.status(403).json({ error: 'Database not allowed' });
      }
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
      if (response.status === 200 && !isAllowedPage(response.data)) {
        return res.status(403).json({ error: 'Page not allowed' });
      }
      if (response.status === 200 && isUserDatabasePage(response.data)) {
        response.data = sanitizeUserPage(response.data);
      }
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
      const page = await notionRequest(`https://api.notion.com/v1/pages/${pageId}`, 'GET');
      if (page.status !== 200) {
        return res.status(page.status).json(page.data);
      }
      if (!isAllowedPage(page.data)) {
        return res.status(403).json({ error: 'Page not allowed' });
      }
      const properties = payload.properties;
      if (!properties || typeof properties !== 'object' || Array.isArray(properties)) {
        return res.status(400).json({ error: 'Only property updates are supported' });
      }
      const allowedProperties = new Set([
        'STATUS',
        'KRONOS DESIGNATI',
        'DISPONIBILITA_VIA_APP',
      ]);
      if (Object.keys(properties).some((key) => !allowedProperties.has(key))) {
        return res.status(403).json({ error: 'Property update not allowed' });
      }
      const previousStatus = extractStatusName(page.data?.properties?.STATUS).toUpperCase();
      const targetStatus = statusNameFromPayload(properties).toUpperCase();
      const response = await notionRequest(
        `https://api.notion.com/v1/pages/${pageId}`,
        'PATCH',
        payload,
      );
      if (
        response.status === 200 &&
        targetStatus === 'DESIGNAZIONE INVIATA' &&
        previousStatus !== 'DESIGNAZIONE INVIATA'
      ) {
        try {
          const notificationResult = await notifyDesignatedCronos(response.data);
          if (response.data && typeof response.data === 'object') {
            response.data.pushNotification = notificationResult;
          }
        } catch (error) {
          if (response.data && typeof response.data === 'object') {
            response.data.pushNotification = {
              sent: 0,
              attempted: 0,
              error: error instanceof Error ? error.message : String(error),
            };
          }
        }
      }
      return res.status(response.status).json(response.data);
    }

    if (action === 'notifyDesignationsForSentStatus') {
      const recentHoursRaw = Number(safeBody.recentHours);
      const recentHours =
        Number.isFinite(recentHoursRaw) && recentHoursRaw > 0
          ? Math.min(recentHoursRaw, 168)
          : 24;
      const editedAfter = Date.now() - recentHours * 60 * 60 * 1000;
      const results = [];
      for (const databaseId of allowedDataDatabaseIds) {
        const pages = await queryAllDatabasePages(databaseId);
        for (const garaPage of pages) {
          const lastEdited = Date.parse(garaPage?.last_edited_time || '');
          if (!Number.isFinite(lastEdited) || lastEdited < editedAfter) continue;
          const props =
            garaPage && typeof garaPage === 'object' && garaPage.properties
              ? garaPage.properties
              : {};
          const statusKey = findKeyByCandidates(props, ['STATUS', 'STATO']);
          const status = statusKey ? extractStatusName(props[statusKey]).toUpperCase() : '';
          if (status !== 'DESIGNAZIONE INVIATA') continue;
          try {
            const notificationResult = await notifyDesignatedCronos(garaPage);
            results.push({
              garaId: typeof garaPage.id === 'string' ? garaPage.id : '',
              garaTitolo: extractPageTitle(garaPage),
              ...notificationResult,
            });
          } catch (error) {
            results.push({
              garaId: typeof garaPage.id === 'string' ? garaPage.id : '',
              garaTitolo: extractPageTitle(garaPage),
              sent: 0,
              attempted: 0,
              error: error instanceof Error ? error.message : String(error),
            });
          }
        }
      }

      const sent = results.reduce((sum, item) => sum + (Number(item.sent) || 0), 0);
      const attempted = results.reduce(
        (sum, item) => sum + (Number(item.attempted) || 0),
        0,
      );
      return res.status(200).json({
        ok: true,
        sent,
        attempted,
        recentHours,
        checked: results.length,
        results,
      });
    }

    if (action === 'registerPushToken') {
      const userId = typeof safeBody.userId === 'string' ? safeBody.userId.trim() : '';
      const token = typeof safeBody.token === 'string' ? safeBody.token.trim() : '';
      const deviceId = typeof safeBody.deviceId === 'string' ? safeBody.deviceId.trim() : '';
      if (!userId || !token) {
        return res.status(400).json({ error: 'Missing userId or token for registerPushToken' });
      }
      if (session.sub !== userId && session.admin !== true) {
        return res.status(403).json({ error: 'Cannot register a token for another user' });
      }

      const page = await notionRequest(`https://api.notion.com/v1/pages/${userId}`, 'GET');
      if (page.status !== 200) {
        return res.status(page.status).json(page.data);
      }
      const props = page.data && typeof page.data === 'object' ? page.data.properties : {};
      let tokenKey = findKeyByCandidates(props, [
        'FCM_TOKEN',
        'PUSH_TOKEN',
        'TOKEN_PUSH',
      ]);
      if (!tokenKey) {
        const ensured = await ensurePushTokenProperty();
        if (ensured.status !== 200) {
          return res.status(ensured.status).json(ensured.data);
        }
        tokenKey = 'FCM_TOKEN';
      }

      const existingRecords = extractPushTokenRecords(props[tokenKey]);
      const now = new Date().toISOString();
      const currentRecord = {
        token,
        deviceId,
        updatedAt: now,
        enabled: true,
      };
      const records = [
        currentRecord,
        ...existingRecords.filter((entry) => {
          if (!entry || entry.token === token) return false;
          if (deviceId && entry.deviceId === deviceId) return false;
          // Legacy string tokens are from the pre-deviceId flow and can create
          // duplicate notifications on the same device after worker migration.
          if (deviceId && entry.legacy === true) return false;
          return true;
        }),
      ].slice(0, 10);

      const updatePayload = {
        properties: {
          [tokenKey]: {
            rich_text: pushTokenRichText(records),
          },
        },
      };

      const updated = await notionRequest(
        `https://api.notion.com/v1/pages/${userId}`,
        'PATCH',
        updatePayload,
      );
      if (updated.status !== 200) return res.status(updated.status).json(updated.data);
      return res.status(200).json({ ok: true, tokenCount: records.length });
    }

    if (action === 'deactivatePushToken') {
      const userId = typeof safeBody.userId === 'string' ? safeBody.userId.trim() : '';
      const token = typeof safeBody.token === 'string' ? safeBody.token.trim() : '';
      const deviceId = typeof safeBody.deviceId === 'string' ? safeBody.deviceId.trim() : '';
      if (!userId || (!token && !deviceId)) {
        return res.status(400).json({ error: 'Missing userId and token/deviceId for deactivatePushToken' });
      }
      if (session.sub !== userId && session.admin !== true) {
        return res.status(403).json({ error: 'Cannot deactivate a token for another user' });
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
      if (!tokenKey) return res.status(200).json({ ok: true, tokenCount: 0 });

      const existingRecords = extractPushTokenRecords(props[tokenKey]);
      const records = existingRecords
        .filter((entry) => {
          if (!entry) return false;
          if (token && entry.token === token) return false;
          if (deviceId && entry.deviceId === deviceId) return false;
          return true;
        })
        .slice(0, 10);

      const updated = await notionRequest(
        `https://api.notion.com/v1/pages/${userId}`,
        'PATCH',
        {
          properties: {
            [tokenKey]: {
              rich_text: pushTokenRichText(records),
            },
          },
        },
      );
      if (updated.status !== 200) return res.status(updated.status).json(updated.data);
      return res.status(200).json({ ok: true, tokenCount: records.length });
    }

    if (action === 'listPushNotifications') {
      const userId = typeof safeBody.userId === 'string' ? safeBody.userId.trim() : session.sub;
      if (!userId) return res.status(400).json({ error: 'Missing userId for listPushNotifications' });
      if (session.sub !== userId && session.admin !== true) {
        return res.status(403).json({ error: 'Cannot list notifications for another user' });
      }

      const page = await notionRequest(`https://api.notion.com/v1/pages/${userId}`, 'GET');
      if (page.status !== 200) return res.status(page.status).json(page.data);
      const props = page.data && typeof page.data === 'object' ? page.data.properties : {};
      const notificationKey = findKeyByCandidates(props, [
        'FCM_NOTIFICATIONS',
        'PUSH_NOTIFICATIONS',
        'NOTIFICHE_PUSH',
      ]);
      const notifications = notificationKey
        ? extractNotificationRecords(props[notificationKey])
        : [];
      return res.status(200).json({ ok: true, notifications });
    }

    if (action === 'markPushNotificationsRead') {
      const userId = typeof safeBody.userId === 'string' ? safeBody.userId.trim() : session.sub;
      if (!userId) return res.status(400).json({ error: 'Missing userId for markPushNotificationsRead' });
      if (session.sub !== userId && session.admin !== true) {
        return res.status(403).json({ error: 'Cannot mark notifications for another user' });
      }

      const page = await notionRequest(`https://api.notion.com/v1/pages/${userId}`, 'GET');
      if (page.status !== 200) return res.status(page.status).json(page.data);
      const props = page.data && typeof page.data === 'object' ? page.data.properties : {};
      const notificationKey = findKeyByCandidates(props, [
        'FCM_NOTIFICATIONS',
        'PUSH_NOTIFICATIONS',
        'NOTIFICHE_PUSH',
      ]);
      const notifications = notificationKey
        ? extractNotificationRecords(props[notificationKey])
        : [];
      const nextNotifications = notifications.map((entry) => ({ ...entry, read: true }));
      const saved = await saveNotificationRecords(userId, nextNotifications);
      if (saved.status !== 200) return res.status(saved.status).json(saved.data);
      return res.status(200).json({ ok: true, notifications: nextNotifications });
    }

    if (action === 'deletePushNotification') {
      const userId = typeof safeBody.userId === 'string' ? safeBody.userId.trim() : session.sub;
      const notificationId =
        typeof safeBody.notificationId === 'string' ? safeBody.notificationId.trim() : '';
      if (!userId || !notificationId) {
        return res.status(400).json({ error: 'Missing userId or notificationId for deletePushNotification' });
      }
      if (session.sub !== userId && session.admin !== true) {
        return res.status(403).json({ error: 'Cannot delete notifications for another user' });
      }

      const page = await notionRequest(`https://api.notion.com/v1/pages/${userId}`, 'GET');
      if (page.status !== 200) return res.status(page.status).json(page.data);
      const props = page.data && typeof page.data === 'object' ? page.data.properties : {};
      const notificationKey = findKeyByCandidates(props, [
        'FCM_NOTIFICATIONS',
        'PUSH_NOTIFICATIONS',
        'NOTIFICHE_PUSH',
      ]);
      const notifications = notificationKey
        ? extractNotificationRecords(props[notificationKey])
        : [];
      const nextNotifications = notifications.filter((entry) => entry.id !== notificationId);
      const saved = await saveNotificationRecords(userId, nextNotifications);
      if (saved.status !== 200) return res.status(saved.status).json(saved.data);
      return res.status(200).json({ ok: true, notifications: nextNotifications });
    }

    if (action === 'clearPushNotifications') {
      const userId = typeof safeBody.userId === 'string' ? safeBody.userId.trim() : session.sub;
      if (!userId) return res.status(400).json({ error: 'Missing userId for clearPushNotifications' });
      if (session.sub !== userId && session.admin !== true) {
        return res.status(403).json({ error: 'Cannot clear notifications for another user' });
      }

      const saved = await saveNotificationRecords(userId, []);
      if (saved.status !== 200) return res.status(saved.status).json(saved.data);
      return res.status(200).json({ ok: true, notifications: [] });
    }

    if (action === 'sendTestPushToken') {
      const userId = typeof safeBody.userId === 'string' ? safeBody.userId.trim() : '';
      const token = typeof safeBody.token === 'string' ? safeBody.token.trim() : '';
      if (!userId || !token) {
        return res.status(400).json({ error: 'Missing userId or token for sendTestPushToken' });
      }
      if (session.sub !== userId && session.admin !== true) {
        return res.status(403).json({ error: 'Cannot test a token for another user' });
      }

      const result = await sendFcmMessages({
        tokens: [token],
        title: 'Test notifiche',
        body: 'Se leggi questo messaggio, le notifiche funzionano su questo dispositivo.',
        data: {
          type: 'push-test',
          userId,
          createdAt: new Date().toISOString(),
        },
      });
      if (result.sent > 0) {
        await appendUserNotification(userId, {
          title: 'Test notifiche',
          body: 'Se leggi questo messaggio, le notifiche funzionano su questo dispositivo.',
          type: 'push-test',
        });
      }

      return res.status(200).json({ ok: true, ...result });
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
      const available = safeBody.available;
      const garaId = typeof safeBody.garaId === 'string' ? safeBody.garaId.trim() : '';
      const garaTitolo =
        typeof safeBody.garaTitolo === 'string' ? safeBody.garaTitolo.trim() : 'una gara';
      if (!userId || typeof available !== 'boolean') {
        return res.status(400).json({ error: 'Missing availability notification data' });
      }
      if (session.sub !== userId && session.admin !== true) {
        return res.status(403).json({ error: 'Cannot notify availability for another user' });
      }

      const users = await queryAllDatabasePages(DATABASE_ID);
      const tokenCandidates = ['FCM_TOKEN', 'PUSH_TOKEN', 'TOKEN_PUSH'];
      const recipients = new Map();

      for (const row of users) {
        if (!row || typeof row !== 'object') continue;
        if (typeof row.id === 'string' && row.id === userId) continue;

        const props = row.properties && typeof row.properties === 'object' ? row.properties : {};
        if (!isAdminFromProperties(props)) continue;

        const tokenKey = findKeyByCandidates(props, tokenCandidates);
        if (!tokenKey) continue;
        const rowTokens = extractPushTokens(props[tokenKey]);
        if (rowTokens.length === 0) continue;
        if (typeof row.id === 'string') {
          recipients.set(row.id, rowTokens);
        }
      }

      const tokens = new Set();
      for (const rowTokens of recipients.values()) {
        for (const token of rowTokens) {
          tokens.add(token);
        }
      }

      const tokenList = [...tokens];
      if (tokenList.length === 0) {
        return res.status(200).json({
          ok: true,
          sent: 0,
          reason: 'No admin tokens available',
        });
      }

      const bodyText = available
        ? `${userName} si e reso disponibile per ${garaTitolo}`
        : `${userName} ha tolto la disponibilita per ${garaTitolo}`;
      let bodyWithDetails = bodyText;
      let garaData = '';
      let garaLuogo = '';
      if (garaId) {
        const garaPage = await notionRequest(`https://api.notion.com/v1/pages/${garaId}`, 'GET');
        if (garaPage.status === 200) {
          garaData = extractGaraDateText(garaPage.data);
          garaLuogo = extractGaraPlaceText(garaPage.data);
          const details = [garaData, garaLuogo].filter(Boolean).join(' - ');
          if (details) bodyWithDetails = `${bodyText}\n${details}`;
        }
      }
      const result = await sendFcmMessages({
        tokens: tokenList,
        title: available ? 'Nuova disponibilita' : 'Disponibilita rimossa',
        body: bodyWithDetails,
        data: {
          type: 'availability',
          garaId,
          garaTitolo,
          garaData,
          garaLuogo,
          userName,
          available: String(available),
        },
      });
      if (result.sent > 0) {
        await Promise.allSettled(
          [...recipients.keys()].map((recipientId) =>
            appendUserNotification(recipientId, {
              title: available ? 'Nuova disponibilita' : 'Disponibilita rimossa',
              body: bodyWithDetails,
              type: 'availability',
              garaId,
            }),
          ),
        );
      }

      return res.status(200).json({
        ok: true,
        ...result,
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
