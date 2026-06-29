# DukaanZone FCM Hardware Push Setup

This project now has Firebase Cloud Messaging wiring for real Android hardware notifications.

FCM is free for normal push-notification usage. The app still works without Firebase config, but hardware push stays disabled until these steps are done.

## What Was Added

- Android app requests notification permission.
- Flutter registers the device FCM token after user, seller, or admin login.
- Flutter unregisters tokens on logout.
- Backend stores device tokens in PostgreSQL.
- Backend listens for new rows in `notifications` and sends FCM push to the recipient.
- Foreground notifications show using local Android notifications with sound/vibration.

## 1. Create Firebase Project

1. Open Firebase Console.
2. Create or choose a project.
3. Add an Android app.
4. Use this Android package name:

```text
com.example.dukaan_zone_flutter
```

5. Download `google-services.json`.
6. Put it here:

```text
flutter_app/android/app/google-services.json
```

Do not commit private Firebase files if you do not want them public.

## 2. Backend Service Account

In Firebase Console:

1. Project Settings
2. Service accounts
3. Generate new private key
4. Download JSON

For Render, set this environment variable:

```env
FCM_SERVICE_ACCOUNT_JSON=<service account json or base64 json>
```

Base64 option from PowerShell:

```powershell
[Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes((Get-Content .\firebase-service-account.json -Raw)))
```

Paste the full output as `FCM_SERVICE_ACCOUNT_JSON`.

Alternative Render env variables:

```env
FCM_PROJECT_ID=your-project-id
FCM_CLIENT_EMAIL=firebase-adminsdk-...@your-project.iam.gserviceaccount.com
FCM_PRIVATE_KEY="-----BEGIN PRIVATE KEY-----\n...\n-----END PRIVATE KEY-----\n"
```

## 3. Redeploy Backend

After setting env vars on Render:

1. Redeploy backend.
2. Open health check:

```text
https://dukaanzone.onrender.com/health
```

3. Run local or deployed migration if needed:

```powershell
cd backend
npm run db:migrate
```

## 4. Run Android App

For USB Android testing:

```powershell
cd flutter_app
flutter pub get
flutter run -d 3C15CW00CUE00000 --dart-define=API_BASE_URL=https://dukaanzone.onrender.com
```

When the app asks notification permission, tap Allow.

## 5. Test Hardware Push

Use two accounts/devices:

1. Login as seller on one device.
2. Login as user on another device.
3. Send a chat message, follow a shop, complete a mock payment, or send an admin signal.
4. If the recipient app is backgrounded or closed, Android should show a system notification.
5. If the app is open, DukaanZone shows a local foreground notification with sound/vibration.

## 6. Troubleshooting

If push does not arrive:

- Confirm `google-services.json` exists in `flutter_app/android/app/`.
- Rebuild the Android app after adding `google-services.json`.
- Confirm notification permission is allowed in Android app settings.
- Confirm Render has `FCM_SERVICE_ACCOUNT_JSON`.
- Confirm backend logs do not show `FCM disabled`.
- Confirm the user has logged in after Firebase config was added, because token registration happens on login/session restore.

If app builds but push is disabled:

```text
FCM disabled until Firebase config is added
```

This means the Android Firebase config or backend service account is missing.
