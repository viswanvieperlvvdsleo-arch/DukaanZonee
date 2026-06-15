import express from 'express';
import { z } from 'zod';
import { query } from '../db/pool.js';
import { requireAuth } from '../middleware/auth.js';
import { isUserOnline } from '../realtime/socketHub.js';
import { HttpError } from '../utils/httpError.js';

export const chatsRouter = express.Router();

chatsRouter.use(requireAuth);

const liveAccountFilter = `
  AND au.email NOT LIKE '%@dukaanzone.local'
  AND au.email NOT LIKE '%@dz.local'
`;

const roomSchema = z.object({
  roomId: z.string().trim().min(1).max(240),
  limit: z.coerce.number().int().min(1).max(150).default(80),
});

const roomsSchema = z.object({
  scope: z.enum(['shop_payment', 'b2b']).default('shop_payment'),
  limit: z.coerce.number().int().min(1).max(80).default(40),
});

chatsRouter.get('/rooms', async (req, res, next) => {
  try {
    const input = roomsSchema.parse(req.query);
    const rows = await listRooms(req.user, input.scope, input.limit);
    res.json({
      rooms: rows.map((row) => ({
        roomId: row.room_id,
        scope: row.scope,
        lastMessage: chatPreview(row),
        updatedAt: row.created_at,
        shopId: row.shop_id,
        shopName: row.shop_name,
        shopCategory: row.shop_category,
        shopBlock: row.shop_block,
        shopAvatarUrl: row.shop_avatar_url?.startsWith('blob:')
          ? null
          : row.shop_avatar_url,
        shopSellerId: row.shop_seller_id,
        shopSellerOnline: isUserOnline(row.shop_seller_id),
        unreadCount: Number(row.unread_count ?? 0),
        customer: row.customer_id
          ? {
              id: row.customer_id,
              name: row.customer_name,
              phone: row.customer_phone,
              email: row.customer_email,
              avatarUrl: row.customer_avatar_url?.startsWith('blob:')
                ? null
                : row.customer_avatar_url,
              isOnline: isUserOnline(row.customer_id),
            }
          : null,
        sender: {
          id: row.sender_id,
          name: row.sender_name,
          role: row.sender_role,
        },
      })),
    });
  } catch (error) {
    next(error);
  }
});

chatsRouter.get('/rooms/:roomId/messages', async (req, res, next) => {
  try {
    const input = roomSchema.parse({
      roomId: req.params.roomId,
      limit: req.query.limit,
    });
    await assertRoomAccess(req.user, input.roomId);
    const parsedShopRoom = input.roomId.startsWith('shop:')
      ? parseShopRoomId(input.roomId)
      : { shopKey: null, userId: null };
    const legacyShopRoomId = parsedShopRoom.userId
      ? `shop:${parsedShopRoom.shopKey}`
      : null;

    const result = await query(
      `SELECT cm.id, cm.room_id, cm.scope, cm.text, cm.created_at,
        cm.shop_id, cm.target_user_id, cm.delivery_status,
        cm.delivered_at, cm.read_at, cm.message_type, cm.media_url,
        cm.media_name, cm.media_mime, cm.media_size_bytes,
        cm.media_duration_seconds, cm.reaction, cm.deleted_at,
        au.id AS sender_id, au.name AS sender_name, au.role AS sender_role
       FROM chat_messages cm
       INNER JOIN app_users au ON au.id = cm.sender_user_id
       WHERE (
          cm.room_id = $1
          OR (
            $3::TEXT IS NOT NULL
            AND $4::TEXT IS NOT NULL
            AND cm.scope = 'shop_payment'
            AND cm.room_id = $4
            AND (cm.sender_user_id = $3 OR cm.target_user_id = $3)
          )
        )
       ORDER BY cm.created_at DESC
       LIMIT $2`,
      [input.roomId, input.limit, parsedShopRoom.userId, legacyShopRoomId],
    );

    res.json({
      messages: result.rows.reverse().map((row) => ({
        id: row.id,
        roomId: row.room_id,
        scope: row.scope,
        text: row.text,
        shopId: row.shop_id,
        targetUserId: row.target_user_id,
        deliveryStatus: row.delivery_status,
        deliveredAt: row.delivered_at,
        readAt: row.read_at,
        type: row.deleted_at ? 'deleted' : row.message_type,
        mediaUrl: row.media_url,
        mediaName: row.media_name,
        mediaMime: row.media_mime,
        mediaSizeBytes: row.media_size_bytes,
        mediaDurationSeconds: row.media_duration_seconds,
        reaction: row.reaction,
        deletedAt: row.deleted_at,
        createdAt: row.created_at,
        sender: {
          id: row.sender_id,
          name: row.sender_name,
          role: row.sender_role,
        },
      })),
    });
  } catch (error) {
    next(error);
  }
});

chatsRouter.get('/media-storage', async (req, res, next) => {
  try {
    const result = await query(
      `SELECT cm.id, cm.room_id, cm.scope, cm.message_type, cm.media_url,
        cm.media_name, cm.media_mime, cm.media_size_bytes,
        cm.media_duration_seconds, cm.created_at,
        sender.id AS sender_id, sender.name AS sender_name,
        sender.role AS sender_role,
        shop.id AS shop_id, shop.name AS shop_name, shop.category AS shop_category,
        shop.block AS shop_block, shop.avatar_url AS shop_avatar_url,
        customer.id AS customer_id, customer.name AS customer_name,
        customer.profile_pic AS customer_avatar_url
       FROM chat_messages cm
       INNER JOIN app_users sender ON sender.id = cm.sender_user_id
       LEFT JOIN shops shop ON shop.id = cm.shop_id
         OR cm.room_id = 'shop:' || shop.id
         OR cm.room_id LIKE 'shop:' || shop.id || ':user:%'
         OR LOWER(cm.room_id) = LOWER('shop:' || shop.name)
       LEFT JOIN LATERAL (
         SELECT au.id, au.name, au.profile_pic
         FROM app_users au
         WHERE au.deleted_at IS NULL
           AND au.id <> $1
           AND (au.id = cm.sender_user_id OR au.id = cm.target_user_id)
         ORDER BY au.created_at ASC
         LIMIT 1
       ) customer ON TRUE
       WHERE cm.deleted_at IS NULL
         AND cm.media_url IS NOT NULL
         AND cm.message_type IN ('image', 'video', 'pdf', 'voice')
         AND NOT EXISTS (
           SELECT 1
           FROM media_storage_deletions msd
           WHERE msd.user_id = $1 AND msd.message_id = cm.id
         )
         AND (
           cm.sender_user_id = $1
           OR cm.target_user_id = $1
           OR shop.seller_id = $1
           OR (cm.scope = 'b2b' AND $2 = 'seller'
             AND (
               cm.sender_user_id = $1
               OR cm.target_user_id = $1
               OR split_part(cm.room_id, ':', 2) = $1
               OR split_part(cm.room_id, ':', 3) = $1
             )
           )
         )
       ORDER BY cm.created_at DESC
       LIMIT 240`,
      [req.user.sub, req.user.role],
    );

    res.json({
      media: result.rows.map((row) => mapMediaStorageItem(row, req.user)),
    });
  } catch (error) {
    next(error);
  }
});

chatsRouter.delete('/media-storage/:messageId', async (req, res, next) => {
  try {
    const messageId = req.params.messageId;
    await query(
      `INSERT INTO media_storage_deletions (user_id, message_id)
       SELECT $1, cm.id
       FROM chat_messages cm
       LEFT JOIN shops shop ON shop.id = cm.shop_id
         OR cm.room_id = 'shop:' || shop.id
         OR cm.room_id LIKE 'shop:' || shop.id || ':user:%'
         OR LOWER(cm.room_id) = LOWER('shop:' || shop.name)
       WHERE cm.id = $2
         AND cm.media_url IS NOT NULL
         AND (
           cm.sender_user_id = $1
           OR cm.target_user_id = $1
           OR shop.seller_id = $1
           OR (cm.scope = 'b2b' AND $3 = 'seller'
             AND (
               cm.sender_user_id = $1
               OR cm.target_user_id = $1
               OR split_part(cm.room_id, ':', 2) = $1
               OR split_part(cm.room_id, ':', 3) = $1
             )
           )
         )
       ON CONFLICT (user_id, message_id)
       DO UPDATE SET deleted_at = NOW()`,
      [req.user.sub, messageId, req.user.role],
    );
    res.status(204).send();
  } catch (error) {
    next(error);
  }
});

chatsRouter.delete('/rooms/:roomId', async (req, res, next) => {
  try {
    const roomId = req.params.roomId;
    await assertRoomAccess(req.user, roomId);
    await query(
      `INSERT INTO chat_room_hides (user_id, room_id, hidden_at)
       VALUES ($1, $2, NOW())
       ON CONFLICT (user_id, room_id)
       DO UPDATE SET hidden_at = NOW()`,
      [req.user.sub, roomId],
    );
    res.status(204).send();
  } catch (error) {
    next(error);
  }
});

async function assertRoomAccess(user, roomId) {
  if (roomId.startsWith('b2b:')) {
    if (user.role !== 'seller') {
      throw new HttpError(403, 'Only sellers can access B2B chat');
    }
    const sellerIds = parseB2BRoomSellerIds(roomId);
    if (sellerIds.length === 2 && !sellerIds.includes(user.sub)) {
      throw new HttpError(403, 'Seller cannot access another B2B chat');
    }
    return;
  }

  if (!roomId.startsWith('shop:')) return;

  const { shopKey, userId } = parseShopRoomId(roomId);
  if (user.role === 'user' && userId && userId !== user.sub) {
    throw new HttpError(403, 'User cannot access another buyer chat');
  }
  const result = await query(
    `SELECT seller_id FROM shops WHERE id = $1 OR LOWER(name) = LOWER($1)`,
    [shopKey],
  );
  const shop = result.rows[0];
  if (!shop) {
    throw new HttpError(404, 'Chat shop not found');
  }
  if (user.role === 'seller' && shop.seller_id !== user.sub) {
    throw new HttpError(403, 'Seller cannot access another shop chat');
  }
}

function mapMediaStorageItem(row, user) {
  const chatName = mediaChatName(row, user);
  const fileName = row.media_name || mediaDefaultName(row);
  return {
    messageId: row.id,
    roomId: row.room_id,
    scope: row.scope,
    type: row.message_type,
    url: row.media_url,
    name: fileName,
    mime: row.media_mime,
    sizeBytes: row.media_size_bytes ?? 0,
    durationSeconds: row.media_duration_seconds,
    createdAt: row.created_at,
    chatName,
    shop: row.shop_id
      ? {
          id: row.shop_id,
          name: row.shop_name,
          category: row.shop_category,
          block: row.shop_block,
          avatarUrl: row.shop_avatar_url?.startsWith('blob:')
            ? null
            : row.shop_avatar_url,
        }
      : null,
    participant: row.customer_id
      ? {
          id: row.customer_id,
          name: row.customer_name,
          avatarUrl: row.customer_avatar_url?.startsWith('blob:')
            ? null
            : row.customer_avatar_url,
        }
      : {
          id: row.sender_id,
          name: row.sender_name,
          role: row.sender_role,
        },
  };
}

function mediaChatName(row, user) {
  if (row.scope === 'b2b') {
    return row.customer_name || friendlyRoomName(row.room_id, 'b2b') || row.room_id;
  }
  if (user.role === 'seller') {
    return row.customer_name || row.sender_name || 'Customer';
  }
  return row.shop_name || 'Shop';
}

function mediaDefaultName(row) {
  const extension = row.message_type === 'pdf'
    ? 'pdf'
    : row.message_type === 'voice'
      ? 'm4a'
      : row.message_type === 'video'
        ? 'mp4'
        : 'jpg';
  return `${row.message_type}-${row.id}.${extension}`;
}

function friendlyRoomName(roomId, prefix) {
  if (!roomId) return null;
  const marker = `${prefix}:`;
  return roomId.startsWith(marker) ? roomId.slice(marker.length) : null;
}

function parseShopRoomId(roomId) {
  const value = roomId.startsWith('shop:')
    ? roomId.slice('shop:'.length)
    : roomId;
  const userMarkerIndex = value.indexOf(':user:');
  if (userMarkerIndex === -1) {
    return { shopKey: value, userId: null };
  }
  return {
    shopKey: value.slice(0, userMarkerIndex),
    userId: value.slice(userMarkerIndex + ':user:'.length) || null,
  };
}

function parseB2BRoomSellerIds(roomId) {
  const parts = roomId.split(':');
  if (parts.length !== 3 || parts[0] !== 'b2b') return [];
  return [parts[1], parts[2]].filter(Boolean);
}

async function listRooms(user, scope, limit) {
  if (scope === 'b2b') {
    if (user.role !== 'seller') {
      throw new HttpError(403, 'Only sellers can access B2B chat');
    }
    const result = await query(
      `WITH latest AS (
        SELECT DISTINCT ON (cm.room_id)
          cm.id, cm.room_id, cm.scope, cm.text, cm.created_at, cm.shop_id,
          cm.delivery_status, cm.delivered_at, cm.read_at, cm.message_type,
          cm.media_name, cm.deleted_at,
          au.id AS sender_id, au.name AS sender_name, au.role AS sender_role,
          NULL AS shop_seller_id, NULL AS shop_category,
          NULL AS shop_block, NULL AS shop_avatar_url
        FROM chat_messages cm
        INNER JOIN app_users au ON au.id = cm.sender_user_id
        WHERE cm.scope = 'b2b'
          ${liveAccountFilter}
          AND (cm.sender_user_id = $2 OR cm.target_user_id = $2)
        ORDER BY cm.room_id, cm.created_at DESC
      )
      SELECT latest.*, NULL AS shop_name,
        partner.id AS customer_id,
        partner.name AS customer_name,
        partner.phone AS customer_phone,
        partner.email AS customer_email,
        partner.profile_pic AS customer_avatar_url,
        FALSE AS customer_online,
        (
          SELECT COUNT(*)::INT
          FROM chat_messages unread
          WHERE unread.room_id = latest.room_id
            AND unread.sender_user_id <> $2
            AND unread.deleted_at IS NULL
            AND unread.read_at IS NULL
            AND unread.target_user_id = $2
        ) AS unread_count
      FROM latest
      LEFT JOIN LATERAL (
        SELECT au2.id, au2.name, au2.phone, au2.email, au2.profile_pic
        FROM app_users au2
        WHERE (
            au2.id = CASE
              WHEN split_part(latest.room_id, ':', 1) = 'b2b'
                AND split_part(latest.room_id, ':', 2) = $2
                THEN NULLIF(split_part(latest.room_id, ':', 3), '')
              WHEN split_part(latest.room_id, ':', 1) = 'b2b'
                AND split_part(latest.room_id, ':', 3) = $2
                THEN NULLIF(split_part(latest.room_id, ':', 2), '')
              ELSE NULL
            END
            OR EXISTS (
              SELECT 1
              FROM chat_messages cm2
              WHERE cm2.room_id = latest.room_id
                AND au2.id = CASE
                  WHEN cm2.sender_user_id = $2 THEN cm2.target_user_id
                  ELSE cm2.sender_user_id
                END
            )
          )
          AND au2.id IS NOT NULL
          AND au2.id <> $2
          AND au2.deleted_at IS NULL
        ORDER BY au2.updated_at DESC NULLS LAST, au2.created_at DESC
        LIMIT 1
      ) partner ON TRUE
      WHERE NOT EXISTS (
        SELECT 1
        FROM chat_room_hides hide
        WHERE hide.user_id = $2
          AND hide.room_id = latest.room_id
          AND latest.created_at <= hide.hidden_at
      )
      ORDER BY latest.created_at DESC
      LIMIT $1`,
      [limit, user.sub],
    );
    return result.rows;
  }

  const result = await query(
    `WITH latest AS (
      SELECT DISTINCT ON (cm.room_id)
        cm.id, cm.room_id, cm.scope, cm.text, cm.created_at, cm.shop_id,
        cm.delivery_status, cm.delivered_at, cm.read_at, cm.message_type,
        cm.media_name, cm.deleted_at,
        au.id AS sender_id, au.name AS sender_name, au.role AS sender_role,
        s.seller_id AS shop_seller_id,
        s.name AS shop_name,
        s.category AS shop_category,
        s.block AS shop_block,
        s.avatar_url AS shop_avatar_url
      FROM chat_messages cm
      INNER JOIN app_users au ON au.id = cm.sender_user_id
      LEFT JOIN shops s ON s.id = cm.shop_id
        OR cm.room_id = 'shop:' || s.id
        OR cm.room_id LIKE 'shop:' || s.id || ':user:%'
        OR LOWER(cm.room_id) = LOWER('shop:' || s.name)
      WHERE cm.scope = 'shop_payment'
        ${liveAccountFilter}
        AND (
          cm.sender_user_id = $1
          OR cm.target_user_id = $1
          OR s.seller_id = $1
        )
        AND s.id IS NOT NULL
      ORDER BY cm.room_id, cm.created_at DESC
    )
    SELECT latest.*,
      customer.id AS customer_id,
      customer.name AS customer_name,
      customer.phone AS customer_phone,
      customer.email AS customer_email,
      customer.profile_pic AS customer_avatar_url,
      (
        SELECT COUNT(*)::INT
        FROM chat_messages unread
        LEFT JOIN shops unread_shop ON unread_shop.id = unread.shop_id
          OR unread.room_id = 'shop:' || unread_shop.id
          OR unread.room_id LIKE 'shop:' || unread_shop.id || ':user:%'
          OR LOWER(unread.room_id) = LOWER('shop:' || unread_shop.name)
        WHERE unread.room_id = latest.room_id
          AND unread.sender_user_id <> $1
          AND unread.deleted_at IS NULL
          AND unread.read_at IS NULL
          AND (
            unread.target_user_id = $1
            OR unread_shop.seller_id = $1
          )
      ) AS unread_count
    FROM latest
    LEFT JOIN LATERAL (
      SELECT au2.id, au2.name, au2.phone, au2.email, au2.profile_pic
      FROM app_users au2
      WHERE (
          au2.id = NULLIF(split_part(latest.room_id, ':user:', 2), '')
          OR (
            NULLIF(split_part(latest.room_id, ':user:', 2), '') IS NULL
            AND EXISTS (
              SELECT 1
              FROM chat_messages cm2
              WHERE cm2.room_id = latest.room_id
                AND (cm2.sender_user_id = au2.id OR cm2.target_user_id = au2.id)
            )
          )
        )
        AND au2.role = 'user'
        AND au2.deleted_at IS NULL
      ORDER BY CASE
        WHEN au2.id = NULLIF(split_part(latest.room_id, ':user:', 2), '') THEN 0
        ELSE 1
      END, au2.created_at ASC
      LIMIT 1
    ) customer ON TRUE
    WHERE NOT EXISTS (
      SELECT 1
      FROM chat_room_hides hide
      WHERE hide.user_id = $1
        AND hide.room_id = latest.room_id
        AND latest.created_at <= hide.hidden_at
    )
    ORDER BY latest.created_at DESC
    LIMIT $2`,
    [user.sub, limit],
  );
  return result.rows;
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
