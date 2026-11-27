# Implementation matrix

Status vocabulary: VERIFIED / IMPLEMENTED / PARTIAL / STUB / BROKEN /
UNVERIFIED / BLOCKED. "Tests" names the module exercising the row.

| Subsystem | Domain | API | Service | DAL | Database | Event | Projection | Tests | Status |
|---|---|---|---|---|---|---|---|---|---|
| Auth middleware | `AuthorizationDecision` | `AuthMiddleware`, `Authorization` | — | injected `checkPerm` | permission store | — | — | `AuthMiddlewareSpec`, `AuthMiddlewareDecisionSpec`, `RBACCanonSpec` | **VERIFIED** after S-01 |
| JWT auth | `Surypus.JWT.Token` | bearer header | `verifyToken` | — | refresh-token migration `V005` | — | — | `JWTSpec`, `Surypus.JWTSpec` | IMPLEMENTED; rotation **UNVERIFIED** here |
| Bill posting | `Finance.*` | `Surypus.API.Bills` | `Core.Services.Accounting` | `DAL.Mutations`, `DAL.Queries` | `sql/migrations` | `Infrastructure.EventStore.Accounting` | `Core.Accounting.ReadModel` | `Finance.BillSpec`, `AccountingEventsSpec`, `AccountingReadModelSpec` | IMPLEMENTED, end-to-end via executable **UNVERIFIED** (S-02) |
| Accounting invariants | `Finance.Accounting`, `Finance.Ledger` | — | — | — | — | — | — | `Finance.AccountingSpec`, `Finance.LedgerSpec`, `QuickCheckInvariantsSpec` | VERIFIED by property tests |
| Event store | — | — | — | `DAL.EventStore` | `sql/event/V001` | `DAL.EventStore` | replay | `DAL.EventStoreIntegration` | IMPLEMENTED; live DB round-trip UNVERIFIED without `SURYPUS_TEST_DATABASE_URL` |
| Worker queue | `DAL.Queue` | — | `runWorker` | `DAL.Queue` | `job_queue` table | — | — | none named | **STUB** (`processJob`) |
| Multi-tenancy | `MultiTenancy.*` | `tenantMiddleware` | — | tenant-scoped queries | `V001b__tenant_scoping.sql` | tenant claims | — | `TenantIsolationSpec` | IMPLEMENTED; RLS gate UNVERIFIED |
| DSL/codegen | `dsl/schema.yaml` | — | generator | `DAL.Types` | migration generator | — | — | `Core.DSL.ParserSpec`, `Contract.SchemaSpec` | IMPLEMENTED (output consistency UNVERIFIED) |

Note: 166 of 387 source modules have a final path segment that appears in no
test file. That is a triage lead, not proof of zero coverage — module names can
be absent while behaviour is exercised indirectly.
