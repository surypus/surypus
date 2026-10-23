---
last_mapped_commit: 7bd87f6f9f0abbbaddaeb0e604b8ff8fe2ff4c41
last_mapped_at: 2026-10-23
---
<!-- refreshed: 2026-10-23 -->

# Architecture

**Analysis Date:** 2026-10-23

## System Overview

Surypus is a single-package Haskell **modular monolith**. One Cabal library (`Surypus.cabal`, 381 exposed modules) contains a typed HTTP API, application services, domain models, a PostgreSQL persistence layer, and cross-cutting infrastructure. Optional clients live outside the library (`frontend/`, `web/`, `clients/haskell/`).

```text
┌──────────────────────────────────────────────────────────────────────┐
│ Clients                                                              │
│  web/ (static JS/PWA)   frontend/ (Qt6/QML C++)   clients/haskell/   │
└───────────────────────────────┬──────────────────────────────────────┘
                                │ HTTP/JSON + WebSocket
                                ▼
┌──────────────────────────────────────────────────────────────────────┐
│ HTTP boundary — WAI `Application` built by `apiServer`               │
│ `src/Surypus/API/Server.hs`                                          │
│ metrics → rate limit → metrics collection → correlation → tenant    │
│ → JWT auth → RBAC authz → Servant `serve`                            │
└───────────────────────────────┬──────────────────────────────────────┘
                                ▼
┌──────────────────────────────────────────────────────────────────────┐
│ API handlers — `Surypus.API.*` over the typed `SurypusApi`           │
│ `src/Surypus/API/{Bills,Goods,Payment,CRM,Stock,Reports,...}.hs`     │
└───────────────┬───────────────────────────────┬──────────────────────┘
                ▼                               ▼
┌───────────────────────────────┐   ┌──────────────────────────────────┐
│ Application services          │   │ Reporting / AI / WebSocket       │
│ `src/Service/*.hs`            │   │ `src/Surypus/API/Reports.hs`     │
│ `Service.PayrollService`,     │   │ `src/Surypus/AI*`,               │
│ `BillService`, `JobHandlers`  │   │ `src/Surypus/WebSocket*`         │
└───────────────┬───────────────┘   └──────────────────────────────────┘
                ▼
┌──────────────────────────────────────────────────────────────────────┐
│ Persistence — `src/DAL/*`                                            │
│ Persistent entities (`DAL.Schema`, `Surypus.DB.Schema`), raw SQL    │
│ (`MutationsORM`, `QueriesORM`), event store (`DAL.EventStore`)       │
└───────────────┬───────────────────────────────┬──────────────────────┘
                ▼                               ▼
┌───────────────────────────────┐   ┌──────────────────────────────────┐
│ PostgreSQL                    │   │ Redis                            │
│ core tables + `event_store`   │   │ event streams, cache, queues     │
└───────────────────────────────┘   └──────────────────────────────────┘
```

The domain namespaces (`Finance`, `Commerce`, `Inventory`, `HR`, `Production`, ...) are plain Haskell modules of records and pure functions. They are not ring-fenced from the API or DAL at compile time; boundary discipline is by convention (see `docs/architecture/dependency-map.mmd` for the intended map).

## Component Responsibilities

| Component | Responsibility | File |
|-----------|----------------|------|
| HTTP entry | Builds the WAI application, middleware chain, health/metrics endpoints | `src/Surypus/API/Server.hs` |
| Typed API surface | Single Servant API type and handler dispatch | `src/Surypus/API/Server.hs` (`SurypusApi` at line 240, `server` at line 407) |
| Domain endpoint modules | Per-domain handler functions over the DAL | `src/Surypus/API/Bills.hs`, `Goods.hs`, `Payment.hs`, `CRM.hs`, `Accounting.hs`, `Stock.hs`, `Payroll.hs`, `Reports.hs` |
| Application services | Orchestration, job handling, payroll, workflows, UI models | `src/Service/*.hs` |
| Core domain + invariants | Tax, inventory balance, payroll, accounting read model/cache, DSL | `src/Core/Tax.hs`, `src/Core/Inventory.hs`, `src/Core/Payroll/Calculation.hs`, `src/Core/Accounting/ReadModel.hs` |
| Business domain models | Accounting, bills, stock, people, commerce, production | `src/Finance/`, `src/Inventory/`, `src/HR/`, `src/Commerce/`, `src/Production/`, `src/Logistics/` |
| Persistence facade | Mutation/query APIs returning `QueryResult` | `src/DAL/Mutations.hs`, `src/DAL/Queries.hs`, `src/DAL/QueriesORM.hs`, `src/DAL/MutationsORM.hs` |
| ORM schema | Persistent entity definitions | `src/DAL/Schema.hs`, `src/Surypus/DB/Schema.hs` |
| Connection/pool | Pool creation and tenant-scoped `runDb` | `src/DAL/Database.hs`, `src/DAL/Pool.hs`, `src/DAL/ORMPool.hs` |
| Event store | Append-only events, snapshots, replay, broadcaster | `src/DAL/EventStore.hs` |
| Event-sourced accounting | Typed accounting events, snapshots, Redis fan-out | `src/Infrastructure/EventStore/Accounting.hs` |
| Auth | JWT issue/verify, RBAC checks, auth middleware, permissions | `src/Surypus/JWT/Token.hs`, `src/Surypus/RBAC.hs`, `src/Surypus/API/AuthMiddleware.hs`, `src/Surypus/API/Authorization.hs` |
| Multi-tenancy | JWT tenant resolution and DB session context | `src/MultiTenancy/Middleware.hs`, `src/DAL/Database.hs` |
| Observability | Prometheus metrics, structured logging, correlation IDs | `src/Surypus/Metrics.hs`, `src/Surypus/API/Logger.hs`, `src/Surypus/API/MetricsMiddleware.hs` |
| System utilities | Cache, circuit breaker, retry, rate limit, scheduler, secrets | `src/System/*.hs` |
| Reporting | Report models, P&L/inventory reports, PDF export | `src/Reports/Report.hs`, `src/Surypus/API/Reports.hs`, `src/Surypus/Reports/*` |
| External integrations | EGAIS, VETIS, Jasper, Pentaho, EDI, webhooks | `src/External/*`, `src/Integration/*` |
| Schema transpiler | Generates typed entities/migrations from YAML | `tools/surypus-codegen/Main.hs`, `dsl/schema.yaml` |

## Pattern Overview

**Overall:** Layered modular monolith with DDD-flavoured domain namespaces, a Servant-typed HTTP interface, and a partially event-sourced accounting/inventory core.

**Key Characteristics:**
- One Cabal package; all modules share one dependency graph and one runtime.
- Servant type-level routing; the API shape is a single `type SurypusApi`.
- Read/write persistence uses both Persistent/Esqueleto and hand-written SQL via `rawSql`/`rawExecute`.
- Multiple type universes coexist: generated DSL entities, Persistent entities, and hand-written API records (see Anti-Patterns).
- Effects are plain `IO` (plus Servant `Handler`); there is no custom effect system or reader monad. Dependencies are passed explicitly through `Env` or as `ConnectionPool` arguments.
- Event sourcing is implemented for accounting (event store + replay + snapshots + Redis stream), but most CRUD still updates tables directly.

## Layers

**Interface / HTTP layer:**
- Purpose: authenticate, authorize, rate-limit, observe, route, and translate JSON.
- Location: `src/Surypus/API/`.
- Contains: Servant API type, handler modules, middleware, WebSocket and GraphQL adapters.
- Depends on: `DAL.*`, `Service.*`, `Surypus.JWT`, `Surypus.RBAC`, `Surypus.Metrics`.
- Used by: `apiServer` callers and the test suite. No executable currently calls `apiServer`.

**Application service layer:**
- Purpose: multi-step business operations and orchestration.
- Location: `src/Service/`.
- Contains: `BillService`, `PayrollService`, `InventoryService`, `WorkflowEngine`, `JobHandlers`, `Orchestrator`, UI model helpers.
- Depends on: domain modules, `DAL.*`, `Infrastructure.*`.
- Used by: a minority of API handlers (e.g. `Service.PayrollService` in `src/Surypus/API/Server.hs:32`); many handlers call `DAL.Mutations*` directly.

**Domain layer:**
- Purpose: records, sum types, pure calculations, and stated invariants.
- Location: `src/Finance/`, `src/Commerce/`, `src/Inventory/`, `src/HR/`, `src/Production/`, `src/Logistics/`, `src/Retail/`, `src/CRM/`, `src/Shared/`, `src/Core/`.
- Contains: one entity or cohesive concept per module (e.g. `Inventory/Goods.hs`, `Finance/Bill.hs`).
- Depends on: `base`, `text`, `time`, `Decimal` via `Surypus.CoreTypes`.
- Used by: API, services, DAL types, tests.

**Persistence layer:**
- Purpose: SQL generation/execution and mapping rows to domain records.
- Location: `src/DAL/`.
- Contains: `Database.hs` (pool + `runDb`), `Schema.hs` (Persistent), `Mutations.hs`/`MutationsORM.hs` (writes), `Queries.hs`/`QueriesORM.hs` (reads), `EventStore.hs`, `Repository.hs`.
- Depends on: `persistent`, `persistent-postgresql`, `esqueleto`, `postgresql-simple`-style raw SQL through Persistent.
- Used by: API handlers, services, event-store infrastructure.

**Event sourcing / read-model layer:**
- Purpose: append immutable events and rebuild projections.
- Location: `src/DAL/EventStore.hs`, `src/Infrastructure/EventStore/`, `src/Core/Accounting/`, `src/Infrastructure/Redis/`.
- Contains: `Event`/`Snapshot`, typed accounting events, `AccountReadModel`, replay and cache.
- Depends on: `DAL.Database`, `DAL.EventStore`, Redis (`hedis`).
- Used by: `Service.BillService`, accounting handlers, tests.

**Infrastructure / cross-cutting layer:**
- Purpose: operational concerns.
- Location: `src/Infrastructure/`, `src/System/`, `src/MultiTenancy/`, `src/Surypus/Metrics.hs`.
- Contains: backup, encryption, email, file storage, notifications, retry, circuit breaker, cache, rate limiting, metrics, tenant resolution.
- Depends on: external libraries and `DAL` for persistence-backed features.
- Used by: API middleware, services, jobs.

**Tooling / code generation (outside the library):**
- `dsl/schema.yaml` is the source schema.
- `tools/surypus-codegen/surypus-codegen.cabal` builds a separate transpiler executable.
- Generated output is checked in (`src/DAL/Types.hs` header says "Generated from dsl/schema.yaml / DO NOT EDIT MANUALLY").

## Data Flow

### Primary Request Path

1. A client calls `POST /api/v1/...` (base prefix is `"api" :> "v1"` in `src/Surypus/API/Server.hs:240`).
2. The WAI `Application` produced by `apiServer` handles health and metrics prefixes first (`src/Surypus/API/Server.hs:183`, health at `:210`, metrics at `:228`).
3. Middleware runs outermost-to-innermost: `metricsEndpoint` → `rateLimiterMiddleware` → `withMetricsCollection` → `correlationMiddleware` → `tenantMiddleware` → `authMiddleware` → `withAuthzResolverAdvanced` → `serve`.
4. Tenant middleware decodes the bearer JWT, sets a process-global tenant context, and clears it after the response (`src/MultiTenancy/Middleware.hs:38`).
5. Auth middleware verifies the JWT again (`src/Surypus/API/Server.hs:167`), then RBAC maps path+method to a permission (`src/Surypus/API/Authorization.hs:101`).
6. Servant dispatches to `server env` (`src/Surypus/API/Server.hs:407`), whose handlers receive the `Env` record (pool, logger, metrics, WebSocket handler, push store).
7. A handler calls a domain API module, e.g. `billsCreate` (`src/Surypus/API/Server.hs:600`).
8. The API module delegates to the DAL, e.g. `Surypus.API.Bills.createBill` (`src/Surypus/API/Bills.hs:25`) → `DAL.MutationsORM.createBill` (`src/DAL/MutationsORM.hs:177`).
9. `runDb` executes the SQL with tenant `set_config` when a tenant context exists (`src/DAL/Database.hs:48`).
10. Results return as `QueryResult a` (`src/DAL/Types.hs:117`) and are converted by `liftQ`/`ok` into Servant responses or `err4xx/err5xx` (`src/Surypus/API/Server.hs:549`).

### Write Path Example — Bill Creation

1. JSON `BillInput` is decoded for the `bills` POST route (`src/Surypus/API/Server.hs:250`).
2. `billsCreate` builds a `DAL.Bill` and calls `Bills.createBill` (`src/Surypus/API/Server.hs:600`).
3. `Bills.createBill` calls `ORM.createBill` (`src/Surypus/API/Bills.hs:25`).
4. `DAL.MutationsORM.createBill` executes `INSERT INTO bills ... RETURNING id` (`src/DAL/MutationsORM.hs:177`).
5. On success the raw key is wrapped in `MutationResult` and returned as JSON.
6. There is no transaction spanning bill header, lines, and accounting entries in this path; posting is a separate status update (`DAL.MutationsORM.postBill`, line 233).

### Event-Sourced Accounting Path

1. A domain operation appends an event via `appendAccountingEvent` (`src/Infrastructure/EventStore/Accounting.hs:164`).
2. The event is persisted through `DAL.EventStore.appendEvent`, which inserts into `event_store` (`src/DAL/EventStore.hs:133`).
3. The append publishes to a Redis stream (`Infrastructure.Redis.EventStream.publishEvent`, imported at `src/Infrastructure/EventStore/Accounting.hs:40`).
4. Read models replay events with `Core.Accounting.ReadModel.replayAccountEvents` (`src/Core/Accounting/ReadModel.hs:282`) or rebuild cached balances with `getCurrentBalanceCached` (`:310`).
5. In-process subscribers can be notified through `Broadcaster` (`appendEventBroadcast`, `src/DAL/EventStore.hs:156`) and WebSocket fan-out (`src/Surypus/WebSocket/RedisPublisher.hs`).

### Startup / Build Path

1. `stack build` compiles the library (`hs-source-dirs: src`) and the `surypus-server` executable (`hs-source-dirs: app`, `main-is: Main.hs`) from `Surypus.cabal`.
2. `app/Main.hs` currently prints a prototype banner and exits; it does not create a pool, start Warp, or call `apiServer`.
3. `src/Surypus/App/Main.hs` is a library module that generates RBAC SQL migrations via `Surypus.Domain.RBACCanon.Migration` and writes them to `sql/migrations/`.
4. Database bootstrap is performed by `sql/migrations/init_db.sh` and `config/init_db.sh`, not by application startup.

**State Management:**
- Request-scoped state: `Env` (pool, logger, metrics, WebSocket handler, push store) passed to handlers.
- Process-global state: tenant context (`src/DAL/Database.hs:31`), report file map (`src/Surypus/API/Reports.hs:89`), RBAC permission checker (`src/Surypus/RBAC.hs:142`).
- Durable state: PostgreSQL tables and `event_store`; Redis streams/cache.
- Query results carry success/error/listing explicitly via `QueryResult`.

## Key Abstractions

**`Env`:**
- Purpose: runtime dependencies for handlers.
- Definition: `src/Surypus/API/Server.hs:150`.
- Fields: `envConnectionPool`, `envLogger`, `envMetrics`, `envWSHandler`, `envPushStore`.

**`SurypusApi` (Servant type):**
- Purpose: compile-time description of every endpoint.
- Location: `src/Surypus/API/Server.hs:240`.
- Pattern: one flat `:<|>` tree rooted at `"api" :> "v1"`; GraphQL is mounted as a sub-API.

**`QueryResult a` / `MutationResult`:**
- Purpose: uniform result envelope between DAL and API.
- Definition: `src/DAL/Types.hs:117` (`QuerySuccess`, `QueryError`, `QueryResults`) and `:136` (`MutationResult`).
- Pattern: callers pattern-match; `liftQ` maps errors to HTTP status (`src/Surypus/API/Server.hs:554`).

**`ConnectionPool` + `runDb`:**
- Purpose: the only sanctioned path to persistent SQL.
- Definition: `src/DAL/Database.hs` (type alias, `runDb`, tenant-scoped `runDbWithTenant`).
- Compatibility shim: `src/DAL/Pool.hs` re-exports `DAL.Database`.
- Note: `src/DAL/ORMPool.hs` exposes a second pool constructor with a hard-coded DSN.

**`Event` / `Snapshot`:**
- Purpose: append-only event store records.
- Definition: `src/DAL/EventStore.hs:78` and `:92`.
- Pattern: aggregate id/type, sequence number, schema version, JSON payload, replay via `getEventsFrom`/`replayFromSnapshot`.

**`AccountReadModel` / `BalanceState`:**
- Purpose: projection rebuilt from accounting events.
- Definition: `src/Core/Accounting/ReadModel.hs:59`, `:69`.
- Caching: `Core.Accounting.Cache` (STM LRU) and `Core.Accounting.RedisCache`.

**Tenant context:**
- Purpose: PostgreSQL RLS scoping via `app.tenant_id` / `app.user_id` session variables.
- Definition: `src/DAL/Database.hs:31`, set by `src/MultiTenancy/Middleware.hs:55`.

**`Permission` / `Resource`:**
- Purpose: RBAC vocabulary decoupled from HTTP paths.
- Definition: `src/Surypus/API/Authorization.hs:22`, path-to-permission mapping at `:101`.

**`dsl/schema.yaml`:**
- Purpose: source of truth for generated entity types and migrations.
- Consumers: `tools/surypus-codegen/Main.hs`, `src/DAL/Types.hs`, `docs/architecture/DB_CONTRACT.md`.

## Entry Points

**Library HTTP entry:**
- Location: `src/Surypus/API/Server.hs:183` (`apiServer`).
- Triggers: an external caller or future executable.
- Responsibilities: initialize rate limiter, WebSocket handler, push store; compose middleware; serve `SurypusApi`.
- Current wiring: none. `grep` finds no importer of `Surypus.API.Server` outside the module itself.

**Executable entry:**
- Location: `app/Main.hs:4`.
- Triggers: `stack run`, Docker `api` service.
- Responsibilities: currently only prints two lines. It does not start a server.

**Migration generator entry:**
- Location: `src/Surypus/App/Main.hs:8`.
- Triggers: only if explicitly invoked from GHCi or a wrapper; it is not the Cabal executable's `main`.
- Responsibilities: render V001–V028 RBAC SQL and write files under `sql/migrations/`.

**Code generator entry:**
- Location: `tools/surypus-codegen/Main.hs`.
- Triggers: manual tooling runs.
- Responsibilities: parse `dsl/schema.yaml` and emit Haskell/SQL artifacts.

**Test entry:**
- Location: `test/Test.hs:main`.
- Triggers: `stack test`, `cabal test`.
- Responsibilities: run 50+ Hspec specs and QuickCheck properties; some integration specs require PostgreSQL/Redis environment variables.

**Secondary executables:**
- `app/ai-report.hs` is a standalone AI report demo but is not declared in `Surypus.cabal`.
- Docker Compose declares a `worker` service that invokes `surypus-job-worker`; no such executable stanza exists in `Surypus.cabal`.

## Architectural Constraints

- **Single package:** All 381 exposed modules compile together; changing a shared type (`DAL.Types`, `Surypus.CoreTypes`) can affect the whole codebase. There are no package-level boundaries.
- **Layering is conventional, not enforced:** API modules import `DAL.MutationsORM` directly; `DAL` imports generated/entity types. No module re-export firewall exists.
- **Blocking IO:** Handlers use `liftIO` directly against the pool. There is no async/STM work queue in the request path; long operations (report export, `pg_dump` backup) run inline in `Handler`.
- **Global mutable state:** `unsafePerformIO` initializes the tenant `IORef` (`src/DAL/Database.hs:31`), report file registry (`src/Surypus/API/Reports.hs:89`), and RBAC checker (`src/Surypus/RBAC.hs:142`). The tenant context is a single `IORef`, not thread-local despite the comment, so concurrent requests can overwrite each other's context.
- **Duplicate DB configuration:** `DAL.ORMPool.createPool` and `DAL.Database.createPool` both embed a literal PostgreSQL DSN and a fixed pool size; `Surypus.DB.Pool.mkDBConfig` separately reads `DB_HOST`/`DB_PORT`/etc.
- **Middleware order is semantic:** tenant context must be set before `runDb`; auth must run before RBAC; rate limiting must run before metrics collection. Reordering the chain in `apiServer` changes behavior.
- **Two migration histories:** `sql/migrations/` (versioned `V###__*.sql`) and `config/schema_*.sql` (hundreds of reference schemas) coexist; `config/init_db.sh` applies the latter while `sql/migrations/init_db.sh` applies the former.
- **JWT secret:** `Surypus.JWT.Token.defaultSecretKey` is a development constant in source; no startup guard forces an environment override.
- **Unsafe/partial conversions:** `DAL.Conversion` and event-store row decoders default malformed values to `0`/epoch/empty text rather than failing.
- **Formal verification is annotation-only in the build:** LiquidHaskell refinements exist in `src/Core/Tax.hs`, `src/Core/Inventory.hs`, `src/Finance/Accounting.hs`, `liquidhaskell.yaml`, but `stack build` does not run the solver.

## Anti-Patterns

### Parallel Type and Schema Universes

**What happens:** Four representations of the same business data coexist: DSL-generated entities (`src/DAL/Types.hs`, header "DO NOT EDIT MANUALLY"), Persistent entities (`src/DAL/Schema.hs`, 23 entities), additional Persistent entities (`src/Surypus/DB/Schema.hs`, which re-exports `DAL.Schema`), and hand-written API records (`src/Surypus/Types/*.hs`).
**Why it's wrong:** Field types drift (e.g. generated entities store numeric/text fields as `Text` while `DAL.Types` records use `Double`/`Int64`), and callers must know which universe a function expects.
**Do this instead:** Treat `src/DAL/Types.hs` + `src/DAL/Schema.hs` as canonical for persisted data; add new shared API records to `src/Surypus/Types/` only when they are transport DTOs, and do not mix them in DAL signatures. Regenerate from `dsl/schema.yaml` rather than hand-editing generated code.

### Business Logic in HTTP Handlers

**What happens:** Many handler functions in `src/Surypus/API/Server.hs` call `DAL.Mutations*`/`DAL.QueriesORM` directly (e.g. `billsCreate` at line 600, `handleCreateEntry` at line 871) instead of going through `src/Service/`.
**Why it's wrong:** Validation, permissions, and event emission cannot be reused by jobs, WebSocket paths, or tests; the service layer becomes optional and inconsistent.
**Do this instead:** Put multi-step operations in `src/Service/<Domain>Service.hs` (following `Service.PayrollService`) and keep handlers to decode → service call → encode.

### Success-Shaped Stubs

**What happens:** Several API modules return empty success or a generic error, e.g. `Surypus.API.Bills.listBills` returns `QuerySuccess []` and `getBill` returns `QueryError "Not found"` (`src/Surypus/API/Bills.hs:21-35`); `Surypus.API.Classifiers` returns empty lists for every classifier.
**Why it's wrong:** Callers cannot distinguish "no data" from "not implemented"; `ok` only maps the exact string `"Not Found"` to 404 (`src/Surypus/API/Server.hs:549-552`), so `"Not found"` becomes HTTP 500.
**Do this instead:** Return `QueryError "Not Found"` for missing rows, and implement list queries through `DAL.QueriesORM` rather than returning `[]`.

### Process-Global Singletons via `unsafePerformIO`

**What happens:** Mutable registries are created at module load (`src/DAL/Database.hs:31`, `src/Surypus/API/Reports.hs:89`, `src/Surypus/RBAC.hs:142`).
**Why it's wrong:** Tests cannot isolate state, concurrent requests share the tenant `IORef`, and initialization order is implicit.
**Do this instead:** Create these values in `main`/`apiServer` and pass them through `Env`; for tenant scope, use `runDbWithTenant` or an explicit reader/context value per request.

### Two `Main` Modules and an Unwired Server

**What happens:** `app/Main.hs` is a stub, while `src/Surypus/App/Main.hs` generates migrations; `apiServer` is never imported.
**Why it's wrong:** `stack run` and the Docker `api` service do not serve the API that the tests exercise; deployment expectations do not match the binary.
**Do this instead:** Make `app/Main.hs` create the pool/logger/metrics, resolve public paths and the permission checker, call `apiServer`, and run `Warp.runSettings`; move migration generation to a separate `surypus-migrate` executable.

### Inline Long-Running Work in Handlers

**What happens:** `backupHandler` shells out to `pg_dump` (`src/Surypus/API/Server.hs:908`) and report export runs external conversions inside the request.
**Why it's wrong:** A slow backup or PDF conversion ties up a Warp worker and can hit client/proxy timeouts.
**Do this instead:** Enqueue these operations through `DAL.Queue` / `Production.JobQueue` and return a job id.

## Error Handling

**Strategy:** Explicit result values inside the application, HTTP status translation at the Servant boundary, and `Either Text` for infrastructure/event-store operations.

**Patterns:**
- DAL returns `QueryResult a`; `QueryError` carries a `Text` message (`src/DAL/Types.hs:117`).
- `ok` maps `QueryError "Not Found"` → 404 and any other `QueryError` → 500 (`src/Surypus/API/Server.hs:549`).
- Handlers use `throwError err401/err400/err500` for protocol-level failures (`src/Surypus/API/Server.hs:562-590`).
- Event store / Redis / report code returns `Either Text a` or `IO (Either Text a)` (`src/DAL/EventStore.hs`, `src/Infrastructure/EventStore/Accounting.hs`).
- Middleware emits raw JSON 401/403 responses before Servant is reached (`src/Surypus/API/AuthMiddleware.hs:55`).
- Domain validation uses `Either Text`/`Maybe` smart constructors (`Core.Tax.mkTaxBracket`, `Surypus.Validation`).

## Cross-Cutting Concerns

**Logging:** `Surypus.API.Logger` plus `correlationMiddleware`; correlation id comes from `x-correlation-id` or a fresh UUID (`src/Surypus/API/Server.hs:159`). `katip` is a dependency; `System.Log`/`System.Logger` exist as utilities.

**Validation:** `Surypus.Validation`, `System.Validation`, `System.Validator`, plus smart constructors/`Either` in domain modules. Most DAL functions do not validate; they trust typed inputs.

**Authentication:** HS256 JWT via `jose` (`src/Surypus/JWT/Token.hs`), login/register/auth-me endpoints (`src/Surypus/API/Server.hs:562`), refresh-token repository (`src/Surypus/RefreshTokenRepo.hs`).

**Authorization:** Path+method → `Permission` (`src/Surypus/API/Authorization.hs:101`), checked by `withAuthzResolverAdvanced`; `Surypus.RBAC.requirePermission` offers a handler-level alternative.

**Multi-tenancy:** `MultiTenancy.Middleware` sets `app.tenant_id`/`app.user_id`; `DAL.Database.runDb` applies them via `set_config` for RLS policies (`sql/migrations/V016__rls_policies.sql`).

**Observability:** `Surypus.Metrics` (STM counters/gauges/histograms) rendered as Prometheus text at `/api/v1/metrics`; `withMetricsCollection` records request counts/durations; health endpoints at `/api/v1/health` and `/api/v1/health/db`.

**Configuration:** Environment variables (`DB_*`, `REDIS_*`, JWT secret) read ad hoc via `lookupEnv`; `Surypus.Domain.Config.Config.RuntimeConfig` is a minimal typed config that is not wired into `apiServer`.

---

*Architecture analysis: 2026-10-23*
