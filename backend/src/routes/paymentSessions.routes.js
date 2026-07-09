import express from 'express';
import { z } from 'zod';
import { config } from '../config.js';
import { query, withTransaction } from '../db/pool.js';
import { optionalAuth, requireAuth } from '../middleware/auth.js';
import {
  estimateGatewayFeeCents,
  getPaymentGateway,
  listPaymentGateways,
  makeGatewayReference,
  paymentProviderIds,
  toPublicGateway,
} from '../payments/gatewayRegistry.js';
import { publishToRole, publishToUser, publishToUsers } from '../realtime/socketHub.js';
import { HttpError, notFound } from '../utils/httpError.js';
import { extractUpiId, makeId, makeQrFingerprint, normalizeQrPayload } from '../utils/ids.js';

export const paymentSessionsRouter = express.Router();

const scanQrSchema = z.object({
  qrPayload: z.string().trim().min(1).max(2000),
});

const checkoutItemSchema = z.object({
  shelfItemId: z.string().trim().min(1),
  quantity: z.number().int().min(1).max(99),
});

const completeCheckoutSchema = z.object({
  shopId: z.string().trim().min(1),
  amountCents: z.number().int().min(1).optional(),
  items: z.array(checkoutItemSchema).max(120).default([]),
  source: z.enum(['in_app', 'offline_scan']).default('in_app'),
  provider: z.enum(paymentProviderIds).default('mock_gateway'),
});

async function getPaymentSession(qrPayload) {
  const normalizedPayload = normalizeQrPayload(qrPayload);
  const fingerprint = makeQrFingerprint(normalizedPayload);
  const upiId = extractUpiId(normalizedPayload);

  const shopResult = await query(
    `SELECT s.id, s.seller_id, s.name, s.category, s.block, s.address, s.latitude, s.longitude,
      qr_code, qr_payload, payment_qr_payload, payment_qr_fingerprint, upi_id,
      gateway_provider, is_open
      , seller.phone AS seller_phone
     FROM shops s
     INNER JOIN app_users seller ON seller.id = s.seller_id
     WHERE payment_qr_fingerprint = $1
      OR qr_code = $1
      OR qr_payload = $2
      OR ($3::TEXT IS NOT NULL AND upi_id = $3)`,
    [fingerprint, normalizedPayload, upiId],
  );

  const shop = shopResult.rows[0];
  if (!shop) {
    throw notFound('Shop payment QR not found');
  }

  const itemsResult = await query(
    `SELECT id, shop_id, name, price_cents, stock_qty, category, barcode,
      description, image_url, alert_threshold, alert_enabled, is_active, updated_at
     FROM shelf_items
     WHERE shop_id = $1 AND is_active = TRUE
     ORDER BY name ASC`,
    [shop.id],
  );

  return {
    shop,
    items: itemsResult.rows,
    paymentSession: {
      qrFingerprint: fingerprint,
      qrPayload: shop.payment_qr_payload ?? shop.qr_payload,
      upiId: shop.upi_id,
      preferredProvider: shop.gateway_provider ?? 'mock_gateway',
      gateway: toPublicGateway(getPaymentGateway(shop.gateway_provider)),
      providers: listPaymentGateways(),
      mode: 'scan_existing_payment_qr_with_live_shelf',
    },
  };
}

paymentSessionsRouter.post('/scan', optionalAuth, async (req, res, next) => {
  try {
    const input = scanQrSchema.parse(req.body);
    const session = await getPaymentSession(input.qrPayload);
    res.json(session);
  } catch (error) {
    next(error);
  }
});

paymentSessionsRouter.get('/qr/:qrCode', async (req, res, next) => {
  try {
    res.json(await getPaymentSession(req.params.qrCode));
  } catch (error) {
    next(error);
  }
});

paymentSessionsRouter.get('/history', requireAuth, async (req, res, next) => {
  try {
    if (req.user.role !== 'user') {
      throw new HttpError(403, 'Only user accounts can view purchase history');
    }

    const result = await query(
      `SELECT
         pr.id,
         pr.user_id,
         pr.shop_id,
         pr.gross_cents,
         pr.gateway_fee_cents,
         pr.commission_cents,
         pr.seller_net_cents,
         pr.status,
         pr.source,
         pr.provider,
         pr.gateway_reference,
         pr.created_at,
         s.name AS shop_name,
         s.category AS shop_category,
         s.block AS shop_block,
         s.avatar_url AS shop_avatar_url,
         s.seller_id,
         seller.name AS seller_name,
         COALESCE(
          json_agg(
            json_build_object(
              'shelfItemId', pri.shelf_item_id,
              'name', pri.item_name,
              'unitPriceCents', pri.unit_price_cents,
              'quantity', pri.quantity,
              'lineTotalCents', pri.line_total_cents
            )
            ORDER BY pri.item_name
          ) FILTER (WHERE pri.id IS NOT NULL),
          '[]'::json
         ) AS items
       FROM payment_records pr
       INNER JOIN shops s ON s.id = pr.shop_id
       INNER JOIN app_users seller ON seller.id = s.seller_id
       LEFT JOIN payment_record_items pri ON pri.payment_id = pr.id
       WHERE pr.user_id = $1
       GROUP BY pr.id, s.id, seller.id
       ORDER BY pr.created_at DESC
       LIMIT 100`,
      [req.user.sub],
    );

    res.json({
      payments: result.rows.map((row) => mapHistoryPayment(row, req.user)),
    });
  } catch (error) {
    next(error);
  }
});

paymentSessionsRouter.post('/complete', requireAuth, async (req, res, next) => {
  try {
    if (req.user.role !== 'user') {
      throw new HttpError(403, 'Only user accounts can complete shop checkout payments');
    }

    const input = completeCheckoutSchema.parse(req.body);
    const items = mergeCheckoutItems(input.items);

    const result = await withTransaction(async (client) => {
      const shopResult = await client.query(
        `SELECT s.id, s.seller_id, s.name, s.category, s.block, s.avatar_url,
          seller.name AS seller_name
         FROM shops s
         INNER JOIN app_users seller ON seller.id = s.seller_id
         WHERE s.id = $1
           AND seller.deleted_at IS NULL
           AND s.is_open = TRUE
         FOR UPDATE OF s`,
        [input.shopId],
      );

      const shop = shopResult.rows[0];
      if (!shop) {
        throw new HttpError(404, 'Shop not found or currently closed');
      }

      const lineItems = [];
      let computedGrossCents = 0;

      if (items.length > 0) {
        const itemIds = items.map((item) => item.shelfItemId);
        const itemRows = await client.query(
          `SELECT id, name, price_cents, stock_qty, is_active,
            alert_threshold, alert_enabled
           FROM shelf_items
           WHERE shop_id = $1 AND id = ANY($2::TEXT[])
           FOR UPDATE`,
          [shop.id, itemIds],
        );
        const rowsById = new Map(itemRows.rows.map((row) => [row.id, row]));

        for (const requested of items) {
          const shelfItem = rowsById.get(requested.shelfItemId);
          if (!shelfItem || shelfItem.is_active !== true) {
            throw new HttpError(400, 'One selected item is no longer available');
          }
          if (shelfItem.stock_qty < requested.quantity) {
            throw new HttpError(
              409,
              `${shelfItem.name} has only ${shelfItem.stock_qty} left`,
            );
          }

          const lineTotalCents = shelfItem.price_cents * requested.quantity;
          computedGrossCents += lineTotalCents;
          lineItems.push({
            shelfItemId: shelfItem.id,
            itemName: shelfItem.name,
            unitPriceCents: shelfItem.price_cents,
            quantity: requested.quantity,
            lineTotalCents,
          });
        }
      }

      const grossCents = lineItems.length > 0
        ? computedGrossCents
        : input.amountCents;
      if (!grossCents || grossCents <= 0) {
        throw new HttpError(400, 'Select items or enter a payment amount');
      }

      const commissionRate = await getCurrentCommissionRate(client);
      const commissionCents = Math.round(grossCents * commissionRate);
      const gateway = getPaymentGateway(input.provider);
      const gatewayFeeCents = estimateGatewayFeeCents(grossCents, gateway.id);
      const sellerNetCents = Math.max(
        0,
        grossCents - commissionCents - gatewayFeeCents,
      );
      const paymentId = makeId('pay');
      let razorpayOrderId = null;
      let status = 'completed';

      if (input.provider === 'razorpay') {
        status = 'pending';
        const keyId = process.env.RAZORPAY_KEY_ID;
        const keySecret = process.env.RAZORPAY_KEY_SECRET;
        if (!keyId || !keySecret) {
          throw new HttpError(500, 'Razorpay integration is not configured on this server');
        }
        const authHeader = 'Basic ' + Buffer.from(keyId + ':' + keySecret).toString('base64');
        const response = await fetch('https://api.razorpay.com/v1/orders', {
          method: 'POST',
          headers: {
            'Content-Type': 'application/json',
            'Authorization': authHeader,
          },
          body: JSON.stringify({
            amount: grossCents,
            currency: 'INR',
            receipt: paymentId,
          }),
        });
        if (!response.ok) {
          const errText = await response.text();
          throw new HttpError(500, `Razorpay order creation failed: ${errText}`);
        }
        const rzOrder = await response.json();
        razorpayOrderId = rzOrder.id;
      }

      const gatewayReference = razorpayOrderId || makeGatewayReference(gateway.id, paymentId);

      const paymentResult = await client.query(
        `INSERT INTO payment_records (
          id, user_id, shop_id, gross_cents, gateway_fee_cents,
          commission_cents, seller_net_cents, status, source, provider,
          gateway_reference
        )
        VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11)
        RETURNING id, user_id, shop_id, gross_cents, gateway_fee_cents,
          commission_cents, seller_net_cents, status, source, provider,
          gateway_reference, created_at`,
        [
          paymentId,
          req.user.sub,
          shop.id,
          grossCents,
          gatewayFeeCents,
          commissionCents,
          sellerNetCents,
          status,
          input.source,
          gateway.id,
          gatewayReference,
        ],
      );

      const lowStockAlerts = [];
      for (const item of lineItems) {
        await client.query(
          `INSERT INTO payment_record_items (
            id, payment_id, shelf_item_id, item_name, unit_price_cents,
            quantity, line_total_cents
          )
          VALUES ($1, $2, $3, $4, $5, $6, $7)`,
          [
            makeId('payitem'),
            paymentId,
            item.shelfItemId,
            item.itemName,
            item.unitPriceCents,
            item.quantity,
            item.lineTotalCents,
          ],
        );

        if (status === 'completed') {
          const updatedItem = await client.query(
            `UPDATE shelf_items
              SET stock_qty = stock_qty - $2,
                  updated_at = NOW()
              WHERE id = $1
              RETURNING id, name, stock_qty, alert_threshold, alert_enabled`,
            [item.shelfItemId, item.quantity],
          );
          const stockItem = updatedItem.rows[0];
          const threshold = Number(stockItem?.alert_threshold);
          if (
            stockItem?.alert_enabled === true &&
            Number.isFinite(threshold) &&
            threshold >= 0 &&
            Number(stockItem.stock_qty) <= threshold
          ) {
            lowStockAlerts.push(stockItem);
          }
        }
      }

      if (status === 'pending') {
        return {
          shop,
          payment: paymentResult.rows[0],
          items: lineItems,
          razorpayOrderId,
          status: 'pending',
        };
      }

      const sellerNotificationId = makeId('notif');
      const sellerNotification = {
        id: sellerNotificationId,
        type: 'payment.completed',
        title: 'New checkout payment',
        body: `${req.user.name ?? 'Customer'} paid ${formatRupees(grossCents)} at ${shop.name}`,
        shopId: shop.id,
        shopName: shop.name,
        actorName: req.user.name ?? 'Customer',
      };
      await client.query(
        `INSERT INTO notifications (
          id, recipient_user_id, actor_user_id, shop_id, type, title, body
        )
        VALUES ($1, $2, $3, $4, 'payment.completed', $5, $6)`,
        [
          sellerNotificationId,
          shop.seller_id,
          req.user.sub,
          shop.id,
          sellerNotification.title,
          sellerNotification.body,
        ],
      );

      const paymentChatMessage = {
        id: paymentId,
        roomId: `shop:${shop.id}:user:${req.user.sub}`,
        scope: 'shop_payment',
        senderUserId: req.user.sub,
        targetUserId: shop.seller_id,
        shopId: shop.id,
        text: `Paid ${formatRupees(grossCents)} to ${shop.name}`,
        type: 'payment',
        createdAt: paymentResult.rows[0].created_at,
        sender: {
          id: req.user.sub,
          name: req.user.name ?? 'Customer',
          role: req.user.role,
        },
      };
      await client.query(
        `INSERT INTO chat_messages (
          id, room_id, scope, sender_user_id, target_user_id, shop_id, text,
          message_type, delivery_status, delivered_at
        )
        VALUES ($1, $2, 'shop_payment', $3, $4, $5, $6, 'payment',
          'sent_online', NOW())
        ON CONFLICT (id) DO NOTHING`,
        [
          paymentChatMessage.id,
          paymentChatMessage.roomId,
          paymentChatMessage.senderUserId,
          paymentChatMessage.targetUserId,
          paymentChatMessage.shopId,
          paymentChatMessage.text,
        ],
      );

      const lowStockNotifications = [];
      for (const stockItem of lowStockAlerts) {
        const notificationId = makeId('notif');
        const threshold = Number(stockItem.alert_threshold);
        const body = `${stockItem.name} is now at ${stockItem.stock_qty} left after checkout. Alert threshold: ${threshold}.`;
        await client.query(
          `INSERT INTO notifications (
            id, recipient_user_id, actor_user_id, shop_id, type, title, body
          )
          VALUES ($1, $2, $3, $4, 'stock.low', 'Low stock alert', $5)`,
          [notificationId, shop.seller_id, req.user.sub, shop.id, body],
        );
        lowStockNotifications.push({
          id: notificationId,
          type: 'stock.low',
          title: 'Low stock alert',
          body,
          shopId: shop.id,
          shopName: shop.name,
          actorName: req.user.name ?? 'Customer',
        });
      }

      const admins = await client.query(
        `SELECT id
         FROM app_users
         WHERE role = 'admin' AND deleted_at IS NULL`,
      );
      const adminNotificationIds = [];
      const adminNotification = {
        type: 'payment.completed.admin',
        title: 'Checkout recorded',
        body: `${req.user.name ?? 'Customer'} paid ${formatRupees(grossCents)} to ${shop.name}. DukaanZone fee: ${formatRupees(commissionCents)}.`,
        shopId: shop.id,
        shopName: shop.name,
        actorName: req.user.name ?? 'Customer',
      };
      for (const admin of admins.rows) {
        const notificationId = makeId('notif');
        adminNotificationIds.push(admin.id);
        await client.query(
          `INSERT INTO notifications (
            id, recipient_user_id, actor_user_id, shop_id, type, title, body
          )
          VALUES ($1, $2, $3, $4, 'payment.completed.admin', $5, $6)`,
          [
            notificationId,
            admin.id,
            req.user.sub,
            shop.id,
            adminNotification.title,
            adminNotification.body,
          ],
        );
      }

      return {
        shop,
        payment: paymentResult.rows[0],
        items: lineItems,
        sellerNotification,
        lowStockNotifications,
        adminNotification,
        adminNotificationIds,
        paymentChatMessage,
      };
    });

    if (result.status === 'pending') {
      res.status(201).json({
        status: 'pending',
        payment: {
          id: result.payment.id,
          status: 'pending',
          grossCents: result.payment.gross_cents,
          provider: 'razorpay',
          gatewayReference: result.payment.gateway_reference,
        },
        razorpayOrderId: result.razorpayOrderId,
        keyId: process.env.RAZORPAY_KEY_ID,
      });
      return;
    }

    const payload = mapCompletedPayment(result.payment, result.shop, result.items, req.user);
    publishToUser(result.shop.seller_id, 'notification.created', result.sellerNotification);
    for (const notification of result.lowStockNotifications) {
      publishToUser(result.shop.seller_id, 'notification.created', notification);
    }
    publishToUsers(result.adminNotificationIds, 'notification.created', result.adminNotification);
    publishToUser(result.shop.seller_id, 'payment.completed', payload);
    publishToUser(req.user.sub, 'payment.completed', payload);
    publishToRole('admin', 'payment.completed', payload);
    const stockPayload = {
      shopId: result.shop.id,
      sellerId: result.shop.seller_id,
      itemIds: result.items.map((item) => item.shelfItemId),
      reason: 'payment_completed',
    };
    publishToRole('user', 'stock.updated', stockPayload);
    publishToRole('admin', 'stock.updated', stockPayload);
    publishToUser(result.shop.seller_id, 'stock.updated', stockPayload);
    publishToUsers(
      [result.shop.seller_id, req.user.sub],
      'chat.message',
      result.paymentChatMessage,
    );

    res.status(201).json({ payment: payload });
  } catch (error) {
    next(error);
  }
});

paymentSessionsRouter.post('/razorpay/verify', requireAuth, async (req, res, next) => {
  try {
    const schema = z.object({
      paymentId: z.string().trim().min(1),
      razorpayPaymentId: z.string().trim().min(1),
      razorpayOrderId: z.string().trim().min(1),
      razorpaySignature: z.string().trim().min(1),
    });
    const { paymentId, razorpayPaymentId, razorpayOrderId, razorpaySignature } = schema.parse(req.body);

    const crypto = await import('crypto');
    const secret = process.env.RAZORPAY_KEY_SECRET;
    const body = razorpayOrderId + '|' + razorpayPaymentId;
    const expectedSignature = crypto
      .createHmac('sha256', secret)
      .update(body.toString())
      .digest('hex');

    if (expectedSignature !== razorpaySignature) {
      throw new HttpError(400, 'Invalid payment signature. Verification failed.');
    }

    const result = await withTransaction(async (client) => {
      const payResult = await client.query(
        `SELECT id, user_id, shop_id, gross_cents, gateway_fee_cents, commission_cents, seller_net_cents, status, source
         FROM payment_records
         WHERE id = $1 AND status = 'pending'
         FOR UPDATE`,
        [paymentId]
      );
      const payment = payResult.rows[0];
      if (!payment) {
        throw new HttpError(404, 'Pending payment record not found');
      }

      await client.query(
        `UPDATE payment_records
         SET status = 'completed',
             gateway_reference = $2,
             updated_at = NOW()
         WHERE id = $1`,
        [paymentId, razorpayPaymentId]
      );

      const shopResult = await client.query(
        `SELECT s.id, s.seller_id, s.name, s.category, s.block, s.avatar_url,
          seller.name AS seller_name
         FROM shops s
         INNER JOIN app_users seller ON seller.id = s.seller_id
         WHERE s.id = $1`,
        [payment.shop_id]
      );
      const shop = shopResult.rows[0];

      const itemsResult = await client.query(
        `SELECT shelf_item_id, item_name, unit_price_cents, quantity
         FROM payment_record_items
         WHERE payment_id = $1`,
        [paymentId]
      );
      const items = itemsResult.rows;

      const lowStockAlerts = [];
      for (const item of items) {
        const updatedItem = await client.query(
          `UPDATE shelf_items
            SET stock_qty = stock_qty - $2,
                updated_at = NOW()
            WHERE id = $1
            RETURNING id, name, stock_qty, alert_threshold, alert_enabled`,
          [item.shelf_item_id, item.quantity]
        );
        const stockItem = updatedItem.rows[0];
        if (stockItem) {
          const threshold = Number(stockItem.alert_threshold);
          if (
            stockItem.alert_enabled === true &&
            Number.isFinite(threshold) &&
            threshold >= 0 &&
            Number(stockItem.stock_qty) <= threshold
          ) {
            lowStockAlerts.push(stockItem);
          }
        }
      }

      const sellerNotificationId = makeId('notif');
      const sellerNotification = {
        id: sellerNotificationId,
        type: 'payment.completed',
        title: 'New checkout payment',
        body: `${req.user.name ?? 'Customer'} paid ${formatRupees(payment.gross_cents)} at ${shop.name}`,
        shopId: shop.id,
        shopName: shop.name,
        actorName: req.user.name ?? 'Customer',
      };
      await client.query(
        `INSERT INTO notifications (
          id, recipient_user_id, actor_user_id, shop_id, type, title, body
        )
        VALUES ($1, $2, $3, $4, 'payment.completed', $5, $6)`,
        [
          sellerNotificationId,
          shop.seller_id,
          req.user.sub,
          shop.id,
          sellerNotification.title,
          sellerNotification.body,
        ]
      );

      const paymentChatMessage = {
        id: paymentId,
        roomId: `shop:${shop.id}:user:${req.user.sub}`,
        scope: 'shop_payment',
        senderUserId: req.user.sub,
        targetUserId: shop.seller_id,
        shopId: shop.id,
        text: `Paid ${formatRupees(payment.gross_cents)} to ${shop.name}`,
        type: 'payment',
        createdAt: new Date(),
        sender: {
          id: req.user.sub,
          name: req.user.name ?? 'Customer',
          role: req.user.role,
        },
      };
      await client.query(
        `INSERT INTO chat_messages (
          id, room_id, scope, sender_user_id, target_user_id, shop_id, text,
          message_type, delivery_status, delivered_at
        )
        VALUES ($1, $2, 'shop_payment', $3, $4, $5, $6, 'payment',
          'sent_online', NOW())
        ON CONFLICT (id) DO NOTHING`,
        [
          paymentChatMessage.id,
          paymentChatMessage.roomId,
          paymentChatMessage.senderUserId,
          paymentChatMessage.targetUserId,
          paymentChatMessage.shopId,
          paymentChatMessage.text,
        ]
      );

      const lowStockNotifications = [];
      for (const stockItem of lowStockAlerts) {
        const notificationId = makeId('notif');
        const threshold = Number(stockItem.alert_threshold);
        const body = `${stockItem.name} is now at ${stockItem.stock_qty} left after checkout. Alert threshold: ${threshold}.`;
        await client.query(
          `INSERT INTO notifications (
            id, recipient_user_id, actor_user_id, shop_id, type, title, body
          )
          VALUES ($1, $2, $3, $4, 'stock.low', 'Low stock alert', $5)`,
          [notificationId, shop.seller_id, req.user.sub, shop.id, body]
        );
        lowStockNotifications.push({
          id: notificationId,
          type: 'stock.low',
          title: 'Low stock alert',
          body,
          shopId: shop.id,
          shopName: shop.name,
          actorName: req.user.name ?? 'Customer',
        });
      }

      const admins = await client.query(
        `SELECT id
         FROM app_users
         WHERE role = 'admin' AND deleted_at IS NULL`,
      );
      const adminNotificationIds = [];
      const adminNotification = {
        type: 'payment.completed.admin',
        title: 'Checkout recorded',
        body: `${req.user.name ?? 'Customer'} paid ${formatRupees(payment.gross_cents)} to ${shop.name}. DukaanZone fee: ${formatRupees(payment.commission_cents)}.`,
        shopId: shop.id,
        shopName: shop.name,
        actorName: req.user.name ?? 'Customer',
      };
      for (const admin of admins.rows) {
        const notificationId = makeId('notif');
        adminNotificationIds.push(admin.id);
        await client.query(
          `INSERT INTO notifications (
            id, recipient_user_id, actor_user_id, shop_id, type, title, body
          )
          VALUES ($1, $2, $3, $4, 'payment.completed.admin', $5, $6)`,
          [
            notificationId,
            admin.id,
            req.user.sub,
            shop.id,
            adminNotification.title,
            adminNotification.body,
          ]
        );
      }

      return {
        shop,
        payment: { ...payment, status: 'completed', gateway_reference: razorpayPaymentId },
        items: items.map(item => ({
          shelfItemId: item.shelf_item_id,
          itemName: item.item_name,
          unitPriceCents: item.unit_price_cents,
          quantity: item.quantity,
          lineTotalCents: item.unit_price_cents * item.quantity,
        })),
        sellerNotification,
        lowStockNotifications,
        adminNotification,
        adminNotificationIds,
        paymentChatMessage,
      };
    });

    const payload = mapCompletedPayment(result.payment, result.shop, result.items, req.user);
    publishToUser(result.shop.seller_id, 'notification.created', result.sellerNotification);
    for (const notification of result.lowStockNotifications) {
      publishToUser(result.shop.seller_id, 'notification.created', notification);
    }
    publishToUsers(result.adminNotificationIds, 'notification.created', result.adminNotification);
    publishToUser(result.shop.seller_id, 'payment.completed', payload);
    publishToUser(req.user.sub, 'payment.completed', payload);
    publishToRole('admin', 'payment.completed', payload);
    const stockPayload = {
      shopId: result.shop.id,
      sellerId: result.shop.seller_id,
      itemIds: result.items.map((item) => item.shelfItemId),
      reason: 'payment_completed',
    };
    publishToRole('user', 'stock.updated', stockPayload);
    publishToRole('admin', 'stock.updated', stockPayload);
    publishToUser(result.shop.seller_id, 'stock.updated', stockPayload);
    publishToUsers(
      [result.shop.seller_id, req.user.sub],
      'chat.message',
      result.paymentChatMessage,
    );

    res.json({ verified: true, payment: payload });
  } catch (error) {
    next(error);
  }
});

function mergeCheckoutItems(items) {
  const merged = new Map();
  for (const item of items) {
    const current = merged.get(item.shelfItemId) ?? 0;
    merged.set(item.shelfItemId, current + item.quantity);
  }
  return [...merged.entries()].map(([shelfItemId, quantity]) => ({
    shelfItemId,
    quantity,
  }));
}

function mapCompletedPayment(payment, shop, items, user) {
  return {
    id: payment.id,
    shopId: payment.shop_id,
    shopName: shop.name,
    shopCategory: shop.category,
    shopBlock: shop.block,
    shopAvatarUrl: shop.avatar_url?.startsWith('blob:') ? null : shop.avatar_url,
    sellerId: shop.seller_id,
    sellerName: shop.seller_name,
    userId: payment.user_id,
    userName: user.name ?? 'Customer',
    grossCents: payment.gross_cents,
    gatewayFeeCents: payment.gateway_fee_cents ?? 0,
    commissionCents: payment.commission_cents,
    sellerNetCents: payment.seller_net_cents,
    status: payment.status,
    source: payment.source,
    provider: payment.provider ?? 'mock_gateway',
    gateway: toPublicGateway(getPaymentGateway(payment.provider)),
    gatewayReference: payment.gateway_reference,
    createdAt: payment.created_at,
    items: items.map((item) => ({
      shelfItemId: item.shelfItemId,
      name: item.itemName,
      unitPriceCents: item.unitPriceCents,
      quantity: item.quantity,
      lineTotalCents: item.lineTotalCents,
    })),
  };
}

function mapHistoryPayment(row, user) {
  return {
    id: row.id,
    shopId: row.shop_id,
    shopName: row.shop_name,
    shopCategory: row.shop_category,
    shopBlock: row.shop_block,
    shopAvatarUrl: row.shop_avatar_url?.startsWith('blob:') ? null : row.shop_avatar_url,
    sellerId: row.seller_id,
    sellerName: row.seller_name,
    userId: row.user_id,
    userName: user.name ?? 'Customer',
    grossCents: row.gross_cents,
    gatewayFeeCents: row.gateway_fee_cents ?? 0,
    commissionCents: row.commission_cents,
    sellerNetCents: row.seller_net_cents,
    status: row.status,
    source: row.source,
    provider: row.provider ?? 'mock_gateway',
    gateway: toPublicGateway(getPaymentGateway(row.provider)),
    gatewayReference: row.gateway_reference,
    createdAt: row.created_at,
    items: row.items ?? [],
  };
}

function formatRupees(cents) {
  return `Rs ${(cents / 100).toFixed(cents % 100 === 0 ? 0 : 2)}`;
}

async function getCurrentCommissionRate(client) {
  const result = await client.query(
    `SELECT value FROM platform_settings WHERE key = 'payment'`,
  );
  const value = result.rows[0]?.value ?? {};
  const configuredRate = Number(value.commissionRate ?? value.commission_rate);
  if (Number.isFinite(configuredRate)) {
    return Math.min(Math.max(configuredRate, 0), 0.25);
  }
  return config.commissionRate;
}
