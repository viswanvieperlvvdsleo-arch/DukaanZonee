import { createApp } from '../src/app.js';
import { pool } from '../src/db/pool.js';

const app = createApp();
const server = await new Promise((resolve) => {
  const listener = app.listen(0, () => resolve(listener));
});
const { port } = server.address();
const baseUrl = process.env.API_URL ?? `http://localhost:${port}`;
const stamp = Date.now();
const paymentQrPayload = `upi://pay?pa=smoke-${stamp}@upi&pn=Smoke%20Fresh%20Farms&cu=INR`;

async function request(path, options = {}) {
  const response = await fetch(`${baseUrl}${path}`, {
    ...options,
    headers: {
      'content-type': 'application/json',
      ...(options.headers ?? {}),
    },
  });
  const body = await response.json().catch(() => ({}));
  if (!response.ok) {
    throw new Error(`${options.method ?? 'GET'} ${path} failed: ${response.status} ${JSON.stringify(body)}`);
  }
  return body;
}

try {
  const seller = await request('/api/auth/register/seller', {
    method: 'POST',
    body: JSON.stringify({
      name: 'Smoke Seller',
      email: `seller_${stamp}@dukaanzone.local`,
      phone: '9000000001',
      password: 'SmokePass123!',
      shopName: 'Smoke Fresh Farms',
      category: 'Grocery',
      block: 'Block A',
      address: 'Local test shop',
      latitude: 17.73,
      longitude: 83.31,
      paymentQrPayload,
    }),
  });

  await request('/api/auth/register/user', {
    method: 'POST',
    body: JSON.stringify({
      name: 'Smoke User',
      email: `user_${stamp}@dukaanzone.local`,
      phone: '9000000002',
      password: 'SmokePass123!',
    }),
  });

  const item = await request('/api/seller/items', {
    method: 'POST',
    headers: { authorization: `Bearer ${seller.token}` },
    body: JSON.stringify({
      name: 'Fresh Bananas',
      priceCents: 6000,
      stockQty: 15,
      category: 'Fruit',
      barcode: `SMOKE-${stamp}`,
    }),
  });

  const session = await request('/api/payment-sessions/scan', {
    method: 'POST',
    body: JSON.stringify({ qrPayload: paymentQrPayload }),
  });

  console.log(JSON.stringify({
    seller: seller.user.email,
    linkedPaymentQr: seller.shop.payment_qr_payload,
    upiId: seller.shop.upi_id,
    item: item.item.name,
    sessionItemCount: session.items.length,
  }, null, 2));
} finally {
  await new Promise((resolve, reject) => {
    server.close((error) => (error ? reject(error) : resolve()));
  });
  await pool.end();
}
