import cors from 'cors';
import express from 'express';
import { config } from './config.js';
import { createRateLimiter } from './middleware/rateLimit.js';
import { rejectPrototypePollution, securityHeaders } from './middleware/security.js';
import { authRouter } from './routes/auth.routes.js';
import { adminRouter } from './routes/admin.routes.js';
import { chatsRouter } from './routes/chats.routes.js';
import { discoveryRouter } from './routes/discovery.routes.js';
import { notificationsRouter } from './routes/notifications.routes.js';
import { paymentSessionsRouter } from './routes/paymentSessions.routes.js';
import { pushRouter } from './routes/push.routes.js';
import { sellerRouter } from './routes/seller.routes.js';
import { settingsRouter } from './routes/settings.routes.js';
import { supportRouter } from './routes/support.routes.js';
import { query } from './db/pool.js';
import { HttpError } from './utils/httpError.js';

export function createApp() {
  const app = express();

  app.disable('x-powered-by');
  app.set('trust proxy', 1);
  app.use(securityHeaders);

  app.use(cors({
    origin(origin, callback) {
      if (!origin || config.corsOrigins.length === 0 || config.corsOrigins.includes(origin) || isLocalDevOrigin(origin)) {
        return callback(null, true);
      }
      return callback(new HttpError(403, 'Origin not allowed'));
    },
  }));
  app.use(express.json({ limit: '12mb' }));
  app.use(rejectPrototypePollution);
  app.use(createRateLimiter({ windowMs: 60_000, max: 180 }));

  app.get('/health', (_req, res) => {
    res.json({ ok: true, service: 'dukaanzone-backend' });
  });

  app.get('/health/db', async (_req, res, next) => {
    try {
      await query('SELECT 1');
      res.json({ ok: true, service: 'dukaanzone-backend', database: 'connected' });
    } catch (error) {
      next(error);
    }
  });

  app.use('/api/auth', authRouter);
  app.use('/api/admin', adminRouter);
  app.use('/api/chats', chatsRouter);
  app.use('/api/discovery', discoveryRouter);
  app.use('/api/notifications', notificationsRouter);
  app.use('/api/seller', sellerRouter);
  app.use('/api/push', pushRouter);
  app.use('/api/settings', settingsRouter);
  app.use('/api/support', supportRouter);
  app.use('/api/payment-sessions', paymentSessionsRouter);

  app.use((_req, _res, next) => {
    next(new HttpError(404, 'Route not found'));
  });

  app.use((error, _req, res, _next) => {
    const databaseError = mapDatabaseError(error);
    if (databaseError) {
      return res.status(databaseError.status).json({
        error: databaseError.message,
        details: databaseError.details,
      });
    }

    if (error?.name === 'ZodError') {
      return res.status(400).json({
        error: 'Validation failed',
        details: error.issues,
      });
    }

    const status = error.status ?? 500;
    const message = status === 500 ? 'Internal server error' : error.message;

    if (status === 500) {
      console.error(error);
    }

    return res.status(status).json({
      error: message,
      details: error.details,
    });
  });

  return app;
}

function mapDatabaseError(error) {
  if (!error?.code) return null;

  if (error.code === '23505') {
    const constraint = error.constraint ?? '';
    if (
      constraint.includes('payment_qr') ||
      constraint.includes('upi_id') ||
      constraint.includes('shops_payment_qr') ||
      constraint.includes('shops_upi')
    ) {
      return {
        status: 409,
        message: 'Payment QR or UPI ID already linked to another shop',
        details: { constraint },
      };
    }

    return {
      status: 409,
      message: 'This record already exists',
      details: { constraint },
    };
  }

  if (error.code === '42703' || error.code === '42P01') {
    return {
      status: 503,
      message: 'Database schema is not ready. Restart or redeploy the backend so migrations run.',
      details: { code: error.code },
    };
  }

  if (
    error.code === 'ECONNREFUSED' ||
    error.code === 'ENOTFOUND' ||
    error.code === 'ETIMEDOUT' ||
    error.code === '28P01' ||
    error.code === '3D000' ||
    error.code === '57P03'
  ) {
    return {
      status: 503,
      message: 'Database is not reachable. Check Render DATABASE_URL and PostgreSQL service.',
      details: { code: error.code },
    };
  }

  return null;
}

function isLocalDevOrigin(origin) {
  try {
    const { hostname, protocol } = new URL(origin);
    if (protocol !== 'http:' && protocol !== 'https:') return false;
    return hostname === 'localhost' ||
      hostname === '127.0.0.1' ||
      hostname === '10.0.2.2' ||
      hostname.endsWith('.trycloudflare.com') ||
      hostname.startsWith('192.168.') ||
      hostname.startsWith('10.');
  } catch {
    return false;
  }
}
