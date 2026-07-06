import fs from 'node:fs';
import admin from 'firebase-admin';
import { config } from '../config.js';
import { query } from '../db/pool.js';
import { makeId } from '../utils/ids.js';

const invalidTokenCodes = new Set([
  'messaging/invalid-argument',
  'messaging/invalid-registration-token',
  'messaging/registration-token-not-registered',
]);

let appInitialized = false;
let initAttempted = false;
let warnedDisabled = false;

export function isPushConfigured() {
  return Boolean(
    config.fcmServiceAccountJson ||
      (config.fcmProjectId && config.fcmClientEmail && config.fcmPrivateKey),
  );
}

export async function registerPushToken({
  accountType,
  accountId,
  token,
  platform,
  deviceId,
}) {
  const trimmedToken = token?.trim();
  if (!trimmedToken) return null;

  const existing = await query('SELECT id FROM push_tokens WHERE token = $1', [
    trimmedToken,
  ]);
  const id = existing.rows[0]?.id ?? makeId('push');

  await query(
    `INSERT INTO push_tokens (
      id, account_type, account_id, token, platform, device_id, last_seen_at
    )
    VALUES ($1, $2, $3, $4, $5, $6, NOW())
    ON CONFLICT (token) DO UPDATE SET
      account_type = EXCLUDED.account_type,
      account_id = EXCLUDED.account_id,
      platform = EXCLUDED.platform,
      device_id = EXCLUDED.device_id,
      last_seen_at = NOW()`,
    [
      id,
      accountType,
      accountId,
      trimmedToken,
      platform?.trim() || null,
      deviceId?.trim() || null,
    ],
  );

  return { id, token: trimmedToken };
}

export async function unregisterPushToken(token) {
  const trimmedToken = token?.trim();
  if (!trimmedToken) return;
  await query('DELETE FROM push_tokens WHERE token = $1', [trimmedToken]);
}

export async function unregisterPushTokensForAccount(accountType, accountId) {
  if (!accountType || !accountId) return;
  await query(
    'DELETE FROM push_tokens WHERE account_type = $1 AND account_id = $2',
    [accountType, accountId],
  );
}

export async function sendPushToUserId(userId, payload) {
  if (!userId) return { sent: 0, disabled: !isPushConfigured() };
  const user = await query('SELECT role FROM app_users WHERE id = $1', [userId]);
  const role = user.rows[0]?.role;
  if (!role) return { sent: 0 };
  return sendPushToAccount(role, userId, payload);
}

export async function sendPushToAccount(accountType, accountId, payload) {
  if (!isPushConfigured()) {
    warnPushDisabled();
    return { sent: 0, disabled: true };
  }

  const messaging = getMessaging();
  if (!messaging) return { sent: 0, disabled: true };

  const result = await query(
    `SELECT token FROM push_tokens
     WHERE account_type = $1 AND account_id = $2
     ORDER BY last_seen_at DESC`,
    [accountType, accountId],
  );
  const tokens = result.rows.map((row) => row.token).filter(Boolean);
  if (tokens.length === 0) return { sent: 0 };

  const response = await messaging.sendEachForMulticast({
    tokens,
    notification: {
      title: payload.title || 'DukaanZone',
      body: payload.body || '',
    },
    data: stringifyData(payload.data ?? {}),
    android: {
      priority: 'high',
      notification: {
        channelId: 'dukaanzone_alerts',
        sound: 'default',
      },
    },
    apns: {
      payload: {
        aps: {
          sound: 'default',
        },
      },
    },
  });

  const staleTokens = [];
  response.responses.forEach((item, index) => {
    if (!item.success && invalidTokenCodes.has(item.error?.code)) {
      staleTokens.push(tokens[index]);
    }
  });
  if (staleTokens.length > 0) {
    await query('DELETE FROM push_tokens WHERE token = ANY($1)', [staleTokens]);
  }

  return { sent: response.successCount, failed: response.failureCount };
}

function getMessaging() {
  if (!initAttempted) {
    initAttempted = true;
    try {
      const credential = admin.credential.cert(readServiceAccount());
      admin.initializeApp({ credential });
      appInitialized = true;
    } catch (error) {
      console.warn(`FCM disabled: ${error.message}`);
      appInitialized = false;
    }
  }

  if (!appInitialized) return null;
  return admin.messaging();
}

function readServiceAccount() {
  if (config.fcmServiceAccountJson) {
    let raw = config.fcmServiceAccountJson.trim();
    if (raw.startsWith('{')) {
      // Fix for Render and Docker double-escaping newlines in JSON strings
      raw = raw.replace(/\\n/g, '\n');
      return JSON.parse(raw);
    }
    if (raw.endsWith('.json') && fs.existsSync(raw)) {
      return JSON.parse(fs.readFileSync(raw, 'utf8'));
    }
    return JSON.parse(Buffer.from(raw, 'base64').toString('utf8'));
  }

  if (config.fcmProjectId && config.fcmClientEmail && config.fcmPrivateKey) {
    return {
      project_id: config.fcmProjectId,
      client_email: config.fcmClientEmail,
      private_key: config.fcmPrivateKey.replace(/\\n/g, '\n'),
    };
  }

  throw new Error('missing Firebase service account config');
}

function stringifyData(data) {
  return Object.fromEntries(
    Object.entries(data)
      .filter(([, value]) => value !== undefined && value !== null)
      .map(([key, value]) => [key, String(value)]),
  );
}

function warnPushDisabled() {
  if (warnedDisabled) return;
  warnedDisabled = true;
  console.warn('FCM disabled: set Firebase service account env vars to enable hardware push.');
}
