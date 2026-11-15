# Local PostgreSQL accounting migration

These maintenance tools target only `127.0.0.1:5432/authdb`, the explicitly
selected `hk` or dated QA schema, and Flyway target V60. They do not launch
Spring/API services, background jobs, email, payment providers or an APK build.
They never run Flyway clean, repair, checksum overrides or automatic baseline.

`MaintainAccounting.java` uses the business service's own runtime dependencies
and compiled accounting classes. Java 21 source launch supports four commands:

- `info`: read the current/pending Flyway versions.
- `migrate`: validate applied checksums and apply only pending versions to V60.
- `verify`: validate the final history/schema and confirm force updates are off.
- `smoke`: exercise the actual JDBC store/source queries and accounting service
  using a unique synthetic shop inside a transaction that is always rolled back.
  Checks include balanced opening, stable-ID retry, statement/journal output and
  contribution not being recognized as profit. No real opening is created.

Required environment variables (never commit credential values):
`ACCOUNTING_DB_URL`, `ACCOUNTING_DB_SCHEMA`, `ACCOUNTING_DB_USER`,
`ACCOUNTING_DB_PASSWORD`.

Generate the classpath from the business repository with Java 21:

```bash
./gradlew -q -I /absolute/path/inventory_1/ops/postgresql/runtime-classpath.init.gradle accountingMaintenanceClasspath
```

Pass that output to Java's `--class-path`, followed by the absolute path to
`MaintainAccounting.java`, the command, and the business service's
`src/main/resources/db/migration` directory. Compile the business classes first
if necessary; no APK or application server startup is needed.

## Safety workflow

1. Resolve the local target, current version, pending SQL and active connections.
2. Create a full `pg_dump --format=custom` outside Git with 0700 directory/0600
   file permissions. Verify `pg_restore --list`, record SHA-256, and fingerprint
   existing application/auth rows with `existing-data-fingerprint.sql`.
3. The local `auth` role owns `authdb` but has no CREATEDB privilege. The dated
   `clone-accounting-check.sql` copies existing hk tables/data, indexes/checks
   and foreign keys into an isolated schema. This is a SQL clone, not a claim
   that a full archive restore has been performed. Do not reuse the fixed name
   when a schema already exists, or grant extra role privileges just for testing.
4. Migrate/verify/smoke the isolated clone before the original hk schema.
5. Migrate/verify/smoke hk, then retry migrate and require zero further changes.
6. Compare all pre-existing data fingerprints and public auth Flyway history.
   Confirm new invoice columns are NULL on old rows and no real opening or
   financial entries have been invented.
7. Run guarded cleanup of only the explicitly dated QA schema. Keep the protected
   backup; do not use a broad DROP/restore/clean against the shared database.

The fingerprint excludes Flyway history, newly created tables and only the three
new invoice columns. It compares original column values and row counts across
all existing hk/public application tables without printing user data.

Before a future migration, review/update the dated QA target and verification
expectations. Full backup restore, VM deployment, production promotion and
multi-device/load acceptance remain separate, explicitly scoped operations.
