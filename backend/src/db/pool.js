import pg from 'pg';
import { config } from '../config.js';

const shouldUseSsl = shouldRequireSsl(config.databaseUrl, config.pgSslMode);

export const pool = new pg.Pool({
  connectionString: config.databaseUrl,
  max: config.pgPoolMax,
  connectionTimeoutMillis: config.pgConnectionTimeoutMs,
  idleTimeoutMillis: config.pgIdleTimeoutMs,
  ssl: shouldUseSsl
    ? { rejectUnauthorized: config.pgSslRejectUnauthorized }
    : undefined,
});

export async function query(text, params) {
  return pool.query(text, params);
}

export async function withTransaction(work) {
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    const result = await work(client);
    await client.query('COMMIT');
    return result;
  } catch (error) {
    await client.query('ROLLBACK');
    throw error;
  } finally {
    client.release();
  }
}

function shouldRequireSsl(databaseUrl, sslMode) {
  if (sslMode === 'disable') return false;
  if (sslMode === 'require' || sslMode === 'verify-full' || sslMode === 'verify-ca') return true;
  if (process.env.NODE_ENV !== 'production') return false;

  try {
    const host = new URL(databaseUrl).hostname;
    return host !== 'localhost' && host !== '127.0.0.1';
  } catch {
    return false;
  }
}
