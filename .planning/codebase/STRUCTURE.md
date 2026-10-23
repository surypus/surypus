---
last_mapped_commit: 7bd87f6f9f0abbbaddaeb0e604b8ff8fe2ff4c41
last_mapped_at: 2026-10-23
---
# Codebase Structure

**Analysis Date:** 2026-10-23

## Directory Layout

```text
surypus/
├── src/                     # Haskell library (381 exposed modules)
│   ├── Core/                # Verified core: tax, inventory, payroll, accounting read model, DSL
│   ├── DAL/                 # Persistence: schemas, pools, mutations, queries, event store
│   ├── Surypus/             # Application core: API, types, DB schema, JWT, RBAC, WebSocket, AI
│   ├── Service/             # Application services and orchestration
│   ├── System/              # Cross-cutting runtime utilities (cache, retry, metrics, secrets)
│   ├── Infrastructure/      # Backup, encryption, email, Redis, event-store adapters
│   ├── Finance/             # Accounting, bills, tax, ledger, currency domain
│   ├── Commerce/            # Sales, purchases, cash, orders, pricing, loyalty
│   ├── Inventory/           # Goods, stock, lots, warehouses, units
│   ├── HR/                  # Persons, employees, positions, payroll
│   ├── Production/          # MRP, work orders, tech cards, job system
│   ├── Logistics/           # Receipts, routes, transfers, transport
│   ├── Retail/              # Cash registers, terminals, receipts, scales
│   ├── CRM/                 # CRM type namespace
│   ├── Shared/              # Shared filters, grids, conflict helpers, service mesh
│   ├── Integration/         # EDI, webhooks, bank statements, sync, external API adapters
│   ├── External/            # EGAIS, VETIS, Jasper, Pentaho, UHTT adapters
│   ├── MultiTenancy/        # Tenant resolution, isolation, provisioning
│   ├── Security/            # Quantum crypto helpers
│   ├── Science/             # ML demand forecasting and features
│   ├── Tech/                # Tech cards/issues
│   ├── Messaging/           # Messages and communications
│   ├── Domain/              # Minimal accounting event types
│   ├── Reports/             # Report model types
│   └── *.hs                 # Namespace aggregator/re-export modules
├── app/                     # Executable sources (`Main.hs` stub, `ai-report.hs` demo)
├── test/                    # Hspec suite mirroring src namespaces; aggregator `test/Test.hs`
├── tools/                   # `surypus-codegen` transpiler and documentation generators
├── dsl/                     # `schema.yaml` — source schema for generated entities
├── sql/                     # Canonical versioned migrations and SQL assets
├── config/                  # Legacy/reference SQL schemas, Prometheus, Grafana
├── api/                     # OpenAPI and gRPC contracts
├── docs/                    # MkDocs sources, ADRs, architecture notes, generated docs
├── scripts/                 # Operational and maintenance scripts
├── frontend/                # Qt6/QML desktop client (C++)
├── web/                     # Static JS/PWA client
├── clients/haskell/         # Standalone Haskell HTTP client
├── docker/                  # Container support files
├── actions/                 # GitHub composite actions
├── opa/                     # Open Policy Agent policies
├── prometheus/              # Prometheus configuration
├── templates/               # Code/report project templates
├── static/                  # Static assets
├── packaging/               # Packaging metadata
├── wiki/                    # Wiki source pages
├── Surypus.cabal            # Single library + `surypus-server` + `surypus-test`
├── stack.yaml               # Stack resolver lts-22.21
├── cabal.project            # Cabal package/constraint configuration
└── Makefile                 # Build, migrate, test, docker, lint targets
```

Not part of the runtime architecture: `dist-newstyle/` and `.stack-work/` (build output), `node_modules/` (documentation tooling), `.beads/` (issue-tracking Dolt DB), `.planning/` (GSD workflow artifacts), and the many agent-config directories (`.claude/`, `.agents/`, `.codex/`, `.cursor/`, `.opencode/`, ...).

## Directory Purposes

**`src/`**
- Purpose: the entire Haskell library.
- Contains: domain modules, API, DAL, services, infrastructure, cross-cutting utilities.
- Key files: `src/Surypus/API/Server.hs`, `src/DAL/Database.hs`, `src/DAL/MutationsORM.hs`, `src/Surypus/CoreTypes.hs`.

**`src/Core/`**
- Purpose: small, invariant-focused core and accounting projections.
- Contains: `Tax.hs`, `Inventory.hs`, `Optimization.hs`, `Payroll/Calculation.hs`, `Accounting/{ReadModel,Cache,RedisCache}.hs`, `DSL/{AST,Parser}.hs`, `Services/Accounting.hs` (stub).
- Key files: `src/Core/Tax.hs`, `src/Core/Accounting/ReadModel.hs`.

**`src/DAL/`**
- Purpose: all PostgreSQL access.
- Contains: pool/database helpers, Persistent schemas, mutation/query facades, raw-SQL ORM modules, event store, repository type classes, queue/payroll/production helpers.
- Key files: `src/DAL/Database.hs`, `src/DAL/Schema.hs`, `src/DAL/Types.hs`, `src/DAL/MutationsORM.hs`, `src/DAL/QueriesORM.hs`, `src/DAL/EventStore.hs`.

**`src/Surypus/`**
- Purpose: application-facing core namespace.
- Contains: `API/` (28 handler/middleware modules), `Types/` (transport DTOs), `DB/` (extra Persistent schema and queries), `JWT/`, `RBAC/`, `WebSocket/`, `AI/`, `Domain/` (RBACCanon, config, observability), `Infra/SqlGen/`, `Reports/`, `App/`.
- Key files: `src/Surypus/API/Server.hs`, `src/Surypus/JWT/Token.hs`, `src/Surypus/Domain/RBACCanon/Migration.hs`.

**`src/Service/`**
- Purpose: application services above the DAL.
- Contains: `BillService`, `PayrollService`, `InventoryService`, `InventoryLifecycleService`, `WorkflowEngine`, `JobHandlers`, `Orchestrator`, `CircuitBreakerAdapter`, `Settings`, UI model modules.
- Key files: `src/Service/PayrollService.hs`, `src/Service/BillService.hs`, `src/Service/WorkflowEngine.hs`.

**`src/System/`**
- Purpose: reusable runtime building blocks with no business semantics.
- Contains: cache, circuit breaker, retry, rate limiter, scheduler, cron, sequence, counter, secrets, validation, metrics, logging, tracing, discovery.
- Key files: `src/System/Cache.hs`, `src/System/Retry.hs`, `src/System/MetricsCollector.hs`.

**`src/Finance/`, `src/Commerce/`, `src/Inventory/`, `src/HR/`**
- Purpose: business domain models.
- Contains: one record/sum-type module per concept, mostly pure.
- Key files: `src/Finance/Accounting.hs`, `src/Finance/Bill.hs`, `src/Commerce/Payment.hs`, `src/Inventory/Stock.hs`, `src/HR/Employee.hs`.

**`src/Infrastructure/`**
- Purpose: infrastructure adapters tied to persistence or external services.
- Contains: event stores for accounting/CRM/inventory, Redis event stream and task queue, backup, encryption, email, file storage, migration, notification, serializer.
- Key files: `src/Infrastructure/EventStore/Accounting.hs`, `src/Infrastructure/Redis/EventStream.hs`.

**`src/Integration/` and `src/External/`**
- Purpose: external system boundaries.
- Contains: EDI, webhooks, bank statements, import/export, sync, health, external API; EGAIS, VETIS, Jasper, Pentaho, UHTT adapters.
- Key files: `src/Integration/API/ExternalAPI.hs`, `src/External/EGAIS.hs`.

**`app/`**
- Purpose: executable entry points.
- Contains: `Main.hs` (stub banner) and `ai-report.hs` (undeclared demo).
- Key files: `app/Main.hs`.

**`test/`**
- Purpose: Hspec + QuickCheck suite.
- Contains: namespace-mirrored `*Spec.hs` modules and `Test.hs` aggregator; integration specs for PostgreSQL and Redis.
- Key files: `test/Test.hs`, `test/DAL/EventStoreIntegration.hs`, `test/Infrastructure/EventStore/AccountingIntegration.hs`.

**`tools/`**
- Purpose: developer tooling outside the library.
- Contains: `surypus-codegen/` (separate Cabal executable), documentation generators, Beads/GitHub sync.
- Key files: `tools/surypus-codegen/Main.hs`, `tools/documentation/generate-module-graph.hs`.

**`sql/`**
- Purpose: canonical database assets.
- Contains: `migrations/` (`V###__*.sql`), `aggregate/`, `core/`, `event/`, `projection/`, `procedures/`, `policy/`, `seeds/`, `service/`, `test/`, `archive/`.
- Key files: `sql/migrations/init_db.sh`, `sql/migrations/V001__core_schema.sql`, `sql/migrations/V016__rls_policies.sql`.

**`config/`**
- Purpose: reference schemas and operational configuration.
- Contains: hundreds of `schema_*.sql` files, `init_db.sh`, `init_optimized.sh`, Prometheus/Grafana config, OpenPapyrus v3 data.
- Key files: `config/init_db.sh`, `config/prometheus.yml`.

**`dsl/`**
- Purpose: schema DSL input.
- Contains: `schema.yaml` with entities, field types, nullability, and refinements.
- Key files: `dsl/schema.yaml`.

**`api/`**
- Purpose: language-neutral API contracts.
- Contains: `rest/openapi.yaml`, `grpc/surypus.proto`.
- Key files: `api/rest/openapi.yaml`, `api/grpc/surypus.proto`.

**`frontend/`, `web/`, `clients/haskell/`**
- Purpose: non-library clients.
- Contains: Qt6/QML C++ app (`frontend/CMakeLists.txt`, `frontend/qml/`), static PWA (`web/index.html`, `web/js/`), Haskell client (`clients/haskell/SurypusClient.hs`).

## Key File Locations

**Entry Points:**
- `app/Main.hs`: Cabal `surypus-server` entry; currently a stub.
- `src/Surypus/API/Server.hs`: `apiServer` application builder and the full `SurypusApi` type.
- `src/Surypus/App/Main.hs`: RBAC migration generator.
- `test/Test.hs`: test-suite `main` and spec aggregator.
- `tools/surypus-codegen/Main.hs`: schema transpiler entry.

**Configuration:**
- `Surypus.cabal`: module list, dependencies, executable/test stanzas.
- `stack.yaml`: resolver `lts-22.21`, local `-Wall`.
- `cabal.project`: package and dependency constraints.
- `Makefile`: build/test/migrate/docker/lint targets.
- `docker-compose.yml`: PostgreSQL, Redis, API, worker services.
- `Dockerfile`: multi-stage build.
- `flake.nix`: Nix development shell.
- `liquidhaskell.yaml`, `.hlint.yaml`, `weeder.toml`: verification/lint configuration.

**Core Logic:**
- `src/Surypus/API/Server.hs`: routing and middleware composition.
- `src/Surypus/API/Authorization.hs`: path/method → permission policy.
- `src/DAL/Database.hs`: pool and tenant-scoped `runDb`.
- `src/DAL/MutationsORM.hs` / `src/DAL/QueriesORM.hs`: raw SQL read/write implementations.
- `src/DAL/EventStore.hs`: append-only event store and snapshots.
- `src/Core/Accounting/ReadModel.hs`: event replay projections.
- `src/Finance/Accounting.hs`: double-entry invariants and transaction processing.

**Testing:**
- `test/Test.hs`: run all specs.
- `test/Finance/`, `test/Inventory/`, `test/Core/`, `test/DAL/`, `test/System/`, `test/Surypus/`: namespace mirrors.
- `test/QuickCheckInvariantsSpec.hs`, `test/Domain/InvariantsSpec.hs`: property/invariant tests.

**Database:**
- `sql/migrations/`: authoritative migration chain.
- `config/schema_*.sql`: legacy/reference DDL.
- `sql/procedures/`: stored procedures.
- `sql/policy/`: RLS/OPA-related policies.
- `sql/event/`, `sql/projection/`: event-store and projection DDL.

## Naming Conventions

**Files:**
- Haskell files use PascalCase matching the module name: `src/Inventory/Goods.hs` → `module Inventory.Goods`.
- One module per file; module path equals directory path.
- Aggregator/re-export modules sit at namespace roots: `src/Finance.hs`, `src/Inventory.hs`, `src/Surypus/Types.hs`.
- Test files use the `*Spec.hs` suffix: `test/Finance/AccountingSpec.hs`.
- Migrations use `V<number>__<snake_case_description>.sql`: `V014__event_store.sql`.
- Raw-SQL DAL modules use the `*ORM` suffix: `DAL.MutationsORM`, `DAL.QueriesORM`, `DAL.ClassifiersORM`.

**Directories:**
- Domain directories are PascalCase and mirror module namespaces: `src/Finance/`, `src/Commerce/Orders/`, `src/Surypus/Domain/RBACCanon/`.
- Lowercase directories are project-level, not Haskell namespaces: `sql/`, `config/`, `tools/`, `docs/`.
- `src/Surypus/` is the only namespace nested under the package name.

**Module Names:**
- Domain types: `Finance.Accounting`, `Inventory.Stock`, `HR.Employee`.
- Application: `Surypus.API.*`, `Surypus.Types.*`, `Surypus.JWT.*`, `Surypus.RBAC.*`.
- Cross-cutting: `System.*`, `Infrastructure.*`, `MultiTenancy.*`.
- Test modules: mirrored namespace plus `Spec` (`Inventory.StockSpec`).

**Types and Functions:**
- Types/constructors: PascalCase (`Bill`, `QueryResult`, `MutationResult`, `AccountReadModel`).
- Functions/fields: camelCase (`createBill`, `runDb`, `applyTax`).
- Record fields are type-prefixed to survive `DuplicateRecordFields`: `billId`, `billTotal`, `personName`, `envConnectionPool`, `trRate`, `leDate`.
- Newtype wrappers: `Decimal`, `NonNeg`, `Pool`.
- JSON DTOs use `*Input`, `*Request`, `*Response`, `*Result` suffixes (`BillInput`, `LoginRequest`, `MutationResult`).

**Constructors:**
- Sum-type constructors are PascalCase (`QuerySuccess`, `Authenticated`, `TenantFromJWT`).
- Legacy/imported enumerations sometimes keep SCREAMING_SNAKE names (`PPOPT_SALES`, `OF_PDF`, `RTList`); do not copy that style for new domain types.

## Where to Add New Code

**New domain concept (record/pure logic):**
- Create `src/<Domain>/<Concept>.hs` with a declared module name matching the path.
- Re-export it from the namespace aggregator (`src/<Domain>.hs`) when it is part of the public surface.
- Add it to `exposed-modules` in `Surypus.cabal`.
- Add `test/<Domain>/<Concept>Spec.hs` and register it in `test/Test.hs`.

**New REST endpoint:**
- Implement handlers in `src/Surypus/API/<Domain>.hs`, following `src/Surypus/API/Bills.hs` or `src/Surypus/API/Payments.hs`.
- Add the route to `type SurypusApi` and the handler to `server` in `src/Surypus/API/Server.hs`.
- Add the path/method → permission mapping in `src/Surypus/API/Authorization.hs` (`requiredPermissionForPathMethod`).
- Call `DAL.Mutations*`/`DAL.QueriesORM` directly for simple CRUD, or a `src/Service/*Service.hs` function for multi-step operations.
- Add a spec under `test/Surypus/API/` and update client surfaces (`web/js/api.js`, `frontend/qml/RestClient.qml`) if needed.

**New application service:**
- Create `src/Service/<Name>Service.hs` and export explicit functions.
- Take `ConnectionPool` (and any other dependencies) as arguments; return `IO (Either ServiceError a)` or `IO (QueryResult a)` consistent with neighbours.
- Add to `exposed-modules` in `Surypus.cabal`.

**New persistence operation:**
- Writes: add to `src/DAL/MutationsORM.hs` and expose a `MutationResult`-shaped facade in `src/DAL/Mutations.hs`.
- Reads: add to `src/DAL/QueriesORM.hs` (raw SQL) or `src/DAL/Queries.hs` (targeted Esqueleto queries).
- Use `runDb`/`runDbWithTenant` from `src/DAL/Database.hs`; never create a new pool inside the operation.
- Map rows explicitly in `src/DAL/Conversion.hs` or a local `*FromRow` helper.

**New persisted entity/table:**
- Add the entity to `dsl/schema.yaml`.
- Regenerate via `tools/surypus-codegen` rather than editing `src/DAL/Types.hs` by hand.
- Add the Persistent definition to `src/DAL/Schema.hs` (or `src/Surypus/DB/Schema.hs` only if it belongs to the newer core set).
- Add a migration under `sql/migrations/` or `sql/aggregate/` using the `V###__*.sql` convention.
- Update `docs/architecture/DB_CONTRACT.md` and `docs/generated/inventory/modules.json` if the module graph changes.

**New event type / projection:**
- Add the typed event and store functions under `src/Infrastructure/EventStore/<Domain>.hs`.
- Persist through `src/DAL/EventStore.hs` (`appendEvent`/`appendEventBroadcast`).
- Add replay/projection logic beside the existing read model (`src/Core/Accounting/ReadModel.hs` is the reference).
- Cover it with an integration spec in `test/Infrastructure/EventStore/`.

**New middleware:**
- Create `src/Surypus/API/<Name>Middleware.hs` exposing `... :: Application -> Application`.
- Insert it into the chain in `apiServer` (`src/Surypus/API/Server.hs:183`) in the correct order (tenant before DB access, auth before authz, rate limit before metrics collection).
- Add it to `exposed-modules` and test middleware behavior directly against a WAI `Request`.

**New cross-cutting utility:**
- Add `src/System/<Name>.hs`; keep it free of business types.
- Add a matching `test/System/<Name>Spec.hs`.

**New external integration:**
- Add an adapter under `src/External/` or `src/Integration/`; keep all network/CLI calls behind a small function returning `Either Text`.
- Wire it through a service or job handler, not directly from a Servant handler.

## Special Directories

**`docs/generated/`:**
- Purpose: machine-generated Haddock, Hoogle, module graphs, and inventory.
- Generated: Yes.
- Committed: Yes (do not edit by hand; regenerate with `tools/documentation/*`).

**`sql/migrations/`:**
- Purpose: ordered schema evolution.
- Generated: Partly (RBAC migrations can be emitted by `src/Surypus/App/Main.hs`).
- Committed: Yes.

**`config/`:**
- Purpose: reference DDL and operational configuration.
- Generated: No.
- Committed: Yes.
- Note: `config/schema_*.sql` is a legacy/reference corpus; `sql/` is the canonical migration path for new work.

**`dist-newstyle/`, `.stack-work/`:**
- Purpose: Cabal/Stack build output.
- Generated: Yes.
- Committed: No (ignored).

**`node_modules/`:**
- Purpose: npm dependencies for documentation/lint tooling.
- Generated: Yes.
- Committed: No.

**`.beads/`:**
- Purpose: Beads issue-tracking Dolt database.
- Generated: Yes (data).
- Committed: Selectively tracked.

**`.planning/`:**
- Purpose: GSD workflow state and codebase maps.
- Generated: Yes.
- Committed: Selectively tracked.

**Agent configuration directories (`.claude/`, `.agents/`, `.codex/`, `.cursor/`, `.gemini/`, `.opencode/`, `.windsurf/`, ...):**
- Purpose: instructions/skills/hooks for AI coding tools.
- Generated: No (installed/managed).
- Committed: Yes.
- Not part of the Haskell runtime; do not treat their contents as application code.

---

*Structure analysis: 2026-10-23*
