# Financial accounts — 2026-10-23

Implementation policy and operational boundaries: [../ops/accounting.md](../ops/accounting.md).
Flutter code is in `lib/features/accounting`; Java code and migration V60 are in
the sibling `haalkhata-service` repository. The implementation increment did not
deploy them. A subsequent explicit request applied local PostgreSQL V59/V60;
see [postgresql-accounting-migration.md](postgresql-accounting-migration.md).

## Automated acceptance cases

| Area | Cases and expected result | Evidence |
| --- | --- | --- |
| Income statement | Discounted sales exclude output VAT; cost uses the recorded purchase-cost snapshot; returns reverse revenue/cost on their own date without reducing the original period twice. | Java `AccountingEngineTest`, Flutter `accounting_domain_test.dart` |
| Cutover/opening | Balanced explicit opening accounts only; no income/expense opening, automatic capital plug, duplicate setup or second posting of pre-cutover history. Setup locks after confirmation. | Java engine/persistence tests |
| Manual finance | Contributions, drawings, principal, interest, asset purchases and depreciation use distinct accounts; principal/depreciation limits, depreciation date and linked reversals are validated. | Java engine/persistence tests |
| Retry/revisions | Initial-payment identity survives sync; missing initial row can later arrive without double counting; deleted payments are not resurrected; same manual UUID is idempotent, changed content conflicts; source revisions append reversals and replacements. | Java engine/persistence, Flutter model/outbox tests |
| Atomicity | A real Spring-advised source transaction rolls back if journal reconciliation fails; nested transactions reconcile only once. | `AccountingMutationAspectTest` with Spring, JDBC transactions and H2 |
| Access/classification | Staff/cross-shop/manual-ID access rejected; authenticated branch context used; invalid source/account combinations rejected; missing legacy payment/supplier/investor evidence remains a visible review issue. | Java persistence/engine tests |
| Quality | Unmatched returns, inconsistent invoices, missing classifications, negative fund/inventory/debt balances and physical-product-cost estimate differences are not silently labelled reconciled. | Java tests plus report/workspace implementation |
| Offline/cache | Cache is namespaced by user/shop/branch and visibly dated; an uncached balance sheet is never fabricated; authorization failures do not reveal cached reports; branch changes cannot write into another cache. | `accounting_client_test.dart` |
| Outbox | Lost response retains the same immutable command UUID; concurrent flush is single-flight; concurrently queued commands survive; HTTP 400 is retained for explicit correction; another branch cannot flush the queue. | `accounting_client_test.dart` using temporary Hive files |
| Scope changes | Unfinished financial forms are blocked after active account/branch changes. | `accounting_ui_test.dart` |
| BN/EN/export | Matching localized account/transaction/metric labels; Bengali-digit input; complete UTF-8 XLSX XML and real PDF generation using the existing complex-script raster pipeline. | `accounting_domain_test.dart` |
| Responsive UI | Income, balance, locked opening, opening form, transaction, loan/depreciation, classification, workspace and journal screens fit 320dp with 2x text, in both languages. | `accounting_ui_test.dart` |
| Privacy | Scoped clearing removes setup, entries, classifications, journal lines/headers and source states without touching another shop; local business-data clearing removes financial caches/outboxes. | Java persistence test; local clearing implementation |

The automated unit suites use no real shop, VM credentials, provider key, SMTP
service or live DB. Their JDBC persistence tests execute V60 against disposable
H2 in PostgreSQL mode. The later real PostgreSQL migration/rollback-only smoke
checks are separately recorded in the linked migration report.

## Results

- Full Flutter regression: **141 passed, 0 failed** (47 seconds).
- New accounting coverage within that suite: **39 tests** (domain/export 11,
  client/outbox 8, responsive UI 20).
- Full Java business-service regression: **108 passed, 0 failed** (45 seconds),
  including **25 new accounting tests** (engine 12, persistence 11, Spring AOP 2).
- Full-project `flutter analyze`: **PASS, no issues found** (252.2 seconds).
  Initial informational lint findings were corrected and the full analyzer was
  rerun; the final Flutter suite also passed after those corrections.
- Authentication service and admin portal were not changed or rerun for this
  accounting increment; previous results remain in `results.md`.
- Follow-up real PostgreSQL 16 migration: **PASS**, local `authdb.hk` is V60;
  original data fingerprints unchanged, retry is a no-op, rollback-only ledger
  checks pass and the temporary clone was removed. No VM migration was done.

## Release checks still required (NOT RUN)

1. Complete a full PostgreSQL archive restore/recovery drill and remote rollout
   plan; run concurrent first setup and multi-device transaction/sync cases.
   Local SQL-clone rehearsal and actual V60 migration are already verified.
2. Confirm actual opening values/cutover and classify missing historical sources
   with the owner/accountant. Compare source invoices, VAT, stock and ledger.
3. Test a signed Android artifact online/offline/restart/reconnect, including a
   lost HTTP response after server commit, rejected queued edits and branch switch.
4. Inspect exported BN/EN PDF/XLSX visually on actual viewers. Automated PDF
   generation is not manual typography/print acceptance.
5. Exercise realistic transaction volumes on the target VM. Reconciliation is a
   deterministic full-scope projection, not a proven high-volume incremental
   engine; benchmark DB lock duration, latency, memory and journal growth.
6. Back up and restore the server ledger/schema, not only phone business JSON.
   Obtain accounting/tax review before treating reports as financial filings.

No APK build, device installation, push or service/VM deployment was run. The
separately authorized local database migration is described above.
