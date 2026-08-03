# Bangla POS Inventory

Offline-first Flutter POS, inventory, customer due, and purchase management app for Bangladeshi small businesses.

## Stack

- Flutter Material 3
- Riverpod for app state
- Hive for offline local storage
- Firebase Auth, Firestore, and FCM integration points
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
- Offline sync: Hive writes first, pending sync records, Firestore push/pull with last-write-wins
- Localization: English and Bangla language switch
- Auth module: Firebase phone OTP service and login screen

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

## Firestore Structure

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

## Firebase Setup

The app starts in local offline mode if Firebase is not configured. To enable Firebase:

1. Run FlutterFire configuration in this project.
2. Add the generated `firebase_options.dart`.
3. Update `AppBootstrap.init()` to call:

```dart
await Firebase.initializeApp(
  options: DefaultFirebaseOptions.currentPlatform,
);
```

4. Enable Phone Authentication in Firebase Auth.
5. Configure Firestore rules around `shops/{shopId}` membership and user role.

## Development

```bash
flutter pub get
flutter analyze
flutter test
flutter run
```

The Flutter CLI was not available in the current shell while this implementation was generated, so dependency resolution and analyzer checks still need to be run in a Flutter-enabled terminal.

## Custom Auth Backend (Auth Service)

The app can authenticate against a self-hosted auth service (Spring Boot) instead
of Firebase Auth. This is enabled by default.

**Switch backends:**

```bash
# Custom auth service (default)
flutter run --dart-define=USE_CUSTOM_AUTH=true

# Legacy Firebase Auth
flutter run --dart-define=USE_CUSTOM_AUTH=false
```

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
- Firebase is still used for Firestore data sync via anonymous sign-in
  (tokens are stored per device; no FirebaseAuth user accounts are created)

### Android note

Debug builds allow cleartext HTTP (`android:usesCleartextTraffic`) so the
emulator can reach the local auth server. Use HTTPS for release builds.
