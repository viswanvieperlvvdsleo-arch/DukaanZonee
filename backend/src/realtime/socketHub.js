import jwt from 'jsonwebtoken';
import { WebSocket, WebSocketServer } from 'ws';
import { config } from '../config.js';
import { query } from '../db/pool.js';
import { makeId } from '../utils/ids.js';

const clientsByUser = new Map();
const clientsByRole = new Map();

export function attachRealtime(server) {
  const wss = new WebSocketServer({ server, path: '/ws' });

  wss.on('connection', (socket, request) => {
    const user = authenticateRequest(request);
    if (!user) {
      socket.close(1008, 'Unauthorized');
      return;
    }

    socket.user = user;
    addClient(user.sub, socket);
    addRoleClient(user.role, socket);
    send(socket, 'socket.connected', {
      userId: user.sub,
      role: user.role,
    });
    send(socket, 'presence.snapshot', {
      onlineUserIds: [...clientsByUser.keys()],
    });
    publishPresence(user.sub, true);
    notifyPendingChatDelivered(user).catch(() => {});

    socket.on('message', (raw) => {
      handleClientMessage(socket, raw).catch((error) => {
        send(socket, 'socket.error', {
          message: error?.message ?? 'Realtime message failed',
        });
      });
    });

    socket.on('close', () => {
      removeClient(user.sub, socket);
      removeRoleClient(user.role, socket);
      if (countOnlineUsers([user.sub]) === 0) {
        publishPresence(user.sub, false);
      }
    });
  });

  return wss;
}

export function publishToUser(userId, type, payload = {}) {
  const clients = clientsByUser.get(userId);
  if (!clients) return 0;

  let delivered = 0;
  for (const socket of clients) {
    if (socket.readyState === WebSocket.OPEN) {
      send(socket, type, payload);
      delivered += 1;
    }
  }
  return delivered;
}

export function publishToUsers(userIds, type, payload = {}) {
  return [...new Set(userIds)].reduce(
    (count, userId) => count + publishToUser(userId, type, payload),
    0,
  );
}

export function publishToRole(role, type, payload = {}) {
  const clients = clientsByRole.get(role);
  if (!clients) return 0;

  let delivered = 0;
  for (const socket of clients) {
    if (socket.readyState === WebSocket.OPEN) {
      send(socket, type, payload);
      delivered += 1;
    }
  }
  return delivered;
}

export function isUserOnline(userId) {
  if (!userId) return false;
  return countOnlineUsers([userId]) > 0;
}

async function handleClientMessage(socket, raw) {
  const message = JSON.parse(raw.toString());
  if (message.type === 'ping') {
    send(socket, 'pong', { at: new Date().toISOString() });
    return;
  }

  if (message.type === 'chat.message') {
    await handleChatMessage(socket, message.payload ?? {});
    return;
  }

  if (message.type === 'chat.delete') {
    await handleChatDelete(socket, message.payload ?? {});
    return;
  }

  if (message.type === 'chat.react') {
    await handleChatReaction(socket, message.payload ?? {});
    return;
  }

  if (message.type === 'chat.typing') {
    await handleChatTyping(socket, message.payload ?? {});
    return;
  }

  if (message.type === 'chat.read') {
    await handleChatRead(socket, message.payload ?? {});
    return;
  }

  if (message.type === 'call.start') {
    await handleCallStart(socket, message.payload ?? {});
    return;
  }

  if (message.type === 'call.end') {
    await handleCallEnd(socket, message.payload ?? {});
  }
}

async function handleChatMessage(socket, payload) {
  const text = `${payload.text ?? ''}`.trim();
  const messageType = normalizeMessageType(payload.type);
  const mediaUrl = payload.mediaUrl?.toString() || payload.mediaPath?.toString() || null;
  if (!text && !mediaUrl && messageType === 'text') return;

  const event = {
    id: payload.id?.toString() || makeId('live_msg'),
    roomId: payload.roomId?.toString() || 'general',
    scope: payload.scope?.toString() || 'chat',
    text: text.slice(0, 4000),
    type: messageType,
    mediaUrl: mediaUrl?.slice(0, 8_000_000) ?? null,
    mediaName: payload.mediaName?.toString()?.slice(0, 240) ?? null,
    mediaMime: payload.mediaMime?.toString()?.slice(0, 120) ?? null,
    reaction: payload.reaction?.toString()?.slice(0, 32) ?? null,
    mediaSizeBytes: normalizeInteger(payload.mediaSizeBytes ?? payload.sizeBytes),
    mediaDurationSeconds: normalizeInteger(
      payload.mediaDurationSeconds ?? payload.duration,
    ),
    sender: {
      id: socket.user.sub,
      name: socket.user.name,
      role: socket.user.role,
    },
    shopId: payload.shopId?.toString() || null,
    createdAt: new Date().toISOString(),
  };

  const access = await assertRealtimeRoomAccess(socket.user, event.roomId, {
    scope: event.scope,
    shopId: event.shopId,
    targetUserId: payload.targetUserId?.toString() || null,
  });
  const targetUserIds = new Set([socket.user.sub]);
  let shopSellerId = null;
  if (payload.targetUserId) {
    targetUserIds.add(payload.targetUserId.toString());
  }
  for (const participantId of access.participantIds) {
    targetUserIds.add(participantId);
  }

  if (event.scope === 'b2b') {
    for (const sellerId of b2BParticipantIdsFromRoom(event.roomId)) {
      targetUserIds.add(sellerId);
    }
  }

  if (access.shop) {
    event.shopId = access.shop.id;
    shopSellerId = access.shop.seller_id;
    targetUserIds.add(shopSellerId);
  }

  const recipientIds = [...targetUserIds].filter((id) => id !== socket.user.sub);
  const onlineRecipients = event.scope === 'b2b'
    ? countOnlineUsers(recipientIds)
    : countOnlineUsers(recipientIds);
  const deliveryStatus = onlineRecipients > 0 ? 'sent_online' : 'sent_offline';
  const targetUserId = payload.targetUserId?.toString()
    ?? (event.scope === 'b2b' ? recipientIds[0] : shopSellerId);

  await query(
    `INSERT INTO chat_messages (
      id, room_id, scope, sender_user_id, target_user_id, shop_id, text,
      message_type, media_url, media_name, media_mime, media_size_bytes,
      media_duration_seconds, reaction, delivery_status, delivered_at
    )
    VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14, $15,
      CASE WHEN $15 = 'sent_online' THEN NOW() ELSE NULL END)
    ON CONFLICT (id) DO NOTHING`,
    [
      event.id,
      event.roomId,
      event.scope,
      socket.user.sub,
      targetUserId,
      event.shopId,
      event.text,
      event.type,
      event.mediaUrl,
      event.mediaName,
      event.mediaMime,
      event.mediaSizeBytes,
      event.mediaDurationSeconds,
      event.reaction,
      deliveryStatus,
    ],
  );

  if (event.scope === 'b2b') {
    publishToUsers([...targetUserIds], 'chat.message', event);
    send(socket, 'chat.receipt', {
      id: event.id,
      roomId: event.roomId,
      status: deliveryStatus,
    });
    return;
  }

  publishToUsers([...targetUserIds], 'chat.message', event);
  send(socket, 'chat.receipt', {
    id: event.id,
    roomId: event.roomId,
    status: deliveryStatus,
  });
}

async function handleChatDelete(socket, payload) {
  const messageId = payload.id?.toString();
  const roomId = payload.roomId?.toString();
  if (!messageId || !roomId) return;

  const update = await query(
    `UPDATE chat_messages
     SET deleted_original_text = COALESCE(deleted_original_text, text),
         deleted_original_type = COALESCE(deleted_original_type, message_type),
         deleted_original_media_url = COALESCE(deleted_original_media_url, media_url),
         deleted_original_media_name = COALESCE(deleted_original_media_name, media_name),
         deleted_original_media_mime = COALESCE(deleted_original_media_mime, media_mime),
         text = 'This message was deleted',
         message_type = 'deleted',
         media_url = NULL,
         media_name = NULL,
         media_mime = NULL,
         media_size_bytes = NULL,
         media_duration_seconds = NULL,
         deleted_at = COALESCE(deleted_at, NOW()),
         deleted_by_user_id = $1
     WHERE id = $2 AND room_id = $3 AND sender_user_id = $1
     RETURNING id, room_id`,
    [socket.user.sub, messageId, roomId],
  );
  if (update.rows.length === 0) return;

  const userIds = await getRoomParticipantIds(roomId);
  publishToUsers([...userIds, socket.user.sub], 'chat.deleted', {
    id: messageId,
    roomId,
    text: 'This message was deleted',
    type: 'deleted',
    deletedBy: {
      id: socket.user.sub,
      name: socket.user.name,
      role: socket.user.role,
    },
    at: new Date().toISOString(),
  });
}

async function handleChatReaction(socket, payload) {
  const messageId = payload.id?.toString();
  const roomId = payload.roomId?.toString();
  const reaction = payload.reaction?.toString()?.slice(0, 32) || null;
  if (!messageId || !roomId) return;

  const update = await query(
    `UPDATE chat_messages cm
     SET reaction = $3
     WHERE cm.id = $1
       AND cm.room_id = $2
       AND cm.deleted_at IS NULL
       AND (
         cm.sender_user_id = $4
         OR cm.target_user_id = $4
         OR cm.shop_id IN (SELECT id FROM shops WHERE seller_id = $4)
         OR (cm.scope = 'b2b' AND $5 = 'seller'
           AND (
             cm.sender_user_id = $4
             OR cm.target_user_id = $4
             OR split_part(cm.room_id, ':', 2) = $4
             OR split_part(cm.room_id, ':', 3) = $4
           )
         )
       )
     RETURNING cm.id, cm.room_id, cm.scope, cm.reaction`,
    [messageId, roomId, reaction, socket.user.sub, socket.user.role],
  );
  const row = update.rows[0];
  if (!row) return;

  const event = {
    id: row.id,
    roomId: row.room_id,
    scope: row.scope,
    reaction: row.reaction,
    actor: {
      id: socket.user.sub,
      name: socket.user.name,
      role: socket.user.role,
    },
    at: new Date().toISOString(),
  };

  const userIds = await getRoomParticipantIds(row.room_id);
  publishToUsers([...userIds, socket.user.sub], 'chat.reacted', event);
}

async function handleChatTyping(socket, payload) {
  const roomId = payload.roomId?.toString();
  if (!roomId) return;

  const scope = payload.scope?.toString() || 'chat';
  const access = await assertRealtimeRoomAccess(socket.user, roomId, {
    scope,
    shopId: payload.shopId?.toString() || null,
    targetUserId: payload.targetUserId?.toString() || null,
  });
  const targetUserIds = new Set([socket.user.sub]);
  if (payload.targetUserId) {
    targetUserIds.add(payload.targetUserId.toString());
  }
  for (const participantId of access.participantIds) {
    targetUserIds.add(participantId);
  }

  if (scope === 'b2b') {
    for (const sellerId of b2BParticipantIdsFromRoom(roomId)) {
      targetUserIds.add(sellerId);
    }
  }

  if (access.shop?.seller_id) {
    targetUserIds.add(access.shop.seller_id);
  }

  targetUserIds.delete(socket.user.sub);
  if (targetUserIds.size === 0) return;

  publishToUsers([...targetUserIds], 'chat.typing', {
    roomId,
    scope,
    isTyping: payload.isTyping !== false,
    sender: {
      id: socket.user.sub,
      name: socket.user.name,
      role: socket.user.role,
    },
    at: new Date().toISOString(),
  });
}

async function handleChatRead(socket, payload) {
  const roomId = payload.roomId?.toString();
  if (!roomId) return;
  await assertRealtimeRoomAccess(socket.user, roomId, {
    scope: payload.scope?.toString() || 'chat',
    shopId: payload.shopId?.toString() || null,
    targetUserId: payload.targetUserId?.toString() || null,
  });

  await query(
    `UPDATE chat_messages cm
     SET delivery_status = 'seen',
         delivered_at = COALESCE(delivered_at, NOW()),
         read_at = COALESCE(read_at, NOW())
     WHERE cm.room_id = $1
       AND cm.sender_user_id <> $2
       AND (
         cm.target_user_id = $2
         OR cm.shop_id IN (SELECT id FROM shops WHERE seller_id = $2)
         OR (cm.scope = 'b2b' AND $3 = 'seller'
           AND (
             cm.target_user_id = $2
             OR split_part(cm.room_id, ':', 2) = $2
             OR split_part(cm.room_id, ':', 3) = $2
           )
         )
       )`,
    [roomId, socket.user.sub, socket.user.role],
  );

  const userIds = await getRoomParticipantIds(roomId);
  userIds.delete(socket.user.sub);
  if (userIds.size === 0) return;

  publishToUsers([...userIds], 'chat.receipt', {
    roomId,
    status: 'seen',
    seenBy: {
      id: socket.user.sub,
      name: socket.user.name,
      role: socket.user.role,
    },
    at: new Date().toISOString(),
  });
}

async function handleCallStart(socket, payload) {
  const roomId = payload.roomId?.toString() || 'general';
  const scope = payload.scope?.toString() || 'shop_payment';
  const kind = normalizeCallKind(payload.kind);
  const callId = payload.id?.toString() || makeId('call');
  const startedAt = new Date().toISOString();
  const targetUserIds = new Set([socket.user.sub]);
  let shopId = payload.shopId?.toString() || null;
  let targetUserId = payload.targetUserId?.toString() || null;

  if (targetUserId) {
    targetUserIds.add(targetUserId);
  }

  const access = await assertRealtimeRoomAccess(socket.user, roomId, {
    scope,
    shopId,
    targetUserId,
  });
  for (const participantId of access.participantIds) {
    targetUserIds.add(participantId);
  }
  if (access.shop?.seller_id) {
    shopId = access.shop.id;
    targetUserId ??= access.shop.seller_id;
    targetUserIds.add(access.shop.seller_id);
  }

  await query(
    `INSERT INTO call_records (
      id, room_id, scope, caller_user_id, target_user_id, shop_id,
      call_kind, status, started_at
    )
    VALUES ($1, $2, $3, $4, $5, $6, $7, 'ringing', NOW())
    ON CONFLICT (id) DO NOTHING`,
    [callId, roomId, scope, socket.user.sub, targetUserId, shopId, kind],
  );

  const event = {
    id: callId,
    roomId,
    scope,
    kind,
    status: 'ringing',
    shopId,
    targetUserId,
    startedAt,
    caller: {
      id: socket.user.sub,
      name: socket.user.name,
      role: socket.user.role,
    },
  };

  if (scope === 'b2b') {
    publishToUsers([...targetUserIds, ...b2BParticipantIdsFromRoom(roomId)], 'call.started', event);
  } else {
    publishToUsers([...targetUserIds], 'call.started', event);
  }
  send(socket, 'call.receipt', event);
}

async function handleCallEnd(socket, payload) {
  const callId = payload.id?.toString();
  if (!callId) return;

  const requestedStatus = normalizeCallStatus(payload.status);
  const update = await query(
    `UPDATE call_records
     SET status = $2,
         answered_at = CASE WHEN $2 = 'accepted' THEN COALESCE(answered_at, NOW()) ELSE answered_at END,
         ended_at = CASE WHEN $2 <> 'accepted' THEN COALESCE(ended_at, NOW()) ELSE ended_at END,
         duration_seconds = CASE
           WHEN $2 IN ('ended', 'declined', 'missed')
           THEN GREATEST(0, EXTRACT(EPOCH FROM (NOW() - started_at))::INTEGER)
           ELSE duration_seconds
         END
     WHERE id = $1
       AND (
         caller_user_id = $3
         OR target_user_id = $3
         OR shop_id IN (SELECT id FROM shops WHERE seller_id = $3)
         OR (scope = 'b2b' AND $4 = 'seller'
           AND (
             split_part(room_id, ':', 2) = $3
             OR split_part(room_id, ':', 3) = $3
           )
         )
       )
     RETURNING id, room_id, scope, caller_user_id, target_user_id, shop_id,
       call_kind, status, started_at, answered_at, ended_at, duration_seconds`,
    [callId, requestedStatus, socket.user.sub, socket.user.role],
  );
  const call = update.rows[0];
  if (!call) return;

  const userIds = await getCallParticipantIds(call);
  const event = {
    id: call.id,
    roomId: call.room_id,
    scope: call.scope,
    kind: call.call_kind,
    status: call.status,
    shopId: call.shop_id,
    startedAt: call.started_at,
    answeredAt: call.answered_at,
    endedAt: call.ended_at,
    durationSeconds: call.duration_seconds,
    actor: {
      id: socket.user.sub,
      name: socket.user.name,
      role: socket.user.role,
    },
  };

  if (call.scope === 'b2b') {
    publishToUsers([...userIds], 'call.updated', event);
  } else {
    publishToUsers([...userIds], 'call.updated', event);
  }
}

async function getCallParticipantIds(call) {
  const userIds = new Set();
  if (call.caller_user_id) userIds.add(call.caller_user_id);
  if (call.target_user_id) userIds.add(call.target_user_id);
  if (call.shop_id) {
    const result = await query('SELECT seller_id FROM shops WHERE id = $1', [
      call.shop_id,
    ]);
    if (result.rows[0]?.seller_id) userIds.add(result.rows[0].seller_id);
  }
  return userIds;
}

async function getRoomParticipantIds(roomId) {
  const result = await query(
    `SELECT cm.sender_user_id, cm.target_user_id, s.seller_id
     FROM chat_messages cm
     LEFT JOIN shops s ON s.id = cm.shop_id
       OR cm.room_id = 'shop:' || s.id
       OR cm.room_id LIKE 'shop:' || s.id || ':user:%'
       OR LOWER(cm.room_id) = LOWER('shop:' || s.name)
     WHERE cm.room_id = $1`,
    [roomId],
  );

  const userIds = new Set();
  for (const row of result.rows) {
    if (row.sender_user_id) userIds.add(row.sender_user_id);
    if (row.target_user_id) userIds.add(row.target_user_id);
    if (row.seller_id) userIds.add(row.seller_id);
  }
  return userIds;
}

async function notifyPendingChatDelivered(user) {
  const result = await query(
    `WITH pending AS (
       SELECT cm.id
       FROM chat_messages cm
       LEFT JOIN shops s ON s.id = cm.shop_id
         OR cm.room_id = 'shop:' || s.id
         OR LOWER(cm.room_id) = LOWER('shop:' || s.name)
       WHERE cm.sender_user_id <> $1
         AND cm.delivery_status = 'sent_offline'
         AND cm.created_at >= NOW() - INTERVAL '30 days'
         AND (
           cm.target_user_id = $1
           OR s.seller_id = $1
           OR (cm.scope = 'b2b' AND $2 = 'seller'
             AND (
               cm.target_user_id = $1
               OR split_part(cm.room_id, ':', 2) = $1
               OR split_part(cm.room_id, ':', 3) = $1
             )
           )
         )
       LIMIT 100
     )
     UPDATE chat_messages cm
     SET delivery_status = 'sent_online',
         delivered_at = COALESCE(delivered_at, NOW())
     FROM pending
     WHERE cm.id = pending.id
     RETURNING cm.room_id, cm.sender_user_id`,
    [user.sub, user.role],
  );

  const at = new Date().toISOString();
  for (const row of result.rows) {
    if (!row.sender_user_id) continue;
    publishToUser(row.sender_user_id, 'chat.receipt', {
      roomId: row.room_id,
      status: 'sent_online',
      onlineBy: {
        id: user.sub,
        name: user.name,
        role: user.role,
      },
      at,
    });
  }
}

async function assertRealtimeRoomAccess(
  user,
  roomId,
  { scope = 'chat', shopId = null, targetUserId = null } = {},
) {
  const normalizedScope = scope?.toString() || 'chat';
  if (normalizedScope === 'b2b' || roomId?.startsWith('b2b:')) {
    if (user.role !== 'seller') {
      throw new Error('Only sellers can access B2B chat');
    }
    const sellerIds = b2BParticipantIdsFromRoom(roomId);
    if (sellerIds.length !== 2) {
      throw new Error('Invalid B2B chat room');
    }
    if (!sellerIds.includes(user.sub)) {
      throw new Error('Seller cannot access another B2B chat');
    }
    if (targetUserId && !sellerIds.includes(targetUserId)) {
      throw new Error('B2B recipient is not part of this room');
    }
    return { shop: null, participantIds: sellerIds };
  }

  if (!roomId?.startsWith('shop:')) {
    throw new Error('Unsupported realtime room');
  }

  const { shopKey, userId } = parseShopRoomId(roomId);
  if (!shopKey && !shopId) {
    throw new Error('Invalid shop chat room');
  }

  const result = await query(
    `SELECT id, seller_id
     FROM shops
     WHERE id = $1 OR id = $2 OR LOWER(name) = LOWER($3)
     LIMIT 1`,
    [shopId, shopKey, shopKey],
  );
  const shop = result.rows[0];
  if (!shop) {
    throw new Error('Chat shop not found');
  }

  if (user.role === 'user') {
    if (!userId) {
      throw new Error('Buyer chat room must include the buyer id');
    }
    if (userId !== user.sub) {
      throw new Error('User cannot access another buyer chat');
    }
    if (targetUserId && targetUserId !== shop.seller_id) {
      throw new Error('Buyer chat recipient must be the shop seller');
    }
    return { shop, participantIds: [user.sub, shop.seller_id] };
  }

  if (user.role === 'seller') {
    if (shop.seller_id !== user.sub) {
      throw new Error('Seller cannot access another shop chat');
    }
    if (targetUserId && userId && targetUserId !== userId) {
      throw new Error('Seller chat recipient must match the buyer room');
    }
    return {
      shop,
      participantIds: [user.sub, userId, targetUserId].filter(Boolean),
    };
  }

  throw new Error('Realtime room access denied');
}

function shopKeyFromRoomId(roomId) {
  if (!roomId?.startsWith('shop:')) return null;
  const value = roomId.slice('shop:'.length);
  const userMarkerIndex = value.indexOf(':user:');
  return userMarkerIndex === -1 ? value : value.slice(0, userMarkerIndex);
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

function b2BParticipantIdsFromRoom(roomId) {
  if (!roomId?.startsWith('b2b:')) return [];
  const parts = roomId.split(':');
  if (parts.length !== 3) return [];
  return parts.slice(1).filter(Boolean);
}

function countOnlineUsers(userIds) {
  let total = 0;
  for (const userId of new Set(userIds)) {
    const clients = clientsByUser.get(userId);
    if (!clients) continue;
    for (const socket of clients) {
      if (socket.readyState === WebSocket.OPEN) total += 1;
    }
  }
  return total;
}

function countRoleRecipients(role, senderUserId) {
  const clients = clientsByRole.get(role);
  if (!clients) return 0;
  let total = 0;
  for (const socket of clients) {
    if (socket.user?.sub !== senderUserId && socket.readyState === WebSocket.OPEN) {
      total += 1;
    }
  }
  return total;
}

function publishPresence(userId, isOnline) {
  const event = {
    userId,
    isOnline,
    at: new Date().toISOString(),
  };
  for (const clients of clientsByRole.values()) {
    for (const socket of clients) {
      if (socket.readyState === WebSocket.OPEN) {
        send(socket, 'presence.update', event);
      }
    }
  }
}

function normalizeMessageType(value) {
  const type = value?.toString() ?? 'text';
  return ['text', 'image', 'video', 'pdf', 'voice', 'deleted'].includes(type)
    ? type
    : 'text';
}

function normalizeInteger(value) {
  const parsed = Number(value);
  if (!Number.isFinite(parsed) || parsed < 0) return null;
  return Math.round(parsed);
}

function normalizeCallKind(value) {
  return value?.toString() === 'video' ? 'video' : 'voice';
}

function normalizeCallStatus(value) {
  const status = value?.toString() ?? 'ended';
  return ['accepted', 'ended', 'declined', 'missed'].includes(status)
    ? status
    : 'ended';
}

function authenticateRequest(request) {
  try {
    const url = new URL(request.url, 'http://localhost');
    const token = url.searchParams.get('token');
    if (!token) return null;
    return jwt.verify(token, config.jwtSecret);
  } catch {
    return null;
  }
}

function addClient(userId, socket) {
  const clients = clientsByUser.get(userId) ?? new Set();
  clients.add(socket);
  clientsByUser.set(userId, clients);
}

function removeClient(userId, socket) {
  const clients = clientsByUser.get(userId);
  if (!clients) return;
  clients.delete(socket);
  if (clients.size === 0) {
    clientsByUser.delete(userId);
  }
}

function addRoleClient(role, socket) {
  const clients = clientsByRole.get(role) ?? new Set();
  clients.add(socket);
  clientsByRole.set(role, clients);
}

function removeRoleClient(role, socket) {
  const clients = clientsByRole.get(role);
  if (!clients) return;
  clients.delete(socket);
  if (clients.size === 0) {
    clientsByRole.delete(role);
  }
}

function send(socket, type, payload) {
  socket.send(JSON.stringify({ type, payload }));
}
