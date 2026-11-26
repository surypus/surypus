# Feature Landscape: v51.0 Enterprise Readiness

**Domain:** Haskell ERP/CRM with formal verification
**Researched:** 2026-06-09
**Overall confidence:** HIGH (verified against existing codebase)

## Executive Summary

This milestone adds production hardening and enterprise features to an existing Haskell ERP/CRM. The codebase already has scaffolding for most features (some are stubs or in-memory only). The work is primarily: (a) replacing stubs with real implementations, (b) adding persistence where only in-memory solutions exist, (c) integrating existing pieces into coherent middleware/service layers, and (d) implementing the multi-tenant architecture.

**Critical insight:** The existing codebase has a pattern of "module with types + stub implementations" (Metrics, RateLimiter, GraphQL, MultiTenancy). The real work is implementing bodies, not designing interfaces.

---

## 1. EventStore Enhancements — Replay, Snapshots, Event Versioning

**State:** `DAL.EventStore` has append/get/replay. Inventory store has in-memory replay. No snapshot persistence.

### Table Stakes

| Feature | What | Complexity | Existing Status |
|---------|------|------------|-----------------|
| Event append with optimistic concurrency | Version check + sequence increment in same transaction | Low | ✅ Basic append exists but no version conflict detection |
| Event stream read (by aggregate) | Get all events for an aggregate in order | Low | ✅ `getEvents`, `getEventsFrom` exist |
| Full replay | Reconstruct state from event history | Medium | ✅ In-memory replay exists for Inventory (`replayInventoryEvents`) |
| Snapshot creation | Persist aggregate state at a point | Medium | ❌ `StockSnapshot` exists but is in-memory only, never saved to DB |
| Snapshot restoration | Load from snapshot + replay remaining events | Medium | ❌ Not implemented |
| Event versioning | Schema version on events for migration | Low | ❌ `eventVersion` field exists but is always `1` |
| Snapshot table | `aggregate_snapshots` table (aggregate_type, aggregate_id, version, state, created_at) | Low | ❌ Does not exist |

### Differentiators

| Feature | Value | Complexity | Notes |
|---------|-------|------------|-------|
| Snapshot at configurable interval | e.g., every N events or by time | Low | Simple counter per aggregate |
| Snapshot rebuilding | Rebuild all snapshots from events | Medium | Admin operation, async |
| Global event stream replay | Rebuild entire system state | High | Needed for disaster recovery |
| Event schema migration | Transform events on-the-fly during replay | High | Version field exists, schema migration logic needed |

### Dependencies

```
DAL.EventStore (existing) → Snapshot table (new) → Snapshot management (new) → Replay improvements (new)
```

**Key decisions:**
- Snapshot table MUST include schema_version field from day one
- Snapshot creation should be async (event after every N events triggers snapshot)
- Snapshot format: JSONB (same as events) for simplicity with Persistent
- Version field `eventVersion` is present but always `1` — define a versioning scheme

---

## 2. GraphQL API — Schema, Resolvers, Servant Integration

**State:** `Surypus.API.GraphQL` exists as a stub with `GraphQLQuery`, `GraphQLResponse`, and a type-level `GraphQLAPI` = `ReqBody '[JSON] GraphQLQuery :> Post '[JSON] GraphQLResponse`.

### Table Stakes

| Feature | What | Complexity | Existing Status |
|---------|------|------------|-----------------|
| Single POST endpoint | `/graphql` accepting `{query, variables}` | Low | ✅ Type defined, handler is stub |
| Query resolution | Map query strings → data | High | ❌ No resolver logic |
| Schema definition | Types, fields, relationships | High | ❌ `Schema = Map Text Text` is placeholder |
| N+1 query prevention | Batch loading for related entities | High | ❌ Not addressed |
| Servant integration | GraphQL endpoint as part of Servant API | Medium | ✅ Type already uses Servant combinators |
| Error response in GraphQL format | `{errors: [{message: "..."}]}` | Low | ❌ Handler returns `Nothing, Nothing` |

### Differentiators

| Feature | Value | Complexity | Notes |
|---------|-------|------------|-------|
| Schema from Haskell types | Auto-derive GraphQL schema from domain types | High | Requires `morpheus-graphql` |
| Per-field auth | Resolver checks permissions | Medium | Integrate existing RBAC |
| Query complexity analysis | Reject expensive queries before execution | Medium | Protect against DoS |
| Subscriptions over WebSocket | Real-time GraphQL | High | Requires existing WS integration |

### Architecture Options

**Option A: Morpheus GraphQL (recommended)**
- Mature, maintained (v0.28.5, March 2026)
- Native Haskell types → GraphQL schema
- Servant integration examples exist
- GADT-based schema definition
- Built-in query validation
- **Add dependency:** `morpheus-graphql`, `morpheus-graphql-core`

**Option B: graphql-api**
- Alternative, less mature
- Uses same GADT approach

### Dependencies

```
Existing REST handlers → GraphQL resolver wrappers → Morpheus schema definition
```

**Key decisions:**
- Use **Morpheus GraphQL** — it's the only actively maintained Haskell GraphQL server
- GraphQL resolvers delegate to existing `Core.Services.*` — do NOT duplicate business logic
- Start with Query-only (no Mutations initially) — mutations go through REST for transactional safety
- Existing auth middleware (JWT) must pass through to GraphQL context

---

## 3. WebSocket — EventStore Integration, Broadcast

**State:** `Surypus.WebSocket` has room-based broadcasting with STM. `Surypus.WebSocket.Integration` connects to EventBus. `Surypus.WebSocket.RedisPublisher` publishes to Redis. `Infrastructure.WebSocket.InventoryBroadcast` bridges inventory events to WS.

### Table Stakes

| Feature | What | Complexity | Existing Status |
|---------|------|------------|-----------------|
| Connection management | Accept, ping/pong, cleanup on disconnect | Low | ✅ In `Surypus.WebSocket.handleWebSocket` |
| Room-based broadcast | Send to subscribers of a room | Low | ✅ `broadcastToRoom` works |
| Global broadcast | Send to all connections | Low | ✅ `broadcastGlobal` |
| EventStore → WS bridge | When event appended, broadcast to subscribers | Medium | ✅ Done for Inventory via global broadcaster MVar |
| Unicast (per-user) | Send to specific user's connections | Medium | ❌ Rooms are topic-based, not user-based |
| Connection tracking | Track user → connection mapping | Medium | ❌ Only room → [connections] mapping exists |

### Differentiators

| Feature | Value | Complexity | Notes |
|---------|-------|------------|-------|
| Reconnection with sequence | Client sends last sequence, catches up | High | Useful for dashboards |
| EventStore tail subscription | Listen for new events continuously | Medium | PostgreSQL LISTEN/NOTIFY or polling |
| Per-user subscriptions | User subscribes to specific aggregates | Medium | Combine with RBAC |

### Problems with Current Implementation

1. **Global broadcaster is a mutable singleton** (`unsafePerformIO` + `MVar`) — only one broadcaster can exist; breaks with multiple server instances
2. **No authentication on WebSocket connect** — any WS client can connect to any room
3. **Redis pub/sub not connected to WS handler** — `RedisPublisher` publishes to Redis but there's no subscriber reading from Redis and pushing to WS connections
4. **No horizontal scaling** — STM-based room state is per-process

### Recommended Architecture

```
Event appended → DAL.EventStore → WebSocket bridge → Redis Pub/Sub
                                                         ↓
                                              Redis subscriber (per instance)
                                                         ↓
                                              WS handler → client connections
```

**Key decisions:**
- Replace `globalBroadcaster` MVar with Redis pub/sub for multi-instance support
- Add auth middleware to WebSocket upgrade path (check JWT before accepting)
- Keep room-based broadcast for topics (inventory, bills, etc.)
- Add per-user message routing for personalized notifications
- Use PostgreSQL `LISTEN/NOTIFY` as an alternative lightweight channel for EventStore events

---

## 4. Payroll Persistence — Model, Calculation Storage

**State:** `Core.Payroll.Calculation` has pure functions. `Service.PayrollService` orchestrates. `HR.Salary` has data types. `DAL.Schema` has `SalaryEntity` (employeeId, date, gross, net, taxAmount, pension, other).

### Table Stakes

| Feature | What | Complexity | Existing Status |
|---------|------|------------|-----------------|
| Payroll period CRUD | Create/read/update/close payroll periods | Low | ❌ Not implemented |
| Employee salary persistence | Store base salary, bonuses, deductions | Low | ✅ `SalaryEntity` exists |
| Payroll calculation storage | Save calculation results per period | Medium | ❌ Current stores single salary per employee |
| Batch payroll run | Calculate all employees in a period | Medium | ❌ Only single-employee calculation |
| Pay slip generation | Details of calculation for employee | Medium | ❌ Not implemented |

### Differentiators

| Feature | Value | Complexity | Notes |
|---------|-------|------------|-------|
| Payroll history | Full history of all payment calculations | Low | Extension of persistence |
| Period closing | Lock period after finalization | Low | Prevent recalculations after approval |
| Integration with accounting | Auto-generate ledger entries from payroll | Medium | Integration with existing double-entry |
| Tax reporting | Generate tax forms from payroll data | Medium | Russian-specific (НДФЛ, страховые) |

### Required Schema Additions

```sql
CREATE TABLE payroll_period (
  id BIGSERIAL PRIMARY KEY,
  company_id BIGINT NOT NULL,
  year INT NOT NULL,
  month INT NOT NULL,
  status TEXT NOT NULL DEFAULT 'draft',  -- draft, processing, finalized, closed
  started_at TIMESTAMPTZ,
  finalized_at TIMESTAMPTZ
);

CREATE TABLE payroll_run (
  id BIGSERIAL PRIMARY KEY,
  period_id BIGINT NOT NULL REFERENCES payroll_period(id),
  employee_id BIGINT NOT NULL,
  base_salary NUMERIC(12,2) NOT NULL,
  gross NUMERIC(12,2) NOT NULL,
  income_tax NUMERIC(12,2) NOT NULL,
  social_tax NUMERIC(12,2) NOT NULL,
  net_salary NUMERIC(12,2) NOT NULL,
  advance NUMERIC(12,2) NOT NULL DEFAULT 0,
  bonus NUMERIC(12,2) NOT NULL DEFAULT 0,
  vacation_pay NUMERIC(12,2) NOT NULL DEFAULT 0,
  sick_pay NUMERIC(12,2) NOT NULL DEFAULT 0,
  total_to_pay NUMERIC(12,2) NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
```

**Key decisions:**
- Use `Decimal` (not `Double`) for all monetary amounts — the existing code uses `Double` but `Decimal` is already a dependency
- Payroll period states: `draft → processing → finalized → closed`
- Run the batch payroll as a Redis job (existing `JobWorker` + `Redis.TaskQueue`)
- Store calculation breakdown (components) for pay slip generation

---

## 5. Production Hardening — Rate Limiting, Metrics, Logging

### 5a. Rate Limiting

**State:** `System.RateLimiter` implements 4 strategies (TokenBucket, LeakyBucket, FixedWindow, SlidingWindow). `System.RateLimiterAdvanced` adds configurable strategies with metrics. Neither is integrated with Servant middleware.

#### Table Stakes

| Feature | What | Complexity | Existing Status |
|---------|------|------------|-----------------|
| Per-IP rate limiting | Limit by client IP | Medium | ❌ All limiters are single-instance, not keyed |
| Per-user rate limiting | Limit by authenticated user | Medium | ❌ Same as above |
| Rate limit headers | Return `X-RateLimit-Limit`, `X-RateLimit-Remaining`, `X-RateLimit-Reset` | Low | ❌ Not implemented |
| Servant middleware | Apply rate limiter as WAI middleware or Servant combinator | Medium | ❌ No middleware exists |
| Configurable limits | Per-route limits via config | Medium | ❌ Not implemented |

#### Differentiators

| Feature | Value | Complexity | Notes |
|---------|-------|------------|-------|
| Per-tenant limits | Different limits per tenant | Medium | Combine with multi-tenancy |
| Sliding window | Smoother than fixed window | Low | Already implemented |
| Rate limit bypass for internal | Whitelist IPs/routes | Low | Useful for health checks |

#### Implementation Approach

```haskell
-- Keyed rate limiter
data KeyedRateLimiter = KeyedRateLimiter
  { krlLimiters :: TVar (Map Text RateLimiterAdvanced)
  , krlDefaultConfig :: RateConfig
  }

-- Integrated as WAI middleware:
rateLimitMiddleware :: KeyedRateLimiter -> (Request -> Text) -> Application -> Application
-- where (Request -> Text) extracts the key (IP, user ID, tenant ID)
```

**Key decisions:**
- **Sliding window** as default strategy (best UX vs security tradeoff)
- Implement keyed limiters using `Map Text RateLimiterAdvanced` with a cleanup goroutine for stale entries
- Apply at WAI middleware level (not Servant combinator) for simplicity; route differentiation can happen via path-prefix keys
- Use `System.RateLimiterAdvanced` as base (already has metrics + config), add keyed wrapper

### 5b. Prometheus Metrics

**State:** `Surypus.Metrics` is a no-op stub. `System.Metrics` has basic counters. `System.MetricsCollector` has STM-based store. `System.MetricsExport` has Prometheus format target type. `Surypus.API.MetricsMiddleware` is a pass-through stub.

#### Table Stakes

| Feature | What | Complexity | Existing Status |
|---------|------|------------|-----------------|
| `/metrics` endpoint | Expose Prometheus text format | Low | ❌ Stub middleware |
| HTTP request counter | `http_requests_total` with status/method labels | Low | ❌ Stub |
| HTTP latency histogram | `http_request_duration_seconds` with buckets | Medium | ❌ Stub |
| DB pool connections | `db_pool_connections` gauge | Low | ❌ Stub |
| Active WebSocket connections | `websocket_connections` gauge | Low | ❌ Not implemented |
| Business metrics | Custom counters per domain | Low | ❌ Not implemented |

#### Differentiators

| Feature | Value | Complexity | Notes |
|---------|-------|------------|-------|
| GHC runtime metrics | GC stats, memory, threads | Low | `prometheus-metrics-ghc` package |
| DB query duration | Per-query timing histogram | Medium | Requires DAL instrumentation |
| Job queue depth | `job_queue_depth` gauge | Low | Integration with existing Redis queue |
| Alert rules | Suggested Prometheus alert rules | Low | Documentation/export |

#### Implementation Approach

**Add dependencies:**
- `prometheus-client` — core metric types
- `wai-middleware-prometheus` — automatic WAI instrumentation + `/metrics` endpoint
- `prometheus-metrics-ghc` — GHC runtime metrics

```haskell
-- Using wai-middleware-prometheus:
import Network.Wai.Middleware.Prometheus (prometheus)

-- This single middleware:
-- 1. Adds /metrics endpoint
-- 2. Records http_requests_total (status, method, path)
-- 3. Records http_request_duration_seconds histogram
app = prometheus defaultPrometheusSettings $ restApp
```

**Key decisions:**
- Use `wai-middleware-prometheus` instead of building custom Prometheus endpoint — it's a standard, well-tested library
- Add custom business metrics via `prometheus-client` `Counter`, `Gauge`, `Histogram` and register them alongside the middleware
- Replace existing `Surypus.Metrics` stub with actual Prometheus metrics
- Keep `System.MetricsCollector` as a lightweight STM-based store for in-memory aggregation (sampling), but expose via Prometheus

### 5c. Structured Logging

**State:** `System.Logger` writes to in-memory TVar list (not production). `System.Log` has types only. `fast-logger` is already a dependency. `monad-logger` is a dependency.

#### Table Stakes

| Feature | What | Complexity | Existing Status |
|---------|------|------------|-----------------|
| Structured JSON output | Each log line as JSON object | Medium | ❌ Only in-memory list |
| Log levels | DEBUG, INFO, WARN, ERROR | Low | ✅ Types exist in System.Logger |
| Correlation IDs | `request_id` in every log entry | Medium | ❌ Not implemented |
| File rotation | Rotate logs by size/time | Low | ❌ Not configured |
| Request logging | Automatic logging of HTTP requests | Low | ❌ Not integrated |

#### Differentiators

| Feature | Value | Complexity | Notes |
|---------|-------|------------|-------|
| katip structured logging | Namespaced, structured payloads | Medium | Typesafe structured context |
| Elasticsearch/Logstash output | Send JSON logs to log aggregator | Low | katip has elasticsearch backend |
| Sampling | Debug-level sampling for high-volume endpoints | Medium | Optional |
| Sensitive data redaction | Auto-redact passwords, tokens in logs | Low | Pattern-based |

#### Implementation Approach

**Option A: katip (recommended for structured logging)**
- Typeclass-based structured payloads
- Namespaces for hierarchical logging
- JSON rendering built-in
- Handle/file backend + Elasticsearch backend
- Mature (maintained, 0.8.8.4 as of Sep 2025)

**Option B: fast-logger + monad-logger (already in deps, simpler)**
- Already in dependency tree
- `monad-logger` provides `MonadLogger` typeclass
- Can combine with `aeson` for JSON formatting
- Simpler but less structured than katip

**Recommended: Use katip** for structured logging, with fast-logger as the backend output:

```haskell
import Katip (Katip, KatipContext, logInfo, logError, (...), initLogEnv, registerScribe)

main = do
  le <- initLogEnv "Surypus" "production"
  (handleScribe, closeScribe) <- mkHandleScribe ColorIfTerminal stdout (permitItem Info) V2
  registerScribe "stdout" handleScribe defaultScribeSettings le
  -- Now log with correlation IDs:
  runKatipContextT le (sl "{requestId}" requestId) $ do
    logInfo $ sl "{method} {path}" !sl "method" "GET" !sl "path" "/api/bills"
```

**Key decisions:**
- **Use katip** — the project specifically mentions it in PROJECT.md (`LOG-01: Structured JSON logging (katip)`)
- Correlation ID: generate UUID per request in middleware, store in `KatipContext`
- Log format: JSON with fields: `timestamp`, `level`, `source`, `message`, `request_id`, `tenant_id`, `user_id`, `duration_ms`
- Route all existing logging (System.Logger, System.Log) through katip; remove TVar-based logger

---

## 6. Multi-Tenant Architecture

**State:** `MultiTenancy.Isolation` has `TenantContext` type + stubs. `MultiTenancy.TenantConfig` has config types + stubs. No real implementation.

### Isolation Strategy Comparison

| Strategy | Isolation | Operational Cost | Max Tenants | Migration Complexity |
|----------|-----------|------------------|-------------|---------------------|
| Shared table + tenant_id column | Low (row-level) | Low | Unlimited | Requires rewriting queries |
| Schema-per-tenant | High (schema-level) | Medium | 1000s | Requires search_path management |
| Database-per-tenant | Very High (DB-level) | High | 100s | Expensive connections |

**Project decision (from PROJECT.md):** Schema-per-tenant ("изоляция данных, schema-per-tenant")

### Table Stakes (Schema-per-Tenant)

| Feature | What | Complexity | Existing Status |
|---------|------|------------|-----------------|
| Tenants table | Registry of tenants with schema names | Low | ❌ Not in DAL.Schema |
| Tenant resolution | Extract tenant from JWT/header/subdomain | Medium | ❌ Stub exists |
| Schema creation | Provision new schema with all tables | High | ❌ Need to run migrations per schema |
| Connection pool routing | Route to correct schema per request | High | ❌ Not implemented |
| Migration strategy | Apply migrations to all tenant schemas | High | ❌ Not implemented |
| Row-level security (RLS) | Fallback for cross-schema queries | Medium | ❌ Not implemented |

### Differentiators

| Feature | Value | Complexity | Notes |
|---------|-------|------------|-------|
| Automated tenant provisioning | New tenant = insert + create schema + run migrations | Medium | Script in application |
| Per-tenant feature flags | Enable/disable features per tenant | Low | `tcFeatures` already in TenantConfig |
| Tenant-aware backups | Backup/restore per schema | Medium | PostgreSQL pg_dump per schema |
| Tenant migration status | Track which schemas have which migration versions | Medium | Migration tracking table per tenant |

### Implementation Approach

**Schema management:**

```sql
-- Shared public schema
CREATE TABLE public.tenants (
  id BIGSERIAL PRIMARY KEY,
  name TEXT NOT NULL,
  slug TEXT NOT NULL UNIQUE,
  schema_name TEXT NOT NULL UNIQUE,
  features JSONB DEFAULT '{}',
  branding JSONB DEFAULT '{}',
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  status TEXT NOT NULL DEFAULT 'active'
);

-- Each tenant gets: CREATE SCHEMA tenant_<id>;
-- Tables are created in each tenant schema
-- search_path = tenant_<id>, public
```

**Connection pool strategy:**
- One `Pool SqlBackend` connected to the database
- On each request (in middleware), execute `SET search_path TO tenant_<slug>, public`
- Using Persistent: `createRawPostgresqlPoolModified` to apply search_path per connection
- **OR** use separate pools per tenant (easier with Persistent but uses more connections)

**Recommended approach for Persistent:**
```haskell
-- Using createRawPostgresqlPoolModified:
createTenantAwarePool :: ConnectionString -> Int -> IO (Pool (RawPostgresql SqlBackend))
createTenantAwarePool connStr poolSize =
  createRawPostgresqlPoolModified setSearchPath connStr poolSize
  where
    setSearchPath conn = do
      -- Initial schema set during pool creation
      -- Then per-request via runSqlConn with SET search_path
      pure ()
```

However, `search_path` is session-level — in a pool, you can't guarantee which connection you get. The safer approach:

**Per-request approach:**
```haskell
runDbForTenant :: Tenant -> SqlPersistT (LoggableT IO) a -> IO a
runDbForTenant tenant action = runDb pool $ do
  rawExecute "SET search_path TO ?" [PersistText (tenantSchema tenant)]
  action
```

This adds a round-trip per query. Acceptable for request-scoped operations.

### Key Decisions

1. **Schema-per-tenant** (from PROJECT.md) with a shared `public` schema for global tables (tenants, users, roles)
2. **No separate connection pools per tenant** — use one pool + `SET search_path` per request
3. **Tenant resolved from JWT claims** (not subdomain or header) — JWT already exists; add `tenant_id` claim
4. **Migration strategy:** Apply new migrations sequentially across all tenant schemas using a `tenant_migrations` tracking table in each schema
5. **RLS as defense-in-depth:** Add row-level security policies even with schema isolation

---

## Feature Dependency Graph

```
                    ┌─────────────┐
                    │ Multi-Tenant │←─── Rate Limiting (per-tenant)
                    └──────┬──────┘    Logging (tenant_id)
                           │
                           ▼
              ┌──────────────────────┐
              │  Tenant Resolution    │
              │  (JWT → tenant_id)    │
              └──────┬───────────────┘
                     │
     ┌───────────────┼───────────────┐
     ▼               ▼               ▼
┌─────────┐   ┌───────────┐   ┌───────────┐
│GraphQL  │   │Rate       │   │Logging    │
│(wraps   │   │Limiting   │   │(katip +   │
│REST)    │   │(WAI       │   │correlation)│
└────┬────┘   │middleware)│   └───────────┘
     │        └───────────┘
     ▼
┌─────────┐   ┌───────────┐
│EventStore│◄──│WebSocket  │
│(snapshot,│   │(EventStore│
│ replay)  │   │ broadcast)│
└────┬────┘   └───────────┘
     │
     ▼
┌─────────┐
│Payroll  │
│(periods,│
│persist) │
└─────────┘

Metrics (WAI middleware, wraps everything)
```

## MVP Recommendation for v51.0

**Prioritize in order:**

1. **Structured logging (katip)** — Foundation: every other feature benefits from structured logging
2. **Prometheus metrics (wai-middleware-prometheus)** — Foundation: monitoring enables confidence in other features
3. **Rate limiting middleware** — Production requirement; quick win using existing `RateLimiterAdvanced`
4. **EventStore snapshots** — Core infrastructure; needed for performance at scale
5. **Payroll persistence** — Business feature; self-contained
6. **WebSocket EventStore integration** — Depends on EventStore stability
7. **GraphQL API** — Can wrap existing REST; parallel work possible
8. **Multi-tenant** — Most invasive; plan carefully, implement last

**Defer:** Global event stream replay (disaster recovery only), GraphQL subscriptions (WS complexity), per-tenant backup/restore (operations tooling).

## Anti-Features

| Anti-Feature | Why Avoid | What to Do Instead |
|--------------|-----------|-------------------|
| Database-per-tenant | Too complex for current scale; connection explosion | Schema-per-tenant (already decided) |
| GraphQL mutations initially | Risk of bypassing existing transactional guarantees | Keep mutations on REST; Query-only GraphQL |
| EventStore on separate database | Already committed to PostgreSQL EventStore (PROJECT.md) | Keep events in same DB |
| Custom Prometheus client | `wai-middleware-prometheus` does this already | Use existing library |
| Per-user WebSocket broadcasts at scale | Complex state management | Start with room-based; add user-only later |
| Custom GraphQL DSL | Use Morpheus or nothing | Roll-your-own is a maintenance trap |

## Sources

- **Codebase analysis:** Existing source files at `src/DAL/EventStore.hs`, `src/Infrastructure/EventStore/Inventory.hs`, `src/System/RateLimiter.hs`, `src/Surypus/Metrics.hs`, `src/MultiTenancy/`, etc.
- **Morpheus GraphQL:** https://hackage.haskell.org/package/morpheus-graphql (v0.28.5, March 2026)
- **prometheus-haskell:** https://github.com/fimad/prometheus-haskell, `wai-middleware-prometheus`
- **katip structured logging:** https://github.com/Soostone/katip (v0.8.8.4, Sep 2025)
- **EventStore snapshot strategies:** https://oneuptime.com/blog/post/2026-01-30-event-snapshotting
- **Multi-tenant PostgreSQL:** https://oneuptime.com/blog/post/2026-01-25-multi-tenant-schemas-postgresql
- **Persistent PostgreSQL:** https://hackage.haskell.org/package/persistent-postgresql (`createRawPostgresqlPoolModified`)
- **PostgreSQL event sourcing:** https://viprasol.com/blog/postgres-event-sourcing/
- **WebSocket broadcast patterns:** https://zknill.io/posts/patterns-for-building-realtime/ (Feb 2025)
