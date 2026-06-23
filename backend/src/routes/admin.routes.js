import express from 'express';
import { z } from 'zod';
import { query, withTransaction } from '../db/pool.js';
import { requireAuth, requireRole } from '../middleware/auth.js';
import {
  isUserOnline,
  publishToUser,
  publishToUsers,
} from '../realtime/socketHub.js';
import { HttpError } from '../utils/httpError.js';
import { makeId } from '../utils/ids.js';

export const adminRouter = express.Router();

adminRouter.use(requireAuth, requireRole('admin'));

const liveAccountFilter = `
  AND u.email NOT LIKE '%@dukaanzone.local'
  AND u.email NOT LIKE '%@dz.local'
`;

const accountsSchema = z.object({
  q: z.string().trim().max(120).optional(),
  limit: z.coerce.number().int().min(1).max(200).default(100),
});

const restrictSchema = z.object({
  days: z.coerce.number().int().min(0).max(365),
  reason: z.string().trim().max(240).optional(),
});

const signalSchema = z.object({
  audience: z.enum(['all', 'users', 'sellers']).default('all'),
  title: z.string().trim().min(2).max(140),
  body: z.string().trim().min(2).max(500),
});

const disputeStatusSchema = z.object({
  status: z.enum(['open', 'acknowledged', 'resolved']),
});

const promotionStatusSchema = z.object({
  status: z.enum(['pending', 'approved', 'rejected', 'refunded', 'expired']),
});

const platformSettingsSchema = z.object({
  commissionRate: z.coerce.number().min(0).max(0.25).optional(),
  promotion3DayRate: z.coerce.number().min(0).max(1000).optional(),
  promotion7DayRate: z.coerce.number().min(0).max(1000).optional(),
  promotion30DayRate: z.coerce.number().min(0).max(1000).optional(),
  notificationHubEnabled: z.boolean().optional(),
  notificationDriver: z.string().trim().max(80).optional(),
  dbPollingIntervalMs: z.coerce.number().int().min(100).max(10000).optional(),
});

adminRouter.get('/overview', async (_req, res, next) => {
  try {
    const result = await query(
      `SELECT
        (SELECT COUNT(*)::INT FROM app_users u WHERE role = 'user' AND deleted_at IS NULL ${liveAccountFilter}) AS user_count,
        (SELECT COUNT(*)::INT FROM app_users u WHERE role = 'seller' AND deleted_at IS NULL ${liveAccountFilter}) AS seller_count,
        (SELECT COUNT(*)::INT FROM shops s INNER JOIN app_users u ON u.id = s.seller_id WHERE u.deleted_at IS NULL ${liveAccountFilter}) AS shop_count,
        (SELECT COUNT(*)::INT
         FROM shelf_items si
         INNER JOIN shops s ON s.id = si.shop_id
         INNER JOIN app_users u ON u.id = s.seller_id
         WHERE si.is_active = TRUE
           AND u.deleted_at IS NULL
           ${liveAccountFilter}) AS product_count,
        (SELECT COUNT(*)::INT FROM chat_messages WHERE deleted_at IS NOT NULL) AS deleted_message_count,
        (SELECT COUNT(*)::INT FROM payment_records WHERE status = 'completed') AS payment_count,
        (SELECT COALESCE(SUM(gross_cents), 0)::INT FROM payment_records WHERE status = 'completed') AS gross_cents,
        (SELECT COALESCE(SUM(gateway_fee_cents), 0)::INT FROM payment_records WHERE status = 'completed') AS gateway_fee_cents,
        (SELECT COALESCE(SUM(seller_net_cents), 0)::INT FROM payment_records WHERE status = 'completed') AS seller_net_cents,
        (SELECT COALESCE(SUM(commission_cents), 0)::INT FROM payment_records WHERE status = 'completed') AS commission_cents`,
    );
    res.json({ overview: result.rows[0] });
  } catch (error) {
    next(error);
  }
});

adminRouter.get('/payments', async (req, res, next) => {
  try {
    const limit = Math.min(
      Math.max(Number.parseInt(req.query.limit?.toString() ?? '120', 10) || 120, 1),
      300,
    );
    const result = await query(
      `SELECT pr.id, pr.gross_cents, pr.gateway_fee_cents,
        pr.commission_cents, pr.seller_net_cents, pr.status, pr.source,
        pr.provider, pr.gateway_reference, pr.created_at,
        buyer.id AS buyer_id, buyer.name AS buyer_name,
        seller.id AS seller_id, seller.name AS seller_name,
        s.id AS shop_id, s.name AS shop_name, s.category, s.block,
        s.upi_id, s.payment_qr_payload, s.payout_status, s.gateway_provider
       FROM payment_records pr
       INNER JOIN app_users buyer ON buyer.id = pr.user_id
       INNER JOIN shops s ON s.id = pr.shop_id
       INNER JOIN app_users seller ON seller.id = s.seller_id
       ORDER BY pr.created_at DESC
       LIMIT $1`,
      [limit],
    );
    res.json({ payments: result.rows.map(mapAdminPayment) });
  } catch (error) {
    next(error);
  }
});

adminRouter.get('/signals', async (_req, res, next) => {
  try {
    const result = await query(
      `SELECT sig.id, sig.audience, sig.title, sig.body, sig.recipient_count,
        sig.created_at, admin.name AS admin_name
       FROM admin_signals sig
       LEFT JOIN app_users admin ON admin.id = sig.admin_user_id
       ORDER BY sig.created_at DESC
       LIMIT 100`,
    );
    res.json({ signals: result.rows.map(mapAdminSignal) });
  } catch (error) {
    next(error);
  }
});

adminRouter.post('/signals', async (req, res, next) => {
  try {
    const input = signalSchema.parse(req.body);
    const roleClause = input.audience === 'all'
      ? "role IN ('user', 'seller')"
      : 'role = $1';
    const roleParams = input.audience === 'all' ? [] : [input.audience.slice(0, -1)];

    const output = await withTransaction(async (client) => {
      const recipients = await client.query(
        `SELECT u.id, u.role
         FROM app_users u
         WHERE ${roleClause}
           AND u.deleted_at IS NULL
           ${liveAccountFilter}`,
        roleParams,
      );
      const recipientIds = recipients.rows.map((row) => row.id);
      const signalId = makeId('signal');
      const signalResult = await client.query(
        `INSERT INTO admin_signals (
          id, admin_user_id, audience, title, body, recipient_count
        )
        VALUES ($1, $2, $3, $4, $5, $6)
        RETURNING id, audience, title, body, recipient_count, created_at`,
        [
          signalId,
          req.user.sub,
          input.audience,
          input.title,
          input.body,
          recipientIds.length,
        ],
      );

      for (const recipientId of recipientIds) {
        await client.query(
          `INSERT INTO notifications (
            id, recipient_user_id, actor_user_id, type, title, body
          )
          VALUES ($1, $2, $3, 'admin.signal', $4, $5)`,
          [makeId('notif'), recipientId, req.user.sub, input.title, input.body],
        );
      }

      return {
        signal: mapAdminSignal(signalResult.rows[0]),
        recipientIds,
      };
    });

    publishToUsers(output.recipientIds, 'notification.created', {
      type: 'admin.signal',
      title: input.title,
      body: input.body,
    });
    res.status(201).json(output);
  } catch (error) {
    next(error);
  }
});

adminRouter.delete('/signals/:signalId', async (req, res, next) => {
  try {
    await query(
      `DELETE FROM admin_signals
       WHERE id = $1`,
      [req.params.signalId],
    );
    res.status(204).send();
  } catch (error) {
    next(error);
  }
});

adminRouter.get('/settings', async (_req, res, next) => {
  try {
    const result = await query(
      `SELECT value, updated_at
       FROM platform_settings
       WHERE key = 'payment'`,
    );
    const value = result.rows[0]?.value ?? {};
    res.json({
      settings: normalizePlatformSettings(value),
      updatedAt: result.rows[0]?.updated_at ?? null,
    });
  } catch (error) {
    next(error);
  }
});

adminRouter.patch('/settings', async (req, res, next) => {
  try {
    const input = platformSettingsSchema.parse(req.body.settings ?? req.body);
    const current = await query(
      `SELECT value FROM platform_settings WHERE key = 'payment'`,
    );
    const merged = {
      ...normalizePlatformSettings(current.rows[0]?.value ?? {}),
      ...input,
    };
    const result = await query(
      `INSERT INTO platform_settings (key, value, updated_by_user_id)
       VALUES ('payment', $1::jsonb, $2)
       ON CONFLICT (key) DO UPDATE
       SET value = platform_settings.value || EXCLUDED.value,
           updated_by_user_id = EXCLUDED.updated_by_user_id,
           updated_at = NOW()
       RETURNING value, updated_at`,
      [JSON.stringify(merged), req.user.sub],
    );
    const settings = normalizePlatformSettings(result.rows[0].value ?? {});
    publishToRole('seller', 'platform.settings.updated', { settings });
    publishToRole('user', 'platform.settings.updated', { settings });
    publishToRole('admin', 'platform.settings.updated', { settings });
    res.json({ settings, updatedAt: result.rows[0].updated_at });
  } catch (error) {
    next(error);
  }
});

adminRouter.get('/disputes', async (req, res, next) => {
  try {
    const party = ['user', 'seller'].includes(req.query.party)
      ? req.query.party
      : null;
    const result = await query(
      `SELECT d.id, d.reporter_role, d.category, d.description, d.status,
        d.created_at, d.updated_at,
        reporter.id AS reporter_id,
        reporter.name AS reporter_name,
        reporter.email AS reporter_email,
        reporter.phone AS reporter_phone
       FROM disputes d
       LEFT JOIN app_users reporter ON reporter.id = d.reporter_user_id
       WHERE ($1::TEXT IS NULL OR d.reporter_role = $1)
       ORDER BY d.created_at DESC
       LIMIT 120`,
      [party],
    );
    res.json({ disputes: result.rows.map(mapAdminDispute) });
  } catch (error) {
    next(error);
  }
});

adminRouter.patch('/disputes/:disputeId/status', async (req, res, next) => {
  try {
    const input = disputeStatusSchema.parse(req.body);
    const result = await query(
      `UPDATE disputes
       SET status = $2, updated_at = NOW()
       WHERE id = $1
       RETURNING id, reporter_user_id, reporter_role, category, description,
        status, created_at, updated_at`,
      [req.params.disputeId, input.status],
    );
    const dispute = result.rows[0];
    if (!dispute) throw new HttpError(404, 'Dispute not found');

    if (dispute.reporter_user_id && input.status !== 'open') {
      const title = input.status === 'resolved'
        ? 'Dispute resolved'
        : 'Dispute acknowledged';
      const body = input.status === 'resolved'
        ? `Your ${dispute.category} report has been resolved by DukaanZone.`
        : `Your ${dispute.category} report is now under review.`;
      await query(
        `INSERT INTO notifications (
          id, recipient_user_id, actor_user_id, type, title, body
        )
        VALUES ($1, $2, $3, 'dispute.status', $4, $5)`,
        [makeId('notif'), dispute.reporter_user_id, req.user.sub, title, body],
      );
      publishToUser(dispute.reporter_user_id, 'notification.created', {
        type: 'dispute.status',
        title,
        body,
      });
    }

    res.json({ dispute: mapAdminDispute(dispute) });
  } catch (error) {
    next(error);
  }
});

adminRouter.delete('/disputes/:disputeId', async (req, res, next) => {
  try {
    const result = await query(
      `DELETE FROM disputes
       WHERE id = $1
       RETURNING id`,
      [req.params.disputeId],
    );
    if (!result.rows[0]) throw new HttpError(404, 'Dispute not found');
    res.status(204).send();
  } catch (error) {
    next(error);
  }
});

adminRouter.get('/promotions', async (_req, res, next) => {
  try {
    const result = await query(
      `SELECT p.id, p.duration_days, p.amount_cents, p.status, p.starts_at,
        p.ends_at, p.impressions, p.clicks, p.created_at, p.updated_at,
        seller.id AS seller_id, seller.name AS seller_name, seller.email AS seller_email,
        shop.id AS shop_id, shop.name AS shop_name, shop.avatar_url AS shop_avatar_url,
        item.id AS item_id, item.name AS item_name, item.image_url AS item_image_url,
        item.price_cents
       FROM product_promotions p
       INNER JOIN app_users seller ON seller.id = p.seller_id
       INNER JOIN shops shop ON shop.id = p.shop_id
       INNER JOIN shelf_items item ON item.id = p.shelf_item_id
       WHERE seller.deleted_at IS NULL
       ORDER BY p.created_at DESC
       LIMIT 120`,
    );
    res.json({ promotions: result.rows.map(mapAdminPromotion) });
  } catch (error) {
    next(error);
  }
});

adminRouter.patch('/promotions/:promotionId/status', async (req, res, next) => {
  try {
    const input = promotionStatusSchema.parse(req.body);
    const result = await query(
      `UPDATE product_promotions
       SET status = $2,
           starts_at = CASE WHEN $2 = 'approved' THEN COALESCE(starts_at, NOW()) ELSE starts_at END,
           ends_at = CASE
             WHEN $2 = 'approved'
               THEN COALESCE(ends_at, NOW() + (duration_days * INTERVAL '1 day'))
             WHEN $2 IN ('rejected', 'refunded', 'expired')
               THEN NOW()
             ELSE ends_at
           END,
           updated_at = NOW()
       WHERE id = $1
       RETURNING id, seller_id, status`,
      [req.params.promotionId, input.status],
    );
    const promotion = result.rows[0];
    if (!promotion) throw new HttpError(404, 'Promotion not found');

    const title = input.status === 'approved'
      ? 'Promotion approved'
      : input.status === 'rejected'
        ? 'Promotion rejected'
        : input.status === 'refunded'
          ? 'Promotion payment return marked'
          : 'Promotion updated';
    const body = input.status === 'refunded'
      ? 'Admin marked your promotion payment for return.'
      : `Your promotion status is now ${input.status}.`;
    await query(
      `INSERT INTO notifications (
        id, recipient_user_id, actor_user_id, type, title, body
      )
      VALUES ($1, $2, $3, 'promotion.status', $4, $5)`,
      [makeId('notif'), promotion.seller_id, req.user.sub, title, body],
    );
    publishToUser(promotion.seller_id, 'notification.created', {
      type: 'promotion.status',
      title,
      body,
    });

    res.json({ ok: true });
  } catch (error) {
    next(error);
  }
});

adminRouter.get('/accounts', async (req, res, next) => {
  try {
    const input = accountsSchema.parse(req.query);
    const search = input.q ? `%${input.q.toLowerCase()}%` : null;
    const users = await query(
      `SELECT u.id, u.name, u.email, u.phone, u.profile_pic, u.created_at,
        u.restricted_until, u.restriction_reason,
        COALESCE(SUM(pr.gross_cents), 0)::INT AS spend_cents,
        COUNT(DISTINCT cm.room_id)::INT AS chat_count
       FROM app_users u
       LEFT JOIN payment_records pr ON pr.user_id = u.id
       LEFT JOIN chat_messages cm ON cm.sender_user_id = u.id OR cm.target_user_id = u.id
       WHERE u.role = 'user'
         AND u.deleted_at IS NULL
         ${liveAccountFilter}
         AND ($1::TEXT IS NULL
          OR LOWER(u.name) LIKE $1
          OR LOWER(u.email) LIKE $1
          OR LOWER(COALESCE(u.phone, '')) LIKE $1)
       GROUP BY u.id
       ORDER BY u.created_at DESC
       LIMIT $2`,
      [search, input.limit],
    );

    const sellers = await query(
      `SELECT u.id AS seller_id, u.name AS owner_name, u.email, u.phone,
        u.profile_pic, u.created_at, u.restricted_until, u.restriction_reason,
        s.id AS shop_id, s.name AS shop_name, s.category, s.block, s.avatar_url,
        s.is_open, s.upi_id, s.payment_qr_payload, s.payout_status,
        s.gateway_provider, s.payment_qr_updated_at,
        COALESCE(SUM(pr.seller_net_cents), 0)::INT AS revenue_cents,
        (SELECT ROUND(AVG(rev.rating)::NUMERIC, 1)::FLOAT
         FROM product_reviews rev
         INNER JOIN shelf_items item ON item.id = rev.shelf_item_id
         WHERE item.shop_id = s.id) AS rating,
        (SELECT COUNT(*)::INT FROM shelf_items item WHERE item.shop_id = s.id) AS item_count,
        (SELECT COUNT(*)::INT FROM shop_followers sf WHERE sf.shop_id = s.id) AS follower_count
       FROM app_users u
       LEFT JOIN shops s ON s.seller_id = u.id
       LEFT JOIN payment_records pr ON pr.shop_id = s.id
       WHERE u.role = 'seller'
         AND u.deleted_at IS NULL
         ${liveAccountFilter}
         AND ($1::TEXT IS NULL
          OR LOWER(u.name) LIKE $1
          OR LOWER(u.email) LIKE $1
          OR LOWER(COALESCE(u.phone, '')) LIKE $1
          OR LOWER(COALESCE(s.name, '')) LIKE $1
          OR LOWER(COALESCE(s.category, '')) LIKE $1)
       GROUP BY u.id, s.id
       ORDER BY u.created_at DESC
       LIMIT $2`,
      [search, input.limit],
    );

    res.json({
      users: users.rows.map(mapAdminUser),
      sellers: sellers.rows.map(mapAdminSeller),
    });
  } catch (error) {
    next(error);
  }
});

adminRouter.get('/accounts/:userId/activity', async (req, res, next) => {
  try {
    const user = await getAdminUser(req.params.userId);
    if (!user) throw new HttpError(404, 'Account not found');

    const searches = await query(
      `SELECT id, query_text, surface, created_at
       FROM search_logs
       WHERE user_id = $1
       ORDER BY created_at DESC
       LIMIT 80`,
      [req.params.userId],
    );

    const payments = await query(
      `SELECT pr.id, pr.gross_cents, pr.gateway_fee_cents,
        pr.commission_cents, pr.seller_net_cents, pr.status, pr.source,
        pr.provider, pr.gateway_reference, pr.created_at, s.name AS shop_name
       FROM payment_records pr
       LEFT JOIN shops s ON s.id = pr.shop_id
       WHERE pr.user_id = $1
          OR s.seller_id = $1
       ORDER BY pr.created_at DESC
       LIMIT 80`,
      [req.params.userId],
    );

    const chats = await query(
      `WITH rooms AS (
        SELECT DISTINCT cm.room_id
        FROM chat_messages cm
        LEFT JOIN shops s ON s.id = cm.shop_id
        WHERE cm.sender_user_id = $1
           OR cm.target_user_id = $1
           OR s.seller_id = $1
      ),
      latest AS (
        SELECT DISTINCT ON (cm.room_id)
          cm.room_id, cm.scope, cm.text, cm.message_type, cm.media_name,
          cm.deleted_at, cm.created_at, cm.sender_user_id,
          cm.target_user_id, cm.shop_id
        FROM chat_messages cm
        INNER JOIN rooms r ON r.room_id = cm.room_id
        ORDER BY cm.room_id, cm.created_at DESC
      )
      SELECT latest.*,
        shop.name AS shop_name,
        shop.category AS shop_category,
        shop.block AS shop_block,
        shop.avatar_url AS shop_avatar_url,
        other_user.name AS other_user_name,
        other_user.email AS other_user_email,
        other_user.phone AS other_user_phone,
        other_user.role AS other_user_role,
        other_user.profile_pic AS other_user_avatar
      FROM latest
      LEFT JOIN LATERAL (
        SELECT s.id, s.name, s.category, s.block, s.avatar_url
        FROM shops s
        WHERE s.id = latest.shop_id
           OR latest.room_id = CONCAT('shop:', s.id)
        LIMIT 1
      ) shop ON TRUE
      LEFT JOIN LATERAL (
        SELECT u.id, u.name, u.email, u.phone, u.role, u.profile_pic, u.created_at
        FROM app_users u
        WHERE u.deleted_at IS NULL
          AND u.id <> $1
          AND (u.id = latest.sender_user_id OR u.id = latest.target_user_id)
        ORDER BY
          CASE WHEN u.role = CASE WHEN $2 = 'seller' THEN 'user' ELSE 'seller' END THEN 0 ELSE 1 END,
          u.created_at DESC
        LIMIT 1
      ) other_user ON TRUE
      ORDER BY latest.created_at DESC
      LIMIT 80`,
      [req.params.userId, user.role],
    );

    res.json({
      account: user,
      searches: searches.rows.map((row) => ({
        id: row.id,
        query: row.query_text,
        surface: row.surface,
        createdAt: row.created_at,
      })),
      payments: payments.rows.map((row) => ({
        id: row.id,
        grossCents: row.gross_cents,
        gatewayFeeCents: row.gateway_fee_cents ?? 0,
        commissionCents: row.commission_cents,
        sellerNetCents: row.seller_net_cents,
        status: row.status,
        source: row.source,
        provider: row.provider,
        gatewayReference: row.gateway_reference,
        shopName: row.shop_name,
        createdAt: row.created_at,
      })),
      chats: chats.rows.map((row) => mapAdminChat(row, user.role)),
    });
  } catch (error) {
    next(error);
  }
});

adminRouter.get('/chats/:roomId/messages', async (req, res, next) => {
  try {
    const result = await query(
      `SELECT cm.id, cm.room_id, cm.scope, cm.text, cm.created_at,
        cm.delivery_status, cm.read_at, cm.message_type, cm.media_url,
        cm.media_name, cm.media_mime, cm.reaction, cm.deleted_at,
        cm.deleted_original_text, cm.deleted_original_type,
        cm.deleted_original_media_url, cm.deleted_original_media_name,
        cm.deleted_by_user_id,
        sender.id AS sender_id, sender.name AS sender_name, sender.role AS sender_role,
        deleter.name AS deleted_by_name
       FROM chat_messages cm
       INNER JOIN app_users sender ON sender.id = cm.sender_user_id
       LEFT JOIN app_users deleter ON deleter.id = cm.deleted_by_user_id
       WHERE cm.room_id = $1
       ORDER BY cm.created_at ASC
       LIMIT 200`,
      [req.params.roomId],
    );
    const room = await getAdminRoomMeta(req.params.roomId);

    res.json({
      room,
      messages: result.rows.map((row) => ({
        id: row.id,
        roomId: row.room_id,
        scope: row.scope,
        text: row.deleted_at
          ? row.deleted_original_text ?? row.text
          : row.text,
        visibleText: row.text,
        type: row.deleted_at
          ? row.deleted_original_type ?? row.message_type
          : row.message_type,
        visibleType: row.message_type,
        mediaUrl: row.deleted_at
          ? row.deleted_original_media_url ?? row.media_url
          : row.media_url,
        mediaName: row.deleted_at
          ? row.deleted_original_media_name ?? row.media_name
          : row.media_name,
        mediaMime: row.media_mime,
        reaction: row.reaction,
        deliveryStatus: row.delivery_status,
        readAt: row.read_at,
        deletedAt: row.deleted_at,
        deletedBy: row.deleted_by_user_id
          ? {
              id: row.deleted_by_user_id,
              name: row.deleted_by_name,
            }
          : null,
        createdAt: row.created_at,
        sender: {
          id: row.sender_id,
          name: row.sender_name,
          role: row.sender_role,
          isOnline: isUserOnline(row.sender_id),
        },
      })),
    });
  } catch (error) {
    next(error);
  }
});

async function getAdminRoomMeta(roomId) {
  const result = await query(
    `WITH participant_ids AS (
      SELECT sender_user_id AS user_id
      FROM chat_messages
      WHERE room_id = $1
      UNION
      SELECT target_user_id AS user_id
      FROM chat_messages
      WHERE room_id = $1 AND target_user_id IS NOT NULL
      UNION
      SELECT s.seller_id AS user_id
      FROM chat_messages cm
      INNER JOIN shops s ON s.id = cm.shop_id
      WHERE cm.room_id = $1
    )
    SELECT u.id, u.name, u.role, u.email, u.phone, u.profile_pic,
      s.id AS shop_id, s.name AS shop_name, s.avatar_url AS shop_avatar_url
    FROM participant_ids p
    INNER JOIN app_users u ON u.id = p.user_id
    LEFT JOIN shops s ON s.seller_id = u.id
    WHERE u.deleted_at IS NULL
    ORDER BY CASE u.role WHEN 'seller' THEN 0 WHEN 'user' THEN 1 ELSE 2 END,
      u.created_at ASC`,
    [roomId],
  );
  const participants = result.rows.map((row) => ({
    id: row.id,
    name: row.shop_name ?? row.name,
    accountName: row.name,
    role: row.role,
    email: row.email,
    phone: row.phone,
    avatarUrl: (row.shop_avatar_url ?? row.profile_pic)?.startsWith('blob:')
      ? null
      : row.shop_avatar_url ?? row.profile_pic,
    isOnline: isUserOnline(row.id),
  }));
  return {
    id: roomId,
    title: buildRoomTitle(roomId, participants),
    participants,
  };
}

function buildRoomTitle(roomId, participants) {
  if (participants.length >= 2) {
    return participants.map((participant) => participant.name).join(' - ');
  }
  if (participants.length === 1) return participants[0].name;
  if (roomId.startsWith('b2b:')) return roomId.slice('b2b:'.length);
  if (roomId.startsWith('shop:')) return roomId.slice('shop:'.length);
  return roomId;
}

adminRouter.get('/sellers/:sellerId/shelf', async (req, res, next) => {
  try {
    const result = await query(
      `SELECT si.id, si.name, si.price_cents, si.stock_qty, si.category,
        si.description, si.image_url, si.alert_threshold, si.alert_enabled,
        si.is_active, si.created_at, si.updated_at,
        s.id AS shop_id, s.name AS shop_name
       FROM shelf_items si
       INNER JOIN shops s ON s.id = si.shop_id
       WHERE s.seller_id = $1
       ORDER BY si.updated_at DESC, si.created_at DESC`,
      [req.params.sellerId],
    );
    res.json({
      items: result.rows.map((row) => ({
        id: row.id,
        name: row.name,
        priceCents: row.price_cents,
        stockQty: row.stock_qty,
        category: row.category,
        description: row.description,
        imageUrl: row.image_url?.startsWith('blob:') ? null : row.image_url,
        alertThreshold: row.alert_threshold,
        alertEnabled: row.alert_enabled,
        isActive: row.is_active,
        shopId: row.shop_id,
        shopName: row.shop_name,
        createdAt: row.created_at,
        updatedAt: row.updated_at,
      })),
    });
  } catch (error) {
    next(error);
  }
});

adminRouter.patch('/accounts/:userId/restriction', async (req, res, next) => {
  try {
    const input = restrictSchema.parse(req.body);
    const restrictedUntil = input.days === 0
      ? null
      : new Date(Date.now() + input.days * 24 * 60 * 60 * 1000).toISOString();
    const result = await query(
      `UPDATE app_users
       SET restricted_until = $2,
           restriction_reason = $3,
           updated_at = NOW()
       WHERE id = $1 AND role <> 'admin' AND deleted_at IS NULL
       RETURNING id`,
      [
        req.params.userId,
        restrictedUntil,
        input.days === 0 ? null : input.reason ?? 'Restricted by admin',
      ],
    );
    if (result.rows.length === 0) throw new HttpError(404, 'Account not found');
    res.json({ ok: true, restrictedUntil });
  } catch (error) {
    next(error);
  }
});

adminRouter.delete('/accounts/:userId', async (req, res, next) => {
  try {
    const deleted = await withTransaction(async (client) => {
      const result = await client.query(
        `UPDATE app_users
         SET deleted_at = NOW(),
             email = CONCAT('deleted+', id, '+', email),
             phone = NULL,
             restricted_until = NULL,
             updated_at = NOW()
         WHERE id = $1 AND role <> 'admin' AND deleted_at IS NULL
         RETURNING id, role`,
        [req.params.userId],
      );
      const account = result.rows[0];
      if (!account) return null;

      if (account.role === 'seller') {
        await client.query(
          `UPDATE shops
           SET payment_qr_payload = NULL,
               payment_qr_fingerprint = NULL,
               upi_id = NULL,
               is_open = FALSE,
               updated_at = NOW()
           WHERE seller_id = $1`,
          [account.id],
        );
      }
      return account;
    });
    if (!deleted) throw new HttpError(404, 'Account not found');
    res.status(204).end();
  } catch (error) {
    next(error);
  }
});

async function getAdminUser(userId) {
  const result = await query(
    `SELECT u.id, u.role, u.name, u.email, u.phone, u.profile_pic,
      u.created_at, u.restricted_until, u.restriction_reason,
      s.id AS shop_id, s.name AS shop_name, s.category, s.block, s.avatar_url
     FROM app_users u
     LEFT JOIN shops s ON s.seller_id = u.id
     WHERE u.id = $1 AND u.deleted_at IS NULL`,
    [userId],
  );
  const row = result.rows[0];
  if (!row) return null;
  return {
    id: row.id,
    role: row.role,
    name: row.name,
    email: row.email,
    phone: row.phone,
    profilePic: row.profile_pic?.startsWith('blob:') ? null : row.profile_pic,
    createdAt: row.created_at,
    restrictedUntil: row.restricted_until,
    restrictionReason: row.restriction_reason,
    isOnline: isUserOnline(row.id),
    shop: row.shop_id
      ? {
          id: row.shop_id,
          name: row.shop_name,
          category: row.category,
          block: row.block,
          avatarUrl: row.avatar_url?.startsWith('blob:') ? null : row.avatar_url,
        }
      : null,
  };
}

function mapAdminUser(row) {
  return {
    id: row.id,
    name: row.name,
    email: row.email,
    phone: row.phone,
    profilePic: row.profile_pic?.startsWith('blob:') ? null : row.profile_pic,
    createdAt: row.created_at,
    restrictedUntil: row.restricted_until,
    restrictionReason: row.restriction_reason,
    spendCents: row.spend_cents ?? 0,
    chatCount: row.chat_count ?? 0,
    isOnline: isUserOnline(row.id),
  };
}

function mapAdminSeller(row) {
  return {
    id: row.seller_id,
    shopId: row.shop_id,
    owner: row.owner_name,
    email: row.email,
    phone: row.phone,
    profilePic: row.profile_pic?.startsWith('blob:') ? null : row.profile_pic,
    shopName: row.shop_name ?? row.owner_name,
    category: row.category,
    block: row.block,
    avatarUrl: row.avatar_url?.startsWith('blob:') ? null : row.avatar_url,
    isOpen: row.is_open,
    status: row.restricted_until && new Date(row.restricted_until) > new Date()
      ? 'Restricted'
      : row.is_open === false
        ? 'Closed'
        : 'Active',
    restrictedUntil: row.restricted_until,
    restrictionReason: row.restriction_reason,
    revenueCents: row.revenue_cents ?? 0,
    rating: row.rating ?? 0,
    itemCount: row.item_count ?? 0,
    followerCount: row.follower_count ?? 0,
    createdAt: row.created_at,
    isOnline: isUserOnline(row.seller_id),
    paymentProfile: {
      upiId: row.upi_id,
      hasUpi: typeof row.upi_id === 'string' && row.upi_id.trim() !== '',
      hasPaymentQr:
        typeof row.payment_qr_payload === 'string' &&
        row.payment_qr_payload.trim() !== '',
      paymentQrUpdatedAt: row.payment_qr_updated_at,
      payoutStatus: row.payout_status ?? 'sandbox_ready',
      gatewayProvider: row.gateway_provider ?? 'mock_gateway',
      payoutReady:
        typeof row.upi_id === 'string' &&
        row.upi_id.trim() !== '' &&
        typeof row.payment_qr_payload === 'string' &&
        row.payment_qr_payload.trim() !== '' &&
        typeof row.phone === 'string' &&
        row.phone.trim() !== '',
    },
  };
}

function mapAdminPayment(row) {
  return {
    id: row.id,
    grossCents: row.gross_cents,
    gatewayFeeCents: row.gateway_fee_cents ?? 0,
    commissionCents: row.commission_cents ?? 0,
    sellerNetCents: row.seller_net_cents ?? 0,
    status: row.status,
    source: row.source,
    provider: row.provider ?? 'mock_gateway',
    gatewayReference: row.gateway_reference,
    createdAt: row.created_at,
    buyer: {
      id: row.buyer_id,
      name: row.buyer_name,
    },
    seller: {
      id: row.seller_id,
      name: row.seller_name,
    },
    shop: {
      id: row.shop_id,
      name: row.shop_name,
      category: row.category,
      block: row.block,
      upiId: row.upi_id,
      hasPaymentQr:
        typeof row.payment_qr_payload === 'string' &&
        row.payment_qr_payload.trim() !== '',
      payoutStatus: row.payout_status ?? 'sandbox_ready',
      gatewayProvider: row.gateway_provider ?? 'mock_gateway',
    },
  };
}

function mapAdminSignal(row) {
  return {
    id: row.id,
    audience: row.audience,
    title: row.title,
    body: row.body,
    recipientCount: row.recipient_count ?? 0,
    adminName: row.admin_name,
    createdAt: row.created_at,
  };
}

function mapAdminDispute(row) {
  return {
    id: row.id,
    reporterRole: row.reporter_role,
    reporter: {
      id: row.reporter_id ?? row.reporter_user_id,
      name: row.reporter_name ?? 'Deleted account',
      email: row.reporter_email,
      phone: row.reporter_phone,
    },
    category: row.category,
    description: row.description,
    status: row.status,
    createdAt: row.created_at,
    updatedAt: row.updated_at,
  };
}

function mapAdminPromotion(row) {
  return {
    id: row.id,
    durationDays: row.duration_days,
    amountCents: row.amount_cents ?? 0,
    status: row.status,
    startsAt: row.starts_at,
    endsAt: row.ends_at,
    impressions: row.impressions ?? 0,
    clicks: row.clicks ?? 0,
    createdAt: row.created_at,
    updatedAt: row.updated_at,
    seller: {
      id: row.seller_id,
      name: row.seller_name,
      email: row.seller_email,
    },
    shop: {
      id: row.shop_id,
      name: row.shop_name,
      avatarUrl: cleanMediaUrl(row.shop_avatar_url),
    },
    item: {
      id: row.item_id,
      name: row.item_name,
      imageUrl: cleanMediaUrl(row.item_image_url),
      priceCents: row.price_cents ?? 0,
    },
  };
}

function normalizePlatformSettings(value) {
  const commissionRate = Number(value.commissionRate ?? value.commission_rate ?? 0.04);
  return {
    commissionRate: Number.isFinite(commissionRate)
      ? Math.min(Math.max(commissionRate, 0), 0.25)
      : 0.04,
    promotion3DayRate: Number(value.promotion3DayRate ?? 30),
    promotion7DayRate: Number(value.promotion7DayRate ?? 60),
    promotion30DayRate: Number(value.promotion30DayRate ?? 150),
    notificationHubEnabled: value.notificationHubEnabled !== false,
    notificationDriver: value.notificationDriver ?? 'PostgreSQL (pg_notify)',
    dbPollingIntervalMs: Number(value.dbPollingIntervalMs ?? 250),
  };
}

function mapAdminChat(row, accountRole) {
  return {
    roomId: row.room_id,
    scope: row.scope,
    title: adminChatTitle(row, accountRole),
    subtitle: adminChatSubtitle(row, accountRole),
    avatarUrl: cleanMediaUrl(adminChatAvatar(row, accountRole)),
    lastMessage: chatPreview(row),
    updatedAt: row.created_at,
  };
}

function adminChatTitle(row, accountRole) {
  if (row.scope === 'b2b') {
    return friendlyRoomName(row.room_id, 'b2b') || row.other_user_name || 'B2B Chat';
  }
  if (accountRole === 'seller') {
    return row.other_user_name || row.other_user_email || row.shop_name || friendlyRoomName(row.room_id, 'shop') || 'User Chat';
  }
  return row.shop_name || row.other_user_name || friendlyRoomName(row.room_id, 'shop') || 'Shop Chat';
}

function adminChatSubtitle(row, accountRole) {
  if (row.scope === 'b2b') {
    return [row.other_user_name, row.other_user_role].filter(Boolean).join(' - ') || 'B2B dialogue';
  }
  if (accountRole === 'seller') {
    return [row.other_user_phone, row.other_user_email].filter(Boolean).join(' - ') || 'Customer chat';
  }
  return [row.shop_category, row.shop_block].filter(Boolean).join(' - ') || row.other_user_email || 'Shop chat';
}

function adminChatAvatar(row, accountRole) {
  if (row.scope === 'b2b') return row.other_user_avatar || row.shop_avatar_url;
  if (accountRole === 'seller') return row.other_user_avatar;
  return row.shop_avatar_url || row.other_user_avatar;
}

function friendlyRoomName(roomId, prefix) {
  if (!roomId) return null;
  const marker = `${prefix}:`;
  return roomId.startsWith(marker) ? roomId.slice(marker.length) : null;
}

function cleanMediaUrl(value) {
  return value?.startsWith('blob:') ? null : value;
}

function chatPreview(row) {
  if (row.deleted_at) return 'This message was deleted';
  const text = row.text?.trim();
  if (text) return text;
  switch (row.message_type) {
    case 'image':
      return 'Image';
    case 'video':
      return 'Video';
    case 'pdf':
      return row.media_name || 'Document';
    case 'voice':
      return 'Voice note';
    default:
      return 'Message';
  }
}
