import express from 'express';
import { z } from 'zod';
import { query } from '../db/pool.js';
import { requireAuth } from '../middleware/auth.js';
import { publishToRole } from '../realtime/socketHub.js';
import { HttpError } from '../utils/httpError.js';
import { makeId } from '../utils/ids.js';

export const supportRouter = express.Router();

supportRouter.use(requireAuth);

const disputeSchema = z.object({
  category: z.string().trim().min(2).max(120),
  description: z.string().trim().min(5).max(1000),
});

supportRouter.get('/disputes', async (req, res, next) => {
  try {
    const result = await query(
      `SELECT id, category, description, status, created_at, updated_at
       FROM disputes
       WHERE reporter_user_id = $1
       ORDER BY created_at DESC
       LIMIT 80`,
      [req.user.sub],
    );
    res.json({ disputes: result.rows.map(mapSupportDispute) });
  } catch (error) {
    next(error);
  }
});

supportRouter.post('/disputes', async (req, res, next) => {
  try {
    if (req.user.role !== 'user' && req.user.role !== 'seller') {
      throw new HttpError(403, 'Only users and sellers can create disputes');
    }
    const input = disputeSchema.parse(req.body);
    const result = await query(
      `INSERT INTO disputes (
        id, reporter_user_id, reporter_role, category, description
      )
      VALUES ($1, $2, $3, $4, $5)
      RETURNING id, category, description, status, created_at, updated_at`,
      [
        makeId('dsp'),
        req.user.sub,
        req.user.role,
        input.category,
        input.description,
      ],
    );
    const dispute = mapSupportDispute(result.rows[0]);
    const title = 'New support ticket';
    const body = `${req.user.name} reported ${dispute.category}: ${dispute.description}`;
    await notifyAdmins(req.user.sub, 'dispute.created', title, body);
    publishToRole('admin', 'notification.created', {
      type: 'dispute.created',
      title,
      body,
    });
    publishToRole('admin', 'dispute.created', {
      id: dispute.id,
      reporterRole: req.user.role,
      category: dispute.category,
      description: dispute.description,
      createdAt: dispute.createdAt,
    });
    res.status(201).json({ dispute });
  } catch (error) {
    next(error);
  }
});

function mapSupportDispute(row) {
  return {
    id: row.id,
    category: row.category,
    description: row.description,
    status: row.status,
    createdAt: row.created_at,
    updatedAt: row.updated_at,
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
