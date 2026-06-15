import crypto from 'node:crypto';

export function makeId(prefix) {
  return `${prefix}_${crypto.randomUUID().replaceAll('-', '')}`;
}

export function makeShopQrCode(shopId) {
  return `DZSHOP_${shopId.replace(/^shop_/, '')}`;
}

export function makeShopQrPayload(qrCode) {
  return `dukaanzone://pay/${qrCode}`;
}

export function normalizeQrPayload(payload) {
  return payload.trim().replace(/\s+/g, '');
}

export function makeQrFingerprint(payload) {
  return crypto
    .createHash('sha256')
    .update(normalizeQrPayload(payload), 'utf8')
    .digest('hex');
}

export function extractUpiId(payload) {
  const normalized = normalizeQrPayload(payload);
  if (/^[a-zA-Z0-9.\-_]{2,}@[a-zA-Z0-9.\-_]{2,}$/.test(normalized)) {
    return normalized;
  }

  try {
    const uri = new URL(normalized);
    if (uri.protocol.toLowerCase() !== 'upi:') {
      return null;
    }
    return uri.searchParams.get('pa');
  } catch {
    return null;
  }
}

export function buildUpiQrPayload(upiId, payeeName = 'Shop') {
  const normalizedUpiId = normalizeQrPayload(upiId);
  const encodedName = encodeURIComponent(payeeName?.trim() || 'Shop');
  return `upi://pay?pa=${normalizedUpiId}&pn=${encodedName}&cu=INR`;
}
