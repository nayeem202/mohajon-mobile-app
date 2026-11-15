# Execution record

## 2026-10-22 — local baseline and regression expansion

Environment: local WSL checkout, Flutter test runner, Java 21 business service,
Java 25 auth service. Auth integration database is disposable H2 (`test` profile).
Existing unrelated worktree changes are preserved. No device install, deployment,
real shop-data changes, external messages or provider charges are authorized.

**This is a local automated regression pass, NOT full-app acceptance sign-off.**
There are 107 documented cases. Their device, external-provider and
infrastructure portions are **NOT RUN** in this local pass.

### Execution evidence

| Component | Before expansion | Final local run | Evidence |
| --- | --- | --- | --- |
| Flutter | 57 passed | 90 passed, 0 failed | `flutter test --coverage --concurrency=2 --reporter expanded`; 49 seconds; `coverage/lcov.info` |
| Business Java | 42 passed | 83 passed, 0 failed/skipped/errors; 15 suites | Java 21 `./gradlew test --max-workers=2 --console=plain`; fresh execution, 51 seconds; XML under sibling `haalkhata-service/build/test-results/test` |
| Auth Java | 4 existing tests (initial task was cached, not fresh evidence) | 21 passed, 0 failed/skipped/errors; 3 suites | Java 25 `./gradlew test --max-workers=2 --console=plain`; fresh execution, 1m57s; H2 and fake notifications; sibling `auth-service/build/test-results/test` |
| Flutter analyzer | Two existing informational missing-braces lints | PASS: no issues found | `flutter analyze`; 305.6 seconds |
| Existing admin portal | Separate optional suite | 5 passed across 2 files | Node 24 + Angular/Vitest; `qa/vitest.config.mjs`; warm retry completed in 27.01 seconds |

91 new automated tests were added across Flutter (33), business Java (41), and
auth Java (17). Existing tests were retained. No tests are marked skipped in
the final Java runs. Generated XML/HTML reports and coverage are intentionally
not committed.

Total final passing automated checks: **194 app/Java tests + 5 existing portal
tests = 199**. The portal's first attempt did not execute tests: its Vitest
worker hit the 60-second initialization timeout on WSL/NTFS. The unchanged
one-worker command was retried after cache warmup and all 5 tests passed.
That intermittent cold-start harness problem is not evidence of a portal
functional failure, but remains a test-runner reliability concern.

Flutter coverage reports **2,456 / 34,331 executable lines (7.15%) across the
257 source files present in that LCOV report**. The app has 282 Dart source files;
this is not a whole-repository coverage percentage, nor evidence that every
screen/flow is tested. Java line/branch coverage has not been instrumented.
Passing counts do not replace measuring the remaining gaps.

`qa/run-tests.sh` was syntax-checked; the component commands above were executed
directly. The combined wrapper has not itself been run end-to-end in this pass.

### Issues found and fixed

The first regression run intentionally exercised expectations before fixes.
Auth security tests reproduced 2 failures; payment/sale tests reproduced 12
failures; cart arithmetic/input assertions also failed before their fixes.
Not every additional boundary test required a production-code change.

| Issue | Cases | Before | Fix and regression evidence |
| --- | --- | --- | --- |
| QA-001, P0: failed login counter never committed | AUTH-09/10 | Failed password threw a runtime exception, rolling back the saved counter; five attempts could never lock the account. | Dedicated `FailedLoginException` is the only login exception excluded from rollback. `AuthSecurityIntegrationTest` uses separate real HTTP/service transactions, verifies each persisted counter and final lockout. |
| QA-002, P0: disabled users could refresh/OTP-login | AUTH-12; SHOP-07 subset | Refresh issued tokens without rechecking account status. | Shared token issuer now checks active status for all login methods. Integration tests cover disabled password, refresh and phone OTP, plus valid existing auth flows. Real Google/Facebook account-disable flows still require provider testing. |
| QA-003, P0: payment branch/tenant boundary bypass | PAY-04 | Idempotent retry could reveal another branch's payment; deletion checked shop but not branch. A foreign-shop existing ID was not rejected explicitly. | Check both shop and branch before returning or mutating; reject foreign IDs. `PaymentServiceTest` asserts no writes for cross-branch retry/delete and foreign-shop ID. |
| QA-004, P0: payment could be attached to wrong customer/branch sale | PAY-03/04 | Request customer and linked sale were loaded independently; the sale branch/customer were not matched. | Require current branch and matching customer; all linked-sale payment sums/reversals use branch-scoped queries. Tests cover rejection and correct partial-payment/deletion balance. |
| QA-005, P1: retrying a deleted payment reported stale success | PAY-05 | Existing soft-deleted row was returned as though the payment succeeded. | Return conflict without resurrecting or reapplying it; idempotent active payment still returns once without writes. |
| QA-006, P0: checkout payment missing branch ID | POS-07 | Initial Java sale payment had null branch, disappearing from branch-filtered payment views. | Assign current branch when constructing initial payment. `SaleServiceTest.initialSalePaymentHasBranchAndCorrectDiscountedVat` captures the saved payment. |
| QA-007, P0: app VAT/discount and paisa rounding disagreed with API | POS-03 | App applied VAT before discount; Java applied VAT after discount. Example: subtotal 200, discount 20, VAT 5% was 190 locally vs 189 on API. | Shared `InvoiceTotals` rounds each line, subtracts rounded discount, then taxes; cart, checkout preview, A4 and thermal totals use it. Cart + invoice tests and the Java sale test share the 189/89 fixture. Existing historical sale rows have NOT been rewritten. |
| QA-008, P1: unsafe cart/voice quantities and monetary inputs | POS-02 | NaN/infinite/fractional quantities, invalid VAT/amounts and negative loyalty redemption entered cart state. Java could narrow quantities above int range. | Reject invalid state at setters; bound Java quantities before narrowing. Voice prevalidates the entire selection and explains whole units in BN/EN before changing the cart; buttons use whole units to match the existing API's integer-stock contract. Quantity, money and voice regressions pass. |
| QA-009, P1: invalid configured payment fees | PAY-07 | Negative, >100%, NaN and infinite fee values were saved. | Validate finite 0..100 fee before mutation; four parameterized regressions pass. |
| QA-010, P2: analyzer cleanup | UI-03 subset | Two pre-existing missing-braces lints in investor selector. | Added braces without changing validation behavior; final analyzer result recorded above. |

### Automated coverage map (subsets, not full acceptance)

| Case area | Test sources | What is actually exercised |
| --- | --- | --- |
| AUTH-01/03/04/07/08/09/10/11/12/13/14/15/16 | Auth `AuthFlowIntegrationTest`, `AuthSecurityIntegrationTest`, `service/FacebookTokenVerifierTest` | Real auth HTTP/security/JPA transactions with H2; token rotation/reset/device isolation/lockout; Facebook response/audience/missing-email parsing with mocked Graph HTTP. No real provider/SMTP/Redis or PostgreSQL certification. |
| STOCK-02/03, SHOP-02/04, PAY-01..08, POS-06/07 and STOCK-06 | Business `ProductServiceTest` (11), `PaymentServiceTest` (20), `SaleServiceTest` (10) | Validation, scoping, idempotency and captured write payloads with mocked repositories. This does NOT prove concurrent DB locking or transaction rollback under PostgreSQL. |
| POS-01/02/03/04 | Flutter `cart_validation_test.dart`, `invoice_totals_test.dart`, `voice_bill_validation_test.dart` | Cart setters, empty/due rejection before storage, shared arithmetic and voice-quantity model validation. Not a full persisted checkout or native speech test. |
| SYNC-01..05 | Flutter `local_collection_test.dart` | Real temporary Hive reads/writes/watches across shops, pending edits/tombstones, older/equal/newer remote merges and remote deletion. Not an HTTP sync/reconnect E2E test. |
| SYNC-07/08, SUP-03, SHOP-03, SUB-01/02, REP-02, SUPP-01 | Existing business sync, purchase receipt, branch, subscription, sales trend and support suites | Existing unit/controller subsets passed; production services/provider callbacks still need acceptance tests. |
| UI-01/03/04, REP-03/04, NOTIF-02/03 | Existing Flutter responsive, typography, friendly-error, report-localization and announcement tests | Selected widths/large text, report export metadata/Bangla rasterization, safe errors and model parsing. Not every screen/card, dialog lifecycle or physical PDF/print verified. |
| UPD-01..05, UI-02 | Existing Flutter app-update/splash tests; business `AppUpdateServiceTest`/`PlatformAdminServiceTest` | Version/store policy and auth gates, native adapter mocked outcomes, first rendered Flutter brand frame. No real Play Store update or Android cold-start recording in this pass. |

### Pending acceptance work / release blockers

These are open test work, not silently accepted successes:

1. P0 full offline checkout/payment/return + process death + reconnect on two
   devices; verify actual server stock, balances, credit limits and batch
   compensation. Reconcile any historical VAT discrepancy without rewriting
   real financial records automatically. Also audit historical Java-created
   payments with null branch IDs: the constructor fix prevents new occurrences,
   but existing live rows were not backfilled or repaired in this local pass.
2. P0 PostgreSQL integration for concurrent last-stock sales, concurrent
   payments, rollback/idempotency, migrations, and authorization on every
   controller/role/shop/branch. Mockito and H2 do not prove these.
3. P0/1 real sandbox Google/Facebook, SMTP delivery, bKash callback/reconcile,
   AI credit deduction and Play internal-track mandatory update/cancellation.
4. P1 all-screen device review in Bangla/English, large text, permissions and
   keyboards; physical thermal receipt and exported Bangla PDF inspection.
5. P0 independent backup restore, VM restart/health, TLS/public endpoint and
   admin-access security checks in a disposable environment.

No APK was built/installed, no services deployed, and no real account/shop data
or credentials were changed. The next device/sandbox pass must be explicitly
scheduled with the appropriate test environment; local passing tests alone are
not a production release approval.
