# DukaanZone Partner Setup Guide

This file is for opening the DukaanZone project on another laptop or PC after downloading the ZIP or cloning the GitHub repo.

Project folders:

- `flutter_app/` -> Flutter frontend
- `backend/` -> Node.js + PostgreSQL backend

---

## 1. Install these first

Before running the project, install:

- Git
- Node.js (version 22 or newer recommended)
- PostgreSQL
- Flutter SDK
- Chrome or Edge
- VS Code or Android Studio

To check versions:

```powershell
node -v
npm -v
flutter --version
psql --version
git --version
```

---

## 2. Open the project

If using ZIP:

1. Extract the ZIP
2. Open terminal in the extracted folder

If using GitHub:

```powershell
git clone https://github.com/viswanvieperlvvdsleo-arch/DukaanZonee.git
cd DukaanZonee
```

---

## 3. Create PostgreSQL database

Create a database named:

```text
dukaanzone_dev
```

If using `psql`:

```sql
CREATE DATABASE dukaanzone_dev;
```

If using pgAdmin:

1. Open pgAdmin
2. Right click `Databases`
3. Click `Create > Database`
4. Name it `dukaanzone_dev`

---

## 4. Backend setup

Go to backend folder:

```powershell
cd backend
```

Install packages:

```powershell
npm install
```

Create a file named `.env` inside the `backend` folder.

Example `.env`:

```env
DATABASE_URL=postgresql://postgres:YOUR_PASSWORD@localhost:5432/dukaanzone_dev
JWT_SECRET=your_super_secret_key_here
PORT=4000
COMMISSION_RATE=0.03
PG_POOL_MAX=10
PG_CONNECTION_TIMEOUT_MS=5000
PG_IDLE_TIMEOUT_MS=30000
ADMIN_BOOTSTRAP_EMAIL=admin@example.com
ADMIN_BOOTSTRAP_PASSWORD=change_this_admin_password
ADMIN_BOOTSTRAP_NAME=DukaanZone Admin
```

Replace:

- `YOUR_PASSWORD` with the local PostgreSQL password
- `your_super_secret_key_here` with any strong random secret. For production, use at least 32 characters.
- `ADMIN_BOOTSTRAP_EMAIL` and `ADMIN_BOOTSTRAP_PASSWORD` with the admin login you want for that machine

Run database migration:

```powershell
npm run db:migrate
```

Start backend:

```powershell
npm start
```

Expected terminal output:

```text
DukaanZone API listening on http://localhost:4000
DukaanZone realtime listening on ws://localhost:4000/ws
```

Backend health check:

Open:

```text
http://localhost:4000/health
```

Expected:

```json
{"ok":true,"service":"dukaanzone-backend"}
```

---

## 5. Flutter frontend setup

Open a new terminal:

```powershell
cd flutter_app
flutter pub get
```

Run main user/seller app:

```powershell
flutter run -d chrome --dart-define=API_BASE_URL=http://127.0.0.1:4000
```

Or run as web server:

```powershell
flutter run -d web-server --web-hostname 0.0.0.0 --web-port 3000 --dart-define=API_BASE_URL=http://127.0.0.1:4000
```

If using another phone on same Wi-Fi, replace `127.0.0.1` with the laptop local IP:

```powershell
flutter run -d web-server --web-hostname 0.0.0.0 --web-port 3000 --dart-define=API_BASE_URL=http://YOUR_LOCAL_IP:4000
```

Then open:

```text
http://YOUR_LOCAL_IP:3000
```

---

## 6. Admin panel setup

Run admin app from a new terminal:

```powershell
cd flutter_app
flutter run -d chrome -t lib/main_admin.dart --dart-define=API_BASE_URL=http://127.0.0.1:4000
```

---

## 7. Important local run order

Always run in this order:

1. Start PostgreSQL
2. Start backend
3. Start Flutter app
4. Start admin app if needed

Recommended order:

```powershell
cd backend
npm install
npm run db:migrate
npm start
```

Open second terminal:

```powershell
cd flutter_app
flutter pub get
flutter run -d chrome --dart-define=API_BASE_URL=http://127.0.0.1:4000
```

Optional third terminal for admin:

```powershell
cd flutter_app
flutter run -d chrome -t lib/main_admin.dart --dart-define=API_BASE_URL=http://127.0.0.1:4000
```

---

## 8. If port 4000 is already in use

Check:

```powershell
netstat -ano | findstr :4000
```

Kill process:

```powershell
taskkill /PID <PID_NUMBER> /F
```

Then run backend again:

```powershell
cd backend
npm start
```

---

## 9. If port 3000 is already in use

Check:

```powershell
netstat -ano | findstr :3000
```

Kill process:

```powershell
taskkill /PID <PID_NUMBER> /F
```

Or use another Flutter web port:

```powershell
flutter run -d web-server --web-hostname 0.0.0.0 --web-port 3001 --dart-define=API_BASE_URL=http://127.0.0.1:4000
```

---

## 10. QR and payment setup note

Seller payment methods support:

- manual UPI ID entry
- live QR scan
- QR image upload decode through backend

If QR image upload does not work:

1. confirm backend is running
2. confirm `.env` is correct
3. confirm Python is installed

Check Python:

```powershell
python --version
```

---

## 11. Camera note for mobile browser

On local HTTP links, some mobile browsers block full camera access.

For best testing:

- use laptop Chrome for camera-based QR tests
- or deploy on HTTPS later for better browser camera support

QR image upload and manual paste are fallback options.

---

## 12. If backend says route not found

Usually this means backend was not restarted after new code changes.

Fix:

```powershell
cd backend
Ctrl + C
npm start
```

---

## 13. If Flutter shows "Could not reach DukaanZone backend"

Check:

1. backend is running
2. backend is on port 4000
3. correct `API_BASE_URL` is used
4. if using phone, laptop IP is correct and both are on same Wi-Fi

Find laptop IP:

```powershell
ipconfig
```

Look under Wi-Fi IPv4 Address, for example:

```text
192.168.x.x
```

Then use:

```text
http://192.168.x.x:4000
```

---

## 14. Important files

Backend:

- `backend/src/server.js`
- `backend/src/app.js`
- `backend/src/routes/`
- `backend/src/db/migrate.js`
- `backend/src/utils/decode_qr_image.py`

Flutter:

- `flutter_app/lib/main.dart`
- `flutter_app/lib/main_admin.dart`
- `flutter_app/lib/services/`
- `flutter_app/lib/ui/pages/`

---

## 15. Current project note

This repo contains both:

- Flutter frontend
- Node/PostgreSQL backend

So always work from the project root carefully, but run commands inside the correct folder:

- frontend commands inside `flutter_app`
- backend commands inside `backend`

---

## 16. Quick command summary

Backend:

```powershell
cd backend
npm install
npm run db:migrate
npm start
```

Frontend:

```powershell
cd flutter_app
flutter pub get
flutter run -d chrome --dart-define=API_BASE_URL=http://127.0.0.1:4000
```

Admin:

```powershell
cd flutter_app
flutter run -d chrome -t lib/main_admin.dart --dart-define=API_BASE_URL=http://127.0.0.1:4000
```

---

If anything fails, first check:

1. PostgreSQL running
2. backend `.env` correct
3. backend started
4. Flutter started with correct API URL

---

## 17. Security notes before deployment

Do not commit real secrets:

- `backend/.env`
- database passwords
- payment gateway keys
- Firebase or push notification private keys
- production signing keys

For production:

- create a separate PostgreSQL user for the app instead of using the `postgres` superuser
- use a strong `JWT_SECRET` with at least 32 characters
- set a strict `CORS_ORIGIN` for the real frontend domain
- use database SSL where the host requires it, for example `PGSSLMODE=require`
- never put private secrets inside `flutter_app/.env`, because Flutter assets can be extracted from the app bundle
- rotate any credential that was ever pushed to GitHub history
