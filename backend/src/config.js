import dotenv from 'dotenv';

dotenv.config();

const required = ['DATABASE_URL', 'JWT_SECRET'];

for (const key of required) {
  if (!process.env[key]) {
    throw new Error(`Missing required environment variable: ${key}`);
  }
}

export const config = {
  port: Number(process.env.PORT ?? 4000),
  databaseUrl: process.env.DATABASE_URL,
  jwtSecret: process.env.JWT_SECRET,
  jwtExpiresIn: process.env.JWT_EXPIRES_IN ?? '7d',
  adminBootstrapEmail:
    process.env.ADMIN_BOOTSTRAP_EMAIL ?? 'ramviswan@gmail.com',
  adminBootstrapPassword:
    process.env.ADMIN_BOOTSTRAP_PASSWORD ?? 'RamViswan@2005Bug',
  adminBootstrapName: process.env.ADMIN_BOOTSTRAP_NAME ?? 'Ram Viswan',
  commissionRate: Number(process.env.COMMISSION_RATE ?? 0.03),
  corsOrigins: (process.env.CORS_ORIGIN ?? '')
    .split(',')
    .map((origin) => origin.trim())
    .filter(Boolean),
};
