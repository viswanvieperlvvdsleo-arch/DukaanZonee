import express from 'express';
import { z } from 'zod';
import { query } from '../db/pool.js';
import { requireAuth, requireRole } from '../middleware/auth.js';
import { publishToRole } from '../realtime/socketHub.js';
import { HttpError } from '../utils/httpError.js';
import {
  buildUpiQrPayload,
  extractUpiId,
  makeId,
  makeQrFingerprint,
  normalizeQrPayload,
} from '../utils/ids.js';
import { decodeQrImage } from '../utils/qrImageDecoder.js';

export const sellerRouter = express.Router();

sellerRouter.use(requireAuth, requireRole('seller'));

const itemSchema = z.object({
  name: z.string().trim().min(2).max(160),
  priceCents: z.number().int().min(0),
  stockQty: z.number().int().min(0).default(0),
  category: z.string().trim().max(80).optional(),
  barcode: z.string().trim().max(120).optional(),
  description: z.string().trim().max(1200).optional(),
  imageUrl: z.string().trim().max(1_000_000).optional(),
  alertThreshold: z.number().int().min(0).optional(),
  alertEnabled: z.boolean().optional(),
  isActive: z.boolean().optional(),
});

const itemUpdateSchema = itemSchema.partial();

const shopUpdateSchema = z.object({
  name: z.string().trim().min(2).max(160).optional(),
  category: z.string().trim().max(80).optional(),
  block: z.string().trim().max(80).optional(),
  address: z.string().trim().max(240).optional(),
  latitude: z.number().min(-90).max(90).optional(),
  longitude: z.number().min(-180).max(180).optional(),
  paymentQrPayload: z.string().trim().min(8).max(2000).optional(),
  upiId: z.string().trim().max(120).optional(),
  avatarUrl: z.string().trim().max(1_000_000).optional(),
  mapUrl: z.string().trim().url().max(2000).optional(),
  isOpen: z.boolean().optional(),
  clearPaymentQr: z.boolean().optional(),
});

const qrImageDecodeSchema = z.object({
  imageData: z.string().min(32).max(8_000_000),
});

const partnerSearchSchema = z.object({
  q: z.string().trim().max(120).optional(),
  limit: z.coerce.number().int().min(1).max(80).default(40),
});

const customerSearchSchema = z.object({
  q: z.string().trim().max(120).optional(),
  limit: z.coerce.number().int().min(1).max(80).default(40),
});

const promotionSchema = z.object({
  shelfItemId: z.string().trim().min(2).max(120),
  durationDays: z.number().int().min(1).max(365),
  amountCents: z.number().int().min(0),
});

async function getSellerShop(sellerId) {
  const result = await query(
    `SELECT id, seller_id, name, category, block, address, latitude, longitude,
      qr_code, qr_payload, payment_qr_payload, payment_qr_fingerprint, upi_id,
      avatar_url, map_url, is_open,
      (SELECT COUNT(*)::INT
       FROM shop_followers sf
       WHERE sf.shop_id = shops.id) AS follower_count,
      (SELECT ROUND(AVG(pr.rating)::NUMERIC, 1)::FLOAT
       FROM product_reviews pr
       INNER JOIN shelf_items review_item ON review_item.id = pr.shelf_item_id
       WHERE review_item.shop_id = shops.id) AS rating
     FROM shops
     WHERE seller_id = $1`,
    [sellerId],
  );

  return result.rows[0];
}

async function getSellerItem(sellerId, itemId) {
  const result = await query(
    `SELECT si.id, si.shop_id, si.name, si.price_cents, si.stock_qty,
      si.category, si.barcode, si.description, si.image_url,
      si.alert_threshold, si.alert_enabled, si.is_active,
      si.created_at, si.updated_at
     FROM shelf_items si
     INNER JOIN shops s ON s.id = si.shop_id
     WHERE si.id = $1 AND s.seller_id = $2`,
    [itemId, sellerId],
  );

  return result.rows[0];
}

sellerRouter.get('/shop', async (req, res, next) => {
  try {
    const shop = await getSellerShop(req.user.sub);
    if (!shop) {
      throw new HttpError(404, 'Seller shop not found');
    }
    res.json({ shop });
  } catch (error) {
    next(error);
  }
});

sellerRouter.get('/dashboard', async (req, res, next) => {
  try {
    const shop = await getSellerShop(req.user.sub);
    if (!shop) {
      throw new HttpError(404, 'Seller shop not found');
    }

    const summary = await query(
      `SELECT
        COALESCE(SUM(pr.gross_cents)
          FILTER (WHERE pr.status = 'completed'), 0)::INT AS total_gross_cents,
        COALESCE(SUM(pr.gateway_fee_cents)
          FILTER (WHERE pr.status = 'completed'), 0)::INT AS total_gateway_fee_cents,
        COALESCE(SUM(pr.seller_net_cents)
          FILTER (WHERE pr.status = 'completed'), 0)::INT AS total_seller_net_cents,
        COALESCE(SUM(pr.commission_cents)
          FILTER (WHERE pr.status = 'completed'), 0)::INT AS total_commission_cents,
        COUNT(*) FILTER (WHERE pr.status = 'completed')::INT AS total_payment_count,
        COALESCE(SUM(pr.gross_cents)
          FILTER (WHERE pr.status = 'completed'
            AND pr.created_at >= DATE_TRUNC('day', NOW())), 0)::INT AS today_gross_cents,
        COALESCE(SUM(pr.gateway_fee_cents)
          FILTER (WHERE pr.status = 'completed'
            AND pr.created_at >= DATE_TRUNC('day', NOW())), 0)::INT AS today_gateway_fee_cents,
        COALESCE(SUM(pr.seller_net_cents)
          FILTER (WHERE pr.status = 'completed'
            AND pr.created_at >= DATE_TRUNC('day', NOW())), 0)::INT AS today_seller_net_cents,
        COALESCE(SUM(pr.commission_cents)
          FILTER (WHERE pr.status = 'completed'
            AND pr.created_at >= DATE_TRUNC('day', NOW())), 0)::INT AS today_commission_cents,
        COUNT(*) FILTER (WHERE pr.status = 'completed'
          AND pr.created_at >= DATE_TRUNC('day', NOW()))::INT AS today_payment_count
       FROM payment_records pr
       WHERE pr.shop_id = $1`,
      [shop.id],
    );

    const inventory = await query(
      `SELECT
        COUNT(*)::INT AS item_count,
        COUNT(*) FILTER (WHERE is_active = TRUE)::INT AS active_item_count,
        COUNT(*) FILTER (
          WHERE is_active = TRUE
            AND alert_enabled = TRUE
            AND stock_qty <= alert_threshold
        )::INT AS low_stock_count
       FROM shelf_items
       WHERE shop_id = $1`,
      [shop.id],
    );

    const recentPayments = await query(
      `SELECT pr.id, pr.gross_cents, pr.gateway_fee_cents,
        pr.commission_cents, pr.seller_net_cents, pr.status, pr.source,
        pr.provider, pr.gateway_reference, pr.created_at,
        buyer.id AS user_id, buyer.name AS user_name, buyer.profile_pic,
        COALESCE(
          JSON_AGG(
            JSON_BUILD_OBJECT(
              'name', pri.item_name,
              'quantity', pri.quantity,
              'lineTotalCents', pri.line_total_cents
            )
          ) FILTER (WHERE pri.id IS NOT NULL),
          '[]'::JSON
        ) AS items
       FROM payment_records pr
       INNER JOIN app_users buyer ON buyer.id = pr.user_id
       LEFT JOIN payment_record_items pri ON pri.payment_id = pr.id
       WHERE pr.shop_id = $1
       GROUP BY pr.id, buyer.id
       ORDER BY pr.created_at DESC
       LIMIT 12`,
      [shop.id],
    );

    const topItems = await query(
      `SELECT pri.shelf_item_id, pri.item_name,
        SUM(pri.quantity)::INT AS quantity,
        SUM(pri.line_total_cents)::INT AS gross_cents
       FROM payment_record_items pri
       INNER JOIN payment_records pr ON pr.id = pri.payment_id
       WHERE pr.shop_id = $1
         AND pr.status = 'completed'
         AND pr.created_at >= DATE_TRUNC('day', NOW())
       GROUP BY pri.shelf_item_id, pri.item_name
       ORDER BY quantity DESC, gross_cents DESC
       LIMIT 8`,
      [shop.id],
    );

    res.json({
      shop,
      summary: {
        ...summary.rows[0],
        ...inventory.rows[0],
      },
      recentPayments: recentPayments.rows.map((row) => ({
        id: row.id,
        grossCents: row.gross_cents,
        gatewayFeeCents: row.gateway_fee_cents ?? 0,
        commissionCents: row.commission_cents,
        sellerNetCents: row.seller_net_cents,
        status: row.status,
        source: row.source,
        provider: row.provider,
        gatewayReference: row.gateway_reference,
        createdAt: row.created_at,
        user: {
          id: row.user_id,
          name: row.user_name,
          profilePic: row.profile_pic?.startsWith('blob:')
            ? null
            : row.profile_pic,
        },
        items: row.items,
      })),
      topItems: topItems.rows.map((row) => ({
        shelfItemId: row.shelf_item_id,
        name: row.item_name,
        quantity: row.quantity,
        grossCents: row.gross_cents,
      })),
    });
  } catch (error) {
    next(error);
  }
});

sellerRouter.get('/promotions', async (req, res, next) => {
  try {
    const shop = await getSellerShop(req.user.sub);
    if (!shop) throw new HttpError(404, 'Seller shop not found');
    const result = await query(
      `SELECT p.id, p.duration_days, p.amount_cents, p.status, p.starts_at,
        p.ends_at, p.impressions, p.clicks, p.created_at, p.updated_at,
        item.id AS item_id, item.name AS item_name, item.image_url AS item_image_url,
        item.price_cents
       FROM product_promotions p
       INNER JOIN shelf_items item ON item.id = p.shelf_item_id
       WHERE p.seller_id = $1
       ORDER BY p.created_at DESC
       LIMIT 80`,
      [req.user.sub],
    );
    res.json({ promotions: result.rows.map(mapSellerPromotion) });
  } catch (error) {
    next(error);
  }
});

sellerRouter.post('/promotions', async (req, res, next) => {
  try {
    const input = promotionSchema.parse(req.body);
    const shop = await getSellerShop(req.user.sub);
    if (!shop) throw new HttpError(404, 'Seller shop not found');
    const item = await getSellerItem(req.user.sub, input.shelfItemId);
    if (!item) throw new HttpError(404, 'Shelf item not found');

    const result = await query(
      `INSERT INTO product_promotions (
        id, seller_id, shop_id, shelf_item_id, duration_days, amount_cents,
        status, starts_at, ends_at
      )
      VALUES (
        $1, $2, $3, $4, $5, $6,
        'approved',
        NOW(),
        NOW() + (($5)::INTEGER * INTERVAL '1 day')
      )
      RETURNING id, duration_days, amount_cents, status, starts_at, ends_at,
        impressions, clicks, created_at, updated_at`,
      [
        makeId('promo'),
        req.user.sub,
        shop.id,
        item.id,
        input.durationDays,
        input.amountCents,
      ],
    );
    const title = 'Promotion payment received';
    const body = `${shop.name} paid for a ${input.durationDays} day boost for ${item.name}. It is live now.`;
    await notifyAdmins(req.user.sub, 'promotion.created', title, body);
    publishToRole('admin', 'notification.created', {
      type: 'promotion.created',
      title,
      body,
    });
    publishToRole('admin', 'promotion.created', {
      id: result.rows[0].id,
      shopId: shop.id,
      shopName: shop.name,
      itemId: item.id,
      itemName: item.name,
      durationDays: input.durationDays,
      amountCents: input.amountCents,
      status: result.rows[0].status,
      startsAt: result.rows[0].starts_at,
      endsAt: result.rows[0].ends_at,
      createdAt: result.rows[0].created_at,
    });
    res.status(201).json({
      promotion: mapSellerPromotion({
        ...result.rows[0],
        item_id: item.id,
        item_name: item.name,
        item_image_url: item.image_url,
        price_cents: item.price_cents,
      }),
    });
  } catch (error) {
    next(error);
  }
});

sellerRouter.get('/b2b/partners', async (req, res, next) => {
  try {
    const input = partnerSearchSchema.parse(req.query);
    const search = input.q ? `%${input.q.toLowerCase()}%` : null;
    const result = await query(
      `SELECT s.id AS shop_id, s.name AS shop_name, s.category, s.block,
        s.address, s.avatar_url, s.upi_id,
        u.id AS seller_id, u.name AS owner_name, u.email, u.phone, u.profile_pic
       FROM shops s
       INNER JOIN app_users u ON u.id = s.seller_id
       WHERE u.role = 'seller'
        AND u.deleted_at IS NULL
        AND u.id <> $1
        AND u.email NOT LIKE '%@dukaanzone.local'
        AND u.email NOT LIKE '%@dz.local'
        AND ($2::TEXT IS NULL
          OR LOWER(s.name) LIKE $2
          OR LOWER(u.name) LIKE $2
          OR LOWER(u.email) LIKE $2
          OR LOWER(COALESCE(u.phone, '')) LIKE $2
          OR LOWER(COALESCE(s.category, '')) LIKE $2
          OR LOWER(COALESCE(s.block, '')) LIKE $2
          OR LOWER(COALESCE(s.upi_id, '')) LIKE $2)
       ORDER BY s.updated_at DESC, s.created_at DESC
       LIMIT $3`,
      [req.user.sub, search, input.limit],
    );

    res.json({
      partners: result.rows.map((row) => ({
        shopId: row.shop_id,
        sellerId: row.seller_id,
        name: row.shop_name,
        owner: row.owner_name,
        category: row.category,
        block: row.block,
        address: row.address,
        email: row.email,
        phone: row.phone,
        upiId: row.upi_id,
        avatarUrl: row.avatar_url?.startsWith('blob:') ? null : row.avatar_url,
        ownerProfilePic: row.profile_pic?.startsWith('blob:') ? null : row.profile_pic,
      })),
    });
  } catch (error) {
    next(error);
  }
});

sellerRouter.get('/customers/search', async (req, res, next) => {
  try {
    const input = customerSearchSchema.parse(req.query);
    const text = input.q?.trim() ?? '';
    const search = text ? `%${text.toLowerCase()}%` : null;
    const shop = await getSellerShop(req.user.sub);
    if (!shop) throw new HttpError(404, 'Seller shop not found');

    const result = await query(
      `SELECT u.id, u.name, u.email, u.phone, u.profile_pic
       FROM app_users u
       WHERE u.role = 'user'
        AND u.deleted_at IS NULL
        AND u.email NOT LIKE '%@dukaanzone.local'
        AND u.email NOT LIKE '%@dz.local'
        AND ($1::TEXT IS NULL
          OR LOWER(u.id) LIKE $1
          OR LOWER(u.name) LIKE $1
          OR LOWER(u.email) LIKE $1
          OR LOWER(COALESCE(u.phone, '')) LIKE $1)
       ORDER BY u.created_at DESC
       LIMIT $2`,
      [search, input.limit],
    );

    res.json({
      customers: result.rows.map((row) => ({
        id: row.id,
        name: row.name,
        email: row.email,
        phone: row.phone,
        avatarUrl: row.profile_pic?.startsWith('blob:') ? null : row.profile_pic,
        roomId: `shop:${shop.id}:user:${row.id}`,
        shopId: shop.id,
      })),
    });
  } catch (error) {
    next(error);
  }
});

sellerRouter.post('/payment-qr/decode-image', async (req, res, next) => {
  try {
    const input = qrImageDecodeSchema.parse(req.body);
    const payload = normalizeQrPayload(await decodeQrImage(input.imageData));
    const upiId = extractUpiId(payload);
    res.json({ payload, upiId });
  } catch (error) {
    next(error);
  }
});

sellerRouter.patch('/shop', async (req, res, next) => {
  try {
    const input = shopUpdateSchema.parse(req.body);
    const shop = await getSellerShop(req.user.sub);
    if (!shop) {
      throw new HttpError(404, 'Seller shop not found');
    }

    const shouldClearPaymentQr = input.clearPaymentQr === true;
    let paymentQrPayload = null;
    let paymentQrFingerprint = null;
    let upiId = input.upiId?.trim() || null;
    const nextShopName = input.name ?? shop.name;

    if (shouldClearPaymentQr) {
      paymentQrPayload = '';
      paymentQrFingerprint = '';
      upiId = '';
    } else if (input.paymentQrPayload !== undefined && input.paymentQrPayload.trim() !== '') {
      paymentQrPayload = normalizeQrPayload(input.paymentQrPayload);
      paymentQrFingerprint = makeQrFingerprint(paymentQrPayload);
      upiId = input.upiId ?? extractUpiId(paymentQrPayload);
    } else if (upiId && !shop.payment_qr_payload) {
      paymentQrPayload = buildUpiQrPayload(upiId, nextShopName);
      paymentQrFingerprint = makeQrFingerprint(paymentQrPayload);
    }

    if (!shouldClearPaymentQr && (paymentQrFingerprint !== null || upiId !== null)) {
      const existingQr = await query(
        `SELECT id FROM shops
         WHERE id <> $1
          AND (
            ($2::TEXT IS NOT NULL AND payment_qr_fingerprint = $2)
            OR ($3::TEXT IS NOT NULL AND upi_id = $3)
          )
         LIMIT 1`,
        [shop.id, paymentQrFingerprint, upiId],
      );
      if (existingQr.rows.length > 0) {
        throw new HttpError(409, 'Payment QR or UPI ID already linked to another shop');
      }
    }

    const result = shouldClearPaymentQr
      ? await query(
          `UPDATE shops
           SET name = COALESCE($2, name),
               category = COALESCE($3, category),
               block = COALESCE($4, block),
               address = COALESCE($5, address),
               latitude = COALESCE($6, latitude),
               longitude = COALESCE($7, longitude),
               payment_qr_payload = NULL,
               payment_qr_fingerprint = NULL,
               upi_id = NULL,
               avatar_url = COALESCE($8, avatar_url),
               map_url = COALESCE($9, map_url),
               is_open = COALESCE($10, is_open),
               updated_at = NOW()
           WHERE id = $1
           RETURNING id, seller_id, name, category, block, address, latitude, longitude,
             qr_code, qr_payload, payment_qr_payload, payment_qr_fingerprint, upi_id,
             avatar_url, map_url, is_open`,
          [
            shop.id,
            input.name ?? null,
            input.category ?? null,
            input.block ?? null,
            input.address ?? null,
            input.latitude ?? null,
            input.longitude ?? null,
            input.avatarUrl ?? null,
            input.mapUrl ?? null,
            input.isOpen ?? null,
          ],
        )
      : await query(
          `UPDATE shops
           SET name = COALESCE($2, name),
               category = COALESCE($3, category),
               block = COALESCE($4, block),
               address = COALESCE($5, address),
               latitude = COALESCE($6, latitude),
               longitude = COALESCE($7, longitude),
               payment_qr_payload = CASE
                 WHEN $8 IS NOT NULL AND $8 <> '' THEN $8
                 ELSE payment_qr_payload
               END,
               payment_qr_fingerprint = CASE
                 WHEN $9 IS NOT NULL AND $9 <> '' THEN $9
                 ELSE payment_qr_fingerprint
               END,
               upi_id = CASE
                 WHEN $10 IS NOT NULL AND $10 <> '' THEN $10
                 ELSE upi_id
               END,
               avatar_url = COALESCE($11, avatar_url),
               map_url = COALESCE($12, map_url),
               is_open = COALESCE($13, is_open),
               updated_at = NOW()
           WHERE id = $1
           RETURNING id, seller_id, name, category, block, address, latitude, longitude,
             qr_code, qr_payload, payment_qr_payload, payment_qr_fingerprint, upi_id,
             avatar_url, map_url, is_open`,
          [
            shop.id,
            input.name ?? null,
            input.category ?? null,
            input.block ?? null,
            input.address ?? null,
            input.latitude ?? null,
            input.longitude ?? null,
            paymentQrPayload,
            paymentQrFingerprint,
            upiId,
            input.avatarUrl ?? null,
            input.mapUrl ?? null,
            input.isOpen ?? null,
          ],
        );

    res.json({ shop: result.rows[0] });
  } catch (error) {
    next(error);
  }
});

sellerRouter.get('/items', async (req, res, next) => {
  try {
    const shop = await getSellerShop(req.user.sub);
    if (!shop) {
      throw new HttpError(404, 'Seller shop not found');
    }

    const result = await query(
      `SELECT id, shop_id, name, price_cents, stock_qty, category, barcode,
        description, image_url, alert_threshold, alert_enabled,
        is_active, created_at, updated_at
       FROM shelf_items
       WHERE shop_id = $1
       ORDER BY created_at DESC`,
      [shop.id],
    );

    res.json({ items: result.rows });
  } catch (error) {
    next(error);
  }
});

sellerRouter.post('/items', async (req, res, next) => {
  try {
    const input = itemSchema.parse(req.body);
    const shop = await getSellerShop(req.user.sub);
    if (!shop) {
      throw new HttpError(404, 'Seller shop not found');
    }

    const result = await query(
      `INSERT INTO shelf_items (
        id, shop_id, name, price_cents, stock_qty, category, barcode,
        description, image_url, alert_threshold, alert_enabled, is_active
      )
      VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12)
      RETURNING id, shop_id, name, price_cents, stock_qty, category,
        barcode, description, image_url, alert_threshold, alert_enabled,
        is_active, created_at, updated_at`,
      [
        makeId('item'),
        shop.id,
        input.name,
        input.priceCents,
        input.stockQty,
        input.category ?? null,
        input.barcode ?? null,
        input.description ?? null,
        input.imageUrl ?? null,
        input.alertThreshold ?? 3,
        input.alertEnabled ?? true,
        input.isActive ?? true,
      ],
    );

    res.status(201).json({ item: result.rows[0] });
  } catch (error) {
    next(error);
  }
});

sellerRouter.patch('/items/:itemId', async (req, res, next) => {
  try {
    const input = itemUpdateSchema.parse(req.body);
    const item = await getSellerItem(req.user.sub, req.params.itemId);
    if (!item) {
      throw new HttpError(404, 'Shelf item not found');
    }

    const result = await query(
      `UPDATE shelf_items
       SET name = COALESCE($2, name),
           price_cents = COALESCE($3, price_cents),
           stock_qty = COALESCE($4, stock_qty),
           category = COALESCE($5, category),
           barcode = COALESCE($6, barcode),
           description = COALESCE($7, description),
           image_url = COALESCE($8, image_url),
           alert_threshold = COALESCE($9, alert_threshold),
           alert_enabled = COALESCE($10, alert_enabled),
           is_active = COALESCE($11, is_active),
           updated_at = NOW()
       WHERE id = $1
       RETURNING id, shop_id, name, price_cents, stock_qty, category,
         barcode, description, image_url, alert_threshold, alert_enabled, is_active,
         created_at, updated_at`,
      [
        item.id,
        input.name ?? null,
        input.priceCents ?? null,
        input.stockQty ?? null,
        input.category ?? null,
        input.barcode ?? null,
        input.description ?? null,
        input.imageUrl ?? null,
        input.alertThreshold ?? null,
        input.alertEnabled ?? null,
        input.isActive ?? null,
      ],
    );

    res.json({ item: result.rows[0] });
  } catch (error) {
    next(error);
  }
});

sellerRouter.delete('/items/:itemId', async (req, res, next) => {
  try {
    const item = await getSellerItem(req.user.sub, req.params.itemId);
    if (!item) {
      throw new HttpError(404, 'Shelf item not found');
    }

    await query('DELETE FROM shelf_items WHERE id = $1', [item.id]);
    res.status(204).send();
  } catch (error) {
    next(error);
  }
});

function mapSellerPromotion(row) {
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
    item: {
      id: row.item_id,
      name: row.item_name,
      imageUrl: row.item_image_url?.startsWith('blob:')
        ? null
        : row.item_image_url,
      priceCents: row.price_cents ?? 0,
    },
  };
}

async function notifyAdmins(actorUserId, type, title, body) {
  const admins = await query(
    `SELECT id
     FROM app_users
     WHERE role = 'admin' AND deleted_at IS NULL`,
  );
  for (const admin of admins.rows) {
    await query(
      `INSERT INTO notifications (
        id, recipient_user_id, actor_user_id, type, title, body
      )
      VALUES ($1, $2, $3, $4, $5, $6)`,
      [makeId('notif'), admin.id, actorUserId, type, title, body],
    );
  }
}
