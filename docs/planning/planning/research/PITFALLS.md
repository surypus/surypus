# Domain Pitfalls: v51.0 Enterprise Readiness

**Domain:** Haskell ERP/CRM (Servant + Persistent + EventStore)
**Researched:** 2026-06-09
**Overall confidence:** HIGH (direct codebase analysis + established Haskell patterns)

---

## Critical Pitfalls

### Pitfall 1: Persistent Connection Pool + `search_path` Leaks

**What goes wrong:** When using schema-per-tenant, each connection in the pool executes `SET search_path = 'tenant_42'` for a request. When the connection is returned to the pool, the `search_path` value persists. The next request (for a different tenant) reuses the same connection with the wrong `search_path`, accessing the wrong tenant's data.

**Why it happens:** `runSqlPool` checks out a connection from the pool, runs the action, and returns it. It does NOT automatically reset session-level settings. `SET search_path` is session-scoped, not transaction-scoped.

**Consequences:** Catastrophic data leak between tenants. Tenant A's request reads Tenant B's data.

**Prevention:**
```haskell
-- WRONG — search_path persists on connection
runSqlPool (rawExecute "SET search_path = 'tenant_42'" [] >> userQuery) pool

-- RIGHT — reset on every checkout
runSqlPool (do
  rawExecute "SET search_path = 'tenant_42'" []
  result <- userQuery
  rawExecute "SET search_path = 'public'" []
  pure result
) pool

-- BETTER — wrapper that always sets tenant context
runDbWithTenant :: TenantContext -> ConnectionPool -> SqlPersistT IO a -> IO a
runDbWithTenant ctx pool action =
  runSqlPool action pool   -- but pool must be tenant-specific, or use SET + teardown
```

**Detection:** Add test that creates two tenants, writes data to both, then reads both from the same connection pool. If data from tenant A appears in tenant B's results, the leak exists.

**Better approach:** Use separate connection pools per tenant (via PgBouncer or `Data.Pool`) instead of managing search_path. But this adds complexity. For v51, use `runDbWithTenant` pattern with `SET search_path` + teardown.

### Pitfall 2: `unsafePerformIO` Global State in EventStore Broadcaster

**What goes wrong:** The `globalBroadcaster` MVar in `DAL.EventStore` is initialized with `unsafePerformIO`:
```haskell
globalBroadcaster :: MVar (Maybe BroadcastCallback)
globalBroadcaster = unsafePerformIO (newMVar Nothing)
```

**Why it happens:** Quick-and-dirty global state to avoid threading the broadcaster through every EventStore call.

**Consequences:**
- `unsafePerformIO` breaks referential transparency — behavior depends on when/if this is evaluated
- Multiple threads calling `setWebSocketBroadcaster` can race on the MVar
- If `globalBroadcaster` is never initialized, `appendEventBroadcast` silently does nothing (broadcaster is Nothing)
- Test isolation is impossible — test A setting the broadcaster affects test B

**Prevention:** Thread `BroadcastCallback` through the EventStore explicitly — either via `AccountingEventStore`/`InventoryEventStore` record fields, or via `ReaderT` pattern. For v51, add a `esBroadcaster :: Maybe BroadcastCallback` field to the event store data types.

**Detection:** Static analysis: any `{-# NOINLINE #-}` with `unsafePerformIO` is a red flag.

### Pitfall 3: GraphQL N+1 Query Problem Over Servant Handlers

**What goes wrong:** A GraphQL query like `{ bills { lines { goods } } }` calls the REST handler for each nested resource individually. For 100 bills, each with 5 lines, this fires 1 + 100 + 500 = 601 separate DB queries.

**Why it happens:** If GraphQL resolvers naively wrap individual Servant handlers (`billsList` → `billGet` → `goodsGet`), each is a separate `runSqlPool` call.

**Consequences:** Orders-of-magnitude performance degradation compared to REST endpoint that returns everything in one query.

**Prevention:**
1. Use **batch resolvers** — Morpheus has `Resolver` type that supports batched field resolution
2. **DataLoader pattern** — Group N individual requests into batched DB queries
3. For complex queries, provide **dedicated GraphQL-only resolvers** that construct optimized Esqueleto queries, rather than wrapping REST handlers
4. Add query depth limiting and complexity analysis to prevent abuse

```haskell
-- Bad: resolver calls individual handler
resolveBill :: Int64 -> Handler Bill
resolveBill id = billGet env id   -- 1 DB query per bill

-- Better: batched resolver
resolveBills :: Handler [Bill] -> GQLResolver [Bill]
resolveBills billsResolver = ...  -- Morpheus batching
```

### Pitfall 4: STM `TChan` Unbounded Growth in WebSocket Subscriptions

**What goes wrong:** If a WebSocket client disconnects but the subscription cleanup fails (exception during disconnect handling), the `TChan` for that subscription remains in the `SubscriptionManager` and accumulates events indefinitely.

**Why it happens:** STM `TChan` is an unbounded FIFO channel. Writers always succeed. No backpressure.

**Consequences:** Memory leak — dead subscriptions accumulate events in unbounded channels until OOM.

**Prevention:**
1. Use `TBQueue` instead of `TChan` — bounded queue with backpressure on write
2. Ensure `bracket` pattern for subscription lifecycle:
   ```haskell
   withSubscription :: SubscriptionManager -> Text -> (TChan DomainEvent -> IO a) -> IO a
   withSubscription subMgr aggType action =
     bracket (subscribe subMgr aggType) (\(_, subId) -> unsubscribe subMgr subId)
             (\(chan, _) -> action chan)
   ```
3. Heartbeat/ping on WebSocket — if client doesn't respond, trigger cleanup

---

## Moderate Pitfalls

### Pitfall 5: Mixed Connection Pool Types (HASQL vs PERSISTENT)

**What goes wrong:** `DAL.Database` exports `ConnectionPool`, `DAL.ORMPool` exports `ConnectionPool`. They are the same type (`PG.ConnectionPool`) but from different modules. Service modules may import from the wrong one.

**Evidence:** The cabal file lists both `DAL.Database` and `DAL.Hasql.Database` as exposed modules. Some code still uses Hasql.

**Prevention:** For v51, standardize on `DAL.Database.ConnectionPool` and re-export from a single location. Remove Hasql pool usage.

### Pitfall 6: Prometheus `/metrics` Endpoint Conflict

**What goes wrong:** The existing `metricsEndpoint` middleware in `Server.hs` serves `/api/v1/metrics` inline. `wai-middleware-prometheus` serves `/metrics` by default. Two different metrics endpoints, possibly serving different formats.

**Prevention:**
1. Remove inline `metricsEndpoint` handler
2. Let `wai-middleware-prometheus` handle `/metrics`
3. Add redirect from `/api/v1/metrics` → `/metrics`
4. Or configure custom path in prometheus middleware

### Pitfall 7: Template Haskell + Dynamic Tenant Schema

**What goes wrong:** `persistent-template` generates types and instances at compile time for a fixed schema. Tenant provisioning requires creating identical schema at runtime for new tenants. TH cannot help here.

**Prevention:** Use raw SQL for tenant schema creation (post-migration step). The `mkPersist` generated types work with any schema as long as the table structure is identical — just change `search_path`.

### Pitfall 8: Rate Limiter `swWindowSec` Bug

**What goes wrong:** In `System.RateLimiter.swCheck`:
```haskell
let windowSize = (fromIntegral (swWindowSec sw) * 60) :: NominalDiffTime
```
This multiplies the window seconds by 60, effectively making it `windowSize * 60` seconds instead of `windowSize` seconds. If configured as 60 seconds, the actual window is 60 minutes.

**Prevention:** Fix the bug — `fromIntegral (swWindowSec sw)` already gives seconds. Remove `* 60`:
```haskell
let windowSize = fromIntegral (swWindowSec sw) :: NominalDiffTime
```

---

## Minor Pitfalls

### Pitfall 9: `DAL.ORMPool` Hardcoded Credentials

**What goes wrong:** `DAL.ORMPool.createPool` has hardcoded `host=localhost port=5432 dbname=surypus user=postgres password=postgres`. This is a security issue and won't work in production.

**Prevention:** Use `Surypus.DB.Pool.createPool` which reads from environment variables. Standardize all pool creation through one module.

### Pitfall 10: GraphQL `gqVariables` Type Mismatch

**What goes wrong:** The existing `GraphQLQuery` type uses `Maybe Value` for variables. Morpheus expects `Maybe (Map Text Value)` or similar structured format.

**Prevention:** When implementing real GraphQL, replace the stub type with Morpheus's own query type.

### Pitfall 11: Payroll `calcSocialTax` Cap Not Updated

**What goes wrong:** Russian social tax cap is hardcoded at 876000. This cap changes annually. The code will produce wrong results after cap changes.

**Prevention:** Make configurable via `TaxConfig` type or DB lookup:
```haskell
data TaxConfig = TaxConfig
  { incomeTaxBrackets :: [(Double, Double)]  -- threshold → rate
  , socialTaxCap :: Double
  , socialTaxRate :: Double
  }
```

---

## Phase-Specific Warnings

| Phase | Likely Pitfall | Mitigation |
|-------|---------------|------------|
| Phase 1 (LOG) | Katip `initLogEnv` called multiple times | Guard with `once` or initialize in `main` before fork |
| Phase 1 (MET) | Port conflict with ekg server | Check if ekg server is active; use different port or disable ekg |
| Phase 2A (MTN) | search_path leak between tenants | Use `runDbWithTenant` wrapper with reset, or separate pools |
| Phase 2A (MTN) | Migration performance with 100+ schemas | Batch migrations, use raw SQL not TH per schema |
| Phase 2B (EVT) | Concurrent snapshot creation | Use `SELECT ... FOR UPDATE` or advisory lock on aggregate |
| Phase 2B (EVT) | Snapshot data too large | Compress JSON, or store only delta from previous snapshot |
| Phase 3 (RTL) | Multi-threaded race on sliding window | Already uses STM — verify atomicity |
| Phase 3 (PAY) | Duplicate payroll calculations | Use idempotency key (`period + employeeId` unique) |
| Phase 4 (WS) | WebSocket disconnection cleanup failure | `bracket` for subscription lifecycle |
| Phase 4 (GQL) | Depth/complexity DoS | Add query depth limit (default 10), complexity analysis |

## Sources

- **Pitfall 1, 2, 4, 8, 9, 10** — Direct codebase analysis of `DAL.EventStore`, `System.RateLimiter`, `Surypus.WebSocket`, `DAL.ORMPool`, `Surypus.API.GraphQL` (HIGH confidence)
- **Pitfall 3** — N+1 is a known GraphQL pattern, verified by Haskell GraphQL community experience (MEDIUM confidence — needs morpheus-specific batching verification)
- **Pitfall 5** — From cabal file and codebase analysis (HIGH confidence)
- **Pitfall 6** — From `wai-middleware-prometheus` docs and existing `Server.hs` code (HIGH confidence)
- **Pitfall 7** — Known Persistent limitation with template Haskell (HIGH confidence)
- **Pitfall 11** — Russian tax law knowledge + code analysis of `Core.Payroll.Calculation` (HIGH confidence)
