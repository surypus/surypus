# Plans

Активные задачи — 19. Обновлено: 2026-10-17.


## In Progress


### Surypus-sca — Real DB queries in all API handlers — replace pure (SomeResponse []) with DAL calls

Replace hardcoded stub responses with real database queries in all API endpoints


### Surypus-601 — Завершить интеграцию stored procedures с Haskell DAL

DAL/Procedures.hs существует (~1600 строк оберток), но в DAL/Queries.hs и DAL/Mutations.hs заменены только 2-3 функции. Нужно: (1) для каждого CRUD endpoint — убедиться что идёт через хранимые процедуры, а не raw SQL, (2) добавить тесты для каждой процедуры, (3) синхронизировать сигнатуры типов Haskell с фактическими SQL функциями.

**Контекст:** INTEGRATION_SUMMARY.md описывает частичную интеграцию

**Теги:** [Haskell, PostgreSQL, DAL]


### Surypus-602 — Стабилизация и упорядочивание миграций БД

В scripts/init_db.sh порядок MIGRATION_ORDER перечисляет файлы по имени, но некоторые из них (20240616_*.sql, 20240617_*.sql) могут конфликтовать с V001-V012. Нужно: (1) провести полный прогон всех миграций на чистой БД и зафиксировать ошибки, (2) ввести flyway-style versioning таблицу schema_version, (3) сделать idempotent-миграции через CREATE IF NOT EXISTS.

**Контекст:** Конфликты в порядке миграций V001-V012

**Теги:** [PostgreSQL, Migrations]


### Surypus-604 — Исправить refresh token rotation

Функция `rotateRefreshTokenBestEffort` использует pattern `try ... :: IO (Either SomeException ...)` и возвращает `Maybe`, что позволяет молча глотать ошибки rotation. Нужно: (1) сделать rotation атомарным через одну транзакцию в БД, (2) добавить invalidation всех других refresh tokens для того же user при ротации, (3) добавить интеграционные тесты для refresh flow.

**Контекст:** rotateRefreshTokenBestEffort может пропустить ошибки

**Теги:** [JWT, Auth, Security]


### Surypus-vyo — Fix stack build: type mismatches in DAL.Queries.hs parameter encoding

Build fails with type mismatch errors in surypus-api/src/Surypus/DAL/Queries.hs. Lambda functions for parameter encoding have incorrect arity - expecting 2-3 parameters but statements have 4+ parameters. Need to fix parameter encoding patterns for TechCard (4 params) and WorkOrder (16 params) queries.


### Surypus-c9v — Add AuthProtect to SurypusApi - extract user from JWT

Add Servant AuthProtect to API so handlers can access authenticated user context. Need to modify SurypusApi type, create auth handler, and update requirePermissionText_ to check real user permissions.


### Surypus-kng — Phase 1.2: Implement real RBAC checks

Replace stub permission check with actual RBAC verification


### Surypus-k2c — Replace API handlers with real DB queries

Replace hardcoded responses in API handlers with real Hasql DAL calls. Focus: persons, goods, bills, accounting endpoints.


### Surypus-u6e — Implement Hasql-based event store in DAL/EventStore.hs

Replace the in-memory event store with a Hasql-based implementation using the event_store table created in V1000. Implement appendEvent, getEvents, getEventsFrom, replayAccount, getLatestSequence using Hasql.


### Surypus-lgr — Fix stack build: hashtables GCC16 + verify Surypus compiles

_No description._


### Surypus-0cg — WebSocket broadcast for Inventory events

Broadcast StockReceived, StockShipped etc. via WebSockets to keep UI in sync


### Surypus-4ij — Phase 2.1: Production Deployment Setup

Set up production deployment configuration, environment variables, and container configuration


### Surypus-8fa — Implement Jobs DAL functions for jobsList, jobsCreate

Add DAL functions getJobs and createJob for job management endpoints. Update endpoints to use real database calls instead of stubs.


### Surypus-617 — Индексы и оптимизация запросов

Нужно: (1) запустить EXPLAIN ANALYZE на всех paginated queries, (2) добавить составные индексы для часто используемых фильтров (bill: doc_date+person_id, person: name+inn, goods: name), (3) добавить partial indexes для status filters, (4) настроить VACUUM и autovacuum.

**Контекст:** Пагинированные запросы без explain analyze

**Теги:** [PostgreSQL, Performance]


### Surypus-618 — Event Store foundation для CQRS

Нужно: (1) создать базовую event_store таблицу (sql/migrations/), (2) реализовать Haskell тип Event и функции appendEvent/getEvents через Hasql, (3) подключить к Bill и Inventory aggregates, (4) outbox pattern для надёжной публикации событий.

**Контекст:** docs/REFACTORING_SUMMARY.md описывает архитектуру

**Теги:** [Event Sourcing, CQRS, PostgreSQL]


### Surypus-622 — Prometheus metrics: реальные метрики вместо заглушек

Нужно: (1) добавить ekg или prometheus-haskell библиотеку, (2) собирать метрики: http_requests_total, http_request_duration_seconds, db_pool_connections, job_queue_size, (3) добавить alerting rules в prometheus/prometheus.yml.

**Контекст:** GET /metrics возвращает MetricsResponse 0 0 0

**Теги:** [Observability, Prometheus, Haskell]


### Surypus-621 — QML: подключить к API и сделать рабочим

Нужно: (1) реализовать login flow в QML, (2) заменить все ListModel на реальные HTTP запросы, (3) подключить WebSocket для live updates, (4) добавить error dialogs.

**Контекст:** qml/Main.qml — полный UI но без реального функционала

**Теги:** [QML, Desktop, Frontend]


## Open


### Surypus-bvn — v52.0: CRM & Reports Implementation

Replace all CRM and Reports stub implementations with real SQL queries. Fix remaining Bills and Goods stubs. Verify Docker build.

Phase 163: CRM Real DB Queries — Contacts, Companies, Pipeline stages, Deal operations (16 stubs in surypus-api/src/Surypus/API/CRM.hs)
Phase 164: Reports Implementation — P&L and Inventory reports (3 stubs in surypus-api/src/Surypus/API/Reports.hs)
Phase 165: Bills Fix & Docker Verification — updateBill, createGood, docker-compose build


### Surypus-681 — Strategic Analysis — 19 tasks across 6 goals (reference)

Full strategic analysis saved to docs/strategic_analysis.md

# Surypus Strategic Analysis — Pāñcāvayava Structure

## Thesis
Surypus — formally verified ERP on Haskell. Current state: "structure exists, implementation absent". API handlers return hardcoded stubs, core business flow (Bill posting) incomplete, RBAC middleware partially connected, Event Store layer only declared.

## Goals & Task List

### Goal 1 — Production-Ready API (5 tasks)
1.1 [CRITICAL] Real DB queries in all API handlers — replace pure (SomeResponse []) with DAL calls
1.2 [CRITICAL] ...

---
This issue tracks the overall strategic plan. Individual tasks are tracked separately.
