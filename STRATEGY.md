# Surypus ERP/CRM — Strategic Analysis (2026 H2)

---

## 1. Strategic Goals (3–5 Year Vision)

### 1.1 Where Is This Project Going?

Surypus aims to be the **only formally verified open-source ERP/CRM** in the Haskell ecosystem. Its differentiator is not feature breadth (it will never match SAP or 1C) but **mathematical correctness of financial operations**: double-entry bookkeeping, VAT calculation, inventory valuation, and payroll are verified via LiquidHaskell refinement types at compile time.

### 1.2 Target Deployment Profile

| Dimension | Target |
|-----------|--------|
| **Deployment** | On-premise & private cloud (Docker Compose + PostgreSQL) |
| **Scale** | SME to mid-market (1–5000 users, single-tenant or multi-tenant) |
| **Industry** | Manufacturing, wholesale, retail, professional services |
| **Geography** | Russia/CIS first (Russian classifiers, VAT, 1C-compatible reports), then international |
| **Distribution** | Docker image, Helm chart, apt/deb package |

### 1.3 What Makes It Unique?

- **LiquidHaskell-verified accounting engine** — no other open-source ERP has this
- **Full Haskell stack** — Servant API, Persistent ORM, STM concurrency, property-based tests
- **Event sourcing** — built-in EventStore on PostgreSQL with replay capability
- **Multi-tenant via RLS** — just completed, scales to thousands of tenants
- **Production observability** — Prometheus metrics + structured JSON logging (just implemented)

### 1.4 North Star

> By 2029, Surypus is the default ERP choice for Haskell-using organisations and the reference implementation of formally verified business software.

---

## 2. Current Position Assessment (2026 H2)

### 2.1 Major Subsystem State

| Subsystem | Modules | Status | Assessment |
|-----------|---------|--------|------------|
| **REST API** | `Surypus.API.Server`, `Surypus.API.*` (22 handlers) | ✅ **Complete** | Servant with 50+ endpoints, OpenAPI capable, fully real-DB backed |
| **Auth & RBAC** | `Surypus.JWT.*`, `Surypus.RBAC`, `Surypus.API.AuthMiddleware` | ⚠️ **Mostly done** | JWT signing/verification working, but RBAC permission store is **stubbed** (`Surypus.RBAC:150-166`) and refresh tokens are `"fake-refresh-token-"` (`Surypus.JWT:117-137`) |
| **Multi-Tenant** | `MultiTenancy.*` | ⚠️ **Done** | RLS middleware + `runDbWithTenant` exist; the unused `getTenantFromRequest`/`checkTenantAccess` placeholders were removed in security/remove-auth-stubs. Tenant context comes only from verified JWT claims in `MultiTenancy.Middleware`. |
| **Accounting** | `Finance.Accounting`, `Core.Accounting.*`, `Core.Services.Accounting` | ✅ **Complete** | Double-entry verified, LiquidHaskell refinement types on core operations |
| **Inventory** | `Inventory.*` (15+ modules), `Core.Services.Inventory` | ✅ **Complete** | Stock operations, lot tracking, warehouse management |
| **Tax/VAT** | `Core.Tax`, `DAL.Procedures` (`calcVAT`, `calcVATInclusive` etc.) | ✅ **Complete** | PostgreSQL stored procedures with Haskell wrappers |
| **Payroll** | `Core.Payroll.Calculation`, `HR.*` | ⚠️ **Partial** | Calculation logic exists, but **persistence layer stubbed** (`DAL.Production`, `Service.PayrollService`) |
| **EventStore** | `DAL.EventStore`, `Infrastructure.EventStore.*` | ⚠️ **Partial** | Append/read/replay work, but **no snapshots, no schema versioning** (Phase 196) |
| **WebSocket** | `Surypus.WebSocket`, `Surypus.WebSocket.*` | ⚠️ **Partial** | Basic room-based broadcast works, but **no EventStore integration** and connection uses `WS.withPingThread` with blocking `forever` |
| **GraphQL** | `Surypus.API.GraphQL` | 🔴 **Stub** | Handler returns `Nothing` (`:31`), not wired into router |
| **Rate Limiting** | `System.RateLimiter`, `System.RateLimiterAdvanced` | ⚠️ **Partial** | Middleware installed, but `swCheck` has **`* 60` window bug** (`System/RateLimiter.hs:121`) |
| **Event Bus** | `EventBus` | 🔴 **Stub** | Uses `Chan DomainEvent`, Kafka TODO, `startProcessor` blocks forever |
| **Observability** | `Surypus.Metrics`, `Surypus.API.MetricsMiddleware`, `Surypus.API.Logger` | ⚠️ **New** | STM-based metrics work, structured JSON logger works, but no katip integration as planned |
| **Reports** | `Reports.*`, `Surypus.API.Reports`, `Surypus.Reports.*` | ⚠️ **Partial** | PDF generation via PDF-Slave/JasperReports, P&L and inventory reports exist |
| **DB Layer** | `DAL.*` (26 modules) | ⚠️ **Migration in progress** | `DAL.Hasql.Database` still used by `Surypus.API.Server:14`, `DAL.DB` is in-memory stubs (322 lines) |
| **Service Layer** | `Service.*` (10+ modules) | ⚠️ **Partial** | `BillService`, `CurrencyService`, `PayrollService`, `Orchestrator` exist but not fully wired |

### 2.2 Technical Debt Hotspots

| # | Location | Issue | Severity |
|---|----------|-------|----------|
| 1 | `DAL.Hasql.Database` | **Still imported** by `Surypus.API.Server:14` as `ConnectionPool` source | **HIGH** — blocks Hasql cleanup |
| 2 | `DAL.DB` (322 lines) | In-memory stub database, **still in cabal exposed-modules** | **HIGH** — shouldn't be in production code |
| 3 | `Surypus.RBAC` lines 144-166 | Permission checking is **hardcoded stubs** | **HIGH** — RBAC is effectively non-functional |
| 4 | `Surypus.JWT` lines 117-137 | Refresh tokens use `"fake-refresh-token-"` prefix | **HIGH** — no real refresh token rotation |
| 5 | `System.RateLimiter` line 121 | `* 60` bug: `swWindowSec * 60` instead of using seconds directly | **HIGH** — window is 60x too large |
| 6 | `MultiTenancy.Isolation` lines 25-27 | `setTenantContext` is `pure ()` | **MEDIUM** — RLS session variables not set per request |
| 7 | `Surypus.API.Server` line 113-114 | `envWSHandler` hardcoded as `Nothing` | **MEDIUM** — WebSocket inoperable |
| 8 | `Surypus.API.GraphQL` line 31 | `graphqlHandler` returns `Nothing Nothing` | **MEDIUM** — GraphQL is dead code |
| 9 | `EventBus` lines 52-55 | `startProcessor` blocks forever on `readChan` with no goroutine | **MEDIUM** — event bus unusable |
| 10 | `DAL.ORMPool` line 14 | **Hardcoded connection string** (no env vars) | **LOW** — but blocks containerisation |
| 11 | `DAL.Database` line 19 | `type Pool = ConnectionPool` alias is unused | **LOW** |
| 12 | `Surypus.cabal` lines 14-408 | 343 exposed modules, many **not compiled/tested** | **MEDIUM** — compilation risk |

### 2.3 Test Coverage Gaps

| Area | Files | Status |
|------|-------|--------|
| **Unit tests** | `test/Finance/TaxSpec.hs`, `test/Finance/AccountingSpec.hs` | Only 2 specs in cabal test-suite (line 486-487) |
| **Integration tests** | `test/Integration/*`, `test/DAL/*`, `test/API/*` | ~20 files exist but **not wired into cabal** |
| **Domain tests** | `test/Domain/*` (10 specs) | Exist but not in cabal |
| **QuickCheck properties** | `test/QuickCheckInvariantsSpec.hs`, `test/Test/QuickCheck/Invariants.hs` | Exist but coverage unknown |
| **RBAC tests** | `test/RBACSpec.hs`, `test/RBACCanonSpec.hs` | Exist but RBAC is stubbed |
| **Observability tests** | `test/ObservabilitySpec.hs` | Exists |
| **Concurrency tests** | `test/ConcurrencySpec.hs` | Exists |
| **EventStore tests** | `test/DAL/EventStoreSpec.hs` | Exists |

**Critical Gap**: The cabal test-suite only compiles 2 test files. ~65 test files exist in `test/` but are excluded from the build. The `test/Main.hs` and `test/Test.hs` files suggest different test entry points.

### 2.4 Documentation State

| Doc | Status | Notes |
|-----|--------|-------|
| `STRATEGY.md` | ⬅️ Just created | This document |
| `PROJECT.md` | ✅ Good | Clear scope, active/out-of-scope, key decisions |
| `ROADMAP.md` (root) | ⚠️ Stale | References old 8-phase v1.0 plan, not current v51.0 |
| `ROADMAP.md` (planning) | ✅ Good | v51.0 phases 194-201 with dependency graph |
| `REQUIREMENTS.md` | ✅ Good | 26 requirements mapped to phases |
| `STATE.md` | ✅ Good | Current state, blockers, risks |
| `AGENTS.md` | ✅ Good | Build/test commands, code style, architecture |
| README.md | ⚠️ Partial | Needs update for v51.0 state |
| API docs | ⚠️ Needs review | OpenAPI spec generation status unknown |
| Architecture docs | ❌ Missing | No single architecture overview document |

---

## 3. Tactical Task List (Next 3–6 Months)

### Phase 196: EventStore Snapshots & Replay (P0)

- **TASK-001**: Event snapshot table (`event_snapshot`) with `UNIQUE (aggregate_id, aggregate_type, version)` constraint
  - New Persistent entity in `DAL.Schema`
  - Migration SQL
  - `DAL.EventStore` API: `saveSnapshot`, `getLatestSnapshot`
  - Effort: 3 days

- **TASK-002**: Snapshot-based replay — when replaying events, load the latest snapshot first and replay only events after it
  - Modify `replayAccount`, `getEvents` to accept snapshot ID
  - Configurable snapshot frequency
  - Effort: 2 days

- **TASK-003**: Event schema versioning with forward-compatible deserialization
  - Add `event_schema_version` field to EventStoreEntity
  - Versioned JSON envelope (`{ "v": 1, "data": {...} }`)
  - Compatibility test for reading old events after schema change
  - Effort: 3 days

- **TASK-004**: Thread-safe broadcaster without `unsafePerformIO` (Phase 194 residual)
  - Verify all TVar/STM usage is safe
  - Remove any remaining `unsafePerformIO` patterns in EventStore
  - Effort: 1 day

### Phase 197: Payroll Persistence (P1)

- **TASK-005**: Create `DAL.Payroll` module with insert/query/audit operations
  - Persistent entity for payroll results
  - Migration for `payroll_result` table
  - Decimal precision for all monetary amounts
  - Effort: 3 days

- **TASK-006**: Connect `Core.Payroll.Calculation` to `DAL.Payroll`
  - Wire existing calculation logic to persistence layer
  - Period-based querying
  - Effort: 2 days

- **TASK-007**: Payroll audit history
  - Track who calculated, when, what values changed
  - Store previous values for diff
  - Effort: 2 days

### Phase 198: Rate Limiting Fixes (P0)

- **TASK-008**: Fix the `* 60` window bug in `System.RateLimiter.swCheck`
  - Change `((fromIntegral (swWindowSec sw) * 60) :: NominalDiffTime)` to `(fromIntegral (swWindowSec sw) :: NominalDiffTime)`
  - Add property test verifying 60-second window
  - Effort: 1 day

- **TASK-009**: Per-tenant rate limits (depends on Phase 195)
  - Extend `SlidingWindow` to accept a tenant key
  - Per-tenant limit buckets
  - `RateLimit-*` response headers
  - Effort: 3 days

### Phase 199: WebSocket EventStore Broadcast (P1)

- **TASK-010**: Connect EventStore append to WebSocket broadcast
  - When events are appended, publish to appropriate rooms
  - Filter by aggregate type per room
  - Effort: 3 days

- **TASK-011**: WebSocket connection lifecycle management
  - `bracket`-style cleanup on disconnect
  - Sequence-based catch-up on reconnect (last known position)
  - Effort: 2 days

- **TASK-012**: Redis pub/sub for horizontal scaling
  - Replace `MVar globalBroadcaster` with Redis pub/sub via hedia
  - Subscribe to event channels on server start
  - Publish events to Redis on append
  - Effort: 4 days

### Phase 200: GraphQL API (P2)

- **TASK-013**: Wire Morpheus GraphQL schema
  - Add Morpheus dependency to cabal
  - Generate GraphQL schema from Haskell types
  - Mount at `/api/v1/graphql`
  - Effort: 5 days

- **TASK-014**: GraphQL auth sharing with REST
  - Reuse JWT+RBAC middleware
  - Test that auth bypass is impossible
  - Effort: 2 days

- **TASK-015**: N+1 query prevention
  - Implement batched resolvers for nested queries (bills→lines, deals→activities)
  - Verify O(1) DB round-trips for complex queries
  - Effort: 3 days

### Phase 201: Hasql Cleanup (P1)

- **TASK-016**: Remove `DAL.Hasql.Database` imports from `Surypus.API.Server`
  - Change to `DAL.Pool` or `DAL.Database`
  - Remove `DAL.Hasql.Database` from cabal exposed-modules
  - Effort: 1 day

- **TASK-017**: Remove `hasql`/`hasql-pool` from cabal dependencies
  - Verify no remaining imports
  - Build and test pass without Hasql
  - Effort: 1 day

- **TASK-018**: Clean up `DAL.DB` (in-memory stubs)
  - Remove from cabal exposed-modules
  - Move to test directory if still needed for testing
  - Effort: 1 day

### RBAC Fixes (P0 — Security Critical)

- **TASK-019**: Implement real permission store in database
  - Create `user_role`, `role_permission` tables
  - Replace `checkUserPermission` stubs with DB queries
  - Replace `checkAdminStatus` stub with DB query
  - Migration scripts for seed data
  - Effort: 5 days

- **TASK-020**: Implement real refresh token rotation
  - Replace `"fake-refresh-token-"` with real JWT-signed refresh tokens
  - `refresh_token` table with revocation support
  - Rotation endpoint (`/api/v1/refresh`)
  - Effort: 3 days

### Infrastructure & CI/CD (P1)

- **TASK-021**: Fix cabal test-suite to include all tests
  - Add all existing test modules to `other-modules` in cabal
  - Ensure `Test.hs` or `Main.hs` discovers all tests
  - Target: 65+ test files compiling
  - Effort: 2 days

- **TASK-022**: Docker Compose with tmp-postgres for CI
  - Add GitHub Actions workflow for integration tests with PostgreSQL
  - Add Redis service for WebSocket/queue tests
  - Effort: 3 days

- **TASK-023**: Health check endpoint completeness
  - Verify `/health` returns `{status: "ok", db: "ok", redis: "ok"}`
  - Add startup probe, liveness probe, readiness probe endpoints
  - Effort: 2 days

- **TASK-024**: Environment variable configuration
  - Replace hardcoded connection string in `DAL.ORMPool`
  - Move all config to environment variables with defaults
  - Add config validation on startup
  - Effort: 2 days

### Security Hardening (P1)

- **TASK-025**: Security audit preparation
  - Review all input validation in API handlers
  - Check SQL injection vectors in `rawSql` calls (`DAL.Procedures` uses parameterised queries ✅)
  - Verify CORS configuration
  - Effort: 3 days

- **TASK-026**: Pen-test prep
  - Authentication bypass testing
  - Rate limit bypass testing
  - Multi-tenant data leakage testing
  - Token tampering testing
  - Effort: 3 days

- **TASK-027**: Secrets management
  - `SURYPUS_JWT_SECRET` validation on startup (partially done in `Surypus.JWT.Token:68`)
  - Add database password from env var
  - Add Redis password from env var
  - Effort: 1 day

### Testing Infrastructure (P0)

- **TASK-028**: Wire all existing test files into cabal
  - Currently only `Finance.TaxSpec` and `Finance.AccountingSpec` are in cabal
  - Add all 65+ test files
  - Fix compilation errors
  - Effort: 3 days

- **TASK-029**: Add integration tests for v51.0 features
  - EventStore snapshot tests
  - Multi-tenant isolation tests (cross-tenant leakage)
  - Rate limit tests
  - WebSocket EventStore broadcast tests
  - Effort: 5 days

- **TASK-030**: Expand QuickCheck property coverage
  - Accounting invariants (ΣDebit = ΣCredit after any transaction)
  - Stock invariants (Rest = Initial + Receipt - Issue)
  - VAT invariants (result ≥ 0, result ≤ base)
  - Multi-tenant isolation properties
  - Effort: 4 days

### Observability Gaps (P1)

- **TASK-031**: Prometheus metrics completeness audit
  - Verify `/metrics` endpoint works end-to-end
  - Add DB connection pool gauge (currently hardcoded to 0)
  - Add job queue depth gauge
  - Add per-endpoint request count
  - Effort: 2 days

- **TASK-032**: Structured logging production readiness
  - Verify correlation IDs flow through all handlers
  - Add structured logging to DAL queries via `logDBQuery`
  - Ensure no `putStrLn` remains in production code (check `EventBus:43`, `Surypus.App.Main`, etc.)
  - Effort: 2 days

---

## 4. Risk Register

### Technical Risks

| # | Risk | Likelihood | Impact | Mitigation |
|----|------|-----------|--------|------------|
| R1 | **Hasql dependency lingers** and blocks build on next Stackage LTS upgrade | Medium | High | Remove in Phase 201 (independent task) |
| R2 | **RLS `search_path` pool leak** — cross-tenant data exposure if connection pool reuses session with stale tenant context | Low | **Critical** | `runDbWithTenant` wrapper clears config after each action; add cross-tenant leakage integration test |
| R3 | **STMs space leak** in WebSocket broadcaster under high connection churn | Low | Medium | Use `TBQueue` (bounded) instead of `TChan`; add lease test |
| R4 | **Morpheus GraphQL** doesn't support N+1 prevention in current LTS | Medium | Medium | Spike during Phase 200 planning; fallback to dedicated Esqueleto queries |
| R5 | **LiquidHaskell** integration breaks with GHC/LTS upgrade | Medium | Medium | Pin LH version in `stack.yaml`; CI gate on LH verification |
| R6 | **Persistent migration conflicts** between 8 parallel phase branches | Medium | High | Number migrations sequentially; use single migration chain in `DAL.Migration` |

### Business Risks

| # | Risk | Likelihood | Impact | Mitigation |
|----|------|-----------|--------|------------|
| R7 | **Low adoption** due to Haskell niche and Russian-market focus | High | Medium | Target B2B SaaS for CIS market; open-source community building |
| R8 | **Key person dependency** — single maintainer risk | Medium | High | Document architecture; onboard second contributor via paid features |
| R9 | **Regulatory changes** in Russian tax/accounting law | Medium | Low | Parameterise VAT rates, tax periods, classifier versions |
| R10 | **Dependency rot** — 128+ Haskell deps requiring constant maintenance | High | Medium | Regular `stack upgrade --dependencies-only` cycles; minimise dep surface |

---

## 5. Key Metrics & Success Criteria

### 5.1 Progress Metrics

| Metric | Current | Target (2026 Q4) |
|--------|---------|-------------------|
| v51.0 phases complete | 2/8 (25%) | 8/8 (100%) |
| Requirements complete | 6/26 (23%) | 26/26 (100%) |
| Exposed modules in cabal | ~141 | ~141 (stable) |
| Test files in cabal | 2 | 65+ |
| CI pipeline green duration | Unknown | 100% |
| LiquidHaskell checks in CI | ❌ | ✅ |
| Docker image published | ❌ | ✅ |

### 5.2 Quality Gates for Production Readiness

| Gate | Criteria | Phase |
|------|----------|-------|
| **G1** | All `unsafePerformIO` removed | 194 ✅ |
| **G2** | Multi-tenant data isolation proved by cross-tenant test | 195 ✅ |
| **G3** | EventStore snapshots with versioning | 196 |
| **G4** | Payroll data persisted with Decimal precision | 197 |
| **G5** | Rate limiting verified (60s window) | 198 |
| **G6** | WebSocket EventStore broadcast working with Redis pub/sub | 199 |
| **G7** | GraphQL endpoint operational with auth sharing | 200 |
| **G8** | No Hasql imports remain | 201 |
| **G9** | RBAC enforced by real DB-backed permission store | Post-201 fix |
| **G10** | All 65+ test files compile and pass in CI | Post-201 fix |
| **G11** | Docker image builds and health endpoint responds | Post-201 fix |
| **G12** | No hardcoded credentials or connection strings | Post-201 fix |

### 5.3 Release Criteria for v51.0

- [ ] Phases 196–201 complete (all requirements satisfied)
- [ ] All 65+ test files compile
- [ ] Integration tests pass with `tmp-postgres`
- [ ] Rate limit window verified correct (no `* 60` bug)
- [ ] Cross-tenant data leakage test passes
- [ ] `hasql`/`hasql-pool` dependencies removed
- [ ] RBAC uses real DB-backed permission store
- [ ] JWT refresh tokens use real rotation (not fake prefix)
- [ ] Docker image builds and health endpoint returns `{"status":"ok"}`
- [ ] OpenAPI spec validates
- [ ] CI pipeline green on main branch

---

*Generated: 2026-06-09 | Author: Strategic Analysis AI*
*Next review: 2026-09-01 or upon v51.0 completion, whichever comes first*
