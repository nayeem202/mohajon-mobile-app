# FAQ coverage — 2026-10-22

Accounting increment (2026-10-23): 4 additional bilingual questions cover opening
setup, capital/loans/assets, review warnings and offline financial statements.
Current catalogue: **93 questions**, still across the same 12 topics. Report-types
copy now includes Income Statement, Balance Sheet and Financial accounts.
The original verification results below describe the 2026-10-22 FAQ increment;
the latest full suite is recorded in [accounting.md](accounting.md).

The Help & support screen now uses a bundled, offline-readable catalogue of
89 questions across 12 topics. Every question, answer and topic title has both
Bangla and English content. The selected app language controls display;
search matches both languages, including answer text and topic names.

Content: `lib/features/profile/data/help_faq_catalog.dart`.
UI: `lib/features/profile/presentation/widgets/help_faq_section.dart`.

## Topics

1. Getting started/account, verification, recovery, social sign-in, shop details.
2. Product categories/units, stock adjustments, search, barcode, batch/expiry.
3. POS, walk-in/due/partial sales, discounts/VAT, loyalty, history and returns.
4. Receipt downloads, location, offline sharing limits, thermal printing.
5. Customer images/import/merge, credit limits, payments, statements and growth.
6. Suppliers, purchases, receipts/partial receipts, planner, returns and proof.
7. Expenses, day closing, cash variance, reports, export and business insights.
8. Staff/permissions, audit history, branches, investors and investment payouts.
9. Subscription/trial, Business entitlement, payments, pending status, AI credits.
10. AI questions/language, voice billing, provider errors and action confirmation.
11. Offline limits, online-only actions, sync, multiple devices, backup/restore.
12. App locks/sessions, lost devices, notifications, announcements, updates,
    deletion and support reporting.

## Content boundaries

- Plan prices, credit allowances and durations are not hardcoded as promises.
- Recording a payment does not imply that a real money transfer occurred.
- Wi-Fi/online status does not guarantee server reachability or completed sync.
- Offline access requires existing local records and applicable access/session.
- JSON export is not described as a complete server/image backup or an encrypted
  archive; backup files may contain private business data.
- Do not uninstall/clear storage/recreate transactions to fix pending sync.
- Whole quantities match the current integer-stock/sale API; every printer,
  automatic order placement and provider availability are not guaranteed.
- Existing placeholder contact email/phone values were NOT changed. FAQs direct
  problem reports to the existing in-app support conversation.

## Verification

`test/help_faq_catalog_test.dart`:

- Unique topic/question IDs; nonempty questions and answers in both languages.
- All major feature areas represented; no missing FAQ-control translations.
- English/Bangla search, whitespace/case normalization and multiword/topic search.

`test/help_faq_section_test.dart`:

- Search, expand/collapse, no-results reset and topic selection in both languages.
- Switching app language updates an expanded answer without mixed-language copy.
- Full Help page at 320dp with 2x text in both languages; this test exposed and
  led to fixes for pre-existing contact-title/copy-hint horizontal overflow.

Results:

- Focused FAQ suite: 12 passed.
- Full Flutter suite: 102 passed, 0 failures (`flutter test --concurrency=2
  --reporter expanded`, 22 seconds).
- Final full-project `flutter analyze`: PASS, no issues found (309.6 seconds).
  The first run found one missing-braces informational lint in the new test;
  it was fixed, then all 12 FAQ tests and the full analyzer were rerun successfully.

No APK build, installation, service change or deployment is part of this update.
