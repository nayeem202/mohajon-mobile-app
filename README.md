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
