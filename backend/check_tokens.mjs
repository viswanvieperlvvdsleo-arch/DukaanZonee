import pg from 'pg';

const client = new pg.Client({
  connectionString: 'postgresql://dukaanzone_dev_user:BYxkYYtYZQYBbPbXVhuJNdUxcuMmHxw2@dpg-d8t5sv0k1i2s738atqo0-a.oregon-postgres.render.com/dukaanzone_dev',
  ssl: { rejectUnauthorized: false },
});

await client.connect();
const result = await client.query('SELECT id, account_type, account_id, platform, device_id, last_seen_at, LEFT(token, 20) as token_preview FROM push_tokens ORDER BY last_seen_at DESC');
console.log('Push tokens in database:', result.rowCount);
console.table(result.rows);
await client.end();
