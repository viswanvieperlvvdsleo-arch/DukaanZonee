import dotenv from 'dotenv';

dotenv.config();

const required = ['DATABASE_URL', 'JWT_SECRET'];

for (const key of required) {
  if (!process.env[key]) {
    throw new Error(`Missing required environment variable: ${key}`);
  }
}

if (process.env.NODE_ENV === 'production' && process.env.JWT_SECRET.length < 32) {
  throw new Error('JWT_SECRET must be at least 32 characters in production');
}

export const config = {
  port: Number(process.env.PORT ?? 4000),
  databaseUrl: process.env.DATABASE_URL,
  jwtSecret: process.env.JWT_SECRET,
  jwtExpiresIn: process.env.JWT_EXPIRES_IN ?? '7d',
  adminBootstrapEmail: process.env.ADMIN_BOOTSTRAP_EMAIL ?? null,
  adminBootstrapPassword: process.env.ADMIN_BOOTSTRAP_PASSWORD ?? null,
  adminBootstrapName: process.env.ADMIN_BOOTSTRAP_NAME ?? 'Admin',
  commissionRate: Number(process.env.COMMISSION_RATE ?? 0.04),
  corsOrigins: (process.env.CORS_ORIGIN ?? '')
    .split(',')
    .map((origin) => origin.trim())
    .filter(Boolean),
  pgPoolMax: Number(process.env.PG_POOL_MAX ?? 10),
  pgConnectionTimeoutMs: Number(process.env.PG_CONNECTION_TIMEOUT_MS ?? 5000),
  pgIdleTimeoutMs: Number(process.env.PG_IDLE_TIMEOUT_MS ?? 30000),
  pgSslMode: process.env.PGSSLMODE ?? process.env.PG_SSLMODE ?? '',
  pgSslRejectUnauthorized:
    process.env.PGSSL_REJECT_UNAUTHORIZED != null
      ? process.env.PGSSL_REJECT_UNAUTHORIZED !== 'false'
      : process.env.RENDER !== 'true',
  fcmServiceAccountJson: process.env.FCM_SERVICE_ACCOUNT_JSON ?? null,
  fcmProjectId: process.env.FCM_PROJECT_ID ?? null,
  fcmClientEmail: process.env.FCM_CLIENT_EMAIL ?? null,
  fcmPrivateKey: process.env.FCM_PRIVATE_KEY ?? null,
};
