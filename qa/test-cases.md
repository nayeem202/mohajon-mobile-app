# Test-case catalogue

Priority: **P0** = security, data integrity or core access; **P1** = important
functionality; **P2** = polish. Each row specifies actions and the expected
assertion. All cases require execution evidence in `results.md`; catalogue
membership alone is not coverage. `A` is suitable for automation, `D` requires
device/E2E, `X` requires an external sandbox/infrastructure. Some cases need both.

## Authentication and sessions

| ID | Priority/type | Test actions → expected result |
| --- | --- | --- |
| AUTH-01 | P0 A | Register valid unique email/phone → hashed password, OWNER account, verification message; no tokens before verification. |
| AUTH-02 | P0 A | Register duplicate email (including changed case/whitespace) or phone → conflict; no duplicate row. |
| AUTH-03 | P1 A | Submit missing/invalid email, short password or phone → validation error without stack trace. |
| AUTH-04 | P0 A | Verify correct OTP, then reuse it → first succeeds; reuse fails. |
| AUTH-05 | P0 A | Submit wrong/expired OTP repeatedly → rejected and attempt/expiry limits enforced. |
| AUTH-06 | P1 A | Resend before current verification code expires → throttled; existing code remains usable. |
| AUTH-07 | P0 A | Login before email verification → forbidden, no session. |
| AUTH-08 | P0 A | Login verified account → access/refresh pair; protected `/me` accepts only valid token. |
| AUTH-09 | P0 A | Submit wrong password five times across separate requests → persisted lockout; correct password cannot bypass it. |
| AUTH-10 | P0 A | Let account lock expire; login correctly → failure counter and lock cleared. |
| AUTH-11 | P0 A | Refresh once, replay old token, then use new token → old rejected, valid rotated token still works. |
| AUTH-12 | P0 A | Disable account after login then refresh → no new credentials issued. |
| AUTH-13 | P0 A | Logout device A, refresh devices A/B → A rejected; B unaffected. |
| AUTH-14 | P0 A | Reset password with verified reset OTP → old password and old refresh tokens rejected. |
| AUTH-15 | P0 A | Request reset for unknown email → generic response, no account-existence disclosure. |
| AUTH-16 | P0 A/X | Google/Facebook token: invalid signature, expiry or wrong app audience → rejected; no account created. |
| AUTH-17 | P1 D/X | Back out of Google/Facebook consent → dismiss loading quietly, no raw cancellation error. |
| AUTH-18 | P0 D | Leave app inactive beyond access-token lifetime → automatic refresh, no needless logout. |
| AUTH-19 | P0 D | Go offline with expired access token → cached shop/data stay available; network failure does not erase session. |
| AUTH-20 | P0 D | Enable PIN/biometric lock, background/resume/process-kill → lock gate enforced; logout removes cached identity. |

## Shop, branches and staff authorization

| ID | Priority/type | Test actions → expected result |
| --- | --- | --- |
| SHOP-01 | P0 D | Complete shop setup, restart offline → shop name/phone/category/logo retained. |
| SHOP-02 | P0 A/D | Read/write shop B IDs as shop A → denied; no information or stock leaks. |
| SHOP-03 | P0 A/D | Trial account creates/switches branch twice → Business restriction enforced every attempt, server-side too. |
| SHOP-04 | P0 A/D | Business owner creates branch; switch A/B → products, sales, payments/reports scoped correctly. |
| SHOP-05 | P1 D | Open branch/online-only actions offline → immediate localized explanation, no long spinner. |
| SHOP-06 | P0 A/D | Restricted staff adds/deletes products, expenses, branches or users → permission matrix enforced by API, not just hidden controls. |
| SHOP-07 | P0 A/D | Remove/deactivate staff → further privileged operations denied; historical audit remains. |
| SHOP-08 | P1 D | Upload invalid/large customer/shop image, then valid image → safe validation, correct preview/upload/cache. |

## Products, stock and POS

| ID | Priority/type | Test actions → expected result |
| --- | --- | --- |
| STOCK-01 | P1 A/D | Create product for each shop category → relevant BN/EN category and unit choices, not default grocery. |
| STOCK-02 | P0 A | Submit negative/nonfinite prices, negative stock or alert threshold → rejected before save. |
| STOCK-03 | P0 A/D | Adjust stock +/-; attempt below zero → correct stock or rejection without partial mutation. |
| STOCK-04 | P1 D | Search by name/barcode + category; clear filters → correct subset and restored list. |
| STOCK-05 | P1 D | Empty low-stock list then populated list → search hidden only when no products available. |
| STOCK-06 | P0 A/D | Sell expired/deleted/unavailable/out-of-stock product → rejected without sale/payment/stock changes. |
| STOCK-07 | P1 D | Scan barcode twice; unknown barcode; deny camera → correct item increment or friendly explanation. |
| POS-01 | P0 A | Add same product twice; change/remove quantity → one cart line, correct totals and preserved item identity. |
| POS-02 | P0 A | Submit NaN/infinity/negative discount, VAT, payment or quantity → rejected; cart/local storage remain valid. |
| POS-03 | P0 A | Compute decimal prices/VAT/discount/paid/due → paisa rounding matches receipt and server. |
| POS-04 | P0 A/D | Save empty cart, zero-total sale, or due without customer → no persisted sale. |
| POS-05 | P0 A/D | Cash, partial and fully due checkout → correct paid/due/status, payment method and branch. |
| POS-06 | P0 A | Retry same sale ID after lost response → one sale, one stock decrement, one payment. |
| POS-07 | P0 A | Sale paid upfront → generated payment carries current branch and appears in that branch's ledger. |
| POS-08 | P0 A/D | Duplicate product lines and concurrent sales of final stock → no oversell or negative stock. |
| POS-09 | P0 A/D | Fail write midway through checkout → no partial sale/stock/payment/customer mutation. |
| POS-10 | P0 A/D | Exceed customer credit limit or redeem excessive loyalty points → blocked; successful sale earns/redeems once. |
| POS-11 | P0 A/D | Return sale items partially/fully then retry/over-return → stock, refund and due correct; cannot return more than sold. |
| POS-12 | P1 D | Save receipt offline → Downloads file exists and localized success message shown. |
| POS-13 | P1 D/X | Offline digital invoice/WhatsApp share → immediate internet-required notice; online share works. |
| POS-14 | P1 D | Print 58/80mm receipt with Bangla names → shop header, aligned totals, legible glyphs, Mohajon footer only. |

## Customers, payments and suppliers

| ID | Priority/type | Test actions → expected result |
| --- | --- | --- |
| CUST-01 | P1 A/D | Create/edit/import/merge customer → fields/logo persist; no duplicate ledger or lost linked transactions. |
| CUST-02 | P0 A/D | Customer statement with sales, partial payments, returns and opening balance → reconciled outstanding balance. |
| CUST-03 | P1 D | Recovery/follow-up and grow-customer cards with long BN/EN text → complete readable actions, no ellipsis hiding meaning. |
| PAY-01 | P0 A | Add zero/negative/NaN/infinite amount → rejected before persistence. |
| PAY-02 | P0 A | Pay outstanding sale exactly/partially/above due → correct status/balance; overpayment rejected. |
| PAY-03 | P0 A | Pay sale using different customer's ID → rejected; neither customer's ledger changes. |
| PAY-04 | P0 A | Add/retry/delete payment ID belonging to another branch/shop → denied without disclosure or mutation. |
| PAY-05 | P0 A | Retry deleted payment ID → cannot resurrect/apply payment again or report stale success. |
| PAY-06 | P0 A | Delete own-branch payment → soft-deleted; sale paid/due/status recomputed from active branch payments. |
| PAY-07 | P1 A | Disabled method, missing required reference, invalid fee → validation error; no save. |
| PAY-08 | P0 A | Staff configures payment method → forbidden; owner-only access verified. |
| SUP-01 | P1 A/D | Supplier categories by shop in BN/EN; add/edit/contact/search → correct catalogue and retained data. |
| SUP-02 | P0 A/D | Purchase with new/existing product and partial supplier payment → correct stock, cost and supplier due. |
| SUP-03 | P0 A/D | Receive purchase order in parts then retry same receipt → received quantities/stock applied exactly once. |
| SUP-04 | P0 A/D | Return supplier goods and reconcile receipt → cannot exceed received stock; due/stock agree. |
| SUP-05 | P1 D | Purchase planner/receipt long names on small screen → no clipped amount/action. |
| EXP-01 | P0 A/D | Add/edit/delete expense then sync → totals/audit correct and branch-scoped. |
| INV-01 | P0 A/D | Investor principal/profit/payout/create/delete → balance and payout history reconcile; cannot overpay. |
| INV-02 | P1 D | Day closing records actual cash and discrepancy; reopen/history → consistent expected cash and permissions. |

## Offline storage and synchronization

| ID | Priority/type | Test actions → expected result |
| --- | --- | --- |
| SYNC-01 | P0 A | Same document ID under two shops → isolated reads, updates, pending queues and deletes. |
| SYNC-02 | P0 A | Local pending edit then pull newer server document → unsynced local intent preserved. |
| SYNC-03 | P0 A | Local pending deletion then server pull → tombstone preserved and queued for push. |
| SYNC-04 | P0 A | Synced doc receives older/equal/newer remote doc → no stale overwrite; newer document applied as synced. |
| SYNC-05 | P0 A | Remote soft deletion → hidden in normal lists, visible when including deleted; not requeued as local edit. |
| SYNC-06 | P0 D | Offline sale/payment/expense; kill/restart; reconnect → data survives, sync exactly once, correct balances/stock. |
| SYNC-07 | P0 A/D | Partial push failure, timeout or token expiry during sync → unsent data remains pending; retries safe. |
| SYNC-08 | P0 A/D | Switch shop/branch during pull/push → no cross-tenant writes or sync cursor corruption. |
| SYNC-09 | P0 D/X | Two devices sell/edit same last-stock document offline → conflict policy verified against real API and database. |
| SYNC-10 | P0 A/D | Export backup; restore valid/invalid/cross-shop file → restored data correct; malformed/unowned data safely rejected. |

## Reports, UI and localization

| ID | Priority/type | Test actions → expected result |
| --- | --- | --- |
| REP-01 | P0 A/D | Sales summary/profit-loss/product/expense/due/payment/inventory/VAT/ledger reports → agree with seeded transactions including refunds/deletions. |
| REP-02 | P1 A/D | Today/custom range/6 months/year trends, midnight boundaries and empty period → correct inclusive dates/buckets/totals. |
| REP-03 | P1 A/D | All report titles, stock movement/dead stock cards in BN/EN → no English-only UI or broken Bangla. |
| REP-04 | P1 D | Export Bangla product/customer names to PDF → shaped, readable glyphs, no truncation or missing font. |
| UI-01 | P1 A/D | AI/subscription/email/purchase dialog at 320/360/412dp, long names and large text → no RenderFlex overflow. |
| UI-02 | P2 A/D | Splash cold/warm starts → logo/text appear together; no black blink; smooth navigation. |
| UI-03 | P2 A/D | English typography, default avatar, premium cards/report round icons → consistent app tokens; no accidental Poppins/Inter. |
| UI-04 | P1 A/D | Every API outage/invalid response/401/403/timeout → friendly BN/EN error, no SQL, server body or exception string leaked. |
| UI-05 | P1 D | Keyboard, back, rotation, Android permission denial and screen reader → actions reachable, no trap or silent failure. |

## Subscription, AI and external payments

| ID | Priority/type | Test actions → expected result |
| --- | --- | --- |
| SUB-01 | P0 A/D | Trial/free/business/expired plans call guarded APIs directly → server entitlement consistent with UI, repeat attempts cannot bypass. |
| SUB-02 | P0 A/X | bKash create/execute/callback/reconcile with duplicate/failed/cancelled callbacks → no double activation/charge. |
| SUB-03 | P0 A/D | AI conversation succeeds/fails/retries → correct welcome/monthly credit deduction; failed requests not charged twice. |
| SUB-04 | P1 D/X | BN/EN UI with opposite-language prompt → understandable reply in requested language. |
| SUB-05 | P1 A/D | AI provider timeout/quota/unsupported region/invalid JSON → actionable friendly error; no exposed API key. |
| SUB-06 | P1 D/X | Voice microphone denied/offline/stopped session → clear status, released microphone, retry works. |

## Notifications, support, updates and operations

| ID | Priority/type | Test actions → expected result |
| --- | --- | --- |
| NOTIF-01 | P0 A/D | Admin-only send API as anonymous/user/admin → 401/403/success respectively, no role bypass. |
| NOTIF-02 | P1 A/D | Login with active expiring announcement → dialog after successful login, dismiss closes; next login repeats before expiry only. |
| NOTIF-03 | P1 A/D | Expired/missing-expiry announcement or ordinary navigation → no unwanted embedded banner/dialog. |
| NOTIF-04 | P1 D/X | Push targeted/all, read/delete/unread count/permission denial → correct recipient and state. |
| SUPP-01 | P1 A/D | Support message/reply/attachment with staff and customer → readable distinct senders, safe upload and authorization. |
| UPD-01 | P0 A | Disabled policy or supported version/build → no mandatory gate. |
| UPD-02 | P0 A/D | Unsupported version/build after login/restored session → mandatory gate before shop UI, back cannot bypass. |
| UPD-03 | P0 A/D | Offline cached mandatory policy/unknown policy → cached requirement enforced; unknown network failure does not falsely lock app. |
| UPD-04 | P0 A/D/X | Update/cancel/resume from Play Store immediate flow → correct package; cancellation keeps gate; installed new version rechecked. |
| UPD-05 | P0 A | Nonadmin edits policy, invalid versions/store URL or disabling policy → authorization/validation/kill switch work. |
| OPS-01 | P0 X | Fresh PostgreSQL migrations and upgrade from backup → schema/data correct; rollback/restore procedure proven. |
| OPS-02 | P0 X | VM reboot/service crash → services restart; health checks reflect dependencies; no localhost-only mobile endpoints. |
| OPS-03 | P0 X | Restore independent encrypted DB + uploaded-image backup to another machine → shops/balances/receipts recover within agreed RPO/RTO. |
| OPS-04 | P0 A/X | Public APIs/admin/static files/logs → no secrets, private backups or cross-user data exposed; TLS/rate limits tested. |
