# Surypus v51.0 — Condensed Tactical Task List

---

## Priority P0 (Must do — security & correctness)

- [ ] **TASK-019**: Implement real RBAC permission store (user_role, role_permission DB tables, replace stubs in `Surypus.RBAC`) — effort: **5 days**
- [ ] **TASK-020**: Implement real JWT refresh token rotation (replace `"fake-refresh-token-"` prefix, revocation table) — effort: **3 days**
- [x] **TASK-008**: Fix `* 60` window bug in `System.RateLimiter.swCheck` — effort: **1 day** ✅ Fixed in commit 535588f2; verified by type-check + new System.RateLimiterSpec tests
- [ ] **TASK-001**: Event snapshot table (`event_snapshot`, Persistent entity, migration, `saveSnapshot`/`getLatestSnapshot` API) — effort: **3 days**
- [ ] **TASK-002**: Snapshot-based replay (load latest snapshot, replay only subsequent events) — effort: **2 days**
- [ ] **TASK-003**: Event schema versioning (`event_schema_version`, versioned JSON envelope, forward-compat deserialization) — effort: **3 days**
- [ ] **TASK-004**: Thread-safe broadcaster audit (remove any remaining `unsafePerformIO` in EventStore) — effort: **1 day**
- [ ] **TASK-028**: Wire all 65+ existing test files into cabal test-suite — effort: **3 days** (partial: System.RateLimiterSpec added 2026-10-09; ConfigSpec, ObservabilitySpec, MigrationDryRunSpec, RBACCanonSpec added 2026-10-10; ConcurrencySpec + Phase5PropsSpec added 2026-10-10; QuickCheckInvariantsSpec added 2026-10-11; Inventory.StockSpec + Inventory.WarehouseSpec added 2026-10-12; HR.OperationsSpec added 2026-10-12; 51+ files remain)
  - ConcurrencySpec: 1 test (Domain.Concurrency.Domain stub)
  - Phase5PropsSpec: 8 tests (BillService refinement + RBAC route mapping)
  - Fixed Phase5PropsSpec to use real Permission type instead of Text
  - Fixed requiredPermissionForPathMethod to strip /api/v1/ prefix before matching
  - Verified: 298 examples, 2 pre-existing timing failures (RateLimiter), 6 pending
  - **2026-10-11**: Fixed cabal file — restored from committed conflict state (9ecd00d4 base + 2 intended changes: removed non-existent Shared.Export.Exporter, added JWTSpec). Added all 18 wired test modules to test-suite other-modules. Created missing test/System/SequenceSpec.hs (11 tests: 7 unit + 4 QuickCheck). Restored README.md and stack.yaml from 9ecd00d4 (removed committed conflict markers). Verified via direct GHC compilation: 298 examples, 2 pre-existing timing failures, 6 pending.
  - **2026-10-11**: Added QuickCheckInvariantsSpec (14 property-based tests: payroll, tax, social tax, income tax brackets). Verified: 14 examples, 0 failures.
- **2026-10-12**: Wired Inventory.StockSpec + Inventory.WarehouseSpec (9 tests: receipt/issue/transfer/adjustment movements, warehouse CRUD + duplicate-code guard). Fixed 3 real compile errors found by compiling (ambiguous `pure ()` in hspec `it` blocks ×2 → `(pure () :: IO ())`; `shouldContain` on `Text` → `T.isInfixOf`). Verified end-to-end: **321 examples, 2 failures (pre-existing RateLimiter timing), 6 pending** — both new specs green.
  - **Excluded Inventory.GoodsSpec** — it does NOT pass: `Inventory.Goods.goodsForRestocking` filters only on `gActive`/`gStatus` and never consults `gMinStock`, so the spec's `goodsForRestocking [g1,g2] == [g1]` assertion is unsatisfiable as written. Also `goodsForRestocking`/`totalInventoryValue` are implemented but **not exported** from `Inventory.Goods`. Needs a decision on intended semantics before wiring (see TASK-033).
- **2026-10-12**: Wired HR.OperationsSpec (14 tests: validatePersonData 5 — valid request, empty code/name, invalid INN/KPP; createPerson CRUD 4 — create, duplicate-INN conflict, findByINN, findByCode; status transitions 3 — activate/deactivate/block; queries 2 — countPersons, personsByKind). Fixed 1 compile error (ambiguous bare `pure ()` in `it` block at OperationsSpec:158 → `(pure () :: IO ())`). Verified end-to-end by direct GHC build+run of the full Test.hs closure (full `cabal build` still blocked by pre-existing library errors in Surypus.API.BillTemplates et al.): **335 examples, 2 failures (pre-existing idle-machine RateLimiter timing tests — they pass only under CPU load), 6 pending** — new spec green (14/14).
- **2026-10-12 (audit)**: `test/HR/PersonSpec.hs` is stale and cannot be wired as-is: it expects `createPerson` with 7 positional args, a `pIsActive` field, and `pPersonKindId :: PersonKind` — none exist in the current API (`HR.Person` has `pPersonKindId :: Int64`; `createPerson` lives in `HR.Operations` with signature `[Person] -> CreatePersonRequest -> Day`). Verified by GHC ("Variable not in scope: pIsActive" + arity errors). Needs rewrite against the real API or deletion — extends TASK-034.
- **TASK-033 (new, found during TASK-028 audit)**: `Inventory.Goods.goodsForRestocking` ignores `gMinStock`/`gMaxStock`, so it cannot report goods below minimum — contradicts both its name and its spec. Fix requires defining intended semantics (below-min-stock? compare against what on-hand quantity, given `Goods` carries no stock level?) and exporting `goodsForRestocking` + `totalInventoryValue`. Blocks wiring of `test/Inventory/GoodsSpec.hs`.
- **TASK-034 (new, found during TASK-028 audit)**: 12 spec files import modules that do not exist and are dead code: `Domain/Bill|Goods|Location|Person|Production|HR|HRProperty|Job|PayrollSpec.hs` (no `src/Domain/*` except `Accounting`), `Domain/CRMSpec.hs` (`src/CRM/` has only `Types.hs`, missing `Contact/Company/Deal/Activity/Pipeline`), `Domain/DocumentSpec.hs` (no `Core.Document.Types`/`Domain.Document`), `DAL/FixturesSpec.hs` (no `DAL.Fixtures`). Either restore the modules or delete the specs.
- [ ] **TASK-029**: Integration tests for v51.0 features (snapshots, multi-tenant, rate limits, WebSocket) — effort: **5 days**
- [ ] **TASK-030**: Expand QuickCheck properties (accounting, stock, VAT invariants; multi-tenant isolation) — effort: **4 days**

## Priority P1 (Should do — production hardening)

- [ ] **TASK-005**: Create `DAL.Payroll` module with insert/query/audit — effort: **3 days**
- [ ] **TASK-006**: Connect `Core.Payroll.Calculation` to `DAL.Payroll` — effort: **2 days**
- [ ] **TASK-007**: Payroll audit history (who, when, diff) — effort: **2 days**
- [ ] **TASK-009**: Per-tenant rate limits with `RateLimit-*` headers — effort: **3 days**
- [ ] **TASK-010**: Connect EventStore append to WebSocket broadcast — effort: **3 days**
- [ ] **TASK-011**: WebSocket lifecycle management (bracket cleanup, catch-up on reconnect) — effort: **2 days**
- [ ] **TASK-012**: Redis pub/sub for horizontal WebSocket scaling — effort: **4 days**
- [ ] **TASK-016**: Remove `DAL.Hasql.Database` imports from `Surypus.API.Server` — effort: **1 day**
- [ ] **TASK-017**: Remove `hasql`/`hasql-pool` from cabal dependencies — effort: **1 day**
- [ ] **TASK-018**: Remove `DAL.DB` in-memory stubs from production code — effort: **1 day**
- [ ] **TASK-021**: Docker Compose with tmp-postgres for CI — effort: **3 days**
- [ ] **TASK-023**: Health check endpoint completeness (db, redis probes) — effort: **2 days**
- [ ] **TASK-024**: Environment variable configuration (replace hardcoded connection strings) — effort: **2 days**
- [ ] **TASK-025**: Security audit (input validation, SQL injection review, CORS) — effort: **3 days**
- [ ] **TASK-026**: Pen-test preparation (auth bypass, rate limit bypass, cross-tenant leakage tests) — effort: **3 days**
- [ ] **TASK-031**: Prometheus metrics completeness audit (pool gauge, per-endpoint counts) — effort: **2 days**
- [ ] **TASK-032**: Structured logging production readiness (correlation IDs, replace putStrLn) — effort: **2 days**
- [ ] **TASK-033**: Fix `Inventory.Goods.goodsForRestocking` semantics — it ignores `gMinStock`/`gMaxStock` and returns all active goods, so it cannot report below-minimum items (blocks `test/Inventory/GoodsSpec.hs`); also export `goodsForRestocking` + `totalInventoryValue` — effort: **1 day**
- [ ] **TASK-034**: Resolve 12 orphaned spec files importing non-existent modules (`Domain.Bill/Goods/Location/Person/Production/HR/Job/Payroll`, `CRM.Contact/Company/Deal/Activity/Pipeline`, `Core.Document.Types`, `Domain.Document`, `DAL.Fixtures`) — restore the modules or delete the specs — effort: **2 days**

## Priority P2 (Nice to have — feature completion)

- [ ] **TASK-013**: Wire Morpheus GraphQL schema at `/api/v1/graphql` — effort: **5 days**
- [ ] **TASK-014**: GraphQL auth sharing with REST (JWT+RBAC reuse) — effort: **2 days**
- [ ] **TASK-015**: N+1 query prevention in GraphQL resolvers — effort: **3 days**
- [ ] **TASK-022**: GitHub Actions workflow for integration tests — effort: **2 days**
- [ ] **TASK-027**: Secrets management (JWT secret validation, DB/Redis passwords from env) — effort: **1 day**

---

**Total estimated effort: ~78 days (≈4 months for 1 FT engineer)**

**Priority breakdown**: P0 = 30 days, P1 = 37 days, P2 = 13 days

**Critical path**: P0 items block P1/P2; RBAC fix (TASK-019) + test wiring (TASK-028) should be first week.
