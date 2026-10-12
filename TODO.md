# Surypus TODO — Unified Task List

Первичные (архитектурные инварианты):
  Ц-1  Доказуемая корректность бизнес-инвариантов
  Ц-2  Безопасность как свойство типовой системы
  Ц-5  Haskell-гомогенность стека

Вторичные (бизнес-полнота):
  Ц-3  Покрытие ERP-контура
  Ц-4  SLA-связанные API

Третичные (позиционирование):
  Ц-6  Event Sourcing как аудируемость
  Ц-7  MPL-2.0 как открытость без GPL-вирусности

bd ready



# Surypus TODO — Unified Task List

> All tasks from all sessions consolidated in one place.
> Sources: TODO.md, BACKLOG.md, docs/phase2_phase3_backlog.md, .beads/issues.jsonl

---

## Strategic Goals

1. Корректность по конструкции
   └── LiquidHaskell, рефайнменты, QuickCheck

2. Событийный аудит и воспроизводимость
   └── Event sourcing для бухгалтерии, склада, CRM

3. Мультиарендность и безопасность
   └── RBAC, JWT, шифрование, изоляция тенантов

4. Интеграционная открытость
   └── REST, GraphQL-прокси, EDI, банковские выписки

5. Наблюдаемость в продакшне
   └── Метрики, трассировка, circuit breaker

6. Производительность через типобезопасность
   └──  ORM, строгая типизация запросов
 

### Architecture
- [x] Migrate to proper Hasql parameterized queries (avoid string interpolation for security)
- [x] Add database connection pooling with proper error handling
- [x] Implement repository pattern for DAL layer
- [x] Add input validation layer (validate requests before DB operations)

### Business Logic
- [x] Implement full accounting module (double-entry bookkeeping)
- [x] Implement inventory/stock management with lot tracking
- [x] Implement VAT calculations with multi-rate support
- [x] Add payroll module integration
- [x] Add report generation (Surypus.Reports module)

### API
- [x] Add OpenAPI/Swagger documentation
- [x] Implement rate limiting middleware
- [x] Add request logging and monitoring
- [x] Implement API versioning strategy (Surypus.APIVersioning)
- [x] Add WebSocket support for real-time updates

### Security
- [x] Implement JWT authentication with refresh tokens
- [x] Add role-based access control (RBAC)
- [x] Add audit logging for sensitive operations
- [x] Implement API key authentication for integrations

### Testing
- [x] Add property-based testing with QuickCheck
- [x] Add integration tests for API endpoints
- [x] Add database migration tests (config/migrations/)
- [x] Add performance/load tests (Prometheus metrics)
- [x] Add Surypus.ValidationSpec — comprehensive validation tests (2026-10-07)
  - validateAccTurnInput: 9 unit tests + 1 QuickCheck property
  - validatePersonInput: 3 unit tests
  - validateINN: 5 unit tests + 1 QuickCheck property
  - validateKPP: 3 unit tests + 1 QuickCheck property
  - validateCurrencyInput: 3 unit tests
  - validateGoodsInput: 2 unit tests
  - validateLocationInput: 2 unit tests
  - validatePaymentInput: 3 unit tests
  - validatePriceInput: 3 unit tests
  - validateTaxInput: 4 unit tests
  - JSON roundtrip tests for AccTurnInput and MutationResult
- [x] Fix `calcNetSalaryFromGross` — return 0 for non-positive gross (2026-10-09)
- [x] Fix QuickCheck generators — produce valid domain data: non-negative amounts, woQtyReleased ≤ woQtyPlan, billAmount = Σ lineTotal (2026-10-09)
- [x] Add `instance Arbitrary Text` to TestHelpers (2026-10-09)
- [x] Full suite green: 160 examples, 0 failures, 6 pending (API stubs) (2026-10-09)
- [x] Fix `checkSlidingWindowWithHeaders` off-by-one in `remaining` (2026-10-09)
- [x] Add System.RateLimiterSpec with 15 tests covering all 4 rate limiter strategies + API middleware logic (2026-10-09)
- [x] Add System.CacheSpec with 17 tests covering System.Cache (calcHitRate, isExpired, calcVATStrict, calcTaxInclusiveStrict, STMCache operations) (2026-10-09)
- [x] Add System.CounterSpec with 15 tests covering System.Counter (nextCounterValue, padding, prefix/suffix, 4 QuickCheck properties) (2026-10-10)
  - 11 unit tests + 4 QuickCheck properties
  - Verified: all 15 tests passing
- [x] Fix Surypus.cabal: add missing modules (Core.Accounting.CacheSpec, JWTSpec, System.CounterSpec) to other-modules, remove duplicate stm/containers deps (2026-10-10)
- [x] Add ConfigSpec, ObservabilitySpec, MigrationDryRunSpec, RBACCanonSpec to cabal test-suite (2026-10-10)
  - 4 new test modules wired into cabal `other-modules` and `Test.hs`
  - All 4 verified via direct GHC compilation (12 examples total, 0 failures)
  - Fixed ConfigSpec: use qualified field access (rcLogLevel/rcMaxWorkers) instead of RecordWildCards pattern
  - Fixed MigrationDryRunSpec: remove references to non-existent generateV029-V040 (only V001-V028 exist)
  - Fixed RBACCanonSpec: remove duplicate V025 check, remove references to non-existent V029-V040
  - Note: full `cabal build` still blocked by pre-existing errors in other library modules (PayrollService, Integration.Health, DAL.Procedures, DAL.MutationsORM)
- [x] Fix committed conflict markers in Surypus.cabal, README.md, stack.yaml (accidentally committed in f4dd61bf "docs: rebuild mkdocs site"); restored from 9ecd00d4 + kept 2 intended changes (2026-10-11)
  - Removed non-existent `Shared.Export.Exporter` from exposed-modules
  - Added all 18 wired test modules to test-suite other-modules (was only 8)
  - Created missing `test/System/SequenceSpec.hs` (11 tests: 7 unit + 4 QuickCheck properties)
  - Restored README.md and stack.yaml from 9ecd00d4 (removed committed conflict markers)
  - Verified via direct GHC compilation: **298 examples, 2 failures (pre-existing RateLimiter timing), 6 pending**
- [x] Add JWTSpec with 22 tests covering Surypus.JWT security-critical module: jwtConfigFromSecret, validateAccessToken, decodeAndValidateToken + QuickCheck security properties (2026-10-09)
  - 17 unit tests + 5 QuickCheck security properties
  - Verified: 22 examples, 0 failures (compiled and run via ghc directly; full cabal build blocked by GHC 9.10.3 vs persistent incompatibility)
- [x] Wire Inventory.StockSpec + Inventory.WarehouseSpec into cabal test-suite (2026-10-12)
  - 9 tests: StockOps receipt/issue/insufficient/transfer/adjustment; Warehouse create/duplicate/read-update-delete/count
  - Fixed 3 genuine compile errors: ambiguous `pure ()` in hspec `it` blocks (Inventory.StockSpec:30, Inventory.WarehouseSpec:24) → `(pure () :: IO ())`; `shouldContain` on `Text` (Inventory.WarehouseSpec:39) → `T.isInfixOf "archived" (wName d) \`shouldBe\` True`
  - Verified by building and running the whole wired suite: **321 examples, 2 failures (pre-existing RateLimiter timing flakes), 6 pending** — both new specs green
- [x] Wire HR.OperationsSpec into cabal test-suite (2026-10-12)
  - 14 tests: validatePersonData (valid request, empty code/name, invalid INN/KPP); createPerson CRUD (create, duplicate-INN conflict, findByINN, findByCode); status transitions (activate/deactivate/block); queries (countPersons, personsByKind)
  - Fixed 1 compile error: ambiguous bare `pure ()` in `it` block (OperationsSpec:158) → `(pure () :: IO ())`
  - Verified by direct GHC build+run of the full Test.hs closure (full `cabal build` still blocked by pre-existing library errors in Surypus.API.BillTemplates et al.): **335 examples, 2 failures (pre-existing idle-machine RateLimiter timing tests), 6 pending** — new spec 14/14 green
  - Audit finding: `test/HR/PersonSpec.hs` is stale against the current API (expects 7-arg `createPerson`, `pIsActive`, `pPersonKindId :: PersonKind` — none exist in `HR.Person`/`HR.Operations`); verified by GHC ("Variable not in scope: pIsActive" + arity errors). Cannot be wired without rewrite — extends TASK-034
- [x] Wire Phase2Phase3.AccountingEventsSpec into cabal test-suite (2026-10-12)
  - 1 test: `rebuildBalance` computes correct result from events (EntryCreated debit 1000 / credit 500 → balance 500.0)
  - Fixed missing export list: `spec` was not exported → added `(spec)` to module header
  - Verified by direct GHC build+run of the full Test.hs closure (full `cabal build` still blocked by pre-existing library errors in Surypus.API.BillTemplates et al.): **336 examples, 2 failures (pre-existing idle-machine RateLimiter timing tests), 6 pending** — new spec green
  - Audit finding: `test/Phase2Phase3/AccountingEventStoreSpec.hs` + `test/Phase2Phase3/ReadModelCacheSpec.hs` are stale — they target an old in-memory `DAL.EventStore` API (`initEventStore`, `EventData{edOldBalance,…}`, `createAccountCreatedEvent`, `createJournalEntryEvent`, `aeAggregateId`, `aeEventType`, `AccountCreated`/`JournalEntryPosted`) that no longer exists; the current `DAL.EventStore` is PostgreSQL-backed (`Event`/`Snapshot` records; `appendEvent`/`getEvents`/`replayAccount` over `ConnectionPool`). Full rewrite against the DB-backed API (needs live DB to run) or deletion — extends TASK-034
- [x] Wire Domain.ProductionPropertySpec into cabal test-suite (2026-10-12)
  - 12 property tests against `Production.Types`: validateTechCard (empty name / invalid status / valid card), validateTechLine (negative qty / invalid scrap % / valid line), validateWorkOrderCore (over-release / negative plan / valid order), mkWorkOrder creates valid orders, released ≤ planned, status in valid range — 100 QuickCheck cases each
  - Fixed 6 compile errors: missing `Arbitrary TechCard`/`Arbitrary TechLine` instances (added; `Arbitrary WorkOrder` reused from TestHelpers via qualified import); `mkWorkOrder` called with 5 args vs real 4-arg signature (dropped stale `processorId`); leftover TemplateHaskell `return []` splice without pragma (removed); ambiguous `choose` result types (annotated `Gen Integer`); `UTCTime` type-only import (→ `UTCTime (..)`); `Bool` vs `Property` mismatch in `prop_statusInValidRange` (→ `property (...)`)
  - Verified by direct GHC build+run of the full Test.hs closure (full `cabal build` still blocked by pre-existing library errors in Surypus.API.BillTemplates et al.): **348 examples, 2 failures (pre-existing idle-machine RateLimiter timing tests), 6 pending** — new spec 12/12 green
  - Audit finding: `test/Integration/ValidationSpec.hs` is stale — `DAL.Types` no longer defines `PersonInput`/`GoodsInput`/`BillInput`/`LocationInput`/`OrderInput`/`PaymentInput`/`PriceInput`/`TaxInput`/`CurrencyInput`/`AccPlanInput` (only `AccTurnInput` remains), and every `validate*Input` in `Surypus.Validation` now takes individual scalar args instead of records. Needs full rewrite — extends TASK-034
- [ ] TASK-033: `Inventory.Goods.goodsForRestocking` ignores `gMinStock`, returns all active goods → cannot report below-minimum items; also not exported. Blocks `test/Inventory/GoodsSpec.hs`.
- [ ] TASK-034: 15 orphaned/stale spec files: 12 import non-existent modules (`Domain.*`, `CRM.Contact/Company/Deal/Activity/Pipeline`, `Core.Document.Types`, `Domain.Document`, `DAL.Fixtures`) — restore or delete; `Phase2Phase3/AccountingEventStoreSpec.hs` + `Phase2Phase3/ReadModelCacheSpec.hs` target the removed in-memory `DAL.EventStore` API — rewrite against the PostgreSQL-backed EventStore or delete; `DAL/TypesSpec.hs` is stale against `DAL.Types` (nonexistent `PersonInput`/`GoodsInput`/`Stock`/`SortDir`/`PaginatedResult`/`DashboardStats`/`*Filter` types, wrong field names, wrong `Bill` arg types) — rewrite before wiring.

### DevOps
- [x] Add Docker configuration
- [x] Add CI/CD pipeline
- [x] Add database migrations (flyway/schema migrations)
- [x] Add health check endpoints
- [x] Add metrics (Prometheus)

---

## Phase 2 — Accounts & Journal Entries (ACID)

### Epic: US-2 Login & RBAC
- [x] US-2-1: Login and RBAC (P1, 3SP) — JWT auth with roles/permissions; 200 + token; RBAC per request
- [x] US-2-5: RBAC negative test (P2, 2SP) — non-authorized user gets 403 Forbidden
- [x] US-2-7: OpenAPI Docs (P3, 2SP) — /docs or /swagger.json available and valid
- [x] US-2-6: Health & Readiness (P2, 2SP) — 200 OK with status fields

### Epic: US-2 Account Management
- [x] US-2-2: Create Account (P1, 5SP) — 201 Created; code unique; stored with timestamps
- [x] US-2-3: Read Accounts (P2, 3SP) — 200; accounts contain created account; code unique

### Epic: US-2 Journal & Read Models
- [x] US-2-4: Create Journal Entry (P1, 5SP) — 201 Created; balance updated 5-10s; validates account exists
- [x] US-2-8: Read model account_balances (P2, 5SP) — API reads balances; updates within 5-10s
- [x] US-2-9: Read model ledger_projection (P2, 5SP) — correct totals per account per period
- [x] US-2-10: Dashboard endpoint (P2, 3SP) — /api/v1/dashboard: revenue, stockValue, pendingPayments
- [x] US-2-11: Read-model caching (P2, 3SP) — in-memory TTL 5-10s; cache hits reduce DB load
- [x] US-2-12: Phase 2 Integration tests (P2, 5SP) — all phase-2 tests pass in CI

---

## Phase 3 — Event Sourcing, Redis, GraphQL, WebSocket

### Epic: US-3 Event Sourcing
- [ ] US-3-1: Accounts Event Store (P1, 8SP) — accounting_events table; append-only events; replay utility
- [ ] US-3-2: Account read-model replay (P1, 5SP) — rebuild balances from event stream

### Epic: US-3 Infrastructure
- [ ] US-3-3: Read models Redis cache (P2, 5SP) — Redis TTL caches 5-10s; Redis streams for events
- [ ] US-3-5: Redis Queue (P3, 5SP) — Redis/Bull for background tasks; retry on failure

### Epic: US-3 API Gateway
- [ ] US-3-4: GraphQL Proxy (P2, 5SP) — /graphql returns data consistent with REST; no direct DB access
- [ ] US-3-6: WebSocket real-time (P3, 5SP) — WebSocket broadcasts events when keys change
- [ ] US-3-7: Proxy usage and client migration plan (P3, 3SP) — GraphQL client integration plan

---

## High Priority

- [x] Add proper parameterized queries instead of string interpolation (security)
- [x] Add filter parameters to paginated queries (connect filter types)
- [x] Add sorting parameters to paginated queries
- [x] Add bill lines endpoint (GET /bills/:id/lines)
- [x] Add order lines endpoint (GET /orders/:id/lines)
- [x] Add sales summary endpoint (GET /sales/summary)
- [x] Add inventory documents endpoint (GET /inventory)
- [x] Implement real dashboard stats from database
- [x] Add JWT authentication middleware to protect endpoints
- [x] Implement login endpoint with JWT token generation
- [x] Add request logging middleware
- [x] Add payments endpoint (GET /payments, GET /bills/:id/payments)
- [x] Add units endpoint (GET /units)
- [x] Add document types endpoint (GET /document-types)
- [x] Add stock summary endpoint (GET /stock/summary)
- [x] Add RBAC types and roles endpoint (GET /roles)
- [x] Implement repository pattern for DAL layer
- [x] Add report generation with JasperReports integration

## Medium Priority

- [x] Add BillLineInput FromJSON instance
- [x] Add PUT/DELETE endpoints for bills and orders
- [x] Add goods prices CRUD endpoints
- [x] Add taxes CRUD endpoints
- [x] Add currencies CRUD endpoints
- [x] Implement API versioning strategy

## Low Priority

- [x] Run hlint and fix warnings
- [x] Add hlint to CI pipeline
- [x] Add pgformatter for SQL formatting

---

## Database Migrations (B1)

- [x] B1-1: Schema columns aligned with procedures.sql
- [x] B1-2: V009__rbac_store.sql — RBAC tables created
- [x] B1-3: V010__production.sql — Production tables created
- [x] B1-4: procedures.sql — Business procedures added
- [x] B1-5: init_db.sh — Order fixed, no hardcoded references

---

## Documentation (B10)

- [x] B10-1: CHANGELOG.md updated with [0.2.0.0] section
- [x] B10-2: AGENTS.md updated with Service Layer, Database Migrations, Job Types
- [x] B10-3: docs/engineering/api-conventions.md created
- [x] B10-4: docs/engineering/testing-guide.md created

---

## New Development Tasks

### Business Logic
- [x] Add multi-currency support
- [x] Add import/export functionality (CSV, Excel)
- [x] Add barcode scanning support (see src/Surypus/RBAC.hs for barcode validation)
- [x] Add email notifications (Core.Notification module)
- [x] Multi-tenancy infrastructure (DAL.Repository.User, Surypus.Tenant)

### API Development
- [x] API versioning strategy implemented
- [x] GraphQL API support (placeholder in Surypus.API.GraphQL)
- [x] WebSocket real-time updates (Surypus.WebSocket)
- [x] Rate limiting improvements (Surypus.API.RateLimit)

### Infrastructure
- [x] Add Prometheus metrics
- [x] Add database migrations (flyway)
- [x] Add integration tests (test/Integration/)
- [x] Add performance/load tests (test/Integration/PerformanceSpec.hs)
- [x] Event Store DB integration (DAL.EventStore)
- [x] Multi-tenancy infrastructure (DAL.Repository.User, Surypus.Tenant)

### Code Quality Tools
#### Haskell (hlint)
- [x] Fix hlint warnings (from ~2951 to 0)
- [x] Add hlint to CI pipeline
- [x] Configure hlint rules in .hlint.yaml
#### SQL (pgformatter)
- [x] Format SQL files in config/
- [x] Add pre-commit hook for SQL formatting
- [x] Add pgformatter to CI pipeline

---

## Frontend Development

### Web Interface
- [x] Expand web/index.html with more pages (Accounting, Payroll, Stock, Locations, Reports)
- [x] Add charts and visualizations
- [x] Add modals for data entry
- [x] Add filter and pagination UI

### Mobile Web Interface
- [x] Expand mobile.html with more pages
- [x] Add responsive design features

### QML Desktop Interface
- [x] Expand Components.qml with reusable components
- [x] Expand Main.qml with dashboard and pages
- [x] Expand main.qml with full application features
- [x] Add CRUD dialogs for entities

---

## Cache Implementation

- [x] Implement functional Core.Accounting.Cache with STM + LRU eviction (2026-10-09)
  - Replaced stub with thread-safe STMCache-backed implementation
  - mkReadModelCache: creates bounded cache with hit/miss statistics
  - getCachedBalance: returns 0.0 on miss, cached value on hit
  - putCachedBalance: inserts/updates entry with LRU eviction at maxSize
  - invalidateCache: removes single entry
  - clearCache: clears all entries
  - cacheStats: tracks hits, misses, and current size
  - Added Core.Accounting.CacheSpec with 15 tests (12 unit + 3 property-based)
  - All 15 cache tests passing

## Stats

| Status | Count |
|--------|-------|
| Done (Phase 2) | 12 |
| Open (Phase 3) | 7 |
| Done (General) | 42 |
| Done (Cache) | 1 |
| Done (System.Cache) | 1 |
| Done (System.Counter) | 1 |
| Done (JWT) | 1 |
| Done (New: Config+Obs+Mig+RBACCanon) | 4 |
| Done (New: Inventory Stock+Warehouse) | 2 |
| Done (New: HR.Operations) | 1 |
| Done (New: Domain.ProductionProperty) | 1 |
| **Total** | **71** |