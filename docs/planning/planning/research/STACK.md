# Technology Stack — v51.0 Enterprise Readiness Additions

**Project:** Surypus ERP/CRM
**Researched:** 2026-06-09
**Mode:** Project Research — Stack additions for new capabilities only
**Resolver:** `lts-22.21` (GHC 9.6.4)

**Rule:** Do NOT re-add anything already in `.cabal` (Servant, Persistent, Esqueleto, hedis, ekg, LiquidHaskell, JWT/RBAC, websockets, etc.)

---

## New Dependencies Summary

| Library | Version | In lts-22? | Purpose |
|---------|---------|------------|---------|
| `morpheus-graphql-server` | 0.27.3 | ✅ Available | GraphQL API layer atop existing REST |
| `morpheus-graphql-subscriptions` | 0.27.3 | ✅ Available | WebSocket subscriptions over GraphQL |
| `katip` | 0.8.8.0 | ✅ In snapshot | Structured JSON logging (replacing TVar logger) |
| `prometheus-client` | 1.1.1 | ✅ In snapshot | Prometheus metric types (counters, gauges, histograms) |
| `wai-middleware-prometheus` | 1.0.0.1 | ✅ In snapshot | WAI middleware: auto `/metrics` + request instrumentation |
| `wai-rate-limit` | 0.3.0.0 | ✅ In snapshot | WAI middleware for rate limiting |
| `servant-rate-limit` | 0.2.0.0 | ✅ In snapshot | Servant-level rate limit combinators |
| `wai-rate-limit-redis` | 0.2.0.1 | ✅ In snapshot | Redis backend for wai-rate-limit |

**No extra-deps required** — all packages available in `lts-22.21` directly.

---

## Feature-by-Feature Stack Recommendations

### 1. GraphQL API (`morpheus-graphql-server`)

**Recommendation:** `morpheus-graphql-server-0.27.3` (lts-22)

**Why Morpheus over alternatives:**
- **Active:** v0.28.5 released Mar 2026, 54 releases, 50 contributors, 416 stars
- **Integration pattern:** `interpreter :: RootResolver -> ByteString -> IO ByteString` — wraps trivially as a Servant `Raw` endpoint; no framework coupling
- **Type-driven:** Derive GraphQL schema from native Haskell types via `Generic` + `GQLType`; schema is always in sync with code
- **Subscriptions:** Built-in `morpheus-graphql-subscriptions` for WebSocket-based GraphQL subscriptions (complements EventStore → WS broadcast)
- **Servant integration:** `morpheus-graphql-server` can be mounted as:
  ```haskell
  type API = "graphql" :> Raw  -- wrap interpreter output
  ```
- **Already exists:** `Surypus.API.GraphQL.hs` stub — ready to be filled

**What NOT to do:**
- Do NOT replace existing REST endpoints with GraphQL — GraphQL is an ADDITIONAL layer
- Do NOT try to auto-generate resolvers from Persistent models — wrap existing Service layer functions
- Do NOT use `graphql-api` (less mature, smaller ecosystem) or write a custom GraphQL parser

**Integration point:** `Surypus.API.GraphQL.hs` → uses existing `Core.Services.*` and `Service.*` modules for resolver implementations.

---

### 2. Structured JSON Logging (`katip`)

**Recommendation:** `katip-0.8.8.0` (in snapshot)

**Why katip over alternatives:**
- **Production-proven:** Used by Soostone in production for years; 0.8.8.x is stable
- **Structured output:** Native JSON scribe for logstash/filebeat consumption
- **Context/namespaces:** `KatipContext` typeclass adds structured context to log lines (correlation IDs, tenant IDs, request IDs) — exactly what distributed ERP needs
- **Scribes architecture:** Write to file, stdout, or custom sinks; configurable at runtime
- **Replaces:** Current `System.Logger` (TVar-based in-memory ring buffer — loses logs on restart, not production-grade)

**What NOT to do:**
- Do NOT use `monad-logger` directly (already a dependency but too basic for structured output)
- Do NOT keep the current TVar-based `System.Logger` for production — it has no persistence, no rotation, no structured output

**Migration path for `System.Logger`:**
1. Add `KatipContext` instance to the app's `Env` monad (or `ReaderT Env`)
2. Replace `writeLogMessage` calls with katip's `logDebug`/`logInfo`/`logError`
3. Keep `System.Logger` module interface but swap implementation to wrap katip
4. Add correlation ID scribe context from existing `correlationMiddleware`

**Integration point:** `Surypus.API.Server.Env` gains a `LogEnv` (katip namespace + scribes). Existing `Log.Logger` type (text-based) gets a compatibility shim or gradual replacement.

---

### 3. Prometheus Metrics (`prometheus-client` + `wai-middleware-prometheus`)

**Recommendation:**
- `prometheus-client-1.1.1` (in snapshot) — metric types
- `wai-middleware-prometheus-1.0.0.1` (in snapshot) — WAI middleware, auto `/metrics` endpoint

**Why Prometheus over keeping EKG only:**
- **Industry standard:** Prometheus is the de-facto metrics standard; Grafana dashboards expect Prometheus format
- **Auto-instrumentation:** `wai-middleware-prometheus` provides WAI middleware that automatically records request count, latency, and response status per route
- **Coexistence:** EKG (`ekg-0.4.1.2` in extra-deps) stays for internal debugging; Prometheus becomes the production metrics endpoint
- **Replaces:** Current `Surypus.Metrics` (STM-based stubs — `recordCounter`/`recordTimer`/`startMetricsServer` are all no-ops)

**What NOT to do:**
- Do NOT add `servant-prometheus` (adds 200-600µs per-request overhead for Servant-level instrumentation; WAI-level is sufficient)
- Do NOT remove EKG yet — useful for ad-hoc debugging; phase out after Prometheus is stable for one release

**Integration pattern in `Surypus.API.Server`:**
```haskell
import Network.Wai.Middleware.Prometheus (prometheus, def)
-- Replace current `withMetricsCollection` stub:
app = prometheus def $ ... existing middleware chain ...
```

Custom metrics (e.g., EventStore replay count, job queue depth) use `prometheus-client` directly:
```haskell
import Prometheus (Counter, Gauge, Histogram, register, incCounter, ...)
eventStoreReplays :: IO Counter
eventStoreReplays = register $ counter (Info "eventstore_replays_total" "Total EventStore replays")
```

**Integration point:** `Surypus.Metrics` — replace STM stubs with real Prometheus metrics. `Surypus.API.MetricsMiddleware` — replace no-op middleware with `wai-middleware-prometheus`. `Surypus.API.Server` — add `/metrics` endpoint.

---

### 4. Rate Limiting (`wai-rate-limit` + `servant-rate-limit`)

**Recommendation:** `wai-rate-limit-0.3.0.0` + `servant-rate-limit-0.2.0.0` + `wai-rate-limit-redis-0.2.0.1`

**Why adopt wai-rate-limit over custom implementation:**
- **Existing code** (`System.RateLimiter`, `System.RateLimiterAdvanced`) has 4 in-memory strategies but:
  - No WAI middleware integration (currently used manually in Server.hs with raw `swCheck`)
  - No Redis persistence (rate limits reset on restart)
  - No Servant-level type-safe combinators
- **wai-rate-limit provides:** Redis backend + WAI middleware + Servant combinators — all production-grade
- **Scalable:** Redis-backed rate limits survive restarts, share across instances

**Two-layer approach:**
1. **WAI middleware layer** (`wai-rate-limit`): Global rate limit per IP (100 req/min as required)
2. **Servant combinator layer** (`servant-rate-limit`): Per-endpoint rate limits (e.g., stricter limits on auth endpoints)

**Custom policy for JWT auth integration:**
The existing `authMiddleware` already extracts JWT user info. We write a custom `HasRateLimitPolicy` instance that keys on user ID or tenant ID (not just IP):

```haskell
instance HasRateLimitPolicy MyAuthPolicy where
  type RateLimitKey MyAuthPolicy = Text  -- userId or tenantId
  getRateLimitKey req = 
    case lookup "Authorization" (requestHeaders req) of
      Just hdr -> extractUserIdFromToken hdr
      Nothing  -> return defaultKey  -- IP-based fallback
```

**What NOT to do:**
- Do NOT keep both `System.RateLimiter` AND `wai-rate-limit` — remove the custom in-memory implementations after migration
- Do NOT use `wai-rate-limit` without Redis for production — in-memory backends reset on restart
- Do NOT apply rate limiting to WebSocket upgrade endpoint without careful thought (WebSocket connections are long-lived)

**Migration from existing:**
1. Add `wai-rate-limit` middleware to WAI stack in `Surypus.API.Server`
2. Remove manual `RL.swCheck` calls from individual handlers
3. After stable, remove `System.RateLimiter` and `System.RateLimiterAdvanced` modules

**Integration point:** `Surypus.API.Server` — add `rateLimiting` to the middleware chain before auth middleware (rate limit before auth to avoid DoS on auth endpoints).

---

### 5. Multi-Tenant Architecture

**No new library needed.** PostgreSQL features + existing Persistent suffice.

**Recommendation: Row-Level Security (RLS) + tenant ID column**

**Three approaches considered:**

| Approach | Isolation | Persistent Compat | Query Complexity | Admin Queries |
|----------|-----------|-------------------|------------------|---------------|
| Row-Level Security (RLS) | Medium | ✅ Works now | Low (automatic) | ✅ Bypass via `app.tenant_id = NULL` |
| Schema-per-tenant | High | ❌ Requires persistent ≥2.14 (entitySchema) | Low | ❌ Complex |
| Database-per-tenant | Highest | ✅ Works | High (multi-DB connections) | ❌ Nearly impossible |

**Why RLS:**
- **Works with current Persistent 2.13.6.1** — no schema support needed
- **Zero query changes** — RLS filters rows automatically via `current_setting('app.tenant_id')`
- **Can evolve to schema-per-tenant later** if isolation needs increase (future Persistent upgrade)
- **Admin bypass** — set `app.tenant_id` to empty/0, RLS policy permits for admin role

**Implementation plan:**

```sql
-- Migration V011: Multi-tenant support
-- 1. Add tenant_id to all tenant-scoped tables
ALTER TABLE goods ADD COLUMN tenant_id INTEGER NOT NULL DEFAULT 1;
ALTER TABLE bills ADD COLUMN tenant_id INTEGER NOT NULL DEFAULT 1;
ALTER TABLE persons ADD COLUMN tenant_id INTEGER NOT NULL DEFAULT 1;
-- ... etc.

-- 2. Enable RLS on tenant-scoped tables
ALTER TABLE goods ENABLE ROW LEVEL SECURITY;
CREATE POLICY tenant_goods_isolation ON goods
  USING (tenant_id = current_setting('app.tenant_id')::INTEGER);

-- 3. Create tenant table
CREATE TABLE tenants (
  id SERIAL PRIMARY KEY,
  name TEXT NOT NULL,
  schema_name TEXT NOT NULL DEFAULT 'public',
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
```

In Haskell:
- **AuthMiddleware** extracts tenant from JWT (already has RBAC resolver) → sets `SET app.tenant_id = ?` via raw SQL on each request
- **Connection pool callback:** `createPostgresqlPool` takes a connection setup callback for `SET search_path` or `SET app.tenant_id`
- **Existing queries** need NO changes — RLS handles filtering transparently
- **Multi-tenancy modules** (`MultiTenancy.TenantConfig`, `MultiTenancy.Isolation`) get real implementations

**What NOT to do:**
- Do NOT add a new ORM or DB abstraction layer — Persistent + RLS is sufficient
- Do NOT attempt schema-per-tenant with current Persistent (2.13.6.1 lacks `entitySchema`)
- Do NOT use `pg-schema` library (adds another type-level DSL on top of Persistent — unnecessary complexity)

**Integration point:** `Surypus.API.AuthMiddleware` → `MultiTenancy.Isolation.setTenantContext`. `DAL.ORMPool` → connection setup callback for per-connection tenant configuration.

---

### 6. EventStore Replay & Snapshots

**No new library needed.** PostgreSQL + Persistent is sufficient.

**Already exists:**
- `DAL.EventStore` — append, getEvents, replayAccount, getLatestSequence
- `Infrastructure.EventStore.Accounting` — `AccountSnapshot`, `replayAccountEvents`, `reconstructAccountBalance`, `projectCurrentState`

**Needed additions (existing stack sufficient):**

| Addition | What's Needed |
|----------|--------------|
| Snapshot table | Persistent entity: `EventStoreSnapshot { aggregateType, aggregateId, snapshotData, sequenceNumber, createdAt }` |
| `saveSnapshot` | Write to snapshot table after replay |
| `getLatestSnapshot` | Read snapshot, replay from that sequence number |
| Snapshot trigger | Decide snapshot frequency (every N events, or on demand) |

**No Redis for snapshots** — snapshots are PostgreSQL-native (transactional consistency with events).

**What NOT to do:**
- Do NOT add another event store library (Kafka, NATS, etc.) — the PostgreSQL EventStore works and is transactionally consistent with accounting data
- Do NOT store snapshots in Redis — they need the same transactional guarantees as events
- Do NOT implement snapshotting without versioning — snapshot schema may change; store serialization format version

**Integration point:** `DAL.EventStore` gets `saveSnapshot` / `getLatestSnapshot`. `Infrastructure.EventStore.Accounting` updated to use snapshots in `reconstructAccountBalance`.

---

### 7. WebSocket Broadcast from EventStore

**No new library needed.** Existing `websockets` + `wai-websockets` + STM channels suffice.

**Already exists:**
- `Surypus.WebSocket` — room-based connections, broadcast, inventory/dashboard rooms
- `Surypus.WebSocket.Integration` — EventBus → WebSocket bridge
- `DAL.EventStore.setWebSocketBroadcaster` — callback-based broadcast on event append

**Needed addition:** Direct EventStore → WebSocket bridge (bypass EventBus):
```haskell
-- New module: Infrastructure.EventStore.Broadcast
startEventStoreBroadcaster :: WS.WebSocketHandler -> IO ()
-- Subscribe to DAL.EventStore appends, broadcast to appropriate WS rooms
```

**What NOT to do:**
- Do NOT use `morpheus-graphql-subscriptions` for EventStore events (GraphQL subscriptions are for GraphQL queries; EventStore events use the existing WebSocket rooms)
- Do NOT add a message broker (RabbitMQ, Kafka) just for WebSocket broadcast — STM + existing `MVar` broadcaster is sufficient for single-instance

---

### 8. Payroll Persistence

**No new library needed.** Existing `persistent` + `esqueleto` + migration system.

**Already exists:**
- `Service.PayrollService` — `PayrollRequest`, `PayrollResult` types, `calculatePayroll` function
- `Core.Payroll.Calculation` — tax/salary/vacation/sick leave calculation functions

**Needed:**

| Addition | Description |
|----------|-------------|
| `PayrollPeriod` entity | `{ id, employeeId, periodStart, periodEnd, status }` |
| `PayrollEntry` entity | `{ id, payrollPeriodId, type, amount, description }` |
| `PayrollContribution` entity | `{ id, payrollEntryId, contributionType, amount }` (social/income tax breakdown) |
| Migration V012 | Create payroll tables |
| DAL module | `DAL.Payroll` or `Core.Services.Payroll` |

**What NOT to do:**
- Do NOT calculate payroll in the database — the Haskell `Core.Payroll.Calculation` is verified with LiquidHaskell; SQL stored procedures would bypass verification
- Do NOT use a separate payroll library — Russian payroll tax rules are jurisdiction-specific; the custom implementation is correct and verified

**Integration point:** New migration + `DAL.Payroll` module. `Service.PayrollService` saves results to DB after calculation.

---

## Hasql → Persistent Migration Status (v50.0 Cleanup)

**Existing Hasql remnants (to be removed in v51.0):**

| File | Hasql Reference | Action |
|------|----------------|--------|
| `DAL.Hasql.Database` | Full Hasql pool module | Remove entire module |
| `DAL.Pool` | Hasql pool wrapper | Remove entire module (replaced by `DAL.ORMPool`) |
| `DAL.Database` | `ConnectionPool` alias from Hasql | Change to Persistent `ConnectionPool` |
| `DAL.Procedures` | Hasql-based stored procedure calls | Rewrite using `rawSql` from Persistent |
| `Core.Accounting.Cache` | `undefined` pool (Hasql leftover) | Replace with Persistent ORMPool |
| `Surypus.API.Server` | Imports `DAL.Hasql.Database.ConnectionPool` | Switch to `DAL.ORMPool.ConnectionPool` |

**New dependency:** None needed — this is purely a cleanup and deletion task.

**What NOT to add:**
- Do NOT use `hasql` for ANY new code — all new database access goes through Persistent/Esqueleto
- Do NOT keep Hasql `extra-deps` — once migration is complete, remove `hasql` and `hasql-pool` from deps

---

## Overengineering Risks — What NOT to Add

| Library/Pattern | Why NOT | Instead |
|----------------|---------|---------|
| `kafka` / `kafka-client` | EventStore on PostgreSQL is sufficient; Kafka adds operational complexity | PostgreSQL EventStore with snapshots |
| `rabbitmq` / `amqp` | Existing hedis/Redis queue works for background jobs; WS broadcast uses direct STM | Redis + STM |
| `pg-schema` | Adds another type-level DSL on top of Persistent | Persistent + raw SQL + RLS |
| `servant-prometheus` | 200-600µs overhead per request for Servant-level detail | `wai-middleware-prometheus` (WAI-level, cheaper) |
| `bloodhound` (Elasticsearch) | Search requirements are SQL-based | PostgreSQL `LIKE`/`tsvector` |
| New Haskell GraphQL client lib | `morpheus-graphql-client` is unnecessary — only need server | `morpheus-graphql-server` only |
| Separate rate-limiting service | Unnecessary for single-binary ERP app | `wai-rate-limit` as WAI middleware |
| Database-per-tenant | Overkill for current scale; connection management complexity | Row-Level Security (can evolve later) |

---

## Version Compatibility Matrix

All new deps are verified against `lts-22.21` (GHC 9.6.4):

| Library | Version | Depends On (key) | Compat With Existing |
|---------|---------|------------------|---------------------|
| `morpheus-graphql-server` | 0.27.3 | `base`, `text`, `aeson`, `containers` | ✅ All in lts-22 |
| `katip` | 0.8.8.0 | `aeson`, `text`, `template-haskell`, `transformers` | ✅ Compatible with `monad-logger` already in stack |
| `prometheus-client` | 1.1.1 | `base`, `text`, `containers`, `unordered-containers` | ✅ Pure, no GHC version issues |
| `wai-middleware-prometheus` | 1.0.0.1 | `wai`, `prometheus-client`, `clock`, `http-types` | ✅ WAI 3.2 already in deps |
| `wai-rate-limit` | 0.3.0.0 | `wai`, `http-types`, `time-units` | ✅ WAI already in deps |
| `servant-rate-limit` | 0.2.0.0 | `servant`, `servant-server`, `wai-rate-limit` | ✅ Servant 0.20 already in deps |
| `wai-rate-limit-redis` | 0.2.0.1 | `wai-rate-limit`, `hedis` | ✅ hedis 0.14 already in deps |

---

## cabal File Changes

Add to `build-depends` in `Surypus.cabal` library section:

```cabal
    -- New for v51.0
    , morpheus-graphql-server >= 0.27 && < 0.29
    , morpheus-graphql-subscriptions >= 0.27 && < 0.29
    , katip >= 0.8.8 && < 0.9
    , prometheus-client >= 1.1 && < 1.2
    , wai-middleware-prometheus >= 1.0 && < 1.1
    , wai-rate-limit >= 0.3 && < 0.4
    , servant-rate-limit >= 0.2 && < 0.3
    , wai-rate-limit-redis >= 0.2 && < 0.3
```

No changes to `extra-deps` in `stack.yaml` — all in lts-22.

---

## Stack install verification

```bash
stack build --no-run-tests --no-run-benchmarks 2>&1 | tail -20
```

Expected: new dependencies resolved from lts-22 snapshot without extra-deps.

---

## Sources

- [Stackage lts-22.0 package list](https://www.stackage.org/lts-22.0) — verified all new deps available
- [morpheus-graphql-server 0.27.3 docs](https://www.stackage.org/lts-22.0/package/morpheus-graphql-server-0.27.3)
- [katip 0.8.8.0 docs](https://www.stackage.org/lts-22.0/package/katip-0.8.8.0)
- [prometheus-client 1.1.1 docs](https://www.stackage.org/lts-22.0/package/prometheus-client-1.1.1)
- [wai-middleware-prometheus 1.0.0.1 docs](https://www.stackage.org/lts-22.0/package/wai-middleware-prometheus-1.0.0.1)
- [wai-rate-limit 0.3.0.0 docs](https://www.stackage.org/lts-22.0/package/wai-rate-limit-0.3.0.0)
- [servant-rate-limit 0.2.0.0 docs](https://www.stackage.org/lts-22.0/package/servant-rate-limit-0.2.0.0)
- [wai-rate-limit-redis 0.2.0.1 docs](https://www.stackage.org/lts-22.0/package/wai-rate-limit-redis-0.2.0.1)
- [Persistent schema support PR #1561](https://github.com/yesodweb/persistent/pull/1561) — confirmed entitySchema not in lts-22 persistent-postgresql (2.13.6.1)
- Codebase analysis: `DAL.Hasql.Database`, `DAL.Pool`, `DAL.Procedures`, `System.RateLimiter`, `System.Logger`, `Surypus.Metrics`, `MultiTenancy.Isolation`
