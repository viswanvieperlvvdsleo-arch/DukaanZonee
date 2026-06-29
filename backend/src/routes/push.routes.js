import express from 'express';
import { z } from 'zod';
import { requireAuth } from '../middleware/auth.js';
import {
  isPushConfigured,
  registerPushToken,
  unregisterPushToken,
  unregisterPushTokensForAccount,
} from '../services/push.service.js';

const router = express.Router();

const pushTokenSchema = z.object({
  token: z.string().min(20),
  platform: z.string().trim().max(40).optional(),
  deviceId: z.string().trim().max(160).optional(),
});

router.use(requireAuth);

router.get('/status', (_req, res) => {
  res.json({ ok: true, configured: isPushConfigured() });
});

router.post('/register', async (req, res, next) => {
  try {
    const body = pushTokenSchema.parse(req.body);
    const saved = await registerPushToken({
      accountType: req.user.role,
      accountId: req.user.sub,
      token: body.token,
      platform: body.platform,
      deviceId: body.deviceId,
    });

    res.json({
      ok: true,
      configured: isPushConfigured(),
      tokenId: saved?.id ?? null,
    });
  } catch (error) {
    next(error);
  }
});

router.delete('/register', async (req, res, next) => {
  try {
    const body = z
      .object({ token: z.string().min(1).optional() })
      .parse(req.body ?? {});
    if (body.token) {
      await unregisterPushToken(body.token);
    } else {
      await unregisterPushTokensForAccount(req.user.role, req.user.sub);
    }
    res.json({ ok: true });
  } catch (error) {
    next(error);
  }
});

export { router as pushRouter };
