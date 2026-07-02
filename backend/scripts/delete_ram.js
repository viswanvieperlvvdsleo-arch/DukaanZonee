import 'dotenv/config';
import pkg from 'pg';
const { Pool } = pkg;

const pool = new Pool({
  connectionString: process.env.DATABASE_URL
});

async function run() {
  try {
    // Also delete any shops owned by them to avoid orphaned data, though foreign keys might handle it.
    // First, find the user(s)
    const users = await pool.query("SELECT id, name, role FROM users WHERE name ILIKE $1", ['%ram%']);
    console.log(`Found ${users.rowCount} users with name containing 'ram'.`);
    
    for (const u of users.rows) {
      if (u.role === 'seller') {
         await pool.query("DELETE FROM shops WHERE seller_id = $1", [u.id]);
         console.log(`Deleted shops for seller ${u.id}`);
      }
      await pool.query("DELETE FROM users WHERE id = $1", [u.id]);
      console.log(`Deleted user ${u.name} (id: ${u.id})`);
    }
  } catch (err) {
    console.error('Error deleting user:', err);
  } finally {
    await pool.end();
  }
}

run();
