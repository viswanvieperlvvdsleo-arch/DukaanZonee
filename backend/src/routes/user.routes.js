import express from 'express';
import { z } from 'zod';
import { requireAuth } from '../middleware/auth.js';
import { query } from '../db/pool.js';
import { makeId } from '../utils/ids.js';

export const userRouter = express.Router();

userRouter.use(requireAuth);

const addressSchema = z.object({
  title: z.string().min(1).max(100),
  address: z.string().min(1).max(1000),
  latitude: z.number().min(-90).max(90).optional().nullable(),
  longitude: z.number().min(-180).max(180).optional().nullable(),
});

userRouter.get('/addresses', async (req, res, next) => {
  try {
    const result = await query(
      `SELECT id, title, address, latitude, longitude, created_at, updated_at
       FROM user_addresses
       WHERE user_id = $1
       ORDER BY created_at DESC`,
      [req.user.sub]
    );
    res.json({ addresses: result.rows });
  } catch (error) {
    next(error);
  }
});

userRouter.post('/addresses', async (req, res, next) => {
  try {
    const data = addressSchema.parse(req.body);
    const id = makeId('addr');
    const result = await query(
      `INSERT INTO user_addresses (id, user_id, title, address, latitude, longitude)
       VALUES ($1, $2, $3, $4, $5, $6)
       RETURNING id, title, address, latitude, longitude, created_at, updated_at`,
      [id, req.user.sub, data.title, data.address, data.latitude, data.longitude]
    );
    res.status(201).json({ address: result.rows[0] });
  } catch (error) {
    next(error);
  }
});

userRouter.delete('/addresses/:id', async (req, res, next) => {
  try {
    const result = await query(
      `DELETE FROM user_addresses
       WHERE id = $1 AND user_id = $2
       RETURNING id`,
      [req.params.id, req.user.sub]
    );
    if (result.rowCount === 0) {
      return res.status(404).json({ error: 'Address not found or unauthorized' });
    }
    res.json({ ok: true, deletedId: req.params.id });
  } catch (error) {
    next(error);
  }
});
