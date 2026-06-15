import { HttpError } from '../utils/httpError.js';

export function createRateLimiter({ windowMs = 60_000, max = 120 } = {}) {
  const buckets = new Map();

  return (req, _res, next) => {
    const key = req.ip ?? req.socket.remoteAddress ?? 'unknown';
    const now = Date.now();
    const bucket = buckets.get(key);

    if (!bucket || now > bucket.resetAt) {
      buckets.set(key, { count: 1, resetAt: now + windowMs });
      return next();
    }

    bucket.count += 1;
    if (bucket.count > max) {
      return next(new HttpError(429, 'Too many requests'));
    }

    return next();
  };
}
