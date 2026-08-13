# Bangla POS Inventory

Offline-first Flutter POS, inventory, customer due, and purchase management app for Bangladeshi small businesses.

## Stack

- Flutter Material 3
- Riverpod for app state
- Hive for offline local storage
- Self-hosted Java backend services (auth-service, haalkhata-service)
- `intl` powered English/Bangla localization
- PDF invoice generation and sharing

## Implemented Modules

- Dashboard analytics: today sales, total due, customers due, top products, low stock, monthly chart
- Products: add, edit, delete, stock tracking, low stock alert, barcode field
- POS: cart, discount, paid/due calculation, stock decrement, PDF invoice
- Customers: add, list, details
- Due management: separate sales and payment records with chronological ledger
- Payments: partial payments by cash, bKash, or Nagad
- Purchases: stock increment and supplier due-ready model
- Offline sync: Hive writes first, pending sync records, push/pull with the Haalkhata service (last-write-wins)
- Localization: English and Bangla language switch
- Auth module: email/password, phone OTP, and Google sign-in via the auth-service

## Due Rule

Customer due is never overwritten as a source of truth. It is always derived as:

```text
sum(customer sales totalAmount) - sum(customer payment amount)
```

Sales and payments are stored independently, so the ledger can show:

```text
Sale +1000
Payment -500
Sale +2000
Payment -1000
Final due = 1500
```

## Sync Data Structure

Collections synced with the Haalkhata service (`haalkhata-service`):

```text
shops/
  shopId/
    products/
    customers/
    sales/
    payments/
    purchases/
    suppliers/
    users/
```

## Google Sign-In

Google sign-in runs through the common authenticate service (`auth-service`):

1. The Flutter app obtains a Google ID token via `google_sign_in`.
2. `CustomAuthBackend` posts it to `POST /api/v1/auth/google`.
3. `GoogleIdTokenVerifier` validates the token against Google's public JWKS and
   the configured `app.google.client-id` (env: `GOOGLE_CLIENT_ID`).
4. The auth-service provisions/links the user and returns JWT access/refresh
   tokens.

On Android the web client ID used as the ID-token audience lives in
`android/app/src/main/res/values/strings.xml` (`default_web_client_id`).

## Development

```bash
flutter pub get
flutter analyze
flutter test
flutter run
```

The Flutter CLI was not available in the current shell while this implementation was generated, so dependency resolution and analyzer checks still need to be run in a Flutter-enabled terminal.

## Custom Auth Backend (Auth Service)

The app authenticates against a self-hosted auth service (Spring Boot),
`auth-service`.

**Backends:**

Custom auth service only; Firebase Auth is no longer a backend.

**Point the app at a different auth server:**

```bash
flutter run --dart-define=AUTH_BASE_URL=https://auth.example.com
```

Defaults: `http://10.0.2.2:8080` (Android emulator → host machine).

### What happens in custom auth mode

- Email/password signup with email-verification code dialog
- Login with JWT access token + rotating refresh token
- Tokens stored in Hive (keys `auth_access_token`, `auth_refresh_token`,
  `auth_session`); expired access tokens are refreshed automatically on 401
- Google sign-in via `google_sign_in`; the ID token is verified server-side
- Logout revokes the refresh token on the server
- Data sync uses the Haalkhata service directly (`/api/v1/sync/push|pull`);
  there is no Firestore anymore

### Android note

Debug builds allow cleartext HTTP (`android:usesCleartextTraffic`) so the
emulator can reach the local auth server. Use HTTPS for release builds.
