# Mohajon Mobile App

**Mohajon** is an offline-first, Bengali-first mobile operating system for
small businesses in Bangladesh. It combines point-of-sale, inventory, customer
dues, purchasing, accounting, and business insights in a single Flutter app.

The app is designed for real shop workflows: records are stored locally first,
users can keep working through unreliable connectivity, and data synchronizes
with Mohajon's self-hosted services when a connection is available.

## Key capabilities

- **Point of sale** — cart, discounts, split/due payments, invoices, returns,
  and shareable digital receipts
- **Inventory** — products, barcode tools, batches, expiry data, stock alerts,
  stock adjustments, and purchase receipts
- **Customers and dues** — chronological ledgers, partial payments, recovery
  plans, follow-ups, and customer import
- **Purchasing and vendors** — suppliers, purchase orders, vendor balances,
  and supplier returns
- **Business operations** — branches, staff roles, audit timeline, expenses,
  investments, daily closing, and configurable payment methods
- **Accounting and reports** — journals, income statements, VAT, sales,
  inventory, expense, customer, and operational reports with PDF/XLSX export
- **Platform features** — subscriptions, bKash payment flow, notifications,
  support inbox, release/update gate, and a voice-assistant workflow

## Architecture

```text
Flutter + Riverpod UI
        │
        ├── Hive local database ──> offline-first reads and queued writes
        │
        ├── Mohajon Auth Service :8080 ──> login and JWT refresh
        │
        └── Mohajon Core Service :8081 ──> business APIs and sync
```

Sales and customer payments are independent ledger records. A customer's due
is calculated from those records, instead of being overwritten as a mutable
total, which keeps the financial history auditable.

## Technology

| Area | Choice |
|---|---|
| Application | Flutter, Material 3, Dart `^3.11.5` |
| State management | Riverpod |
| Local persistence | Hive / Hive Flutter |
| Backend integration | REST APIs, JWT access/refresh tokens, offline sync |
| Device integrations | Barcode scanning, camera/image picker, contacts, file sharing |
| Documents | PDF generation, printing, XLSX/PDF report download |
| Localization | English and Bangla via `intl` and Flutter localization |

## Project layout

```text
lib/
├── core/          # application shell, API client, local DB, models, theme
└── features/      # feature-specific UI, providers, domain models, services
    ├── accounting/
    ├── pos/
    ├── products/
    ├── customers/
    ├── purchases/
    ├── reports/
    ├── subscription/
    └── voice_assistant/
```

## Run locally

### Prerequisites

- Flutter SDK compatible with Dart `^3.11.5`
- An Android emulator/device, iOS simulator, or desktop target
- Local Mohajon Auth and Core services for API-backed workflows

### Commands

```bash
flutter pub get
flutter analyze
flutter test
flutter run \
  --dart-define=AUTH_BASE_URL=http://10.0.2.2:8080 \
  --dart-define=HAALKHATA_BASE_URL=http://10.0.2.2:8081
```

For Android emulators, `10.0.2.2` points to the host machine. Desktop clients
default to `localhost`. Release builds require HTTPS URLs supplied through
these two `--dart-define` values.

## Authentication and sync

The app uses `mohajon-auth-service` for email/password registration, email
verification, Google sign-in, JWT session refresh, and logout. Business data
syncs with `mohajon-core-service`; Firebase is not the primary application
backend.

Never commit production credentials, signing keys, local editor settings, or
runtime logs. The repository ignores those files by default.

## Tests

```bash
flutter analyze
flutter test
```

The suite includes coverage for accounting calculations, cart validation,
invoice totals, purchase receipts, app updates, responsive workflows,
localization, and offline-collection behavior.

## Related repositories

- `mohajon-auth-service` — authentication, tokens, and session management
- `mohajon-core-service` — business APIs, reporting, and synchronization
- `mohajon-admin-portal` — platform operations and customer-support tools

## Notes for maintainers

The Android application ID and Dart package namespace retain their existing
`inventory_1` values because they are linked to the current Firebase/Android
configuration and source imports. The public product name is **Mohajon**.
