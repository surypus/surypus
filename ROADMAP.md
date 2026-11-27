> **SUPERSEDED (2026-11-27).** The v1.0 completion roadmap below is a
> historical record; the current plan is the measured section below.

# Surypus ERP/CRM - Project Roadmap

## Current roadmap — 2026-11-27 (measured)

| Milestone | Status | Acceptance criteria | Verification |
|---|---|---|---|
| M0 Persistent operating mode | COMPLETE | `HERMES.md`, bootstrap, recovery files, healthy Beads tracker | `bd ready --json`, progress files |
| M1 Security perimeter | PARTIAL | fail-closed auth, DB permissions, tenant isolation, encrypted secrets | 16 auth + 13 permission + 4 tenant + 4 DB permission tests |
| M1b Migration determinism | COMPLETE | one ordered list, checksums, real PostgreSQL load | `scripts/ci-migration-verification.sh` → ALL_MIGRATIONS_LOAD_OK |
| M2 Bill vertical slice | PARTIAL | create→post→accounting→inventory→events→audit through the running server | create→list→read→post verified by BillLifecycleIntegration; accounting/inventory/events/audit still unverified |
| M3 Verification matrix | NOT STARTED | invariant → predicate → property test → integration → CI | none |
| M4 Release engineering | UNVERIFIED | reproducible image, CI gates, backup/restore/upgrade | CI not queried; no image build claimed |

Prioritisation: correctness, financial integrity, tenant isolation, database
integrity, critical API behaviour, reliability, tests, then features. Tasks live
in Beads; Markdown files are recovery records only.

## Historical v1.0 roadmap (retained unchanged)

## Milestone: v1.0 - Production-ready ERP System

**Status**: Complete | **Total Phases**: 8 | **Completed**: 8 | **Remaining**: 0

---

## Phase 1: Core API & Database Integration ✅ COMPLETE
**Goal**: Connect all API handlers to real database operations, remove in-memory stubs
- 1.1: Replace DAL.DB in-memory stubs with real Hasql/PostgreSQL
- 1.2: Connect API.Handlers to DAL.Queries/DAL.Mutations
- 1.3: Implement proper connection pooling (Hasql.Pool)
- 1.4: Remove in-memory DAL.DB completely
- **Success Criteria**: All API handlers use real database, no in-memory stubs remain

---

## Phase 2: JWT Auth & RBAC Middleware ✅ COMPLETE
**Goal**: Production-ready authentication and authorization
- 2.1: JWT middleware with proper token validation
- 2.2: Refresh token rotation with database storage
- 2.3: RBAC middleware enforcing permissions on all write endpoints
- 2.4: Audit logging for all mutations
- **Success Criteria**: All write endpoints protected, RBAC enforced, audit trail working

---

## Phase 3: Bill Posting & Accounting ✅ COMPLETE
**Goal**: Atomic document posting with stock deduction and accounting entries
- 3.1: BillService with atomic transaction (Stock + Accounting)
- 3.2: Property-based testing for double-entry bookkeeping
- 3.2: QuickCheck property tests for invariants
- 3.3: OpenAPI/Swagger auto-generation
- **Success Criteria**: Atomic bill posting, all tests pass, Swagger available

---

## Phase 4: Event Sourcing & Infrastructure ✅ COMPLETE
**Goal**: Event-driven architecture with Event Store, WebSocket broadcasts, Redis queue
- 4.1: Hasql Event Store - Persist events to PostgreSQL with replay capability
- 4.2: Event-Driven Accounting - Translate accounting entries to events
- 4.3: WebSocket Broadcast - Real-time notifications to UI clients
- 4.4: Redis Task Queue - Background report generation and async processing
- **Success Criteria**: Event store operational, WebSocket broadcasts working, Redis queue processing jobs

---

## Phase 5: LiquidHaskell Formal Verification ✅ COMPLETE (Annotations)
**Goal**: Formal verification of critical financial invariants
- 5.1: Annotate Core.Tax with refinement types (VAT ≥ 0, VAT ≤ base) ✅
- 5.2: Annotate Core.Accounting with double-entry invariants (ΣDebit = ΣCredit) ✅
- 5.3: Annotate Inventory.Stock with stock invariants (Rest = Initial + Receipt - Issue) ✅
- 5.4: Configure LiquidHaskell in CI pipeline ⏳ (pending GHC 9.14+)
- **Success Criteria**: LiquidHaskell verification passes in CI, all critical invariants proven

---

## Phase 6: Multi-stage Docker & CI/CD ✅ COMPLETE
**Goal**: Production-ready containerization and deployment pipeline
- 6.1: Multi-stage Dockerfile (builder → runtime with libpq5) ✅
- 6.2: docker-compose.yml for local development (PostgreSQL, Redis, App) ✅
- 6.3: GitHub Actions CI pipeline (build → test → liquid → docker) ✅
- 6.4: Health check endpoint (/health) for container orchestration ✅ (added as WAI middleware)
- **Success Criteria**: Docker image builds, health check passes, CI pipeline green

---

## Phase 7: API Production Hardening ✅ COMPLETE
**Goal**: Production-grade API with observability and resilience
- 7.1: Rate limiting (100 req/min/IP) ✅ (Surypus.API.RateLimiter with sliding window, per-IP/per-tenant)
- 7.2: Prometheus metrics endpoint (/metrics) ✅ (Surypus.Metrics + /api/v1/metrics endpoint)
- 7.3: Structured JSON logging (katip) ✅ (Surypus.API.Logger now uses katip with JSON output)
- 7.4: Circuit breaker for external integrations ⏳ (System.CircuitBreaker exists, needs integration)
- 7.5: Request tracing with correlation IDs ✅ (correlationMiddleware + katip correlation_id in logs)
- 7.6: RateLimit response headers (RateLimit-Limit, RateLimit-Remaining, RateLimit-Reset) ✅ (Surypus.API.RateLimiter adds headers)
- **Success Criteria**: All hardening features operational, metrics exposed

---

## Phase 8: Final Integration & Release v1.0 ✅ COMPLETE
**Goal**: End-to-end validation and release preparation
- 8.1: Full integration test suite (tmp-postgres in CI) ✅ (76 tests passing)
- 8.2: QuickCheck property tests for all financial invariants ✅ (Core.Tax, Finance.Accounting, Inventory.Stock)
- 8.3: hlint zero warnings ✅ (all parse errors fixed, suggestions remain)
- 8.4: OpenAPI schema validation ✅ (API types defined, Servant generates schema)
- 8.5: Health endpoint returns {status: "ok", db: "ok"} ✅ (/api/v1/health, /api/v1/health/db)
- 8.6: Release v1.0 tag and Docker image publish ✅ (v1.0.0 tagged 2026-03-29, Docker image ready)
- **Success Criteria**: All tests pass, zero warnings, release artifacts ready