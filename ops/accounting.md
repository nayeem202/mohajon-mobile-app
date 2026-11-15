# Financial statements implementation

## Scope

1. Correct existing local P&L (net-of-output-VAT revenue, dated sales returns,
   cost reversal on the return date, no purchase/loan/capital double counting).
2. Branch-specific, owner-confirmed opening balances at an explicit cutover date.
3. Capital contributions/drawings, borrowing/principal/interest repayments,
   fixed assets and recorded depreciation; auditable corrections.
4. Java double-entry ledger for direct API mutations and offline sync, with
   stable source identities, transaction-scoped locks, revisions/reversals.
5. Premium bilingual income statement/balance sheet, quality warnings, date and
   branch scoping, offline cached reports and PDF/XLSX exports, regression tests.

## Accounting decisions

- Reports are management reports, not an assertion of audited/statutory or tax
  compliance. Accounting/tax policy must be reviewed for the actual business.
- Revenue excludes collected output VAT; purchase costs remain recorded book
  cost (no recoverable-input-VAT deduction without source tax detail).
- Record inventory purchases as assets, recognize recorded item cost at sale,
  and reverse cost at the return date. No current selling-price stock valuation.
- Opening balances are immediately BEFORE cutover; only source events on/after
  cutover are posted. Old records are retained, not rewritten as opening entries.
- Never invent opening capital to plug a difference. Opening debits and credits
  must match; negative retained earnings can explicitly represent past losses.
- Branch identity comes from authenticated server context, not request shop IDs.
- Shop-wide legacy vendor/investment records require explicit owner classification
  and branch assignment; do not guess equity versus loan or duplicate purchase
  linkage. Unclassified/ambiguous sources make reports require review.
- Fixed-asset depreciation is explicitly recorded by the owner, not silently
  estimated from an invented useful life or residual value. Check carrying-value
  limits. Owner withdrawals and loan principal are not operating expenses.
- Preserve original invoice total/initial payment identity on new sales so
  returns do not rewrite original revenue and sync cannot duplicate cash receipts.
- Existing historical amounts with missing evidence are flagged, not presented
  as reconciled merely because the accounting equation balances.
- Ledger source revisions retain the original journal and append equal/opposite
  reversals plus replacement entries. Retry of the same content does not post
  again. Corrections restate source periods; accounting period locks are not an
  audited-close feature in this release.
- Financial reports are server-authoritative. Offline viewing uses explicitly
  marked cached snapshots; pending operations are not represented as final
  server balances. Offline manual finance entries use stable IDs and replay after
  normal domain sync, with validation failures retained for user correction.

## References used for policy design

- [Financial-statement foundations](https://www.business.govt.nz/strategy-and-performance/strategic-finance/understanding-your-balance-sheet)
- [IAS 2 inventory cost and expense recognition](https://www.ifrs.org/content/dam/ifrs/publications/pdf-standards/english/2022/issued/part-a/ias-2-inventories.pdf?bypass=on)
- [IAS 16 depreciation principles](https://www.ifrs.org/issued-standards/list-of-standards/ias-16-property-plant-and-equipment/)

## Progress

- [x] Local P&L correction and fixtures.
- [x] Java schema, posting engine, atomic source integration and owner APIs.
- [x] Opening setup, finance entries/classification and premium statements UI.
- [x] Offline cache/outbox, exports and integration/navigation.
- [x] Java/Flutter regression suites and `flutter analyze`.

## Entry points and operating notes

- Owner: Reports > Income Statement / Balance Sheet / Financial accounts.
  Existing Profit & Loss shortcuts open the corrected Income Statement.
- Select the branch through the existing entitled branch selector, then confirm
  its opening balances. Changing scope blocks an unfinished financial form.
- Financial accounts provides manual transactions, missing-source review,
  immutable reversal history and a dated debit/credit journal.
- Regular sales/collections/purchases/returns are projected automatically.
  Sources without fund/type evidence (including old expenses and supplier or
  investor ledgers) remain incomplete until the owner explicitly classifies them.
  IGNORE means the owner has confirmed a duplicate/noncash source, not silent
  deduplication by matching amount/date.
- Original invoice/payment evidence is preserved on new sales. Historical
  collections require confirmation of only the amount missing from payment rows;
  a return-adjusted paid header is not reliable evidence of an original receipt.
- Current product quantity × recorded unit purchase price is only an inventory
  cross-check, not a substitute valuation method. Differences (including direct
  quantity edits/price changes) require review; no unexplained capital is posted.
- PDF/XLSX exports include branch/period/snapshot and quality/offline warnings.
  PDF uses the existing Bengali shaping/raster pipeline. Exports are private
  business documents; use an appropriate storage/sharing policy.
- Accounting caches/outboxes are separate from ordinary collection sync and
  removed by intentional local business-data clearing. Server financial data is
  included in the existing owner-only shop-data clear transaction.
- Reconciliation currently rebuilds a deterministic full branch projection while
  locking the shop. High-volume latency/locking and retention need benchmarking;
  an incremental high-volume posting engine is not claimed by these tests.

Verification cases/results and remaining PostgreSQL/device/accounting-review
release gates: [../qa/accounting.md](../qa/accounting.md).

The initial implementation did not authorize a live DB migration, deployment or
APK build/install. The user's subsequent explicit migration request was completed
on local PostgreSQL `authdb.hk` (V58 to V60), with backup, SQL-clone rehearsal,
rollback-only ledger checks and unchanged historical-data fingerprints; see
[../qa/postgresql-accounting-migration.md](../qa/postgresql-accounting-migration.md).
No service/VM deployment or APK install was performed. Existing dirty worktrees
are preserved.
