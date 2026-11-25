# Project Research Summary — v51.0 Enterprise Readiness

**Project:** Surypus ERP/CRM
**Domain:** Haskell ERP/CRM with formal verification (Servant + Persistent/Esqueleto + PostgreSQL)
**Researched:** 2026-06-09
**Confidence:** HIGH

## Executive Summary

Surypus is an existing Haskell ERP/CRM with a mature codebase (Servant REST API, Persistent/Esqueleto ORM, PostgreSQL event store, JWT auth, RBAC, Redis job queues). The v51.0 "Enterprise Readiness" milestone adds production-hardening and enterprise features: structured logging (katip), Prometheus metrics, rate limiting, multi-tenant architecture, EventStore snapshots/replay, WebSocket EventStore broadcast, payroll persistence, and a GraphQL API. The dominant pattern across all features is **stub replacement** — the codebase already has type definitions, module skeletons, and incomplete implementations for most features. The real work is filling in function bodies, not designing new interfaces.

**Recommended build order:** Phase 1 — infrastructure foundation (logging + metrics); Phase 2 — parallel tracks for multi-tenant, EventStore snapshots, and payroll persistence; Phase 3 — rate limiting (depends on multi-tenant); Phase 4 — WebSocket EventSource integration and GraphQL (both parallel). GraphQL and WebSocket should come last because they depend on the stability of underlying infrastructure (logging, EventStore, multi-tenant).

**Key risks:** (1) `search_path` connection pool leaks between tenants — the #1 data safety issue; (2) `unsafePerformIO` global state in the EventStore broadcaster breaks referential transparency and test isolation; (3) GraphQL N+1 query problem if resolvers naively wrap individual Servant handlers; (4) a confirmed `* 60` bug in the sliding window rate limiter; (5) a strategic tension between RLS (recommended by STACK research) and schema-per-tenant (specified in PROJECT.md) for multi-tenant isolation.

## Key Findings

### Recommended Stack

All 7 new dependencies are available in `lts-22.21` (GHC 9.6.4) — **no extra-deps required**. The stack additions are minimal and targeted:

| Library | Version | Purpose |
|---------|---------|---------|
| `morpheus-graphql-server` | 0.27.3 | GraphQL API — mounts as Servant `Raw` endpoint, derives schema from Haskell types |
| `katip` | 0.8.8.0 | Structured JSON logging — replaces TVar-based `System.Logger` |
| `prometheus-client` | 1.1.1 | Prometheus metric types — replaces STM stubs in `Surypus.Metrics` |
| `wai-middleware-prometheus` | 1.0.0.1 | Auto-instrumentation: `/metrics` endpoint + request counters/latency |
| `wai-rate-limit` / `servant-rate-limit` | 0.3.0.0 / 0.2.0.0 | WAI middleware + Servant combinators for rate limiting |
| `wai-rate-limit-redis` | 0.2.0.1 | Redis backend for multi-instance rate limiting |

**Critical constraint:** Persistent 2.13.6.1 (in lts-22) lacks `entitySchema` — this blocks the schema-per-tenant approach at the Persistent level. STACK research therefore recommends RLS (row-level security) as the v51 approach, with schema-per-tenant deferred until a Persistent upgrade.

### Expected Features

**Must have (table stakes):**
- **Structured logging (katip):** JSON output with correlation IDs and tenant context — replaces non-functional TVar logger
- **Prometheus `/metrics` endpoint:** Auto-instrumented HTTP request counters, latency histograms, custom business metrics
- **Rate limiting:** Per-IP (WAI middleware) and per-tenant (Servant combinators) with Redis backend
- **EventStore snapshots:** `event_snapshot` table, replay-from-snapshot optimization, configurable snapshot intervals
- **Payroll persistence:** `PayrollPeriod`/`PayrollEntry` entities, calculation storage in `salary` table, batch payroll runs
- **WebSocket EventStore broadcast:** Direct EventStore → WS bridge using STM subscriptions (bypassing EventBus TQueue polling)
- **GraphQL query API:** Morpheus-based `/graphql` endpoint wrapping existing Servant handlers (Query-only, no mutations initially)
- **Multi-tenant isolation:** Either RLS (tenant_id column) or schema-per-tenant (search_path), tenant resolution from JWT

**Should have (differentiators):**
- Per-tenant rate limiting (once multi-tenant is active)
- Graceful WebSocket reconnection with sequence-based catchup
- Payroll period lifecycle (draft → processing → finalized → closed)
- GHC runtime metrics via `prometheus-metrics-ghc`

**Defer (v2+):**
- GraphQL mutations (keep on REST for transactional safety)
- Global event stream replay (disaster recovery only)
- Per-tenant backup/restore (operations tooling)
- GraphQL subscriptions over WebSocket (complex, needs WS stability first)
- Database-per-tenant (overkill for current scale)

### Architecture Approach

The architecture is additive — all new features slot into the existing WAI middleware stack and Servant router without disrupting existing REST endpoints. The middleware order (outer→inner) becomes: **katipLogger → tenantMiddleware → prometheus → rateLimiting → correlationMiddleware → authMiddleware → RBAC → Servant router**. The GraphQL endpoint lives alongside REST at `/api/v1/graphql`. EventStore gets a subscription manager (STM-based) that bridges event appends to WebSocket rooms. Multi-tenant uses either RLS (tenant_id column + `current_setting('app.tenant_id')`) or schema-per-tenant (`SET search_path`), both applied per-request in middleware.

**Major new/modified components:**
1. **`DAL.EventStore.Snapshots`** — Snapshot CRUD, replay-from-snapshot, configurable snapshot frequency
2. **`Infrastructure.EventStore.Subscriptions`** — STM subscription registry connecting EventStore appends → WebSocket rooms
3. **`MultiTenancy.*` (Middleware, Provisioning, Connection)** — Tenant resolution, schema provisioning, pool strategies
4. **`Surypus.API.GraphQL`** — Morpheus resolver definitions wrapping existing Core.Services handlers
5. **`System.RateLimiterEnhanced`** — Per-tenant rate limiter extending existing sliding window implementation
6. **`DAL.Payroll`** — Payroll record CRUD, period management, batch processing
7. **Modified: `Surypus.API.Server`** (new middleware stack), **`Env`** (new fields), **`Surypus.WebSocket`** (subscription management)

### Critical Pitfalls

1. **`search_path` connection pool leak (CATASTROPHIC):** When using schema-per-tenant, `SET search_path` is session-scoped and persists when connections return to the pool. The next tenant's request can read the wrong tenant's data. **Mitigation:** Use `runDbWithTenant` wrapper that resets `search_path = 'public'` after each request, OR use separate pools per tenant. Must be validated with a cross-tenant test.

2. **`unsafePerformIO` global broadcaster (TEST ISOLATION BREAK):** `DAL.EventStore.globalBroadcaster` is an `unsafePerformIO (newMVar Nothing)` — a mutable singleton that breaks referential transparency, races under concurrent access, and prevents test isolation. **Mitigation:** Thread `BroadcastCallback` through EventStore explicitly via record fields or `ReaderT`. Remove the `{-# NOINLINE #-}` global.

3. **GraphQL N+1 query problem (PERFORMANCE):** Naively wrapping individual REST handlers as GraphQL resolvers causes 601 DB queries for a 100-bill-5-line query. **Mitigation:** Use Morpheus batch resolvers, DataLoader pattern, or dedicated Esqueleto queries for complex GraphQL fields.

4. **Rate limiter `* 60` bug (INCORRECT BEHAVIOR):** `System.RateLimiter.swCheck` multiplies `swWindowSec` by 60, making a 60-second window actually 60 minutes. **Mitigation:** Remove the `* 60` factor — the window is already in seconds.

5. **STM `TChan` unbounded growth (MEMORY LEAK):** WebSocket subscriptions use unbounded `TChan` — if disconnect cleanup fails, channels accumulate events forever. **Mitigation:** Use `TBQueue` (bounded + backpressure) and `bracket` for subscription lifecycle.

6. **Duplicate connection pool types (MAINTENANCE):** Both `DAL.Database` and `DAL.ORMPool` export `ConnectionPool` — some modules still reference Hasql pools. Standardize to one module and remove Hasql remnants.

7. **Russian tax cap hardcoded (CORRECTNESS):** `calcSocialTax` has hardcoded cap at 876000 which changes annually. Migrate to a `TaxConfig` type with DB-backed values.

## Implications for Roadmap

### Phase 1: Infrastructure Foundation — Logging + Metrics
**Rationale:** Both are stub replacements (zero-risk), have no dependencies on other features, and everything after benefits from observability. Two independent workstreams that can proceed in parallel.
**Delivers:** Structured JSON logging (katip) with correlation IDs; Prometheus `/metrics` endpoint with auto-instrumentation; removal of TVar-based Logger and STM Metrics stubs.
**Addresses:** FEATURES-5b, FEATURES-5c — production hardening
**Avoids:** PITFALLS-6 (metrics endpoint conflict — remove inline handler, let wai-middleware-prometheus handle `/metrics`)

### Phase 2: Parallel Tracks — Multi-Tenant + EventStore Snapshots + Payroll
**Rationale:** These three features are independent of each other but all benefit from logging (Phase 1). They form the core infrastructure for the remaining features.

**Phase 2a: Multi-Tenant Architecture**
**Rationale:** Needed before per-tenant rate limiting. Must resolve RLS vs schema-per-tenant tension early (see Research Flags).
**Delivers:** Tenant resolution from JWT, tenant middleware (`SET search_path` or `SET app.tenant_id`), tenants table, tenant provisioning, `Env` gains `envTenant`.
**Avoids:** PITFALLS-1 (search_path leak — MUST implement `runDbWithTenant` wrapper with reset), PITFALLS-7 (TH + dynamic schema — use raw SQL for provisioning)
**Research flag:** HIGH — RLS vs schema-per-tenant is unresolved. RLS works with current Persistent but PROJECT.md specifies schema-per-tenant. Needs discussion/decision before implementation.

**Phase 2b: EventStore Snapshots + Replay**
**Rationale:** Foundation for WebSocket broadcast (Phase 4). Self-contained — new table, snapshot management, replay API.
**Delivers:** `event_snapshot` table, `saveSnapshot`/`getLatestSnapshot`, replay-from-snapshot optimization, snapshot API endpoint (admin).
**Avoids:** PITFALLS-2 (fix `unsafePerformIO` global broadcaster), PITFALLS-4 (use `TBQueue` instead of `TChan` from the start)

**Phase 2c: Payroll Persistence**
**Rationale:** Business feature with no dependencies on other Phase 2 items. Simple CRUD + pure calculation.
**Delivers:** `PayrollPeriod`/`PayrollEntry`/`PayrollContribution` entities, `calculateAndPersist` service, batch payroll as Redis job, payroll API endpoints.
**Avoids:** PITFALLS-11 (hardcoded tax cap — make configurable)
**Research flag:** LOW — well-understood CRUD, pure calculation already exists and is LiquidHaskell-verified.

### Phase 3: Rate Limiting (Per-Tenant)
**Rationale:** Depends on Phase 2a (multi-tenant) for tenant resolution. Extends existing sliding window implementation.
**Delivers:** Two-layer rate limiting (WAI middleware for per-IP, Servant combinators for per-endpoint), Redis backend, rate-limit headers, per-tenant limits.
**Avoids:** PITFALLS-8 (fix the `* 60` bug in `swWindowSec`), PITFALLS-3 (correct middleware order — rate limit BEFORE auth to prevent DoS on auth endpoints)
**Research flag:** LOW — existing `System.RateLimiter` and `System.RateLimiterAdvanced` are working; this is additive.

### Phase 4: WebSocket EventStore Integration + GraphQL API
**Rationale:** Both depend on Phase 2 infrastructure. WebSocket needs EventStore snapshots done. GraphQL only needs logging (Phase 1) and can theoretically move earlier, but delaying it allows learning from REST API stability.

**Phase 4a: WebSocket EventStore Broadcast**
**Rationale:** Requires EventStore subscription manager from Phase 2b. Enhances existing WebSocket handler.
**Delivers:** `Infrastructure.EventStore.Subscriptions` (STM subscription registry), direct EventStore → WS bridge, control messages (subscribe/unsubscribe rooms).
**Avoids:** PITFALLS-4 (TBQueue + bracket for lifecycle)

**Phase 4b: GraphQL API**
**Rationale:** No hard dependencies on other Phase 4 items. Can parallel with WebSocket.
**Delivers:** `/api/v1/graphql` endpoint with Morpheus resolvers wrapping existing `Core.Services.*` handlers. Query-only initially.
**Avoids:** PITFALLS-3 (batch resolvers, not naive handler wrapping), PITFALLS-10 (replace stub `GraphQLQuery` with Morpheus's type)
**Research flag:** MEDIUM — Morpheus batch resolver support needs verification. N+1 prevention strategy needs design during planning.

### Phase 5: Hasql → Persistent Cleanup (Cross-cutting)
**Rationale:** Not a feature but essential technical debt. Can be done incrementally throughout v51 or batched at end. Removes 6+ modules of dead code.
**Delivers:** Removal of `DAL.Hasql.Database`, `DAL.Pool`, `DAL.Procedures`; switch `Core.Accounting.Cache` to Persistent; standardize `ConnectionPool` to single module.

### Phase Ordering Rationale

The ordering is driven by three constraints: (1) foundational infrastructure before features that depend on it (LOG → everything else), (2) independent features parallelized where possible (MTN + EVT + PAY in Phase 2), (3) high-risk/irreversible decisions made early (multi-tenant strategy impacts everything downstream). Phase 1 is deliberately low-risk (stub replacement) to build confidence before tackling the riskier items in Phase 2. The Hasql cleanup (Phase 5) is a "blue-green" item that can be done when convenient — it doesn't block or depend on any feature.

### Research Flags

| Phase | Flag | Reason |
|-------|------|--------|
| 2a (MTN) | **HIGH** | RLS vs schema-per-tenant unresolved; `entitySchema` not in Persistent 2.13.6.1; requires explicit architectural decision |
| 4b (GQL) | **MEDIUM** | Morpheus batch resolver/DataLoader support needs verification; N+1 mitigation strategy needed |
| 2b (EVT) | **LOW** | Well-documented event sourcing patterns; snapshot implementation is straightforward CRUD |
| 2c (PAY) | **LOW** | Pure calculation exists and is LiquidHaskell-verified; CRUD is standard Persistent |
| 1 (LOG+MET) | **LOW** | Both are standard stub→real replacements with well-documented libraries |
| 3 (RTL) | **LOW** | Existing limiter works; this is additive (keyed/per-tenant wrapper) |
| 4a (WS) | **LOW** | STM subscription pattern is well-understood; existing WS handler is functional |

## Confidence Assessment

| Area | Confidence | Notes |
|------|------------|-------|
| Stack | **HIGH** | All deps verified against lts-22.21; no extra-deps needed; cabal additions documented with version bounds |
| Features | **HIGH** | Verified against existing codebase — stubs match feature descriptions; feature dependency graph is clear |
| Architecture | **HIGH** | Codebase analysis directly read all referenced modules; middleware order, data flow, and component boundaries are well-understood |
| Pitfalls | **HIGH** | 7 of 11 pitfalls from direct codebase analysis with file:line references; `unsafePerformIO`, `* 60` bug, and `search_path` leak are confirmed in source |

**Overall confidence:** HIGH

The high confidence is justified because all research files are based on direct codebase analysis, not external inference. The stubs exist, the types are defined, and the patterns are established. The one true unknown is the multi-tenant strategy conflict (RLS vs schema-per-tenant), which is a deliberate decision that needs to be resolved before Phase 2a begins — it's not a gap in the research, but a strategic choice with tradeoffs documented.

### Gaps to Address

- **Multi-tenant strategy:** STACK research recommends RLS (works with current Persistent 2.13.6.1). ARCHITECTURE and FEATURES specify schema-per-tenant (from PROJECT.md). This MUST be resolved before Phase 2a implementation. Recommended: RLS for v51 (pragmatic, works now), schema-per-tenant deferred to v52 (requires Persistent upgrade). If schema-per-tenant is required now, the `search_path` leak mitigation (Pitfall 1) becomes blocker-critical.
- **GraphQL N+1 mitigation:** Morpheus batch resolver support needs a spike during Phase 4b planning. The fallback is dedicated Esqueleto queries for complex GraphQL fields.
- **Rate limit migration strategy:** Existing `System.RateLimiter` has working code with a `* 60` bug. The migration to `wai-rate-limit` is defined in STACK, but the bug fix should happen independently (can be done in Phase 1 as a quick win).

## Sources

### Primary — Direct Codebase Analysis (HIGH confidence)
- **STACK.md** — Dependency verification against lts-22.21; cabal file analysis; existing module inventory
- **FEATURES.md** — Direct reading of `DAL.EventStore`, `Surypus.WebSocket`, `System.RateLimiter`, `Surypus.Metrics`, `Service.PayrollService`, `MultiTenancy.*`, `Surypus.API.GraphQL`
- **ARCHITECTURE.md** — Direct reading of `Surypus.API.Server` middleware stack, `Env` type, `DAL.*` modules, `Infrastructure.EventStore.*`
- **PITFALLS.md** — Direct codebase evidence for 7/11 pitfalls (`globalBroadcaster`, `swCheck` bug, `DAL.ORMPool` hardcoded creds, `search_path` leak pattern, duplicate pool types, stub `GraphQLQuery`)

### Secondary — Established Patterns (MEDIUM confidence)
- **Schema-per-tenant vs RLS** — Multiple PostgreSQL multi-tenant guides; Persistent `entitySchema` PR #1561 confirms limitation in lts-22
- **GraphQL N+1 prevention** — General Haskell GraphQL community knowledge; needs morpheus-specific verification during Phase 4b planning
- **Event sourcing with PostgreSQL** — Established pattern; multiple sources confirm JSONB + snapshot table approach

---

*Research completed: 2026-06-09*
*Ready for roadmap: yes*
