# Architecture: v51.0 Enterprise Readiness

**Researched:** 2026-06-09
**Domain:** Haskell ERP/CRM (Servant + Persistent + EventStore)
**Mode:** Ecosystem Architecture
**Overall confidence:** HIGH

---

## 1. Current Architecture Summary

### Existing Layers

```
warp/WAI
  │
  └── Middleware stack (order in apiServer)
       ├── metricsEndpoint           (stub — inline /metrics handler)
       ├── rateLimiting              (works — System.RateLimiter sliding window)
       ├── correlationMiddleware     (works — x-correlation-id)
       ├── authMiddleware            (works — JWT Bearer token via jose)
       ├── withAuthzResolverAdvanced  (works — RBAC path→permission mapping)
       └── serve SurypusApi          (Servant type-level routing)
             ├── login, bills, goods, persons, payments
             ├── dashboard, CRM (deals, contacts, companies, pipeline)
             ├── notifications, reports, orders, users
             ├── integrations, workflows
             └── classifiers (oksm, okv, okei … 15 classifiers)
```

### Core Data Flow

```
HTTP Request
  → WAI Middleware Stack
    → correlationId (x-correlation-id header or UUID)
    → rateLimiting (sliding window, 100 req/min)
    → authMiddleware (JWT verify)
    → RBAC (path→permission→check)
  → Servant Handler (Env → IO (Either Error Response))
    → DAL (Persistent/Esqueleto runSqlPool)
    → PostgreSQL
```

### Key Types

```haskell
-- Server.hs
data Env = Env
  { envConnectionPool :: ConnectionPool     -- Persistent Postgres pool
  , envLogger         :: Log.Logger         -- Stub logger
  , envWSHandler      :: Maybe WS.WebSocketHandler  -- STM-based room registry
  }

-- DAL.Database / DAL.ORMPool (duplicate)
type ConnectionPool = PG.ConnectionPool    -- Database.Persist.Postgresql
type Pool = ConnectionPool

runDb :: ConnectionPool -> SqlPersistT IO a -> IO a
```

### Current State of Targets (all stubs)

| Feature | Module | Status |
|---------|--------|--------|
| EventStore | `DAL.EventStore` | Basic append/list. `globalBroadcaster` via MVar hack. No snapshot table. |
| EventStore Accounting | `Infrastructure.EventStore.Accounting` | Has `AccountingEvent` ADT, in-memory replay via `foldl'`, `AccountSnapshot` type. No DB snapshots. |
| EventStore Inventory | `Infrastructure.EventStore.Inventory` | Same pattern. `StockSnapshot` type. In-memory replay. |
| GraphQL | `Surypus.API.GraphQL` | Types only: `GraphQLQuery`, `GraphQLResponse`. Handler is `const $ return stub`. |
| WebSocket | `Surypus.WebSocket` | STM-based `TVar (Map Text [(Int, WS.Connection)])`. Room subscriptions. |
| WebSocket+EventStore | `Surypus.WebSocket.Integration` | Polls `EventBusAdvanced` TQueue and broadcasts to rooms. |
| Payroll | `Service.PayrollService` | Pure calculation. `SalaryEntity` in Schema. No DB writes. |
| Payroll Engine | `Core.Payroll.Calculation` | Russian tax rules (НДФЛ, страховые взносы). Pure functions. |
| Rate Limiting | `System.RateLimiter` | 4 algorithms (token bucket, leaky bucket, fixed window, sliding window). Working middleware in Server.hs. |
| Metrics | `Surypus.Metrics` | STM counters. All `record*` are no-ops. |
| Metrics Middleware | `Surypus.API.MetricsMiddleware` | Stub. `withMetricsCollection _ app = app`. |
| Logging | `Surypus.API.Logger` | Stub. All `log*` are `const $ return ()`. `unsafePerformIO` global. |
| Multi-Tenancy | `MultiTenancy.Isolation` | `TenantContext` type. `setTenantContext` is `putStrLn`. |
| Tenant Config | `MultiTenancy.TenantConfig` | `TenantConfig` type. `loadTenantConfig` is `return Nothing`. |
| WebSocket Broadcast | `Infrastructure.WebSocket.InventoryBroadcast` | Converts InventoryEvent → JSON → room broadcast. Works. |
| WebSocket Redis | `Surypus.WebSocket.RedisPublisher` | Publishes to Redis channel `surypus:events`. Works. |

---

## 2. Integration Points

### 2.1 EventStore Snapshots

**What changes:** New `event_snapshots` table, snapshot management, replay API endpoint.

**Schema addition:**

```haskell
-- DAL.Schema (existing event_store table)
EventStoreEntity sql=event_store
  aggregateId Int64
  aggregateType Text
  eventType Text
  eventVersion Int
  eventData Text               -- JSON-encoded
  eventMetadata Text Maybe
  sequenceNumber Int64         -- monotonic per aggregate
  occurredAt UTCTime
  createdAt UTCTime
  deriving Show Eq

-- NEW: event_snapshots table
EventSnapshotEntity sql=event_snapshot
  aggregateId Int64
  aggregateType Text
  snapshotVersion Int           -- eventVersion at snapshot time
  lastSequenceNumber Int64      -- sequenceNumber at snapshot time
  snapshotData Text             -- JSON-encoded projected state
  snapshotMetadata Text Maybe
  createdAt UTCTime
  deriving Show Eq

-- Unique: (aggregateId, aggregateType, snapshotVersion)
```

**New module structure:**

```
DAL.EventStore          — existing: basic append/list/sequence
  NEW: storeSnapshot, getLatestSnapshot, getSnapshotsForAggregate
  NEW: replayFromSnapshot — events after snapshot sequence

Infrastructure.EventStore.Accounting
  MODIFY: replayAccountEvents → accept from-snapshot starting state
  NEW: takeAccountSnapshot — persist AccountSnapshot to DB
  NEW: reconstructFromSnapshot — load snapshot + replay events after it

Infrastructure.EventStore.Inventory
  MODIFY: same pattern as Accounting
```

**Integration with existing DAL.EventStore:**

```haskell
-- New functions in DAL.EventStore
storeSnapshot :: ConnectionPool -> Int64 -> Text -> Int -> Int64 -> Value -> Maybe Value -> IO (Either Text ())
getLatestSnapshot :: ConnectionPool -> Int64 -> Text -> IO (Either Text (Maybe EventSnapshotEntity))
getEventsFromSequence :: ConnectionPool -> Int64 -> Text -> Int64 -> IO (Either Text [Event])

-- Replay with snapshot optimization
replayFromSnapshot :: ConnectionPool -> Int64 -> Text -> IO (Either Text (Maybe (EventSnapshotEntity, [Event])))
replayFromSnapshot pool aggId aggType = do
  snapE <- getLatestSnapshot pool aggId aggType
  case snapE of
    Right (Just snap) -> do
      events <- getEventsFromSequence pool aggId aggType (lastSequenceNumber snap + 1)
      pure $ Right (Just (snap, events))
    Right Nothing -> do
      events <- getEvents pool aggId aggType
      pure $ Right (Nothing, events)   -- full replay
    Left err -> pure $ Left err
```

**When to take snapshots:**
- Every N events per aggregate (configurable, default 100)
- On demand via admin API
- During low-traffic window (background job)

### 2.2 GraphQL Alongside REST

**Approach: Morph to proxy pattern — do NOT duplicate handlers.**

GraphQL should NOT be a separate handler layer with its own DB queries. It must wrap existing Servant handlers to avoid maintaining two backends.

**Recommended library:** `morpheus-graphql` (most mature Haskell GraphQL, good servant integration).

```haskell
-- Surypus.API.GraphQL — REPLACE stub with:
data Query = Query
  { bill   :: Int64 -> Handler Bill
  , bills  :: Handler [Bill]
  , goods  :: Handler [Goods]
  , person :: Int64 -> Handler Person
  , persons :: Handler [Person]
  , deals  :: Handler [CRM.Deal]
  , contact :: Int64 -> Handler CRM.Contact
  , -- ... map to existing handler functions
  }

-- Define Morpheus GraphQL schema:
defineEnum "BillType" [ "PURCHASE", "SALES", "TRANSFER" ]
defineObject "Bill" [ "id" !: Int64, "type" !: Int, "total" !: Double ]

-- App resolver:
resolveQuery :: Env -> Query
resolveQuery env = Query
  { bill   = \id -> handlerToGQL $ billGet env id
  , bills  = handlerToGQL $ billsList env
  , -- ...
  }

-- Integration into Servant:
type GraphQLAPI = "graphql" :> ReqBody '[JSON] GraphQLQuery :> Post '[JSON] GraphQLResponse

-- Servant type stays:
type SurypusApi = ...
  :<|> "api" :> "v1" :> GraphQLAPI

-- In apiServer, add graphql route:
graphqlHandler env (GraphQLQuery query vars) = do
  -- Run Morpheus Interpreter with query against resolveQuery env
  result <- interpreter (resolveQuery env) query vars
  pure $ GraphQLResponse (gqlData result) (gqlErrors result)
```

**Integration points with existing server:**

| Existing | GraphQL Integration |
|----------|-------------------|
| `Env` (ConnectionPool, Logger, WSHandler) | Passed to resolvers — same handler functions |
| `AuthMiddleware` | Already on WAI layer — GraphQL under same auth |
| `rateLimiting` | Already on WAI layer — applies to all paths |
| Existing Servant handlers | Wrapped in resolvers, NOT duplicated |

**Important: No duplicate DB logic.** GraphQL resolvers call the same `Core.Services.*` functions as REST handlers. This is the "proxy" pattern — GraphQL is a query language facade over the same service layer.

### 2.3 WebSocket Event Sourcing

**Current:** `Surypus.WebSocket` has STM room registry. `Surypus.WebSocket.Integration` polls `EventBusAdvanced` TQueue.

**Target:** Subscribe WebSocket connections to EventStore streams directly, plus broadcast when events are appended.

**Architecture:**

```
EventStore.appendEvent / appendEventBroadcast
  │
  ├── Write to event_store table (PostgreSQL)
  │
  ├── [NEW] EventStore subscription manager
  │     └── STM-based subscription registry: Map Text [TChan DomainEvent]
  │         (Text = aggregateType filter, or "all")
  │
  ├── [NEW] If broadcaster set (globalBroadcaster MVar):
  │     └── format → WS.sendTextData to matching rooms
  │
  └── [EXISTING] RedisPublisher → Redis pub/sub channel
```

**New module:**

```haskell
-- Infrastructure/EventStore/Subscriptions.hs
data SubscriptionManager = SubscriptionManager
  { smSubscriptions :: TVar (Map Text [TChan DomainEvent])
  , smNextId :: TVar Int
  }

-- Event types for subscriptions
data DomainEvent = DomainEvent
  { deAggregateId :: Int64
  , deAggregateType :: Text
  , deEventType :: Text
  , dePayload :: Value
  , deSequenceNumber :: Int64
  , deTimestamp :: UTCTime
  }

-- subscribe to an aggregate type
subscribe :: SubscriptionManager -> Text -> IO (TChan DomainEvent, Int)
-- unsubscribe
unsubscribe :: SubscriptionManager -> Int -> IO ()
-- publish (called by appendEventBroadcast)
publishEvent :: SubscriptionManager -> DomainEvent -> IO ()
```

**WebSocket handler enhancement:**

```haskell
-- Surypus.WebSocket — MODIFY
handleWebSocket' :: WebSocketHandler -> SubscriptionManager -> WS.Connection -> IO ()
handleWebSocket' handler subMgr conn = do
  key <- allocateKey
  -- client sends subscription message: { "subscribe": ["inventory", "accounting"] }
  msg <- WS.receiveData conn
  let rooms = parseSubscriptionMsg msg
  -- subscribe to EventStore streams
  chans <- mapM (subscribe subMgr) rooms
  -- fork reader: atomically readTChan → WS.sendTextData
  -- fork writer: WS.receiveData → handle control messages
  -- on disconnect: unsubscribe all + cleanup rooms
```

**Backward compatibility:** Existing `broadcastToRoom`, `broadcastGlobal` continue to work. New subscription system is additive.

### 2.4 Payroll Persistence

**Current:** Pure calculation functions. `SalaryEntity` table exists but never written to by service layer.

**Target:** Store `PayrollResult` to `salary` table, support period queries, year-end summaries.

**Schema (already exists):**

```haskell
SalaryEntity sql=salary
  employeeId Int64
  date Day
  gross Double
  net Double
  taxAmount Double
  pension Double
  other Double
  deriving Show Eq
```

**New module:**

```haskell
-- DAL/Payroll.hs (NEW)
createPayrollRecord :: ConnectionPool -> PayrollResult -> IO (Either Text Int64)
getPayrollByEmployee :: ConnectionPool -> Int64 -> Day -> Day -> IO (Either Text [SalaryEntity])
getPayrollByPeriod :: ConnectionPool -> Day -> Day -> IO (Either Text [SalaryEntity])

-- Modify Service.PayrollService
calculateAndPersist :: ConnectionPool -> PayrollRequest -> IO (Either Text PayrollResult)
calculateAndPersist pool req = do
  result <- calculatePayroll req           -- pure calculation
  _ <- createPayrollRecord pool result     -- persist
  pure $ Right result
```

**Integration:**
- New `POST /api/v1/payroll/calculate` → calls `calculateAndPersist`
- New `GET /api/v1/payroll/employees/{id}?from=&to=` → `getPayrollByEmployee`
- Event: append `PayrollCalculated` event to EventStore for audit trail
- RBAC: `payroll:read`, `payroll:write` (already exists in Authorization.hs)

### 2.5 Rate Limiting (Per-Tenant Enhancement)

**Current:** Single global `SlidingWindow` (100 req/min) in `apiServer`. Works on raw WAI level.

**Target:**
- Per-tenant rate limits (once multi-tenant is active)
- Configurable limits per endpoint group
- Rate limit headers (`X-RateLimit-Limit`, `X-RateLimit-Remaining`, `X-RateLimit-Reset`)

**New module:**

```haskell
-- System/RateLimiterEnhanced.hs (NEW)
data RateLimiterConfig = RateLimiterConfig
  { rlcDefaultLimit :: Int
  , rlcDefaultWindow :: Int
  , rlcEndpointOverrides :: Map Text RateLimit
  }

data RateLimit = RateLimit { rlLimit :: Int, rlWindow :: Int } deriving (Eq, Show)

data PerTenantRateLimiter = PerTenantRateLimiter
  { ptrlLimiters :: TVar (Map Text (Map Text SlidingWindow))
  -- ^ tenantId -> (endpoint -> window)
  }

-- Initialize with defaults
initPerTenantLimiter :: RateLimiterConfig -> IO PerTenantRateLimiter

-- Check with headers
checkAndHeaders :: PerTenantRateLimiter -> Maybe Text -> Text -> IO (Bool, ResponseHeaders)
```

**Integration in server middleware (modify `rateLimiting`):**

```haskell
-- In apiServer:
perTenantLimiter <- initPerTenantLimiter config
let app = metricsEndpoint
        $ rateLimitingWithTenant perTenantLimiter  -- MODIFIED
        $ correlationMiddleware logger
        $ authMiddleware
        $ withAuthzResolverAdvanced ...
```

**Backward compatibility:** The existing `rateLimiting` middleware's global check stays as fallback. Per-tenant check added when `X-Tenant-ID` header or JWT `tenant_id` claim is present.

### 2.6 Prometheus Metrics

**Target:** Replace STM stubs with `prometheus-client` + `wai-middleware-prometheus`.

**Dependencies to add:**
- `prometheus-client` (>=1.0)
- `wai-middleware-prometheus` (>=1.0)
- `prometheus-metrics-ghc` (for GHC runtime metrics)

**New WAI middleware approach:**

```haskell
-- Replace Surypus.API.MetricsMiddleware with:
import Network.Wai.Middleware.Prometheus (prometheus, metricsApp)

-- In apiServer:
let app = prometheus                          -- NEW: auto-instruments all routes
        $ rateLimiting ...
        $ ...

-- /metrics endpoint handled by metricsApp from wai-middleware-prometheus
-- No need for inline handler anymore

-- Custom business metrics:
import Data.Prometheus (Counter, Gauge, Histogram, register, inc, set, observe)

instanceRegisterMetrics :: IO ()
instanceRegisterMetrics = do
  _ <- register "surypus_bills_created_total" "Total bills created"
  _ <- register "surypus_payroll_processed_total" "Total payroll calculations"
  _ <- register "surypus_websocket_connections" "Active WS connections"
  _ <- register "surypus_db_pool_size" "Database pool size"
  pure ()
```

**Integration points:**

| Existing | Replacement |
|----------|-------------|
| `Surypus.Metrics` (STM) | `prometheus-client` `Counter`/`Gauge`/`Histogram` |
| `Surypus.API.MetricsMiddleware` (stub) | `wai-middleware-prometheus` `prometheus` |
| `metricsEndpoint` (inline handler) | `metricsApp` from library |
| `recordCounter` / `recordGauge` | `inc` / `set` / `observe` from library |

**Backward compatibility:** Keep `Surypus.Metrics` module as thin wrapper around `prometheus-client` types:

```haskell
-- Surypus.Metrics — MODIFY
import qualified Data.Prometheus as P

newtype Counter = Counter P.Counter
newtype Gauge = Gauge P.Gauge

initMetrics :: IO Metrics
recordCounter :: Metrics -> Text -> Int64 -> IO ()
```

Or replace entirely — existing callers are few (Core.Accounting.Cache, System.Metrics — check call sites).

### 2.7 Structured Logging (Katip)

**Target:** Replace stub `Surypus.API.Logger` with `katip`-based structured JSON logging.

**Dependencies to add:**
- `katip` (>=0.8.8)
- `katip-elasticsearch` (optional, for centralized logging)

**New Logger:**

```haskell
-- Surypus/API/Logger.hs — REPLACE entirely

import Katip

-- Katip provides:
--   KatipContext (class for structured logging)
--   Slice (namespace)
--   Payload (structured fields)
--   JsonScribe (JSON output to file)

initLogger :: LogLevel -> FilePath -> IO ()
initLogger level logPath = do
  -- Create JSON scribe
  handleScribe <- mkHandleScribe ColorIfTerminal OutputFile logPath (pure ())
  -- Register scribe
  _ <- registerScribe "json" handleScribe defaultScribeSettings
  -- Set global environment
  let env = "production"
  _ <- initLogEnv "surypus" env
  pure ()

-- Correlation ID via KatipContext:
-- Katip has Namespace + LogContexts for structured fields
-- No need for custom withCorrelationId

-- Logging becomes:
logInfo' :: (KatipContext m) => Text -> Slice -> LogStr -> m ()
logInfo' msg slc body = logMsg slc InfoS $ ":: " <> body <> " :: " <> logStr msg

-- With structured fields:
logWithFields :: (KatipContext m) => Text -> [(Text, Text)] -> m ()
```

**Integration with existing callers:**

Currently used in:
- `Surypus.API.Server` — `correlationMiddleware` creates correlation ID, `envLogger` field
- Various handlers via `Log.logInfo`, `Log.logError`

**Migration path:**
1. Add `katip` dependency and `Logger` type as wrapper
2. Replace `envLogger :: Log.Logger` with `envLogger :: Katip.LogEnv` or keep as wrapper:
   ```haskell
   data Logger = Logger { logEnv :: LogEnv, logNamespace :: Namespace }
   ```
3. Replace `logInfo`/`logError` implementations to call katip
4. Keep the same module API signature so all callers work unchanged

**Correlation ID:** Katip handles via `LogContexts`. Use `KatipContext` constraint instead of threading through `Logger`.

### 2.8 Multi-Tenant Architecture

**Decision: Schema-per-tenant with Row-Level Security fallback.**

For an ERP system where:
- Data isolation is critical (accounting, payroll, inventory)
- Typical tenant count is 10-500 (not 10,000+)
- Regulatory compliance may require strict separation
- Schema-per-tenant queries are faster (no `WHERE tenant_id = ?` on every table)

**Architecture:**

```
┌──────────────────────────────────────────┐
│              PostgreSQL                    │
│                                            │
│  public schema (shared):                   │
│    - tenants table                         │
│    - users table (cross-tenant auth)       │
│    - plans/features/billing                │
│                                            │
│  tenant_{id} schema (per tenant):          │
│    - all business tables                   │
│      persons, goods, bills, stock,          │
│      accounting, payroll, event_store,      │
│      event_snapshots, audit_log             │
│    - identical structure                   │
│                                            │
│  CURRENTLY: all data in public schema      │
│  MIGRATION: tenant_0 schema (default)       │
└──────────────────────────────────────────┘
```

**New modules:**

```haskell
-- MultiTenancy/Middleware.hs (NEW)
-- Tenant resolution from JWT claims
data TenantResolution
  = TenantFromJWT          -- JWT has tenant_id claim
  | TenantFromHeader       -- X-Tenant-ID header
  | TenantFromSubdomain    -- tenant.example.com

-- TenantMiddleware sets search_path:
tenantMiddleware :: TenantResolution -> Application -> Application
tenantMiddleware resolution app req respond = do
  tenantId <- resolveTenant resolution req
  -- Set PostgreSQL session variables
  --   SET app.tenant_id = 'tenant_42'
  --   SET search_path = 'tenant_42, public'
  runDb [SqlPersistT] $ do
    rawExecute "SET app.tenant_id = ?" [PersistInt64 tenantId]
    rawExecute "SET search_path = ?" [PersistText ("tenant_" <> show tenantId <> ", public")]
  app req respond

-- MultiTenancy/Provisioning.hs (NEW)
-- Create tenant schema, clone base tables, run migrations
provisionTenant :: ConnectionPool -> Int64 -> TenantConfig -> IO (Either Text ())
provisionTenant pool tenantId config = do
  rawExecute "CREATE SCHEMA IF NOT EXISTS tenant_?" [PersistInt64 tenantId]
  -- Copy base schema
  -- Run migrations on new schema
  -- Insert into public.tenants
  pure $ Right ()

-- MultiTenancy/Connection.hs (NEW)
-- Connection pool per tenant? Or shared pool with schema switching?
-- For 10-500 tenants: shared pool with search_path switching
-- For 500+ tenants: pool-per-tenant (PgBouncer)
```

**Connection Pool Strategy:**

```
Shared pool (recommended for v51):
  ┌────────────┐     ┌──────────────┐
  │ Connection │────→│ SET search_path│
  │ Pool (20)  │     │ = tenant_42  │
  └────────────┘     └──────────────┘

Advantages:
- Simple, no pool per tenant
- Connection reuse
- Easy to scale up pool size

Pool per tenant (future option):
  ┌────────────┐
  │ PgBouncer  │──→ pool for tenant_42
  │            │──→ pool for tenant_99
  └────────────┘
  
Needed when: tenant count > 500, or some tenants have much higher load
```

**Migration from public to tenant schemas:**

```
Phase 2a: Read from tenant_0 schema (public data copied)
Phase 2b: Dual-read: check tenant schema, fallback to public
Phase 2c: Write only to tenant schema
Phase 2d: Drop public tables
```

**Using the existing `MultiTenancy.Isolation.TenantContext` type:**

```haskell
-- Extend TenantContext with schema resolution
data TenantContext = TenantContext
  { tcTenantId   :: Int64
  , tcSchemaName :: Text       -- "tenant_42"
  , tcUserId     :: Int64
  }

-- Replace stubs:
setTenantContext :: TenantContext -> ConnectionPool -> IO ()
setTenantContext ctx pool = runDb pool $
  rawExecute "SET search_path = ?" [PersistText (tcSchemaName ctx)]
```

---

## 3. Data Flow Diagrams

### 3.1 Full Request Flow (After v51)

```
Client
  │
  ├── HTTP Request ──────→ WAI (warp)
  │                              │
  │                              ├── katipLogger        (structured log begin)
  │                              ├── tenantMiddleware    (resolve tenant, set search_path)
  │                              ├── prometheus          (instrumented by wai-middleware-prometheus)
  │                              ├── rateLimiting         (per-tenant sliding window)
  │                              ├── correlationMiddleware (x-correlation-id)
  │                              ├── authMiddleware       (JWT verify)
  │                              └── withAuthzResolverAdvanced (RBAC)
  │                                   │
  │                                   └── Servant router
  │                                         │
  │                                         ├── /api/v1/* ──────→ REST handlers ──→ Service ──→ DAL ──→ PostgreSQL
  │                                         │                                              │
  │                                         │                                              └── EventStore.appendEvent
  │                                         │                                                    │
  │                                         │                                                    ├── event_store table
  │                                         │                                                    ├── Subscriptions (WS broadcast)
  │                                         │                                                    └── RedisPublisher
  │                                         │
  │                                         ├── /graphql ──────→ Morpheus resolver
  │                                         │                         │
  │                                         │                         └── calls same handler functions as REST
  │                                         │
  │                                         └── /metrics ──────→ prometheus metricsApp
  │
  ├── WebSocket Upgrade ──→ WAI
  │                              │
  │                              └── WS.Connection handler
  │                                   ├── Subscribe to EventStore streams
  │                                   ├── Receive push events
  │                                   └── Control messages (subscribe/unsubscribe rooms)
  │
  └── Response ←──────────────────── WAI
                                        │
                                        ├── katip log end (duration, status)
                                        └── prometheus record (latency, status code)
```

### 3.2 EventStore Replay with Snapshots Flow

```
Request: GET /api/v1/events/:aggregateType/:aggregateId/replay

Handler:
  1. Get latest snapshot from event_snapshot table
  2. If snapshot exists:
       a. Load lastSequenceNumber from snapshot
       b. Load events from event_store where sequenceNumber > lastSequenceNumber
       c. Apply events to snapshot state → final state
  3. If no snapshot:
       a. Load ALL events from event_store
       b. Fold over events (empty initial state) → final state
  4. Return final state + metadata (snapshotVersion, replayCount)

Snapshot trigger:
  Background job threshold check:
    - Per aggregate: count events since last snapshot
    - If > threshold (default 100), take snapshot:
      1. Replay to current state
      2. INSERT into event_snapshot
      3. Return JobResult
```

### 3.3 Payroll Processing with Event Sourcing Flow

```
POST /api/v1/payroll/calculate
{
  "employeeId": 42,
  "period": "2026-06-01",
  "baseSalary": 150000,
  "bonus": 50000,
  "daysWorked": 22,
  "vacationDays": 0,
  "sickDays": 0
}
  │
  ├── 1. Validate input
  │
  ├── 2. Service.PayrollService.calculatePayroll
  │       ├── calcNetSalaryFromGross → 150000 - calcIncomeTax(150000)
  │       ├── calcIncomeTax → 150000 * 0.13 = 19500
  │       ├── calcSocialTax → 150000 * 0.30 = 45000
  │       └── calcMonthlyAdvance → 150000 * 0.40 = 60000
  │
  ├── 3. DAL.Payroll.createPayrollRecord → INSERT INTO salary
  │
  ├── 4. EventStore.appendEvent → "PayrollCalculated"
  │       └── WebSocket broadcast → payroll room
  │
  └── 5. Return PayrollResult
```

### 3.4 Multi-Tenant Request Resolution Flow

```
Request → tenantMiddleware
  │
  ├── Extract tenant identifier:
  │   ├── From JWT claim: "tenant_id": 42
  │   ├── From header: X-Tenant-ID: 42
  │   └── From subdomain: tenant42.example.com
  │
  ├── Lookup tenant:
  │   ├── Check public.tenants WHERE id = ?
  │   ├── Verify tenant is active
  │   └── Get schema name
  │
  ├── Set session context:
  │   ├── SET search_path = 'tenant_42, public'
  │   └── SET app.tenant_id = '42'
  │
  ├── Pass TenantContext to Env:
  │   └── envTenant :: Maybe TenantContext
  │
  ├── Handler runs in tenant schema:
  │   └── All Persistent queries use search_path → tenant_42 tables
  │
  └── Rate limiter keyed by tenant_id:
      └── PerTenantRateLimiter uses tenant_id in lookup
```

---

## 4. New Components

### 4.1 New Modules

| Module | Purpose | Dependencies |
|--------|---------|--------------|
| `DAL.EventStore.Snapshots` | Snapshot CRUD, replay-from-snapshot | `DAL.Schema`, `DAL.EventStore` |
| `DAL.Payroll` | Payroll record CRUD | `DAL.Types`, `DAL.Schema` |
| `Infrastructure.EventStore.Subscriptions` | STM subscription registry for WS + EventStore bridge | `DAL.EventStore` |
| `MultiTenancy.Middleware` | Tenant resolution from JWT/header/subdomain, search_path setting | `MultiTenancy.TenantConfig` |
| `MultiTenancy.Provisioning` | Tenant schema creation, migration automation | `MultiTenancy.TenantConfig`, `DAL.Migration` |
| `MultiTenancy.Connection` | Pool management strategies | `MultiTenancy.TenantConfig` |
| `System.RateLimiterEnhanced` | Per-tenant rate limiting, configurable limits | `System.RateLimiter` |
| `Surypus.API.GraphQL.Resolvers` | GraphQL resolvers wrapping Servant handlers | `Surypus.API.*` |
| `Surypus.API.GraphQL.Schema` | Morpheus GraphQL schema definition | `morpheus-graphql` |

### 4.2 Modules to Modify

| Module | What Changes | Backward Compat? |
|--------|-------------|-----------------|
| `DAL.EventStore` | Add: `storeSnapshot`, `getLatestSnapshot`, `getEventsFromSequence` | Yes (additive) |
| `DAL.Schema` | Add: `EventSnapshotEntity` table | Yes (new table, migration) |
| `Infrastructure.EventStore.Accounting` | Add: `takeAccountSnapshot`, `reconstructFromSnapshot` | Yes (additive) |
| `Infrastructure.EventStore.Inventory` | Add: same pattern as Accounting | Yes (additive) |
| `Surypus.WebSocket` | Add: subscription to EventStore streams, control messages | Yes (WS protocol extension) |
| `Surypus.WebSocket.Integration` | Rewrite to use `SubscriptionManager` instead of polling TQueue | Needs testing (behavior change) |
| `Surypus.API.Server` | Add: `envTenant`, replace metrics/logging stubs, add GraphQL route | Minimal (add fields to Env) |
| `Surypus.API.Logger` | Replace implementation with katip, keep module API | Yes (same exports) |
| `Surypus.Metrics` | Replace with prometheus-client wrappers | Needs caller audit |
| `Surypus.API.MetricsMiddleware` | Replace with `wai-middleware-prometheus` | Yes (wai middleware) |
| `Service.PayrollService` | Add: `calculateAndPersist`, payroll history queries | Yes (additive) |
| `app/Main.hs` | Add: tenant middleware, katip init, prometheus init | Yes (additive) |
| `MultiTenancy.Isolation` | Replace stubs with real implementations | Yes (same types) |
| `MultiTenancy.TenantConfig` | Add: DB-backed lookup | Yes (additive) |
| `Surypus.API.Authorization` | Add: event_store, payroll, graphql path→permission mappings | Yes (additive) |

### 4.3 New Middleware (in WAI order)

```
Order in apiServer (outer→inner):
  1. katipLogger          [NEW] structured log request begin/end
  2. tenantMiddleware      [NEW] tenant resolution + search_path
  3. prometheus            [NEW] wai-middleware-prometheus
  4. rateLimiting          [MODIFIED] per-tenant rate limiting
  5. correlationMiddleware  [EXISTING] x-correlation-id
  6. authMiddleware         [EXISTING] JWT verify
  7. withAuthzResolver      [EXISTING] RBAC
  8. serve api              [EXISTING] Servant router
       ├── REST routes
       ├── GraphQL route
       └── /metrics (handled by prometheus middleware)
```

---

## 5. Suggested Build Order with Dependency Graph

### Dependency Graph

```
LOG (katip logging)
  │
  ├── MTN (multi-tenant)       ── depends on: LOG
  │     │
  │     └── RTL (rate limit)   ── depends on: MTN (per-tenant)
  │
  ├── MET (Prometheus metrics) ── depends on: LOG (for error logging)
  │
  ├── PAY (payroll)            ── depends on: LOG, EVT (audit trail)
  │
  ├── EVT (EventStore snap)   ── depends on: LOG
  │     │
  │     └── WS (WebSocket)    ── depends on: EVT (subscriptions)
  │
  └── GQL (GraphQL)           ── depends on: LOG (logging in resolvers)
                                (no dep on other new features)
```

### Phase Ordering

```
Phase 1: LOG + MET (infrastructure)
  ─ No new dependencies, foundation for observability
  ─ Katip logging + Prometheus metrics replace stubs
  ─ Everything after benefits from observability

Phase 2: MTN (multi-tenant)
  ─ Requires logging for auditing
  ─ Foundation for per-tenant features
  ─ Schema-per-tenant migration plan

Phase 3: EVT (EventStore snapshots)
  ─ Independent of multi-tenant
  ─ New snapshot table, replay API

Phase 4: RTL (per-tenant rate limiting)
  ─ Requires MTN for tenant resolution
  ─ Extends existing rate limiter

Phase 5: PAY (payroll persistence)
  ─ Requires LOG
  ─ Can use EVT for audit events
  ─ Simple CRUD + pure calculation

Phase 6: WS (WebSocket event sourcing)
  ─ Requires EVT for subscription management
  ─ Enhances existing WS handler

Phase 7: GQL (GraphQL API)
  ─ Requires LOG
  ─ No other deps — could move earlier
```

### Parallelization Opportunities

| Parallel Group | Phases | Rationale |
|---------------|--------|-----------|
| **Group A** | Phase 1 (LOG+MET) | Independent, no blockers |
| **Group B** | Phase 2 (MTN) + Phase 3 (EVT) | Independent of each other |
| **Group C** | Phase 4 (RTL) | Needs Phase 2 |
| **Group D** | Phase 5 (PAY) | Needs Phase 1, could join B if LOG is done |
| **Group E** | Phase 6 (WS) + Phase 7 (GQL) | Independent of each other, WS needs Phase 3 |

**Recommended:** Do Phase 1 first (LOG + MET — both are stub replacement, quick wins). Then parallelize Phase 2 (MTN) + Phase 3 (EVT) + Phase 5 (PAY). Then Phase 4 (RTL) + Phase 6 (WS) + Phase 7 (GQL) can all proceed after their deps.

---

## 6. Backward Compatibility Strategy

### 6.1 General Principles

1. **Additive changes first** — new tables, new modules, new endpoints
2. **Deprecate, don't delete** — mark old functions as `{-# DEPRECATED #-}`
3. **Feature flags** — wrap new behavior behind config flags
4. **Dual-write** — where possible, write to both old and new during migration

### 6.2 Feature-Specific Strategies

| Feature | BC Strategy |
|---------|-------------|
| **LOG** | Keep same module exports. Old `initLogger logLevel` still works, just more powerful. No code changes needed in callers. |
| **MET** | Keep `Surypus.Metrics` type aliases. Replace internals. Add `prometheus-client` registrations alongside. Old callers compile unchanged. |
| **MTN** | Default tenant (tenant_id=0) mirrors public schema. Tenant resolution is middleware — disabled by default. Config flag: `ENABLE_MULTI_TENANT=false`. |
| **EVT** | Snapshots table is additive. Old `getEvents` still works. Snapshot logic requires no changes to event producers. |
| **RTL** | Global rate limiter stays as fallback. Per-tenant is additive when tenant is resolved. |
| **PAY** | `SalaryEntity` table exists but was never written — no migration needed. New endpoints and service functions. |
| **WS** | Old `broadcastToRoom`/`broadcastGlobal` unchanged. New subscription system is parallel. WebSocket protocol: old clients still get `broadcastGlobal`. |
| **GQL** | New endpoint at `/graphql`. Does not change existing REST endpoints. Schema is subset of REST — no duplication. |

### 6.3 Database Migration Compatibility

```sql
-- V011__event_snapshots.sql (ADDITIVE — no changes to existing tables)
CREATE TABLE event_snapshot (
  id BIGSERIAL PRIMARY KEY,
  aggregate_id BIGINT NOT NULL,
  aggregate_type TEXT NOT NULL,
  snapshot_version INT NOT NULL,
  last_sequence_number BIGINT NOT NULL,
  snapshot_data TEXT NOT NULL,
  snapshot_metadata TEXT,
  created_at TIMESTAMP NOT NULL DEFAULT NOW(),
  UNIQUE (aggregate_id, aggregate_type, snapshot_version)
);

-- V012__payroll_index.sql (ADDITIVE)
CREATE INDEX idx_salary_employee_period ON salary (employee_id, date);
CREATE INDEX idx_salary_period ON salary (date);

-- V013__tenants.sql (ADDITIVE — new table in public schema)
CREATE TABLE tenants (
  id BIGSERIAL PRIMARY KEY,
  name TEXT NOT NULL,
  schema_name TEXT NOT NULL UNIQUE,
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  features JSONB DEFAULT '{}',
  branding JSONB DEFAULT '{}',
  created_at TIMESTAMP NOT NULL DEFAULT NOW()
);
```

### 6.4 Configuration Backward Compatibility

```yaml
# config.yaml — additive fields
server:
  port: 8080
  cors: true

logging:
  level: info              # kept
  format: json              # NEW: "json" or "text" (default "json")
  path: /var/log/surypus/   # NEW: log file path

multi_tenant:
  enabled: false            # NEW: default off
  strategy: schema          # "schema" or "row-level"
  resolution: jwt           # "jwt", "header", "subdomain"

metrics:
  provider: prometheus      # NEW: "prometheus" or "ekg" or "none"

rate_limiting:
  default_limit: 100
  default_window_sec: 60
  per_tenant: false         # NEW: default off
```

---

## 7. Key Constraints and Risks

### 7.1 Haskell-Specific Constraints

1. **Persistent's `runSqlPool` + `search_path`:** After `SET search_path = 'tenant_42'`, all subsequent queries using `runSqlPool` on the same connection will use the correct schema. BUT: connections are pooled and reused — must reset `search_path` before returning to pool (or set it on checkout).

   Solution: Use `runSqlPool` with `after` callback that sets `search_path`, or wrap `runDb` to always set tenant:
   ```haskell
   runDbWithTenant :: TenantContext -> ConnectionPool -> SqlPersistT IO a -> IO a
   runDbWithTenant ctx pool action =
     runSqlPool (rawExecute "SET search_path = ?" [PersistText (tcSchemaName ctx)] >> action) pool
   ```

2. **Servant type-level boilerplate:** Adding GraphQL to `SurypusApi` type requires appending `:<|> "api" :> "v1" :> GraphQLAPI` and adding to the `server` function. Modifying `Env` type requires updating all handlers that pattern-match. Manageable but tedious.

3. **Template Haskell stage restriction:** `persistent-template` generates code at compile time. New tables require recompilation. Use raw SQL for runtime-only schemas (tenant provisioning).

### 7.2 Risks

| Risk | Severity | Mitigation |
|------|----------|------------|
| Per-tenant schema migrations slow down with 100+ tenants | Medium | Use raw SQL + batch migration tool, not TH per tenant |
| GraphQL N+1 query problem | Medium | Use batched resolvers (DataLoader pattern via `haxl` or manual) |
| Connection pool starvation with many tenants | Low | Monitor pool usage, increase pool size, consider PgBouncer |
| Existing `unsafePerformIO` global state (Logger, Broadcaster) | Medium | Katip replaces Logger. Broadcaster MVar needs proper init. |
| Hasql dependency still present | Low | Already tracked as known problem. Not blocking this milestone. |

### 7.3 Library Dependencies to Add

```cabal
-- In surypus.cabal:
, katip >= 0.8.8
, prometheus-client >= 1.0
, wai-middleware-prometheus >= 1.0
, morpheus-graphql >= 0.27
, prometheus-metrics-ghc >= 1.0  (optional, for GHC metrics)
```

---

## 8. Sources

- **Existing codebase analysis** — Direct reading of all modules referenced above (HIGH confidence)
- **katip** — Hackage katip 0.8.8.4, structured JSON logging framework (HIGH confidence via Hackage docs)
- **prometheus-client** — Hackage prometheus-client (HIGH confidence via Prometheus official client library listing)
- **wai-middleware-prometheus** — Hackage v1.0.1.0, auto-instruments WAI apps (HIGH confidence via Hackage docs)
- **morpheus-graphql** — Haskell GraphQL server with Servant integration (MEDIUM confidence — needs version pin validation)
- **Schema-per-tenant vs RLS** — Multiple PostgreSQL multi-tenant guides (HIGH confidence — established PostgreSQL pattern)
- **Persistent search_path** — Code analysis of `runSqlPool` behavior (MEDIUM confidence — needs runtime verification)
