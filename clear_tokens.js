import pg from 'pg';

const client = new pg.Client({
  connectionString: 'postgresql://dukaanzone_dev_user:BYxkYYtYZQYBbPbXVhuJNdUxcuMmHxw2@dpg-d8t5sv0k1i2s738atqo0-a/dukaanzone_dev',
  ssl: { rejectUnauthorized: false },
});

await client.connect();
const del = await client.query('DELETE FROM push_tokens');
console.log(`Deleted ${del.rowCount} old push tokens.`);
const check = await client.query('SELECT COUNT(*) as remaining FROM push_tokens');
console.log(`Remaining tokens: ${check.rows[0].remaining}`);
await client.end();
