# DukaanZone Backend

Local API server for seller/user auth, seller shop QR creation, live shelf items, and payment-session lookup.

## Setup

1. Copy `.env.example` to `.env`.
2. Install dependencies:

   ```powershell
   cmd /c npm.cmd install
   ```

3. Run migrations:

   ```powershell
   cmd /c npm.cmd run db:migrate
   ```

4. Start the API:

   ```powershell
   cmd /c npm.cmd run dev
   ```

## First Test Flow

1. Register a seller: `POST /api/auth/register/seller`
2. Register a user: `POST /api/auth/register/user`
3. Seller adds a shelf item: `POST /api/seller/items`
4. User scans seller QR payload via: `GET /api/payment-sessions/qr/:qrCode`
