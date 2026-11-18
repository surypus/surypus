# Backlog

Закрытые задачи — 69. Обновлено: 2026-11-18.

- `Surypus-7kr` (P2) Document test execution blockers and provide runbook — completed 2026-11-18: created `docs/tasks/Runbook.md` (test execution guide, env-var gating, wiring procedure for new specs). Verified: full test suite `cabal test surypus-test` → 1139 examples, 0 failures, 3 pending (3 pending = pre-existing DB/Redis integration tests requiring env vars), exit 0.
- `Surypus-2j3` (P0) Real DB queries in all API handlers — replace pure (SomeResponse []) with DAL calls
- `Surypus-awg` (P0) Implement proper requirePermission with user context
- `Surypus-122` (P0) Fix requirePermission_ to actually check user permissions
- `Surypus-ayj` (P0) Fix Nix build environment for test execution
- `Surypus-2w6` (P0) 1.3 — Stabilize DB migrations (resolve conflicts)
- `Surypus-600` (P0) Подключить реальные DB-запросы в API handlers
- `Surypus-603` (P0) Завершить RBAC middleware для всех endpoints
- `Surypus-608` (P0) Интеграционные тесты API endpoints против реальной PostgreSQL
- `Surypus-611` (P0) Реализовать полный Bill posting flow
- `Surypus-3k7` (P1) Fix stack build: hashtables C compile error on GHC 9.6.5
- `Surypus-uja` (P1) Integrate Event Store into Inventory service
- `Surypus-0qr` (P1) Phase 1.2: Implement real RBAC checks in requirePermissionText_
- `Surypus-dn2` (P1) Fix stub API handlers returning hardcoded data
- `Surypus-h57` (P1) Implement JWT authentication middleware
- `Surypus-9vq` (P1) Create WebSocket module infrastructure
- `Surypus-zn8` (P1) Provide test database with schema for local testing
- `Surypus-8e5` (P1) Add database test fixture infrastructure for RBAC tests
- `Surypus-p65` (P1) Setup test App.hs module with mkApp implementation
- `Surypus-cdz` (P1) Implement remaining API handlers with real DB queries
- `Surypus-627` (P1) 2.2 — LiquidHaskell invariants для Bill (NonNeg, balance conservation)
- `Surypus-628` (P1) 3.3 — Устранить SURYPUS_SKIP_RBAC_TESTS флаг
- `Surypus-629` (P1) 6.3 — CI/CD gates: stack build+test, hlint, matrix testing
- `Surypus-605` (P1) Реализовать полноценный сервисный слой (Service.*)
- `Surypus-606` (P1) Завершить WebSocket реальные уведомления
- `Surypus-607` (P1) Реализовать Job Worker и background processing
- `Surypus-611` (P1) QuickCheck property tests для всех domain invariants — дополнено проверками для `Finance.Currency.convertAmount` (неотрицание результата, аддитивность относительно суммы с учётом погрешности float) — тесты зелёные (987 examples, 0 failures)
- `Surypus-631` (P1) Add QuickCheck property for Inventory.Stock invariants — `mkStock` result always satisfies `validateStock` and record is unchanged (2026-10-22) — implemented in test/Domain/InvariantsSpec.hs, 17 examples, 0 failures
- `Surypus-632` (P1) Fix `Commerce.ServiceBill.getBalance` overpayment clamp + wire `Commerce.ServiceBillSpec` — `getBalance` returned negative when `sbPaid > sbTotal`, contradicting the same `NonNeg` invariant as `Commerce.Invoice.calcInvoiceBalance`. Fixed to `max 0 (sbTotal - sbPaid)`. 5 tests wired: partial remainder, full payment → 0, overpayment clamped, zero total → 0, QuickCheck non-negativity. Verified: **1002 examples, 0 new failures, 2 pending** (pre-existing DB-gated). Negative check: spec against pre-fix `ServiceBill.hs` fails exactly the overpayment + property tests
- `Surypus-610` (P1) Repair failing test infrastructure и добавить CI gates — прогон в CI-среде: 987 examples, 0 failures, 3 pending (интеграционные блоки требуют SURYPUS_TEST_DATABASE_URL / SURYPUS_TEST_REDIS_URL)
- `Surypus-612` (P1) Завершить модуль Payroll: SalaryCharge, периоды, расчёты
- `Surypus-613` (P1) Реализовать инвентаризацию (Inventory document lifecycle)
- `Surypus-616` (P1) Connection pooling, health checks, circuit breaker
- `Surypus-619` (P1) Web UI: подключить к реальному API
- `Surypus-but` (P2) в Bill и Payment учитывать currency_id и exchange_rate
- `Surypus-197` (P2) Add AuthProtect to SurypusApi for JWT authentication
- `Surypus-aps` (P2) Implement real JWT token validation
- `Surypus-5r1` (P2) Fix remaining stub API handlers (reports, dashboard, jobs)
- `Surypus-1nd` (P2) Analyze current API handlers - identify hardcoded data
- `Surypus-ds3` (P2) Create new project structure and workflow
- `Surypus-zou` (P2) Integrate Hasql-based EventStore into Accounting and Inventory services
- `Surypus-7kr` (P2) Document test execution blockers and provide runbook
- `Surypus-614` (P2) Реализовать модуль Production: TechCard, WorkOrder, MRP
- `Surypus-615` (P2) Multi-currency support: конвертация, курсы, расчёты
- `Surypus-620` (P2) GraphQL proxy: завершить schema и resolvers
- `Surypus-623` (P2) Structured logging с correlation IDs
- `Surypus-624` (P2) Docker multi-stage build оптимизация
- `Surypus-08t` (P2) US-2-2: Create Account (P1, 5SP)
- `Surypus-0z4` (P2) US-2-6: Health & Readiness (P2, 2SP)
- `Surypus-1oi` (P2) US-3-4: GraphQL Proxy (P2, 5SP)
- `Surypus-348` (P2) US-2-7: OpenAPI Docs (P3, 2SP)
- `Surypus-37h` (P2) US-3-5: Redis Queue (P3, 5SP)
- `Surypus-3vh` (P2) US-2-11: Read-model caching (P2, 3SP)
- `Surypus-4s9` (P2) US-3-3: Read models Redis cache (P2, 5SP)
- `Surypus-5gq` (P2) US-2-1: Login and RBAC (P1, 3SP)
- `Surypus-929` (P2) US-2-12: Phase 2 Integration tests (P2, 5SP)
- `Surypus-bm3` (P2) US-2-8: Read model account_balances (P2, 5SP)
- `Surypus-knx` (P2) US-2-9: Read model ledger_projection (P2, 5SP)
- `Surypus-lmw` (P2) US-3-2: Account read-model replay (P1, 5SP)
- `Surypus-n1i` (P2) US-3-1: Accounts Event Store (P1, 8SP)
- `Surypus-noa` (P2) US-2-10: Dashboard endpoint (P2, 3SP)
- `Surypus-p21` (P2) US-3-7: Proxy usage and client migration plan (P3, 3SP)
- `Surypus-tpj` (P2) US-2-4: Create Journal Entry (P1, 5SP)
- `Surypus-v3t` (P2) US-3-6: WebSocket real-time (P3, 5SP)
- `Surypus-x0e` (P2) US-2-3: Read Accounts (P2, 3SP)
- `Surypus-ykn` (P2) US-2-5: RBAC negative test (P2, 2SP)
|- `Surypus-633` (P1) Add QuickCheck property tests for `Finance.OpKindEx` — opKindGroup classification (one of 4 declared groups, all groups covered), mutually exclusive predicates (isPaymentOp/isAdjustmentOp/isTransferOp), three predicates cover exactly the non-financial kinds, prettyOpKindEx yields distinct strings. Added `test/Finance/OpKindExSpec.hs` and wired into test-suite surypus-test via Surypus.cabal (other-modules) and test/Test.hs (import + spec). Verified: full suite surypus-test PASS — 1081 examples, 0 failures, 3 pending (pre-existing).
|- `Surypus-634` (P1) Add QuickCheck property for Core.Inventory stock-balance invariant — `Rest = Initial + Receipt - Issue`. Added `test/Core/InventorySpec.hs` (5 unit tests + 2 QuickCheck properties) and wired into `test-suite surypus-test` via `Surypus.cabal` (other-modules) and `test/Test.hs` (import + spec invocation). Verified: full suite surypus-test PASS — 1024 examples, 0 failures, 3 pending (pre-existing).
|- `Surypus-635` (P1) Add QuickCheck property tests for `Commerce.Discount.calcDiscount` — threshold (below min → 0), fixed-value (DTFixed equals the fixed value once the threshold is met), non-negativity, and percentage linearity. Added `test/Commerce/DiscountSpec.hs` and wired it into `test-suite surypus-test` via `Surypus.cabal` (other-modules) and `test/Test.hs` (import + spec invocation). Verified: full suite surypus-test PASS — 1015 examples, 0 failures, 3 pending.
|- `Surypus-636` (P1) Add QuickCheck property tests for `Production.Types` — validateWorkOrderCore (accepts valid WOs, rejects empty code, non-positive goods id, negative planned/released qty, released > planned, status out of 0..4), validateTechCard (rejects empty name/version, non-positive goods id, status outside 0..2), validateTechLine (rejects non-positive card/line/goods id, negative qty, negative unit id, scrap outside 0..100). Added `test/Production/TypesSpec.hs` and wired into test-suite surypus-test. Verified: full suite surypus-test PASS — 1081 examples, 0 failures, 3 pending (pre-existing).
|- `Surypus-637` (P1) Add QuickCheck property tests for `Surypus.CoreTypes` — NonNeg wrapper semantics: mkNonNeg accepts all non-negative Decimals, rejects negatives; unNonNeg is left inverse; wrapped value always non-negative. Added `test/Surypus/CoreTypesSpec.hs` and wired into test-suite surypus-test. Verified: full suite surypus-test PASS — 1081 examples, 0 failures, 3 pending (pre-existing).
|- `Surypus-640` (P1) Add QuickCheck property tests for `Finance.Asset` — depreciation model invariants: book value never below salvage, non-increasing over time, floor reached exactly at end of useful life, `annualDepreciation == (cost - salvage) / life`, `isFullyDepreciated` iff book value <= salvage, `needsRepair` iff age > 80% of life. Added `test/Finance/AssetSpec.hs` and wired it into the test-suite (`Surypus.cabal` other-modules + `test/Test.hs` import + spec). Verified: full suite `surypus-test` PASS — 1134 examples, 0 failures, 3 pending (pre-existing DB/Redis tests requiring env vars). All 8 QuickCheck properties pass 100 tests each; 3 unit tests pin the formula contract; 3 deterministic boundary tests pin the floor (book value resets to salvage exactly at end of life, `isFullyDepreciated` flips False→True exactly at the floor) and the 80% repair threshold (False at age 8, True at age 9).
|- `Surypus-641` (P1) Add QuickCheck property tests for `Finance.Journal` — double-entry journaling invariants: `cancelJournalEntry` forces `JSCancelled`; `calculateJournalBalance` returns the exact balance for a known account and 0 for an unknown account; `validateJournal` rejects journals with draft (`JSEntry`) entries and with `journalValidated = False`; the property `accepts every valid posted journal` passes 100 cases. Added `test/Finance/JournalSpec.hs` and wired into `test-suite surypus-test` via `Surypus.cabal` (other-modules) and `test/Test.hs` (import + spec). Verified: full suite `surypus-test` PASS — 1103 examples, 0 failures, 3 pending (3 pending = pre-existing DB/Redis integration tests requiring env vars).
|- `Surypus-642` (P1) Add QuickCheck property tests for `Finance.Ledger` — double-entry ledger invariants: a posting preserves the accounting equation (debit = credit) for debit/credit-nature accounts; `postTurn` rejects entries that are not `TSNew`; posting order does not affect the result; `calculateAccountBalance` returns the accumulated balance per account. Added `test/Finance/LedgerSpec.hs` and wired into `test-suite surypus-test` via `Surypus.cabal` (other-modules) and `test/Test.hs` (import + spec). Verified: full suite `surypus-test` PASS — 1120 examples, 0 failures, 3 pending (3 pending = pre-existing DB/Redis integration tests requiring env vars).
|- `Surypus-643` (P1) Add QuickCheck property tests for `System.Scheduler` — scheduling invariants: `calculateNextRun` returns the first day at-or-after the start that satisfies the predicate, always at midnight (including year boundaries); `updateJobQueue` stores each job under its `jobNextRun` key; `scheduleOnce` enqueues the job with the requested time and enabled flag. Added `test/System/SchedulerSpec.hs` and wired into `test-suite surypus-test` via `Surypus.cabal` (other-modules) and `test/Test.hs` (import + spec). Verified: full suite `surypus-test` PASS — 1112 examples, 0 failures, 3 pending (3 pending = pre-existing DB/Redis integration tests requiring env vars).
||- `Surypus-626` (P3) Seed data и demo environment

||- `Surypus-644` (P1) Add QuickCheck property tests для `Core.Tax` (`calcTaxInclusive` / `calcTaxExclusive`) — 6 properties: inclusive ≥ price, inclusive == price + VAT, inclusive == price*(100+rate)/100, exclusive ≥ half of price, exclusive ≤ price, exclusive ≤ inclusive. Added to `test/Core/TaxSpec.hs` (generators + properties), wired through the test-suite. Verified: `surypus-test` PASS — 1139 examples, 0 failures, 3 pending (3 pending = pre-existing DB/Redis integration tests requiring env vars). During verification a pre-existing wrong assertion was found and fixed: `calcTaxInclusive (RatePercent 100) (Money 100)` is 200 (price + 100% VAT), not 100.
||- `Surypus-645` (P1) Add QuickCheck property tests for `Finance.AccPlan` — accounting-plan record invariants: `mkNonNeg` accepts every non-negative value and rejects negatives (round-trip through `unNonNeg`); `createAccPlan` applies the documented defaults (no parent, active, created today, never updated); `activateAccPlan`/`deactivateAccPlan` toggle `apIsActive` and stamp `apUpdatedAt`; `prettyAccPlan` always contains the code/name and its status suffix agrees with the active flag. Added `test/Finance/AccPlanSpec.hs` and wired it into `test-suite surypus-test` via `Surypus.cabal` (other-modules) and `test/Test.hs` (import + spec). No production change required. Verified: full suite `surypus-test` PASS — **1154 examples, 0 failures, 3 pending** (3 pending = pre-existing DB/Redis integration tests requiring env vars). Negative check: raising the `mkNonNeg` acceptance threshold from 0 to -1e6 makes exactly the 2 rejection tests fail (1154 examples, 2 failures) — the spec is not vacuous.
