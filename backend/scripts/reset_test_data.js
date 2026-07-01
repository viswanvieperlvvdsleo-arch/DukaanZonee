/**
 * reset_test_data.js
 * ------------------
 * Deletes ALL data in the database, including admin accounts, shops, 
 * items, chats, etc. This resets the app to a completely blank slate.
 * 
 * Note: If you login with the admin bootstrap email/password again, 
 * the admin account will automatically be recreated.
 *
 * Run from inside the backend/ folder:
 *   node scripts/reset_test_data.js
 */

import { pool } from '../src/db/pool.js';

async function reset() {
  const client = await pool.connect();
  try {
    await client.query('BEGIN');

    // ── 1. Delete all chat messages & call records ───────────────────────────
    await client.query(`DELETE FROM media_storage_deletions`);
    await client.query(`DELETE FROM chat_room_hides`);
    await client.query(`DELETE FROM call_records`);
    await client.query(`DELETE FROM chat_messages`);
    console.log('✓ Chat messages and call records cleared');

    // ── 2. Delete promotions, disputes, signals ──────────────────────────────
    await client.query(`DELETE FROM product_promotions`);
    await client.query(`DELETE FROM admin_signals`);
    await client.query(`DELETE FROM disputes`);
    console.log('✓ Promotions / signals / disputes cleared');

    // ── 3. Delete saved items and groups ────────────────────────────────────
    await client.query(`DELETE FROM saved_group_items`);
    await client.query(`DELETE FROM saved_groups`);
    await client.query(`DELETE FROM saved_products`);
    console.log('✓ Saved items cleared');

    // ── 4. Delete reviews, followers ────────────────────────────────────────
    await client.query(`DELETE FROM product_reviews`);
    await client.query(`DELETE FROM shop_followers`);
    console.log('✓ Reviews / followers cleared');

    // ── 5. Delete payments ───────────────────────────────────────────────────
    await client.query(`DELETE FROM payment_record_items`);
    await client.query(`DELETE FROM payment_records`);
    console.log('✓ Payment records cleared');

    // ── 6. Delete notifications and push tokens ──────────────────────────────
    await client.query(`DELETE FROM notifications`);
    await client.query(`DELETE FROM push_tokens`);
    console.log('✓ Notifications / push tokens cleared');

    // ── 7. Delete search logs ────────────────────────────────────────────────
    await client.query(`DELETE FROM search_logs`);

    // ── 8. Delete shelf items (shop products) ────────────────────────────────
    await client.query(`DELETE FROM shelf_items`);
    console.log('✓ Shelf items cleared');

    // ── 9. Delete shops ──────────────────────────────────────────────────────
    await client.query(`DELETE FROM shops`);
    console.log('✓ Shops cleared');

    // ── 10. Delete all user/platform settings ────────────────────────────────
    await client.query(`DELETE FROM user_settings`);
    await client.query(`DELETE FROM platform_settings`);
    console.log('✓ Settings cleared');

    // ── 11. Delete all user accounts (including admin) ───────────────────────
    const deleted = await client.query(`
      DELETE FROM app_users
      RETURNING email, role
    `);
    console.log(`✓ Deleted ALL ${deleted.rowCount} user account(s):`);
    for (const row of deleted.rows) {
      console.log(`   • [${row.role}] ${row.email}`);
    }

    await client.query('COMMIT');
    console.log('\n✅  All database data completely deleted (Total wipe).');
  } catch (err) {
    await client.query('ROLLBACK');
    console.error('❌  Reset failed — rolled back:', err.message);
    process.exit(1);
  } finally {
    client.release();
    await pool.end();
  }
}

reset();
