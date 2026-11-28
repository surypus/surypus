> **SUPERSEDED (2026-11-27).** The v1.0 "production-ready / 8 of 8 complete"
> claim below is a historical record, not the current state. It is retained
> verbatim after the measured section.

# Surypus Project State

## Current state — 2026-11-27 (measured)

- Branch `autonomous/audit-2026-11-27` at cycle-10 commit; not merged to
  `origin/main` (`0a20715`). Worktree was clean before this update.
- 387 library modules, 95 test modules.
- `stack test`: **1272 examples, 0 failures, 4 pending** without a database;
  **1278 examples, 0 failures, 2 pending** with `SURYPUS_TEST_DATABASE_URL`.
- Beads is healthy; all registered issues are closed; `bd dolt push` works.
- VERIFIED in this branch: fail-closed authorization, DB-backed permission
  checks (live PostgreSQL), real `apiServer` in the executable, per-thread
  tenant context, AES-GCM-SIV secret storage, unique event IDs, fail-closed
  job processing, one authoritative migration order (374 files; full chain
  loads cleanly against PostgreSQL in a rolled-back transaction).
- PARTIAL: bill create/list/read/post through the running server is verified;
  accounting, inventory movements, events and audit are now verified in the
  same integration test.
  GraphQL compliance; workflow engine reliability; GitHub CI status;
  `check-tenant-rls.sh`; LiquidHaskell proof coverage.
- Milestones: M0 persistent operating mode — complete; M1 security perimeter —
  substantial, not complete; M2 core vertical slice — unverified.
- Authoritative pointers: `docs/engineering/AUTONOMOUS_PROGRESS.md`,
  `docs/engineering/NEXT_ACTIONS.md`, `docs/engineering/VERIFICATION_LOG.md`,
  `docs/engineering/audit/BASELINE.md`, `sql/MIGRATIONS.md`.

## Historical v1.0 document (retained unchanged)

**Milestone**: v1.0 - Production-ready ERP System
**Last Updated**: 2026-06-12
**Current Phase**: COMPLETE - v1.0 Released

## Phase Progress

| Phase | Status | Progress | Notes |
|-------|--------|----------|-------|
| Phase 1: Core API & DB Integration | ✅ COMPLETE | 100% | All API handlers use real database |
| Phase 2: JWT Auth & RBAC | ✅ COMPLETE | 100% | JWT middleware, RBAC, audit logging |
| Phase 3: Bill Posting & Accounting | ✅ COMPLETE | 100% | Atomic bill posting, QuickCheck tests |
| Phase 4: Event Sourcing & Infrastructure | ✅ COMPLETE | 100% | EventStore, WebSocket, Redis, Payroll, Inventory/Bill services all integrated |
| Phase 5: LiquidHaskell Formal Verification | ✅ COMPLETE (Annotations) | 100% | Refinement types on Tax, Accounting, Stock; CI pending GHC 9.14+ |
| Phase 6: Docker & CI/CD | ✅ COMPLETE | 100% | Multi-stage Dockerfile, docker-compose with Redis, CI pipeline, health endpoints |
| Phase 7: API Hardening | ✅ COMPLETE | 100% | Rate limiting, Prometheus metrics, katip logging, RateLimit headers, correlation IDs |
| Phase 8: Final Integration & Release | ✅ COMPLETE | 100% | All tests pass, hlint errors fixed, health endpoints, release ready |

## Phase 8 Completed Items
- ✅ 8.1: Full integration test suite (76 tests passing)
- ✅ 8.2: QuickCheck property tests for all financial invariants (Core.Tax, Finance.Accounting, Inventory.Stock)
- ✅ 8.3: hlint zero parse errors (all fixed, suggestions remain)
- ✅ 8.4: OpenAPI schema validation (Servant API types)
- ✅ 8.5: Health endpoint returns {status: "ok", db: "ok"} (/api/v1/health, /api/v1/health/db)
- ✅ 8.6: Release v1.0 tag and Docker image publish (v1.0.0 already tagged, Docker image ready for build)

## Phase 7 Completed Items
- ✅ Rate limiting (100 req/min/IP, sliding window, per-IP/per-tenant with RateLimit headers)
- ✅ Prometheus metrics endpoint (/metrics) with request count, duration histogram, error rate
- ✅ Structured JSON logging (katip) with correlation IDs, tenant context
- ✅ RateLimit response headers (RateLimit-Limit, RateLimit-Remaining, RateLimit-Reset)
- ✅ Request tracing with correlation IDs (correlationMiddleware + katip logging)
- ⏳ Circuit breaker for external integrations (System.CircuitBreaker exists, needs integration)

## Phase 6 Completed Items
- ✅ Multi-stage Dockerfile (builder → runtime with libpq5, curl, dumb-init)
- ✅ docker-compose.yml with PostgreSQL, Redis, API, Worker services
- ✅ GitHub Actions CI pipeline (build, test, hlint, liquidhaskell, docker)
- ✅ Health check endpoints: `/api/v1/health` (OK), `/api/v1/health/db` (DB OK/ERROR)
- ✅ Health check middleware implemented as WAI middleware (runs before auth)
- ✅ Docker HEALTHCHECK uses curl to `/api/v1/health`

## Phase 5 Completed Items
- ✅ Core.Tax: VAT invariants (rate 0-1, result >= 0 and <= base)
- ✅ Finance.Accounting: Double-entry invariants (debit/credit non-negative, balanced transactions)
- ✅ Inventory.Stock: Stock invariants (Rest = Initial + Receipt - Issue, non-negative quantities)
- ⏳ LiquidHaskell CI pipeline: Pending GHC 9.14+ upgrade (current 9.6.5)

## Phase 4 Completed Items
- ✅ DAL.EventStore (262 lines) - real Persistent-backed Event Store
- ✅ Infrastructure.EventStore.Inventory (201 lines) - event-sourced inventory
- ✅ Infrastructure.EventStore.Accounting - event-sourced accounting
- ✅ Core.Services.Accounting (144 lines) - integrated with EventStore
- ✅ Service.InventoryService - integrated with EventStore
- ✅ DAL.Payroll (121 lines) - Decimal precision payroll persistence
- ✅ Core.Accounting.Cache - real ConnectionPool
- ✅ DAL.Repository.RBAC - real Persistent queries
- ✅ Surypus.API.Bills.postBill - emits bill.posted events to EventStore
- ✅ Surypus.WebSocket.Integration - fixed truncated JSON (finalizeMessage called)
- ✅ Integration.Health - real DB persistence with IntegrationHealthEntity
- ✅ Core.Accounting.RedisCache (304 lines) - full Redis implementation
- ✅ Schema coverage - WorkflowDefinition, WorkflowInstance, TechCard, WorkOrder entities added

## Remaining bd Issues (7)
- T-030: Complete API/GraphQL/Proxy.hs (P3)
- T-029: Complete Surypus/API/Production.hs (P3)
- T-028: Connect authMiddleware to RBAC (P3)
- T-027: Verify all handlers in Surypus/API/Server.hs (P3)
- T-038: Document API contracts with Swagger/OpenAPI (P4)
- T-036: Archive/remove incomplete modules (P4)
- T-033: Eliminate duplicate types across modules (P4)

## v1.0 Release Summary
**All 8 Phases Complete - Production Release Ready** ✅

### Release Tags
- v1.0.0 (2026-03-29) - Initial service layer, Servant API, JWT/WebSocket auth, test infrastructure
- v1.0.1, v1.0.2 available for hotfixes

### Key achievements:
- ✅ Full REST API with Servant (bills, goods, persons, payments, CRM, orders, etc.)
- ✅ JWT authentication with refresh tokens + RBAC authorization
- ✅ Event sourcing with PostgreSQL EventStore + WebSocket broadcasts
- ✅ Payroll persistence with Decimal precision
- ✅ Structured JSON logging (katip) with correlation IDs
- ✅ Prometheus metrics + rate limiting with headers
- ✅ Multi-stage Docker + docker-compose + GitHub Actions CI
- ✅ LiquidHaskell refinement type annotations (VAT, double-entry, stock invariants)
- ✅ 76 integration tests passing
- ✅ hlint parse errors eliminated
- ✅ Health endpoints for orchestration

### Next Steps
- Docker image publishing: `docker build -t surypus/surypus:latest .`
- Deploy to staging/production environment
- Monitor metrics and audit logs