import pg from 'pg';

const DB = process.env.DB_URL;
const client = new pg.Client({
  connectionString: DB,
  ssl: { rejectUnauthorized: false },
});

await client.connect();
const del = await client.query('DELETE FROM push_tokens');
console.log('Deleted old push tokens:', del.rowCount);
const check = await client.query('SELECT COUNT(*) as remaining FROM push_tokens');
console.log('Remaining tokens:', check.rows[0].remaining);
await client.end();
