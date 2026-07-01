import express from 'express';
import { z } from 'zod';
import { query, withTransaction } from '../db/pool.js';
import { optionalAuth, requireAuth } from '../middleware/auth.js';
import { publishToRole, publishToUser } from '../realtime/socketHub.js';
import { HttpError } from '../utils/httpError.js';
import { makeId } from '../utils/ids.js';

export const discoveryRouter = express.Router();

const PUBLIC_DEMO_PRODUCT_FILTER_SQL = `
       AND LOWER(TRIM(si.name)) NOT IN ('gateway test item', 'test gateway item')
       AND LOWER(TRIM(s.name)) NOT LIKE 'mock gateway%'`;

const PUBLIC_DEMO_SHOP_FILTER_SQL = `
       AND LOWER(TRIM(s.name)) NOT LIKE 'mock gateway%'`;

const PUBLIC_DEMO_SHOP_FILTER_UNALIASED_SQL = `
       AND LOWER(TRIM(name)) NOT LIKE 'mock gateway%'`;

const searchSchema = z.object({
  q: z.string().trim().max(120).optional(),
  limit: z.coerce.number().int().min(1).max(80).default(40),
});

const reviewSchema = z.object({
  rating: z.number().int().min(1).max(5).default(5),
  comment: z.string().trim().min(2).max(1200),
});

const savedGroupItemSchema = z.object({
  shelfItemId: z.string().trim().min(1),
  quantity: z.number().int().min(1).max(99),
});

const savedGroupSchema = z.object({
  name: z.string().trim().min(1).max(80),
  shopId: z.string().trim().min(1).optional(),
  shopName: z.string().trim().min(1).max(120),
  items: z.array(savedGroupItemSchema).min(1).max(120),
});

const savedGroupUpdateSchema = z.object({
  name: z.string().trim().min(1).max(80).optional(),
  shopName: z.string().trim().min(1).max(120).optional(),
  items: z.array(savedGroupItemSchema).min(1).max(120).optional(),
});

function publicProductQuery({
  whereSql = '',
  values = [],
  limit = 40,
  currentUserId = null,
  extraJoinSql = '',
  promotionSelectSql = 'NULL::TEXT AS promotion_id',
  orderSql = 'si.updated_at DESC, si.created_at DESC',
} = {}) {
  const currentUserParam = values.length + 1;
  const limitParam = values.length + 2;
  return query(
    `SELECT
       si.id,
       ${promotionSelectSql},
       si.shop_id,
       si.name,
       si.price_cents,
       si.stock_qty,
       si.category,
       si.description,
       si.image_url,
       si.updated_at,
       s.name AS shop_name,
       s.category AS shop_category,
       s.block,
       s.address,
       s.latitude,
       s.longitude,
       s.payment_qr_payload,
       s.upi_id,
       seller.phone AS seller_phone,
       s.avatar_url,
       s.map_url,
       s.is_open,
       (SELECT COUNT(*)::INT
        FROM shop_followers sf
        WHERE sf.shop_id = s.id) AS follower_count,
       EXISTS(
        SELECT 1
        FROM shop_followers sf
        WHERE sf.shop_id = s.id AND sf.user_id = $${currentUserParam}
       ) AS is_following,
       EXISTS(
        SELECT 1
        FROM saved_products sp
        WHERE sp.shelf_item_id = si.id AND sp.user_id = $${currentUserParam}
       ) AS is_saved,
       (SELECT ROUND(AVG(pr.rating)::NUMERIC, 1)::FLOAT
        FROM product_reviews pr
        INNER JOIN shelf_items review_item ON review_item.id = pr.shelf_item_id
        WHERE review_item.shop_id = s.id) AS shop_rating
     FROM shelf_items si
     INNER JOIN shops s ON s.id = si.shop_id
     INNER JOIN app_users seller ON seller.id = s.seller_id
     ${extraJoinSql}
     WHERE si.is_active = TRUE
       ${PUBLIC_DEMO_PRODUCT_FILTER_SQL}
       ${whereSql}
     ORDER BY ${orderSql}
     LIMIT $${limitParam}`,
    [...values, currentUserId, limit],
  );
}

function mapProduct(row) {
  const imageUrl = row.image_url?.startsWith('blob:') ? null : row.image_url;
  const avatarUrl = row.avatar_url?.startsWith('blob:') ? null : row.avatar_url;

  return {
    id: row.id,
    promotionId: row.promotion_id,
    shopId: row.shop_id,
    name: row.name,
    priceCents: row.price_cents,
    stockQty: row.stock_qty,
    category: row.category,
    description: row.description,
    imageUrl,
    updatedAt: row.updated_at,
    isSaved: row.is_saved ?? false,
    shop: {
      id: row.shop_id,
      name: row.shop_name,
      category: row.shop_category,
      block: row.block,
      address: row.address,
      latitude: row.latitude,
      longitude: row.longitude,
      paymentQrPayload: row.payment_qr_payload,
      upiId: row.upi_id,
      phone: row.seller_phone,
      avatarUrl,
      mapUrl: row.map_url,
      followerCount: row.follower_count ?? 0,
      rating: row.shop_rating ?? 0,
      isFollowing: row.is_following ?? false,
      isOpen: row.is_open,
    },
  };
}

function mapShopRow(row) {
  return {
    id: row.id,
    sellerId: row.seller_id,
    name: row.name,
    category: row.category,
    block: row.block,
    address: row.address,
    latitude: row.latitude,
    longitude: row.longitude,
    paymentQrPayload: row.payment_qr_payload,
    upiId: row.upi_id,
    phone: row.seller_phone,
    avatarUrl: row.avatar_url?.startsWith('blob:') ? null : row.avatar_url,
    mapUrl: row.map_url,
    items: row.items ?? [],
    isOpen: row.is_open,
    followerCount: row.follower_count ?? 0,
    isFollowing: row.is_following ?? false,
    rating: row.rating ?? 0,
  };
}

function mapSavedGroups(rows) {
  const groupsById = new Map();
  for (const row of rows) {
    if (!groupsById.has(row.group_id)) {
      groupsById.set(row.group_id, {
        id: row.group_id,
        name: row.group_name,
        shopId: row.group_shop_id,
        shopName: row.group_shop_name,
        createdAt: row.group_created_at,
        updatedAt: row.group_updated_at,
        items: {},
        products: [],
      });
    }
    const group = groupsById.get(row.group_id);
    if (!row.product_id) continue;
    group.items[row.product_id] = row.quantity;
    group.products.push(
      mapProduct({
        id: row.product_id,
        shop_id: row.shop_id,
        name: row.product_name,
        price_cents: row.price_cents,
        stock_qty: row.stock_qty,
        category: row.category,
        description: row.description,
        image_url: row.image_url,
        updated_at: row.product_updated_at,
        shop_name: row.shop_name,
        shop_category: row.shop_category,
        block: row.block,
        address: row.address,
        latitude: row.latitude,
        longitude: row.longitude,
        payment_qr_payload: row.payment_qr_payload,
        upi_id: row.upi_id,
        avatar_url: row.avatar_url,
        map_url: row.map_url,
        is_open: row.is_open,
        follower_count: row.follower_count,
        is_following: row.is_following,
        shop_rating: row.shop_rating,
      }),
    );
  }
  return [...groupsById.values()];
}

async function getSavedGroups(userId, groupId = null) {
  const values = [userId];
  let groupFilter = '';
  if (groupId) {
    values.push(groupId);
    groupFilter = `AND sg.id = $2`;
  }

  const result = await query(
    `SELECT
       sg.id AS group_id,
       sg.name AS group_name,
       sg.shop_id AS group_shop_id,
       sg.shop_name AS group_shop_name,
       sg.created_at AS group_created_at,
       sg.updated_at AS group_updated_at,
       sgi.quantity,
       si.id AS product_id,
       si.shop_id,
       si.name AS product_name,
       si.price_cents,
       si.stock_qty,
       si.category,
       si.description,
       si.image_url,
       si.updated_at AS product_updated_at,
       s.name AS shop_name,
       s.category AS shop_category,
       s.block,
       s.address,
       s.latitude,
       s.longitude,
       s.payment_qr_payload,
       s.upi_id,
       s.avatar_url,
       s.map_url,
       s.is_open,
       (SELECT COUNT(*)::INT
        FROM shop_followers sf
        WHERE sf.shop_id = s.id) AS follower_count,
       EXISTS(
        SELECT 1
         FROM shop_followers sf
         WHERE sf.shop_id = s.id AND sf.user_id = $1
         ) AS is_following,
         TRUE AS is_saved,
         (SELECT ROUND(AVG(pr.rating)::NUMERIC, 1)::FLOAT
        FROM product_reviews pr
        INNER JOIN shelf_items review_item ON review_item.id = pr.shelf_item_id
        WHERE review_item.shop_id = s.id) AS shop_rating
     FROM saved_groups sg
     LEFT JOIN saved_group_items sgi ON sgi.group_id = sg.id
     LEFT JOIN shelf_items si ON si.id = sgi.shelf_item_id AND si.is_active = TRUE
     LEFT JOIN shops s ON s.id = si.shop_id
     LEFT JOIN app_users seller ON seller.id = s.seller_id
     WHERE sg.user_id = $1
       ${groupFilter}
       AND (
        si.id IS NULL
        OR s.is_open = TRUE
       )
     ORDER BY sg.created_at DESC, si.name ASC`,
    values,
  );
  return mapSavedGroups(result.rows);
}

function mergeSavedGroupItems(items) {
  const merged = new Map();
  for (const item of items) {
    const current = merged.get(item.shelfItemId) ?? 0;
    merged.set(item.shelfItemId, Math.min(current + item.quantity, 99));
  }
  return [...merged.entries()].map(([shelfItemId, quantity]) => ({
    shelfItemId,
    quantity,
  }));
}

async function incrementPromotionImpressions(promotionIds) {
  const uniqueIds = [...new Set(promotionIds)];
  if (uniqueIds.length === 0) return;
  const result = await query(
    `UPDATE product_promotions
     SET impressions = impressions + 1,
         updated_at = NOW()
     WHERE id = ANY($1::TEXT[])
     RETURNING id, impressions, clicks`,
    [uniqueIds],
  );
  for (const row of result.rows) {
    publishToRole('admin', 'promotion.metrics', {
      promotionId: row.id,
      impressions: row.impressions,
      clicks: row.clicks,
    });
  }
}

discoveryRouter.get('/home', optionalAuth, async (req, res, next) => {
  try {
    const input = searchSchema.parse(req.query);
    const result = await publicProductQuery({
      limit: input.limit,
      currentUserId: req.user?.sub ?? null,
    });
    const products = result.rows.map(mapProduct);
    const promotedResult = await publicProductQuery({
      promotionSelectSql: 'p.id AS promotion_id',
      extraJoinSql: `INNER JOIN product_promotions p
        ON p.shelf_item_id = si.id AND p.shop_id = s.id`,
      whereSql: `AND p.status = 'approved'
        AND (p.starts_at IS NULL OR p.starts_at <= NOW())
        AND (p.ends_at IS NULL OR p.ends_at >= NOW())`,
      orderSql: `COALESCE(p.starts_at, p.updated_at, p.created_at) DESC,
        p.created_at DESC`,
      limit: 6,
      currentUserId: req.user?.sub ?? null,
    });
    await incrementPromotionImpressions(
      promotedResult.rows.map((row) => row.promotion_id).filter(Boolean),
    );
    const promoted = promotedResult.rows.map(mapProduct);
    const seenProductIds = new Set();
    const mergedProducts = [...promoted, ...products].filter((product) => {
      if (seenProductIds.has(product.id)) return false;
      seenProductIds.add(product.id);
      return true;
    });

    res.json({
      featured: promoted.length ? promoted : mergedProducts.slice(0, 6),
      products: mergedProducts,
    });
  } catch (error) {
    next(error);
  }
});

discoveryRouter.post('/promotions/:promotionId/click', optionalAuth, async (req, res, next) => {
  try {
    const result = await query(
      `UPDATE product_promotions
       SET clicks = clicks + 1,
           updated_at = NOW()
       WHERE id = $1
         AND status = 'approved'
         AND (starts_at IS NULL OR starts_at <= NOW())
         AND (ends_at IS NULL OR ends_at >= NOW())
       RETURNING id, impressions, clicks`,
      [req.params.promotionId],
    );
    if (!result.rows[0]) throw new HttpError(404, 'Active promotion not found');
    publishToRole('admin', 'promotion.metrics', {
      promotionId: result.rows[0].id,
      impressions: result.rows[0].impressions,
      clicks: result.rows[0].clicks,
    });
    res.json({ promotion: result.rows[0] });
  } catch (error) {
    next(error);
  }
});

discoveryRouter.get('/search', optionalAuth, async (req, res, next) => {
  try {
    const input = searchSchema.parse(req.query);
    const text = input.q ?? '';
    await logSearch(req.user?.sub, text, 'product_search');

    if (!text) {
      const result = await publicProductQuery({
        limit: input.limit,
        currentUserId: req.user?.sub ?? null,
      });
      return res.json({ products: result.rows.map(mapProduct) });
    }

    const search = `%${text.toLowerCase()}%`;
    const result = await publicProductQuery({
      whereSql: `AND (
        LOWER(si.name) LIKE $1
        OR LOWER(COALESCE(si.category, '')) LIKE $1
        OR LOWER(COALESCE(si.description, '')) LIKE $1
        OR LOWER(s.name) LIKE $1
        OR LOWER(COALESCE(s.category, '')) LIKE $1
        OR LOWER(COALESCE(s.block, '')) LIKE $1
        OR LOWER(COALESCE(s.address, '')) LIKE $1
        OR LOWER(COALESCE(s.upi_id, '')) LIKE $1
        OR LOWER(COALESCE(s.id, '')) LIKE $1
      )`,
      values: [search],
      limit: input.limit,
      currentUserId: req.user?.sub ?? null,
    });

    res.json({ products: result.rows.map(mapProduct) });
  } catch (error) {
    next(error);
  }
});

discoveryRouter.get('/shops', optionalAuth, async (req, res, next) => {
  try {
    const input = searchSchema.parse(req.query);
    const text = input.q ?? '';
    await logSearch(req.user?.sub, text, 'shop_search');
    const values = [req.user?.sub ?? null, input.limit];
    let filterSql = '';

    if (text) {
      values.push(`%${text.toLowerCase()}%`);
      filterSql = `AND (
        LOWER(s.name) LIKE $3
        OR LOWER(COALESCE(s.category, '')) LIKE $3
        OR LOWER(COALESCE(s.block, '')) LIKE $3
        OR LOWER(COALESCE(s.address, '')) LIKE $3
        OR LOWER(COALESCE(s.upi_id, '')) LIKE $3
        OR LOWER(COALESCE(s.id, '')) LIKE $3
        OR LOWER(COALESCE(seller.email, '')) LIKE $3
        OR LOWER(COALESCE(seller.phone, '')) LIKE $3
        OR EXISTS (
          SELECT 1
          FROM shelf_items search_item
          WHERE search_item.shop_id = s.id
            AND search_item.is_active = TRUE
            AND (
              LOWER(search_item.name) LIKE $3
              OR LOWER(COALESCE(search_item.category, '')) LIKE $3
              OR LOWER(COALESCE(search_item.barcode, '')) LIKE $3
            )
        )
      )`;
    }

    const result = await query(
      `SELECT
         s.id,
         s.seller_id,
         s.name,
         s.category,
         s.block,
         s.address,
         s.latitude,
         s.longitude,
         s.payment_qr_payload,
         s.upi_id,
         seller.phone AS seller_phone,
         s.avatar_url,
         s.map_url,
         s.is_open,
         (SELECT COUNT(*)::INT
          FROM shop_followers sf
          WHERE sf.shop_id = s.id) AS follower_count,
       EXISTS(
        SELECT 1
        FROM shop_followers sf
        WHERE sf.shop_id = s.id AND sf.user_id = $1
       ) AS is_following,
       FALSE AS is_saved,
       (SELECT ROUND(AVG(pr.rating)::NUMERIC, 1)::FLOAT
          FROM product_reviews pr
          INNER JOIN shelf_items review_item ON review_item.id = pr.shelf_item_id
          WHERE review_item.shop_id = s.id) AS rating,
       (SELECT COALESCE(
          json_agg(
            json_build_object(
              'id', item.id,
              'name', item.name,
              'category', item.category,
              'barcode', item.barcode,
              'stockQty', item.stock_qty,
              'priceCents', item.price_cents
            )
            ORDER BY item.updated_at DESC
          ),
          '[]'::json
        )
        FROM shelf_items item
        WHERE item.shop_id = s.id
          AND item.is_active = TRUE) AS items
       FROM shops s
       INNER JOIN app_users seller ON seller.id = s.seller_id
       WHERE s.is_open = TRUE
         ${PUBLIC_DEMO_SHOP_FILTER_SQL}
         ${filterSql}
       ORDER BY s.updated_at DESC, s.created_at DESC
       LIMIT $2`,
      values,
    );

    res.json({ shops: result.rows.map(mapShopRow) });
  } catch (error) {
    next(error);
  }
});

discoveryRouter.get('/shops/:shopId', optionalAuth, async (req, res, next) => {
  try {
    const shop = await getPublicShop(req.params.shopId, req.user?.sub ?? null);
    if (!shop) {
      throw new HttpError(404, 'Shop not found');
    }
    res.json({ shop });
  } catch (error) {
    next(error);
  }
});

discoveryRouter.post('/shops/:shopId/follow', requireAuth, async (req, res, next) => {
  try {
    const output = await withTransaction(async (client) => {
      const shopResult = await client.query(
        `SELECT id, seller_id, name
         FROM shops
         WHERE id = $1 AND is_open = TRUE
         ${PUBLIC_DEMO_SHOP_FILTER_UNALIASED_SQL}`,
        [req.params.shopId],
      );

      if (shopResult.rows.length === 0) {
        throw new HttpError(404, 'Shop not found');
      }

      const shop = shopResult.rows[0];
      const followResult = await client.query(
        `INSERT INTO shop_followers (shop_id, user_id)
         VALUES ($1, $2)
         ON CONFLICT DO NOTHING
         RETURNING shop_id`,
        [shop.id, req.user.sub],
      );

      let notification = null;
      if (followResult.rowCount > 0 && shop.seller_id !== req.user.sub) {
        const notificationId = makeId('notif');
        await client.query(
          `INSERT INTO notifications (
            id, recipient_user_id, actor_user_id, shop_id, type, title, body
          )
          VALUES ($1, $2, $3, $4, 'shop_followed', $5, $6)`,
          [
            notificationId,
            shop.seller_id,
            req.user.sub,
            shop.id,
            'New follower',
            `${req.user.name ?? 'A neighbor'} followed ${shop.name}.`,
          ],
        );
        notification = {
          type: 'shop_followed',
          title: 'New follower',
          body: `${req.user.name ?? 'A neighbor'} followed ${shop.name}.`,
          shopId: shop.id,
          shopName: shop.name,
          actorName: req.user.name ?? 'A neighbor',
          id: notificationId,
        };
      }

      return {
        shop: await getPublicShop(shop.id, req.user.sub, client),
        sellerId: shop.seller_id,
        notification,
      };
    });

    if (output.notification) {
      publishToUser(output.sellerId, 'notification.created', output.notification);
    }
    publishToUser(output.sellerId, 'shop.followers.updated', {
      shopId: output.shop.id,
      followerCount: output.shop.followerCount,
      isFollowing: output.shop.isFollowing,
    });

    res.status(201).json({ shop: output.shop });
  } catch (error) {
    next(error);
  }
});

discoveryRouter.delete('/shops/:shopId/follow', requireAuth, async (req, res, next) => {
  try {
    const shopResult = await query(
      `SELECT id, seller_id
       FROM shops
       WHERE id = $1 AND is_open = TRUE
       ${PUBLIC_DEMO_SHOP_FILTER_UNALIASED_SQL}`,
      [req.params.shopId],
    );
    const sellerId = shopResult.rows[0]?.seller_id;

    await query(
      `DELETE FROM shop_followers
       WHERE shop_id = $1 AND user_id = $2`,
      [req.params.shopId, req.user.sub],
    );

    const shop = await getPublicShop(req.params.shopId, req.user.sub);
    if (!shop) {
      throw new HttpError(404, 'Shop not found');
    }
    if (sellerId) {
      publishToUser(sellerId, 'shop.followers.updated', {
        shopId: shop.id,
        followerCount: shop.followerCount,
        isFollowing: shop.isFollowing,
      });
    }
    res.json({ shop });
  } catch (error) {
    next(error);
  }
});

discoveryRouter.get('/saved/products', requireAuth, async (req, res, next) => {
  try {
    const result = await query(
      `SELECT
         si.id,
         si.shop_id,
         si.name,
         si.price_cents,
         si.stock_qty,
         si.category,
         si.description,
         si.image_url,
         si.updated_at,
         s.name AS shop_name,
         s.category AS shop_category,
         s.block,
         s.address,
         s.latitude,
         s.longitude,
         s.payment_qr_payload,
         s.upi_id,
         s.avatar_url,
         s.map_url,
         s.is_open,
         (SELECT COUNT(*)::INT
          FROM shop_followers sf
          WHERE sf.shop_id = s.id) AS follower_count,
         EXISTS(
          SELECT 1
          FROM shop_followers sf
          WHERE sf.shop_id = s.id AND sf.user_id = $1
         ) AS is_following,
         (SELECT ROUND(AVG(pr.rating)::NUMERIC, 1)::FLOAT
          FROM product_reviews pr
          INNER JOIN shelf_items review_item ON review_item.id = pr.shelf_item_id
          WHERE review_item.shop_id = s.id) AS shop_rating
       FROM saved_products saved
       INNER JOIN shelf_items si ON si.id = saved.shelf_item_id
       INNER JOIN shops s ON s.id = si.shop_id
       INNER JOIN app_users seller ON seller.id = s.seller_id
       WHERE saved.user_id = $1
         AND si.is_active = TRUE
         AND s.is_open = TRUE
         ${PUBLIC_DEMO_PRODUCT_FILTER_SQL}
       ORDER BY saved.created_at DESC`,
      [req.user.sub],
    );

    res.json({ products: result.rows.map(mapProduct) });
  } catch (error) {
    next(error);
  }
});

discoveryRouter.post('/products/:productId/save', requireAuth, async (req, res, next) => {
  try {
    const product = await publicProductQuery({
      whereSql: 'AND si.id = $1',
      values: [req.params.productId],
      limit: 1,
      currentUserId: req.user.sub,
    });
    if (product.rows.length === 0) {
      throw new HttpError(404, 'Product not found');
    }

    await query(
      `INSERT INTO saved_products (user_id, shelf_item_id)
       VALUES ($1, $2)
       ON CONFLICT (user_id, shelf_item_id)
       DO UPDATE SET created_at = NOW()`,
      [req.user.sub, req.params.productId],
    );

    res.status(201).json({ product: mapProduct(product.rows[0]) });
  } catch (error) {
    next(error);
  }
});

discoveryRouter.delete('/products/:productId/save', requireAuth, async (req, res, next) => {
  try {
    await query(
      `DELETE FROM saved_products
       WHERE user_id = $1 AND shelf_item_id = $2`,
      [req.user.sub, req.params.productId],
    );
    res.status(204).end();
  } catch (error) {
    next(error);
  }
});

discoveryRouter.get('/saved/groups', requireAuth, async (req, res, next) => {
  try {
    res.json({ groups: await getSavedGroups(req.user.sub) });
  } catch (error) {
    next(error);
  }
});

discoveryRouter.post('/saved/groups', requireAuth, async (req, res, next) => {
  try {
    const input = savedGroupSchema.parse(req.body);
    const items = mergeSavedGroupItems(input.items);
    const groupId = makeId('grp');

    await withTransaction(async (client) => {
      const itemIds = items.map((item) => item.shelfItemId);
      const productResult = await client.query(
        `SELECT si.id, si.shop_id, s.name AS shop_name
         FROM shelf_items si
         INNER JOIN shops s ON s.id = si.shop_id
         INNER JOIN app_users seller ON seller.id = s.seller_id
          WHERE si.id = ANY($1::TEXT[])
            AND si.is_active = TRUE
            AND s.is_open = TRUE
            ${PUBLIC_DEMO_PRODUCT_FILTER_SQL}`,
        [itemIds],
      );
      if (productResult.rows.length !== itemIds.length) {
        throw new HttpError(400, 'One saved group item is no longer available');
      }

      const productShopIds = new Set(productResult.rows.map((row) => row.shop_id));
      const resolvedShopId = input.shopId ?? productResult.rows[0]?.shop_id ?? null;
      const resolvedShopName = input.shopName || productResult.rows[0]?.shop_name || 'Saved shop';
      if (productShopIds.size > 1) {
        throw new HttpError(400, 'A saved group can only contain one shop shelf');
      }

      await client.query(
        `INSERT INTO saved_groups (id, user_id, name, shop_id, shop_name)
         VALUES ($1, $2, $3, $4, $5)`,
        [groupId, req.user.sub, input.name, resolvedShopId, resolvedShopName],
      );
      for (const item of items) {
        await client.query(
          `INSERT INTO saved_group_items (group_id, shelf_item_id, quantity)
           VALUES ($1, $2, $3)`,
          [groupId, item.shelfItemId, item.quantity],
        );
      }
    });

    const groups = await getSavedGroups(req.user.sub, groupId);
    res.status(201).json({ group: groups[0] });
  } catch (error) {
    next(error);
  }
});

discoveryRouter.patch('/saved/groups/:groupId', requireAuth, async (req, res, next) => {
  try {
    const input = savedGroupUpdateSchema.parse(req.body);
    const groupId = req.params.groupId;

    await withTransaction(async (client) => {
      const groupResult = await client.query(
        `SELECT id
         FROM saved_groups
         WHERE id = $1 AND user_id = $2
         FOR UPDATE`,
        [groupId, req.user.sub],
      );
      if (groupResult.rows.length === 0) {
        throw new HttpError(404, 'Saved group not found');
      }

      if (input.name || input.shopName) {
        await client.query(
          `UPDATE saved_groups
           SET name = COALESCE($3, name),
               shop_name = COALESCE($4, shop_name),
               updated_at = NOW()
           WHERE id = $1 AND user_id = $2`,
          [groupId, req.user.sub, input.name ?? null, input.shopName ?? null],
        );
      }

      if (input.items) {
        const items = mergeSavedGroupItems(input.items);
        const itemIds = items.map((item) => item.shelfItemId);
        const productResult = await client.query(
          `SELECT si.id, si.shop_id, s.name AS shop_name
           FROM shelf_items si
           INNER JOIN shops s ON s.id = si.shop_id
           INNER JOIN app_users seller ON seller.id = s.seller_id
            WHERE si.id = ANY($1::TEXT[])
              AND si.is_active = TRUE
              AND s.is_open = TRUE
              ${PUBLIC_DEMO_PRODUCT_FILTER_SQL}`,
          [itemIds],
        );
        if (productResult.rows.length !== itemIds.length) {
          throw new HttpError(400, 'One saved group item is no longer available');
        }
        const productShopIds = new Set(productResult.rows.map((row) => row.shop_id));
        if (productShopIds.size > 1) {
          throw new HttpError(400, 'A saved group can only contain one shop shelf');
        }

        await client.query(`DELETE FROM saved_group_items WHERE group_id = $1`, [groupId]);
        for (const item of items) {
          await client.query(
            `INSERT INTO saved_group_items (group_id, shelf_item_id, quantity)
             VALUES ($1, $2, $3)`,
            [groupId, item.shelfItemId, item.quantity],
          );
        }
        await client.query(
          `UPDATE saved_groups
           SET shop_id = $2,
               shop_name = COALESCE($3, shop_name),
               updated_at = NOW()
           WHERE id = $1`,
          [
            groupId,
            productResult.rows[0]?.shop_id ?? null,
            input.shopName ?? productResult.rows[0]?.shop_name ?? null,
          ],
        );
      }
    });

    const groups = await getSavedGroups(req.user.sub, groupId);
    res.json({ group: groups[0] });
  } catch (error) {
    next(error);
  }
});

discoveryRouter.delete('/saved/groups/:groupId', requireAuth, async (req, res, next) => {
  try {
    await query(
      `DELETE FROM saved_groups
       WHERE id = $1 AND user_id = $2`,
      [req.params.groupId, req.user.sub],
    );
    res.status(204).end();
  } catch (error) {
    next(error);
  }
});

discoveryRouter.get('/products/:productId/reviews', async (req, res, next) => {
  try {
    const reviews = await getReviews(req.params.productId);
    res.json(buildReviewPayload(reviews));
  } catch (error) {
    next(error);
  }
});

discoveryRouter.post('/products/:productId/reviews', requireAuth, async (req, res, next) => {
  try {
    const input = reviewSchema.parse(req.body);
    const item = await query(
      `SELECT si.id, si.name, s.id AS shop_id, s.name AS shop_name, s.seller_id
       FROM shelf_items si
       INNER JOIN shops s ON s.id = si.shop_id
       WHERE si.id = $1 AND si.is_active = TRUE AND s.is_open = TRUE
       ${PUBLIC_DEMO_PRODUCT_FILTER_SQL}`,
      [req.params.productId],
    );

    if (item.rows.length === 0) {
      throw new HttpError(404, 'Product not found');
    }

    await query(
      `INSERT INTO product_reviews (id, shelf_item_id, user_id, rating, comment)
       VALUES ($1, $2, $3, $4, $5)`,
      [makeId('review'), req.params.productId, req.user.sub, input.rating, input.comment],
    );

    const reviewedItem = item.rows[0];
    if (reviewedItem.seller_id !== req.user.sub) {
      const notificationId = makeId('notif');
      const body = `${req.user.name ?? 'A neighbor'} rated ${reviewedItem.name} ${input.rating}/5.`;
      await query(
        `INSERT INTO notifications (
          id, recipient_user_id, actor_user_id, shop_id, type, title, body
        )
        VALUES ($1, $2, $3, $4, 'product_reviewed', 'New product review', $5)`,
        [
          notificationId,
          reviewedItem.seller_id,
          req.user.sub,
          reviewedItem.shop_id,
          body,
        ],
      );
      publishToUser(reviewedItem.seller_id, 'notification.created', {
        id: notificationId,
        type: 'product_reviewed',
        title: 'New product review',
        body,
        shopId: reviewedItem.shop_id,
        shopName: reviewedItem.shop_name,
        actorName: req.user.name ?? 'A neighbor',
      });
    }

    const reviews = await getReviews(req.params.productId);
    res.status(201).json(buildReviewPayload(reviews));
  } catch (error) {
    next(error);
  }
});

discoveryRouter.delete('/products/:productId/reviews/:reviewId', requireAuth, async (req, res, next) => {
  try {
    const result = await query(
      `DELETE FROM product_reviews
       WHERE id = $1
         AND shelf_item_id = $2
         AND user_id = $3
       RETURNING id`,
      [req.params.reviewId, req.params.productId, req.user.sub],
    );

    if (result.rows.length === 0) {
      throw new HttpError(404, 'Review not found');
    }

    const reviews = await getReviews(req.params.productId);
    res.json(buildReviewPayload(reviews));
  } catch (error) {
    next(error);
  }
});

async function getReviews(productId) {
  const result = await query(
    `SELECT pr.id, pr.rating, pr.comment, pr.created_at,
       au.id AS user_id, au.name AS user_name
     FROM product_reviews pr
     INNER JOIN app_users au ON au.id = pr.user_id
     WHERE pr.shelf_item_id = $1
     ORDER BY pr.created_at DESC`,
    [productId],
  );
  return result.rows;
}

async function getPublicShop(shopId, currentUserId = null, client = { query }) {
  const result = await client.query(
    `SELECT
       s.id,
       s.name,
       s.category,
       s.block,
       s.address,
       s.latitude,
       s.longitude,
       s.payment_qr_payload,
       s.upi_id,
       seller.phone AS seller_phone,
       s.avatar_url,
       s.map_url,
       s.is_open,
       (SELECT COUNT(*)::INT
        FROM shop_followers sf
        WHERE sf.shop_id = s.id) AS follower_count,
       EXISTS(
        SELECT 1
        FROM shop_followers sf
        WHERE sf.shop_id = s.id AND sf.user_id = $2
       ) AS is_following,
       (SELECT ROUND(AVG(pr.rating)::NUMERIC, 1)::FLOAT
        FROM product_reviews pr
        INNER JOIN shelf_items review_item ON review_item.id = pr.shelf_item_id
        WHERE review_item.shop_id = s.id) AS rating
     FROM shops s
     INNER JOIN app_users seller ON seller.id = s.seller_id
     WHERE s.id = $1
       AND s.is_open = TRUE
       ${PUBLIC_DEMO_SHOP_FILTER_SQL}`,
    [shopId, currentUserId],
  );

  if (result.rows.length === 0) return null;
  const row = result.rows[0];
  return {
    id: row.id,
    name: row.name,
    category: row.category,
    block: row.block,
    address: row.address,
    latitude: row.latitude,
    longitude: row.longitude,
    paymentQrPayload: row.payment_qr_payload,
    upiId: row.upi_id,
    phone: row.seller_phone,
    avatarUrl: row.avatar_url?.startsWith('blob:') ? null : row.avatar_url,
    mapUrl: row.map_url,
    isOpen: row.is_open,
    followerCount: row.follower_count ?? 0,
    isFollowing: row.is_following ?? false,
    rating: row.rating ?? 0,
  };
}

function buildReviewPayload(rows) {
  const averageRating = rows.length === 0
    ? 0
    : rows.reduce((sum, row) => sum + row.rating, 0) / rows.length;

  return {
    summary: {
      count: rows.length,
      averageRating: Number(averageRating.toFixed(1)),
    },
    reviews: rows.map((row) => ({
      id: row.id,
      rating: row.rating,
      comment: row.comment,
      userId: row.user_id,
      userName: row.user_name,
      createdAt: row.created_at,
    })),
  };
}

async function logSearch(userId, text, surface) {
  const queryText = text?.trim();
  if (!userId || !queryText) return;
  await query(
    `INSERT INTO search_logs (id, user_id, query_text, surface)
     VALUES ($1, $2, $3, $4)`,
    [makeId('search'), userId, queryText.slice(0, 240), surface],
  );
}
