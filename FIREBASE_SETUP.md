# Firebase Spark setup

This app can sync products, customers, sales, payments, purchases, suppliers, and users to Cloud Firestore while keeping Hive as the offline local store.

## 1. Create the free Firebase project

1. Create a Firebase project and keep it on the Spark plan.
2. Enable Authentication > Sign-in method > Anonymous.
3. Create a Cloud Firestore database.
4. Keep the database location close to your users.

## 2. Connect the Flutter app

Run these from the project root:

```bash
dart pub global activate flutterfire_cli
flutterfire configure
```

Select Android and any other platforms you need. This generates `lib/firebase_options.dart` and platform config files such as `android/app/google-services.json`.

## 3. Deploy Firestore rules

```bash
firebase deploy --only firestore:rules
```

The included rules allow authenticated users to access only their matching `shop_{uid}` path. Sign in with the app before using sync or profile save.

## 4. Free-plan sync notes

The sync service pushes pending local records first, then pulls only remote records changed since the last successful pull for each collection. That keeps Firestore reads lower than fetching every document on every sync.

Firestore Spark/free quota is limited. Avoid tapping sync repeatedly with large demo data, and keep one Firebase project per real shop if you need clean quota tracking.
