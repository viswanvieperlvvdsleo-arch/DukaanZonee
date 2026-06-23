import express from 'express';
import { query } from '../db/pool.js';
import { requireAuth } from '../middleware/auth.js';
import { HttpError } from '../utils/httpError.js';

export const settingsRouter = express.Router();

settingsRouter.use(requireAuth);

function assertPlainObject(value) {
  if (!value || typeof value !== 'object' || Array.isArray(value)) {
    throw new HttpError(400, 'Settings payload must be an object');
  }
  return value;
}

settingsRouter.get('/me', async (req, res, next) => {
  try {
    const result = await query(
      `INSERT INTO user_settings (user_id, preferences)
       VALUES ($1, '{}'::jsonb)
       ON CONFLICT (user_id) DO UPDATE SET user_id = EXCLUDED.user_id
       RETURNING preferences, updated_at`,
      [req.user.sub],
    );

    res.json({
      preferences: result.rows[0].preferences ?? {},
      updatedAt: result.rows[0].updated_at,
    });
  } catch (error) {
    next(error);
  }
});

settingsRouter.get('/platform', async (_req, res, next) => {
  try {
    const result = await query(
      `SELECT value, updated_at
       FROM platform_settings
       WHERE key = 'payment'`,
    );
    res.json({
      settings: normalizePlatformSettings(result.rows[0]?.value ?? {}),
      updatedAt: result.rows[0]?.updated_at ?? null,
    });
  } catch (error) {
    next(error);
  }
});

settingsRouter.patch('/me', async (req, res, next) => {
  try {
    const preferences = assertPlainObject(req.body.preferences ?? req.body);
    const result = await query(
      `INSERT INTO user_settings (user_id, preferences)
       VALUES ($1, $2::jsonb)
       ON CONFLICT (user_id) DO UPDATE
       SET preferences = user_settings.preferences || EXCLUDED.preferences,
           updated_at = NOW()
       RETURNING preferences, updated_at`,
      [req.user.sub, JSON.stringify(preferences)],
    );

    res.json({
      preferences: result.rows[0].preferences ?? {},
      updatedAt: result.rows[0].updated_at,
    });
  } catch (error) {
    next(error);
  }
});

function normalizePlatformSettings(value) {
  const commissionRate = Number(value.commissionRate ?? value.commission_rate ?? 0.04);
  return {
    commissionRate: Number.isFinite(commissionRate)
      ? Math.min(Math.max(commissionRate, 0), 0.25)
      : 0.04,
    promotion3DayRate: Number(value.promotion3DayRate ?? 30),
    promotion7DayRate: Number(value.promotion7DayRate ?? 60),
    promotion30DayRate: Number(value.promotion30DayRate ?? 150),
    notificationHubEnabled: value.notificationHubEnabled !== false,
    notificationDriver: value.notificationDriver ?? 'PostgreSQL (pg_notify)',
    dbPollingIntervalMs: Number(value.dbPollingIntervalMs ?? 250),
  };
}
