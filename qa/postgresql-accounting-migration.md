# Real PostgreSQL accounting migration — 2026-10-23

Explicit follow-up request: apply the real PostgreSQL migration.

## Target and scope

- Local PostgreSQL **16.15**, `127.0.0.1:5432`, database `authdb`, business
  schema `hk`, connected as its existing `auth` owner.
- Previous business version **V58**; final **V60**, zero failed migrations.
- Applied **V59 app_update_policies** and **V60 accounting_ledger** through the
  business service's resolved Flyway runtime. Applied checksums validated normally;
  no repair, clean, checksum edits, baseline or role-privilege changes were used.
- Authentication schema `public` was not migrated. Test VM, service binaries,
  app/device, scheduled jobs and external providers were not deployed/started.

## Backup

Full custom-format database archive, outside the workspace/Git:

```
/home/pc/.local/state/mohajon-postgresql-backups/pre-v60-20261023-en6EBm/authdb-before-v60.dump
```

- Archive size: **184,639 bytes**; file permission **0600**, directory **0700**.
- SHA-256: `ee595310fe2dcc04cd669baffb4106e4e8ef3d91125dfeee27547b97249fd33a`.
- `pg_restore --list` succeeded; archive listing, digest and before/after data
  fingerprints remain in the same protected directory. The archive contains
  private business/auth data and must not be committed or publicly shared.
- A full archive restore into another database was **not** performed. The role
  lacks CREATEDB; no new privilege was granted to work around that restriction.

## Verification performed

1. Cloned the existing V58 hk tables/data, indexes/checks and foreign keys into
   isolated schema `qa_accounting_migration_20261023` in the same PostgreSQL DB.
   Migrated that clone to V60 and ran schema and actual-JDBC accounting checks.
2. Applied the same two pending migrations to the original `hk` schema.
3. Verified all six accounting tables and three nullable original-invoice/payment
   columns. Both seeded app-update policies remain **force-update disabled**.
4. Exercised the actual `AccountingStore`, `AccountingSources` and
   `AccountingService` against PostgreSQL: balanced opening, duplicate command
   retry, balance sheet, journal, and capital excluded from profit. Synthetic
   shop/data were inside an always-rollback transaction on both schemas.
5. Retried Flyway migration: **0 migrations executed**; V60 remains current.
6. Compared row counts and original-value fingerprints across **68 pre-existing
   hk/public tables**, before cloning, after migration and after cleanup: exact
   match. The three newly added NULL sales fields/new tables are excluded from
   the comparison. Public auth Flyway history also matches exactly.
7. Old sales have **0** non-NULL values in the new fields: no history was guessed
   or backfilled. Real accounting setup/entry/journal counts remain **0**; owners
   still explicitly confirm their own branch cutover/opening values.
8. Guarded cleanup removed **only the temporary QA clone schema**. Original hk
   tables remain intact; no test schema or synthetic financial data remains.
   The retained pre-migration archive can recover the temporary clone's source
   data if needed.
9. Full-project `flutter analyze`: **PASS, no issues found** (221.1 seconds).

Reusable local tools and safety notes: [../ops/postgresql/README.md](../ops/postgresql/README.md).

## Still separate acceptance work

- Full archive restore/recovery drill into a separate database; remote/production
  rollout and its approved recovery plan.
- Concurrent first setup/multi-device requests, realistic load/locking tests and
  actual signed-device offline/reconnect/PDF-viewer acceptance.
- Start/deploy the updated backend and build/install an APK only when requested.
- Owner/accountant confirmation of real opening balances and historical sources.
