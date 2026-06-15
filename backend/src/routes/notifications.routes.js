import express from 'express';
import { query } from '../db/pool.js';
import { requireAuth } from '../middleware/auth.js';

export const notificationsRouter = express.Router();

notificationsRouter.use(requireAuth);

notificationsRouter.get('/', async (req, res, next) => {
  try {
    const result = await query(
      `SELECT
         n.id,
         n.type,
         n.title,
         n.body,
         n.is_read,
         n.created_at,
         actor.name AS actor_name,
         s.id AS shop_id,
         s.name AS shop_name,
         s.avatar_url AS shop_avatar_url
       FROM notifications n
       LEFT JOIN app_users actor ON actor.id = n.actor_user_id
       LEFT JOIN shops s ON s.id = n.shop_id
       WHERE n.recipient_user_id = $1
       ORDER BY n.created_at DESC
       LIMIT 80`,
      [req.user.sub],
    );

    res.json({
      notifications: result.rows.map((row) => ({
        id: row.id,
        type: row.type,
        title: row.title,
        body: row.body,
        isRead: row.is_read,
        createdAt: row.created_at,
        actorName: row.actor_name,
        shopId: row.shop_id,
        shopName: row.shop_name,
        shopAvatarUrl: row.shop_avatar_url?.startsWith('blob:')
          ? null
          : row.shop_avatar_url,
      })),
    });
  } catch (error) {
    next(error);
  }
});

notificationsRouter.patch('/read-all', async (req, res, next) => {
  try {
    await query(
      `UPDATE notifications
       SET is_read = TRUE
       WHERE recipient_user_id = $1`,
      [req.user.sub],
    );
    res.json({ ok: true });
  } catch (error) {
    next(error);
  }
});

notificationsRouter.patch('/:notificationId/read', async (req, res, next) => {
  try {
    await query(
      `UPDATE notifications
       SET is_read = TRUE
       WHERE id = $1 AND recipient_user_id = $2`,
      [req.params.notificationId, req.user.sub],
    );
    res.json({ ok: true });
  } catch (error) {
    next(error);
  }
});

notificationsRouter.delete('/', async (req, res, next) => {
  try {
    await query('DELETE FROM notifications WHERE recipient_user_id = $1', [
      req.user.sub,
    ]);
    res.status(204).send();
  } catch (error) {
    next(error);
  }
});

notificationsRouter.delete('/:notificationId', async (req, res, next) => {
  try {
    await query(
      `DELETE FROM notifications
       WHERE id = $1 AND recipient_user_id = $2`,
      [req.params.notificationId, req.user.sub],
    );
    res.status(204).send();
  } catch (error) {
    next(error);
  }
});
