import { pool } from '../db/pool.js';
import { sendPushToUserId } from './push.service.js';

let started = false;

export async function startNotificationPushListener() {
  if (started) return;
  started = true;

  const connect = async () => {
    let client;
    let released = false;
    const release = () => {
      if (!client || released) return;
      released = true;
      client.release();
    };

    try {
      client = await pool.connect();

      client.on('notification', async (message) => {
        try {
          const payload = JSON.parse(message.payload ?? '{}');
          await sendPushToUserId(payload.recipientUserId, {
            title: payload.title,
            body: payload.body,
            data: {
              notificationId: payload.id,
              type: payload.type,
            },
          });
        } catch (error) {
          console.warn(`FCM notification dispatch failed: ${error.message}`);
        }
      });

      client.on('error', (error) => {
        console.warn(`Notification push listener lost database connection: ${error.message}`);
        release();
        setTimeout(connect, 5000);
      });

      await client.query('LISTEN dukaanzone_notifications');
      console.log('DukaanZone push listener ready');
    } catch (error) {
      console.warn(`Notification push listener unavailable: ${error.message}`);
      release();
      setTimeout(connect, 5000);
    }
  };

  await connect();
}
