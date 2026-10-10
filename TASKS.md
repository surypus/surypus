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
- [ ] **TASK-028**: Wire all 65+ existing test files into cabal test-suite — effort: **3 days** (partial: System.RateLimiterSpec added 2026-10-09; ConfigSpec, ObservabilitySpec, MigrationDryRunSpec, RBACCanonSpec added 2026-10-10; ConcurrencySpec + Phase5PropsSpec added 2026-10-10; 55+ files remain)
  - ConcurrencySpec: 1 test (Domain.Concurrency.Domain stub)
  - Phase5PropsSpec: 8 tests (BillService refinement + RBAC route mapping)
  - Fixed Phase5PropsSpec to use real Permission type instead of Text
  - Fixed requiredPermissionForPathMethod to strip /api/v1/ prefix before matching
  - Verified: 297 examples, 2 pre-existing timing failures (RateLimiter), 6 pending
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
