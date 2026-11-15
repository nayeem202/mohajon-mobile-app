# Mohajon quality checks

This folder is the app + Java services' test plan and execution record. A listed
case is **not** a claim that it has passed. See [test-cases.md](test-cases.md) for
the catalogue and [results.md](results.md) for dated evidence and open work.
The subsequent bilingual FAQ expansion and its checks are recorded in [faq.md](faq.md).
Financial-statement coverage and remaining release checks are in [accounting.md](accounting.md).
The completed local PostgreSQL V60 migration is recorded in
[postgresql-accounting-migration.md](postgresql-accounting-migration.md).

## Scope and safety

- Flutter: `inventory_1/test`, including real temporary Hive storage tests.
- Business API: sibling `haalkhata-service/src/test` (Java 21).
- Authentication API: sibling `auth-service/src/test` (Java 25); its integration
  tests use the `test` profile's in-memory H2 database and fake email sender.
- Device, PostgreSQL, external identity/payment/AI providers and Play Store
  checks remain separate acceptance tests. Mock tests cannot certify them.
- Never point test datasource URLs at the test VM or a real shop database.
  Use synthetic shops/users and disposable databases. Never copy real keys,
  passwords, personal data or database dumps into test fixtures or this folder.
- Do not install, build an APK, deploy or send real notifications as part of the
  automated suite. Those actions require an explicit request.

## Run automated checks (WSL)

From the Flutter repository:

```bash
bash qa/run-tests.sh
# Or run one component:
bash qa/run-tests.sh flutter
bash qa/run-tests.sh business
bash qa/run-tests.sh auth
```

The script continues to the next component after a failure and returns nonzero
if any component failed. Logs are in ignored `qa/artifacts/`. Flutter coverage is
in ignored `coverage/lcov.info`; Java XML/HTML reports are in each service's
`build/test-results/test` and `build/reports/tests/test`. Java source/tests are in
separate Git repositories and must be committed there separately.

The run ends with `flutter analyze`. That check is not an APK build and does not
replace runtime tests. Environment overrides: `FLUTTER_BIN`, `AUTH_SERVICE_DIR`,
`BUSINESS_SERVICE_DIR`, `AUTH_JAVA_HOME`, `BUSINESS_JAVA_HOME`.

Optional existing admin-portal tests (Node 24, run from the sibling portal):

```bash
export PATH=/home/pc/.nvm/versions/node/v24.18.0/bin:$PATH
npm test -- --watch=false --runner-config=/mnt/c/Users/PC/IdeaProjects/inventory_1/qa/vitest.config.mjs
```

The one-worker runner configuration avoids excessive worker startup on WSL/NTFS.
No portal dependencies are installed or upgraded by these commands.

## Acceptance/release gate

1. Run all automated suites; record counts, failures and analyzer findings.
2. Use two shops, two branches, OWNER and restricted STAFF accounts, plus
   trial/expired/business subscriptions in a disposable test environment.
3. Exercise every P0 case on an Android phone online, offline, after process
   death, and after reconnection. Validate server balances/stock after sync.
4. Check Bangla and English, 320/360/412 dp widths and enlarged text; inspect
   exported Bangla receipts/PDFs and a physical thermal print.
5. Check PostgreSQL migrations on a disposable restored database and prove
   backup restoration. H2 auth tests are not PostgreSQL compatibility proof.
6. Run provider sandboxes and Play internal testing with the actual signed
   artifact. Mark blocked/unrun cases explicitly; never relabel mocks as E2E.
7. No P0 failures may remain for a production release. Review P1 issues and
   document any accepted risk before release.
