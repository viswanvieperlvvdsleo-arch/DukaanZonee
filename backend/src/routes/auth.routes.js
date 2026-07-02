import bcrypt from 'bcryptjs';
import express from 'express';
import jwt from 'jsonwebtoken';
import { z } from 'zod';
import { config } from '../config.js';
import { query, withTransaction } from '../db/pool.js';
import { requireAuth } from '../middleware/auth.js';
import { HttpError } from '../utils/httpError.js';
import {
  buildUpiQrPayload,
  extractUpiId,
  makeId,
  makeQrFingerprint,
  normalizeQrPayload,
} from '../utils/ids.js';

export const authRouter = express.Router();

const registerUserSchema = z.object({
  name: z.string().trim().min(2).max(120),
  email: z.string().trim().email().max(180).transform((value) => value.toLowerCase()),
  phone: z.string().trim().max(30).optional(),
  password: z.string().min(8).max(200),
});

const registerSellerSchema = registerUserSchema
  .extend({
    shopName: z.string().trim().min(2).max(160),
    category: z.string().trim().max(80).optional(),
    block: z.string().trim().max(80).optional(),
    address: z.string().trim().max(240).optional(),
    latitude: z.number().min(-90).max(90).optional(),
    longitude: z.number().min(-180).max(180).optional(),
    mapUrl: z.string().trim().max(1200).optional(),
    paymentQrPayload: z.string().trim().max(2000).optional(),
    upiId: z.string().trim().max(120).optional(),
  })
  .superRefine((value, ctx) => {
    if (!value.paymentQrPayload?.trim() && !value.upiId?.trim()) {
      ctx.addIssue({
        code: z.ZodIssueCode.custom,
        path: ['paymentQrPayload'],
        message: 'Add a payment QR or enter a UPI ID',
      });
    }
  });

const loginSchema = z.object({
  email: z.string().trim().email().transform((value) => value.toLowerCase()),
  password: z.string().min(1),
  role: z.enum(['user', 'seller', 'admin']).optional(),
});

const updateProfileSchema = z.object({
  name: z.string().trim().min(2).max(120).optional(),
  phone: z.string().trim().max(30).optional(),
  profilePic: z.string().trim().max(1_000_000).optional(),
});

function signToken(user) {
  return jwt.sign(
    { sub: user.id, role: user.role, email: user.email, name: user.name },
    config.jwtSecret,
    { expiresIn: config.jwtExpiresIn },
  );
}

function publicUser(row) {
  return {
    id: row.id,
    role: row.role,
    name: row.name,
    email: row.email,
    phone: row.phone,
    profilePic: row.profile_pic,
  };
}

authRouter.post('/register/user', async (req, res, next) => {
  try {
    const input = registerUserSchema.parse(req.body);
    const passwordHash = await bcrypt.hash(input.password, 12);
    const id = makeId('user');

    const result = await withTransaction(async (client) => {
      await releaseDeletedEmail(client, input.email);
      return client.query(
        `INSERT INTO app_users (id, role, name, email, phone, password_hash)
         VALUES ($1, 'user', $2, $3, $4, $5)
         RETURNING id, role, name, email, phone`,
        [id, input.name, input.email, input.phone ?? null, passwordHash],
      );
    });

    const user = result.rows[0];
    res.status(201).json({ user: publicUser(user), token: signToken(user) });
  } catch (error) {
    if (error.code === '23505') {
      return next(new HttpError(409, 'Email already registered'));
    }
    return next(error);
  }
});

authRouter.post('/register/seller', async (req, res, next) => {
  try {
    const input = registerSellerSchema.parse(req.body);
    const passwordHash = await bcrypt.hash(input.password, 12);
    const sellerId = makeId('seller');
    const shopId = makeId('shop');
    const manualUpiId = input.upiId?.trim() || null;
    const paymentQrPayload = input.paymentQrPayload?.trim()
      ? normalizeQrPayload(input.paymentQrPayload)
      : buildUpiQrPayload(manualUpiId, input.shopName);
    const paymentQrFingerprint = makeQrFingerprint(paymentQrPayload);
    const upiId = manualUpiId ?? extractUpiId(paymentQrPayload);

    const { seller, shop } = await withTransaction(async (client) => {
      await releaseDeletedEmail(client, input.email);
      await releaseDeletedShopIdentifier(client, paymentQrFingerprint, upiId);

      const existingEmail = await client.query(
        `SELECT id FROM app_users
         WHERE email = $1 AND deleted_at IS NULL
         LIMIT 1`,
        [input.email],
      );
      if (existingEmail.rows.length > 0) {
        throw new HttpError(409, 'Email already registered');
      }

      const existingQr = await client.query(
        `SELECT s.id
         FROM shops s
         INNER JOIN app_users u ON u.id = s.seller_id
         WHERE u.deleted_at IS NULL
          AND (
            s.payment_qr_fingerprint = $1
            OR ($2::TEXT IS NOT NULL AND s.upi_id = $2)
          )
         LIMIT 1`,
        [paymentQrFingerprint, upiId],
      );
      if (existingQr.rows.length > 0) {
        throw new HttpError(409, 'Payment QR or UPI ID already linked to another shop');
      }

      const sellerResult = await client.query(
        `INSERT INTO app_users (id, role, name, email, phone, password_hash)
         VALUES ($1, 'seller', $2, $3, $4, $5)
         RETURNING id, role, name, email, phone`,
        [sellerId, input.name, input.email, input.phone ?? null, passwordHash],
      );

      const shopResult = await client.query(
        `INSERT INTO shops (
          id, seller_id, name, category, block, address,
          latitude, longitude, qr_code, qr_payload,
          payment_qr_payload, payment_qr_fingerprint, upi_id, map_url
        )
        VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14)
        RETURNING id, seller_id, name, category, block, address,
          latitude, longitude, qr_code, qr_payload,
          payment_qr_payload, payment_qr_fingerprint, upi_id, map_url, is_open`,
        [
          shopId,
          sellerId,
          input.shopName,
          input.category ?? null,
          input.block ?? null,
          input.address ?? null,
          input.latitude ?? null,
          input.longitude ?? null,
          paymentQrFingerprint,
          paymentQrPayload,
          paymentQrPayload,
          paymentQrFingerprint,
          upiId,
          input.mapUrl ?? null,
        ],
      );

      return { seller: sellerResult.rows[0], shop: shopResult.rows[0] };
    });

    res.status(201).json({
      user: publicUser(seller),
      shop,
      token: signToken(seller),
    });
  } catch (error) {
    if (error.code === '23505') {
      return next(new HttpError(409, 'Email or payment QR already registered'));
    }
    return next(error);
  }
});

async function releaseDeletedEmail(client, email) {
  const deletedAccounts = await client.query(
    `SELECT id, role
     FROM app_users
     WHERE email = $1 AND deleted_at IS NOT NULL`,
    [email],
  );

  for (const account of deletedAccounts.rows) {
    await client.query(
      `UPDATE app_users
       SET email = CONCAT('deleted+', id, '+', email),
           phone = NULL,
           updated_at = NOW()
       WHERE id = $1 AND deleted_at IS NOT NULL`,
      [account.id],
    );

    if (account.role === 'seller') {
      await releaseDeletedSellerShop(client, account.id);
    }
  }
}

async function releaseDeletedShopIdentifier(client, paymentQrFingerprint, upiId) {
  const deletedShops = await client.query(
    `SELECT s.seller_id
     FROM shops s
     INNER JOIN app_users u ON u.id = s.seller_id
     WHERE u.deleted_at IS NOT NULL
      AND (
        s.payment_qr_fingerprint = $1
        OR ($2::TEXT IS NOT NULL AND s.upi_id = $2)
      )`,
    [paymentQrFingerprint, upiId],
  );

  for (const shop of deletedShops.rows) {
    await releaseDeletedSellerShop(client, shop.seller_id);
  }
}

async function releaseDeletedSellerShop(client, sellerId) {
  await client.query(
    `UPDATE shops
     SET payment_qr_payload = NULL,
         payment_qr_fingerprint = NULL,
         upi_id = NULL,
         is_open = FALSE,
         updated_at = NOW()
     WHERE seller_id = $1`,
    [sellerId],
  );
}

authRouter.post('/login', async (req, res, next) => {
  try {
    const input = loginSchema.parse(req.body);
    let result = await query(
      `SELECT id, role, name, email, phone, profile_pic, password_hash,
        restricted_until, restriction_reason, deleted_at
       FROM app_users
       WHERE email = $1`,
      [input.email],
    );

    let user = result.rows[0];
    if (!user &&
        input.role === 'admin' &&
        input.email === config.adminBootstrapEmail &&
        input.password === config.adminBootstrapPassword) {
      const passwordHash = await bcrypt.hash(input.password, 12);
      result = await query(
        `INSERT INTO app_users (id, role, name, email, phone, password_hash)
         VALUES ('admin_bootstrap', 'admin', $1, $2, NULL, $3)
         ON CONFLICT (id) DO UPDATE
         SET name = EXCLUDED.name,
             email = EXCLUDED.email,
             password_hash = EXCLUDED.password_hash,
             deleted_at = NULL,
             restricted_until = NULL,
             updated_at = NOW()
         RETURNING id, role, name, email, phone, profile_pic, password_hash,
          restricted_until, restriction_reason, deleted_at`,
        [config.adminBootstrapName, input.email, passwordHash],
      );
      user = result.rows[0];
    }
    if (!user || !(await bcrypt.compare(input.password, user.password_hash))) {
      throw new HttpError(401, 'Invalid email or password');
    }
    if (user.deleted_at) {
      throw new HttpError(403, 'This account has been deleted');
    }
    if (user.restricted_until && new Date(user.restricted_until) > new Date()) {
      throw new HttpError(
        403,
        user.restriction_reason || 'This account is temporarily restricted',
      );
    }

    if (input.role && input.role !== user.role) {
      throw new HttpError(403, `This account is not a ${input.role}`);
    }

    res.json({ user: publicUser(user), token: signToken(user) });
  } catch (error) {
    next(error);
  }
});

authRouter.get('/me', requireAuth, async (req, res, next) => {
  try {
    const result = await query(
      `SELECT id, role, name, email, phone, profile_pic
       FROM app_users
       WHERE id = $1`,
      [req.user.sub],
    );

    const user = result.rows[0];
    if (!user) {
      throw new HttpError(404, 'User not found');
    }

    res.json({ user: publicUser(user) });
  } catch (error) {
    next(error);
  }
});

authRouter.patch('/me', requireAuth, async (req, res, next) => {
  try {
    const input = updateProfileSchema.parse(req.body);
    const result = await query(
      `UPDATE app_users
       SET name = COALESCE($2, name),
           phone = COALESCE($3, phone),
           profile_pic = COALESCE($4, profile_pic),
           updated_at = NOW()
       WHERE id = $1
       RETURNING id, role, name, email, phone, profile_pic`,
      [
        req.user.sub,
        input.name ?? null,
        input.phone ?? null,
        input.profilePic ?? null,
      ],
    );

    const user = result.rows[0];
    if (!user) {
      throw new HttpError(404, 'User not found');
    }

    res.json({ user: publicUser(user) });
  } catch (error) {
    next(error);
  }
});

authRouter.post('/me/delete', requireAuth, async (req, res, next) => {
  try {
    const { password } = req.body;
    if (!password) {
      throw new HttpError(400, 'Password is required to delete account');
    }

    const userResult = await query(
      `SELECT id, password_hash, role, email FROM app_users WHERE id = $1 AND deleted_at IS NULL`,
      [req.user.sub]
    );

    const user = userResult.rows[0];
    if (!user) {
      throw new HttpError(404, 'User not found or already deleted');
    }

    const isValid = await bcrypt.compare(password, user.password_hash);
    if (!isValid) {
      throw new HttpError(401, 'Incorrect password');
    }

    await withTransaction(async (client) => {
      // 1. Mark user as deleted and rename email to free it up
      await client.query(
        `UPDATE app_users
         SET deleted_at = NOW(),
             email = CONCAT('deleted+', id, '+', email),
             phone = NULL,
             updated_at = NOW()
         WHERE id = $1`,
        [user.id]
      );

      // 2. If seller, clear shop identifiers and close it
      if (user.role === 'seller') {
        await releaseDeletedSellerShop(client, user.id);
      }
    });

    res.json({ message: 'Account deleted successfully' });
  } catch (error) {
    next(error);
  }
});
