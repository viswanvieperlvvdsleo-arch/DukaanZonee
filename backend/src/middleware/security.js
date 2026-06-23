import { HttpError } from '../utils/httpError.js';

const dangerousKeys = new Set(['__proto__', 'prototype', 'constructor']);

export function securityHeaders(req, res, next) {
  res.setHeader('X-Content-Type-Options', 'nosniff');
  res.setHeader('X-Frame-Options', 'DENY');
  res.setHeader('Referrer-Policy', 'no-referrer');
  res.setHeader('Cross-Origin-Resource-Policy', 'same-site');
  res.setHeader('Permissions-Policy', 'camera=(), microphone=(), geolocation=()');

  if (req.secure || req.get('x-forwarded-proto') === 'https') {
    res.setHeader('Strict-Transport-Security', 'max-age=15552000; includeSubDomains');
  }

  next();
}

export function rejectPrototypePollution(req, _res, next) {
  if (hasDangerousKey(req.body) || hasDangerousKey(req.query) || hasDangerousKey(req.params)) {
    return next(new HttpError(400, 'Invalid request payload'));
  }
  return next();
}

function hasDangerousKey(value, seen = new WeakSet()) {
  if (!value || typeof value !== 'object') return false;
  if (seen.has(value)) return false;
  seen.add(value);

  if (Array.isArray(value)) {
    return value.some((entry) => hasDangerousKey(entry, seen));
  }

  return Object.entries(value).some(([key, entry]) => {
    return dangerousKeys.has(key) || hasDangerousKey(entry, seen);
  });
}
