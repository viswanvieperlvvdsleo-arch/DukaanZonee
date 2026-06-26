import { pool } from './pool.js';

const statements = [
  `CREATE TABLE IF NOT EXISTS app_users (
    id TEXT PRIMARY KEY,
    role TEXT NOT NULL CHECK (role IN ('user', 'seller', 'admin')),
    name TEXT NOT NULL,
    email TEXT NOT NULL UNIQUE,
    phone TEXT,
    profile_pic TEXT,
    password_hash TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
  )`,
  `ALTER TABLE app_users ADD COLUMN IF NOT EXISTS profile_pic TEXT`,
  `ALTER TABLE app_users ADD COLUMN IF NOT EXISTS restricted_until TIMESTAMPTZ`,
  `ALTER TABLE app_users ADD COLUMN IF NOT EXISTS restriction_reason TEXT`,
  `ALTER TABLE app_users ADD COLUMN IF NOT EXISTS deleted_at TIMESTAMPTZ`,
  `CREATE TABLE IF NOT EXISTS shops (
    id TEXT PRIMARY KEY,
    seller_id TEXT NOT NULL UNIQUE REFERENCES app_users(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    category TEXT,
    block TEXT,
    address TEXT,
    latitude NUMERIC(10, 7),
    longitude NUMERIC(10, 7),
    qr_code TEXT NOT NULL UNIQUE,
    qr_payload TEXT NOT NULL UNIQUE,
    payment_qr_payload TEXT,
    payment_qr_fingerprint TEXT UNIQUE,
    upi_id TEXT,
    payout_status TEXT NOT NULL DEFAULT 'sandbox_ready',
    gateway_provider TEXT NOT NULL DEFAULT 'mock_gateway',
    gateway_account_id TEXT,
    payment_qr_updated_at TIMESTAMPTZ,
    avatar_url TEXT,
    map_url TEXT,
    is_open BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
  )`,
  `ALTER TABLE shops ADD COLUMN IF NOT EXISTS payment_qr_payload TEXT`,
  `ALTER TABLE shops ADD COLUMN IF NOT EXISTS payment_qr_fingerprint TEXT`,
  `ALTER TABLE shops ADD COLUMN IF NOT EXISTS upi_id TEXT`,
  `ALTER TABLE shops ADD COLUMN IF NOT EXISTS latitude NUMERIC(10, 7)`,
  `ALTER TABLE shops ADD COLUMN IF NOT EXISTS longitude NUMERIC(10, 7)`,
  `ALTER TABLE shops ADD COLUMN IF NOT EXISTS payout_status TEXT NOT NULL DEFAULT 'sandbox_ready'`,
  `ALTER TABLE shops ADD COLUMN IF NOT EXISTS gateway_provider TEXT NOT NULL DEFAULT 'mock_gateway'`,
  `ALTER TABLE shops ADD COLUMN IF NOT EXISTS gateway_account_id TEXT`,
  `ALTER TABLE shops ADD COLUMN IF NOT EXISTS payment_qr_updated_at TIMESTAMPTZ`,
  `ALTER TABLE shops ADD COLUMN IF NOT EXISTS avatar_url TEXT`,
  `ALTER TABLE shops ADD COLUMN IF NOT EXISTS map_url TEXT`,
  `ALTER TABLE shops ADD COLUMN IF NOT EXISTS is_open BOOLEAN NOT NULL DEFAULT TRUE`,
  `ALTER TABLE shops ADD COLUMN IF NOT EXISTS created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()`,
  `ALTER TABLE shops ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()`,
  `CREATE UNIQUE INDEX IF NOT EXISTS shops_payment_qr_fingerprint_idx
    ON shops(payment_qr_fingerprint)
    WHERE payment_qr_fingerprint IS NOT NULL`,
  `CREATE UNIQUE INDEX IF NOT EXISTS shops_upi_id_idx
    ON shops(upi_id)
    WHERE upi_id IS NOT NULL`,
  `CREATE TABLE IF NOT EXISTS shelf_items (
    id TEXT PRIMARY KEY,
    shop_id TEXT NOT NULL REFERENCES shops(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    price_cents INTEGER NOT NULL CHECK (price_cents >= 0),
    stock_qty INTEGER NOT NULL DEFAULT 0 CHECK (stock_qty >= 0),
    category TEXT,
    barcode TEXT,
    description TEXT,
    image_url TEXT,
    alert_threshold INTEGER NOT NULL DEFAULT 3 CHECK (alert_threshold >= 0),
    alert_enabled BOOLEAN NOT NULL DEFAULT TRUE,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
  )`,
  `ALTER TABLE shelf_items ADD COLUMN IF NOT EXISTS description TEXT`,
  `ALTER TABLE shelf_items ADD COLUMN IF NOT EXISTS alert_threshold INTEGER NOT NULL DEFAULT 3 CHECK (alert_threshold >= 0)`,
  `ALTER TABLE shelf_items ADD COLUMN IF NOT EXISTS alert_enabled BOOLEAN NOT NULL DEFAULT TRUE`,
  `CREATE INDEX IF NOT EXISTS shelf_items_shop_active_idx
    ON shelf_items(shop_id, is_active)`,
  `CREATE TABLE IF NOT EXISTS payment_records (
    id TEXT PRIMARY KEY,
    user_id TEXT NOT NULL REFERENCES app_users(id) ON DELETE RESTRICT,
    shop_id TEXT NOT NULL REFERENCES shops(id) ON DELETE RESTRICT,
    gross_cents INTEGER NOT NULL CHECK (gross_cents >= 0),
    gateway_fee_cents INTEGER NOT NULL DEFAULT 0 CHECK (gateway_fee_cents >= 0),
    commission_cents INTEGER NOT NULL CHECK (commission_cents >= 0),
    seller_net_cents INTEGER NOT NULL CHECK (seller_net_cents >= 0),
    status TEXT NOT NULL DEFAULT 'completed' CHECK (status IN ('pending', 'completed', 'failed', 'refunded')),
    source TEXT NOT NULL DEFAULT 'in_app' CHECK (source IN ('in_app', 'offline_scan')),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
  )`,
  `ALTER TABLE payment_records ADD COLUMN IF NOT EXISTS gateway_fee_cents INTEGER NOT NULL DEFAULT 0 CHECK (gateway_fee_cents >= 0)`,
  `ALTER TABLE payment_records ADD COLUMN IF NOT EXISTS provider TEXT NOT NULL DEFAULT 'mock_gateway'`,
  `ALTER TABLE payment_records ADD COLUMN IF NOT EXISTS gateway_reference TEXT`,
  `CREATE TABLE IF NOT EXISTS payment_record_items (
    id TEXT PRIMARY KEY,
    payment_id TEXT NOT NULL REFERENCES payment_records(id) ON DELETE CASCADE,
    shelf_item_id TEXT REFERENCES shelf_items(id) ON DELETE SET NULL,
    item_name TEXT NOT NULL,
    unit_price_cents INTEGER NOT NULL CHECK (unit_price_cents >= 0),
    quantity INTEGER NOT NULL CHECK (quantity > 0),
    line_total_cents INTEGER NOT NULL CHECK (line_total_cents >= 0)
  )`,
  `CREATE TABLE IF NOT EXISTS user_settings (
    user_id TEXT PRIMARY KEY REFERENCES app_users(id) ON DELETE CASCADE,
    preferences JSONB NOT NULL DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
  )`,
  `CREATE TABLE IF NOT EXISTS platform_settings (
    key TEXT PRIMARY KEY,
    value JSONB NOT NULL DEFAULT '{}'::jsonb,
    updated_by_user_id TEXT REFERENCES app_users(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
  )`,
  `INSERT INTO platform_settings (key, value)
    VALUES ('payment', '{"commissionRate":0.04}'::jsonb)
    ON CONFLICT (key) DO NOTHING`,
  `UPDATE platform_settings
    SET value = value || '{"commissionRate":0.04}'::jsonb,
        updated_at = NOW()
    WHERE key = 'payment'
      AND updated_by_user_id IS NULL
      AND COALESCE((value->>'commissionRate')::NUMERIC, 0.03) = 0.03`,
  `CREATE TABLE IF NOT EXISTS product_reviews (
    id TEXT PRIMARY KEY,
    shelf_item_id TEXT NOT NULL REFERENCES shelf_items(id) ON DELETE CASCADE,
    user_id TEXT NOT NULL REFERENCES app_users(id) ON DELETE CASCADE,
    rating INTEGER NOT NULL DEFAULT 5 CHECK (rating BETWEEN 1 AND 5),
    comment TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
  )`,
  `CREATE INDEX IF NOT EXISTS product_reviews_item_created_idx
    ON product_reviews(shelf_item_id, created_at DESC)`,
  `CREATE TABLE IF NOT EXISTS saved_products (
    user_id TEXT NOT NULL REFERENCES app_users(id) ON DELETE CASCADE,
    shelf_item_id TEXT NOT NULL REFERENCES shelf_items(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (user_id, shelf_item_id)
  )`,
  `CREATE INDEX IF NOT EXISTS saved_products_user_created_idx
    ON saved_products(user_id, created_at DESC)`,
  `CREATE TABLE IF NOT EXISTS saved_groups (
    id TEXT PRIMARY KEY,
    user_id TEXT NOT NULL REFERENCES app_users(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    shop_id TEXT REFERENCES shops(id) ON DELETE SET NULL,
    shop_name TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
  )`,
  `CREATE INDEX IF NOT EXISTS saved_groups_user_created_idx
    ON saved_groups(user_id, created_at DESC)`,
  `CREATE TABLE IF NOT EXISTS saved_group_items (
    group_id TEXT NOT NULL REFERENCES saved_groups(id) ON DELETE CASCADE,
    shelf_item_id TEXT NOT NULL REFERENCES shelf_items(id) ON DELETE CASCADE,
    quantity INTEGER NOT NULL CHECK (quantity > 0 AND quantity <= 99),
    PRIMARY KEY (group_id, shelf_item_id)
  )`,
  `CREATE TABLE IF NOT EXISTS shop_followers (
    shop_id TEXT NOT NULL REFERENCES shops(id) ON DELETE CASCADE,
    user_id TEXT NOT NULL REFERENCES app_users(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (shop_id, user_id)
  )`,
  `CREATE INDEX IF NOT EXISTS shop_followers_user_idx
    ON shop_followers(user_id, created_at DESC)`,
  `CREATE TABLE IF NOT EXISTS notifications (
    id TEXT PRIMARY KEY,
    recipient_user_id TEXT NOT NULL REFERENCES app_users(id) ON DELETE CASCADE,
    actor_user_id TEXT REFERENCES app_users(id) ON DELETE SET NULL,
    shop_id TEXT REFERENCES shops(id) ON DELETE CASCADE,
    type TEXT NOT NULL,
    title TEXT NOT NULL,
    body TEXT,
    is_read BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
  )`,
  `CREATE INDEX IF NOT EXISTS notifications_recipient_created_idx
    ON notifications(recipient_user_id, created_at DESC)`,
  `CREATE TABLE IF NOT EXISTS admin_signals (
    id TEXT PRIMARY KEY,
    admin_user_id TEXT REFERENCES app_users(id) ON DELETE SET NULL,
    audience TEXT NOT NULL CHECK (audience IN ('all', 'users', 'sellers')),
    title TEXT NOT NULL,
    body TEXT NOT NULL,
    recipient_count INTEGER NOT NULL DEFAULT 0 CHECK (recipient_count >= 0),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
  )`,
  `CREATE INDEX IF NOT EXISTS admin_signals_created_idx
    ON admin_signals(created_at DESC)`,
  `CREATE TABLE IF NOT EXISTS disputes (
    id TEXT PRIMARY KEY,
    reporter_user_id TEXT REFERENCES app_users(id) ON DELETE SET NULL,
    reporter_role TEXT NOT NULL DEFAULT 'user' CHECK (reporter_role IN ('user', 'seller')),
    category TEXT NOT NULL,
    description TEXT NOT NULL,
    status TEXT NOT NULL DEFAULT 'open' CHECK (status IN ('open', 'acknowledged', 'resolved')),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
  )`,
  `CREATE INDEX IF NOT EXISTS disputes_status_created_idx
    ON disputes(status, created_at DESC)`,
  `CREATE TABLE IF NOT EXISTS product_promotions (
    id TEXT PRIMARY KEY,
    seller_id TEXT NOT NULL REFERENCES app_users(id) ON DELETE CASCADE,
    shop_id TEXT NOT NULL REFERENCES shops(id) ON DELETE CASCADE,
    shelf_item_id TEXT NOT NULL REFERENCES shelf_items(id) ON DELETE CASCADE,
    duration_days INTEGER NOT NULL CHECK (duration_days > 0),
    amount_cents INTEGER NOT NULL DEFAULT 0 CHECK (amount_cents >= 0),
    status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'approved', 'rejected', 'refunded', 'expired')),
    starts_at TIMESTAMPTZ,
    ends_at TIMESTAMPTZ,
    impressions INTEGER NOT NULL DEFAULT 0 CHECK (impressions >= 0),
    clicks INTEGER NOT NULL DEFAULT 0 CHECK (clicks >= 0),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
  )`,
  `ALTER TABLE product_promotions DROP CONSTRAINT IF EXISTS product_promotions_status_check`,
  `ALTER TABLE product_promotions
    ADD CONSTRAINT product_promotions_status_check
    CHECK (status IN ('pending', 'approved', 'rejected', 'refunded', 'expired'))`,
  `CREATE INDEX IF NOT EXISTS product_promotions_status_created_idx
    ON product_promotions(status, created_at DESC)`,
  `CREATE TABLE IF NOT EXISTS chat_messages (
    id TEXT PRIMARY KEY,
    room_id TEXT NOT NULL,
    scope TEXT NOT NULL DEFAULT 'chat',
    sender_user_id TEXT NOT NULL REFERENCES app_users(id) ON DELETE CASCADE,
    target_user_id TEXT REFERENCES app_users(id) ON DELETE SET NULL,
    shop_id TEXT REFERENCES shops(id) ON DELETE CASCADE,
    text TEXT NOT NULL,
    message_type TEXT NOT NULL DEFAULT 'text',
    media_url TEXT,
    media_name TEXT,
    media_mime TEXT,
    media_size_bytes INTEGER,
    media_duration_seconds INTEGER,
    reaction TEXT,
    delivery_status TEXT NOT NULL DEFAULT 'sent_online',
    delivered_at TIMESTAMPTZ,
    read_at TIMESTAMPTZ,
    deleted_at TIMESTAMPTZ,
    deleted_by_user_id TEXT REFERENCES app_users(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
  )`,
  `ALTER TABLE chat_messages ADD COLUMN IF NOT EXISTS message_type TEXT NOT NULL DEFAULT 'text'`,
  `ALTER TABLE chat_messages ADD COLUMN IF NOT EXISTS media_url TEXT`,
  `ALTER TABLE chat_messages ADD COLUMN IF NOT EXISTS media_name TEXT`,
  `ALTER TABLE chat_messages ADD COLUMN IF NOT EXISTS media_mime TEXT`,
  `ALTER TABLE chat_messages ADD COLUMN IF NOT EXISTS media_size_bytes INTEGER`,
  `ALTER TABLE chat_messages ADD COLUMN IF NOT EXISTS media_duration_seconds INTEGER`,
  `ALTER TABLE chat_messages ADD COLUMN IF NOT EXISTS reaction TEXT`,
  `ALTER TABLE chat_messages ADD COLUMN IF NOT EXISTS delivery_status TEXT NOT NULL DEFAULT 'sent_online'`,
  `ALTER TABLE chat_messages ADD COLUMN IF NOT EXISTS delivered_at TIMESTAMPTZ`,
  `ALTER TABLE chat_messages ADD COLUMN IF NOT EXISTS read_at TIMESTAMPTZ`,
  `ALTER TABLE chat_messages ADD COLUMN IF NOT EXISTS deleted_at TIMESTAMPTZ`,
  `ALTER TABLE chat_messages ADD COLUMN IF NOT EXISTS deleted_by_user_id TEXT REFERENCES app_users(id) ON DELETE SET NULL`,
  `ALTER TABLE chat_messages ADD COLUMN IF NOT EXISTS deleted_original_text TEXT`,
  `ALTER TABLE chat_messages ADD COLUMN IF NOT EXISTS deleted_original_type TEXT`,
  `ALTER TABLE chat_messages ADD COLUMN IF NOT EXISTS deleted_original_media_url TEXT`,
  `ALTER TABLE chat_messages ADD COLUMN IF NOT EXISTS deleted_original_media_name TEXT`,
  `ALTER TABLE chat_messages ADD COLUMN IF NOT EXISTS deleted_original_media_mime TEXT`,
  `CREATE TABLE IF NOT EXISTS media_storage_deletions (
    user_id TEXT NOT NULL REFERENCES app_users(id) ON DELETE CASCADE,
    message_id TEXT NOT NULL REFERENCES chat_messages(id) ON DELETE CASCADE,
    deleted_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (user_id, message_id)
  )`,
  `CREATE TABLE IF NOT EXISTS chat_room_hides (
    user_id TEXT NOT NULL REFERENCES app_users(id) ON DELETE CASCADE,
    room_id TEXT NOT NULL,
    hidden_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (user_id, room_id)
  )`,
  `CREATE TABLE IF NOT EXISTS search_logs (
    id TEXT PRIMARY KEY,
    user_id TEXT REFERENCES app_users(id) ON DELETE SET NULL,
    query_text TEXT NOT NULL,
    surface TEXT NOT NULL DEFAULT 'search',
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
  )`,
  `CREATE INDEX IF NOT EXISTS search_logs_user_created_idx
    ON search_logs(user_id, created_at DESC)`,
  `CREATE INDEX IF NOT EXISTS chat_messages_room_created_idx
    ON chat_messages(room_id, created_at DESC)`,
  `CREATE INDEX IF NOT EXISTS chat_messages_sender_created_idx
    ON chat_messages(sender_user_id, created_at DESC)`,
  `WITH identifiable_shop_rooms AS (
    SELECT cm.id, s.id AS shop_id,
      CASE
        WHEN sender.role = 'user' THEN cm.sender_user_id
        WHEN target_user.role = 'user' THEN cm.target_user_id
        ELSE NULL
      END AS buyer_id
    FROM chat_messages cm
    INNER JOIN app_users sender ON sender.id = cm.sender_user_id
    LEFT JOIN app_users target_user ON target_user.id = cm.target_user_id
    INNER JOIN shops s ON s.id = cm.shop_id
      OR cm.room_id = 'shop:' || s.id
      OR LOWER(cm.room_id) = LOWER('shop:' || s.name)
    WHERE cm.scope = 'shop_payment'
      AND cm.room_id NOT LIKE 'shop:%:user:%'
  )
  UPDATE chat_messages cm
  SET room_id = 'shop:' || identifiable_shop_rooms.shop_id || ':user:' || identifiable_shop_rooms.buyer_id,
      shop_id = COALESCE(cm.shop_id, identifiable_shop_rooms.shop_id)
  FROM identifiable_shop_rooms
  WHERE cm.id = identifiable_shop_rooms.id
    AND identifiable_shop_rooms.buyer_id IS NOT NULL`,
  `CREATE TABLE IF NOT EXISTS call_records (
    id TEXT PRIMARY KEY,
    room_id TEXT NOT NULL,
    scope TEXT NOT NULL DEFAULT 'shop_payment',
    caller_user_id TEXT NOT NULL REFERENCES app_users(id) ON DELETE CASCADE,
    target_user_id TEXT REFERENCES app_users(id) ON DELETE SET NULL,
    shop_id TEXT REFERENCES shops(id) ON DELETE CASCADE,
    call_kind TEXT NOT NULL CHECK (call_kind IN ('voice', 'video')),
    status TEXT NOT NULL DEFAULT 'ringing' CHECK (status IN ('ringing', 'accepted', 'ended', 'declined', 'missed')),
    started_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    answered_at TIMESTAMPTZ,
    ended_at TIMESTAMPTZ,
    duration_seconds INTEGER
  )`,
  `ALTER TABLE call_records ADD COLUMN IF NOT EXISTS target_user_id TEXT REFERENCES app_users(id) ON DELETE SET NULL`,
  `ALTER TABLE call_records ADD COLUMN IF NOT EXISTS shop_id TEXT REFERENCES shops(id) ON DELETE CASCADE`,
  `ALTER TABLE call_records ADD COLUMN IF NOT EXISTS duration_seconds INTEGER`,
  `CREATE INDEX IF NOT EXISTS call_records_room_started_idx
    ON call_records(room_id, started_at DESC)`,
  `CREATE INDEX IF NOT EXISTS call_records_caller_started_idx
    ON call_records(caller_user_id, started_at DESC)`,
];

async function migrate() {
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    for (const statement of statements) {
      await client.query(statement);
    }
    await client.query('COMMIT');
    console.log('Database migration completed');
  } catch (error) {
    await client.query('ROLLBACK');
    throw error;
  } finally {
    client.release();
    await pool.end();
  }
}

migrate().catch((error) => {
  console.error(error);
  process.exit(1);
});
