# Engineering Debt Register

**Initialized:** 2026-11-27  
**Status:** Preliminary; all historical leads require revalidation.


## Audit leads requiring verification

| ID | Area | Historical observation / lead | Priority | Status |
|---|---|---|---|
| DEBT-001 | Billing/API | Previously observed bill-list/get paths with stub-like behavior | P1 | UNVERIFIED |
| DEBT-002 | Inventory lifecycle | Previously described lifecycle operations as Phase 1 stubs | P1 | UNVERIFIED |
| DEBT-003 | Job handlers | Earlier review noted handlers may return success without substantive work | P1 | UNVERIFIED |
| DEBT-004 | RBAC storage | Earlier review raised concerns about in-memory state/persistence boundaries | P0/P1 pending evidence | UNVERIFIED |
| DEBT-005 | GraphQL | May be a minimal/custom resolver rather than a compliant execution engine | P2 | UNVERIFIED |
| DEBT-006 | Workflow engine | Earlier review raised resilience concerns about errors, timeouts, and retries | P1/P2 | UNVERIFIED |
| DEBT-007 | Documentation drift | Docs may not reflect current code or test coverage | P2 | UNVERIFIED |

## Revalidation — 2026-11-27 (evidence-based)

| ID | Finding | Evidence | Status |
|---|---|---|---|
| DEBT-003 | CONFIRMED: `DAL.Queue.processJob` and all `process*` helpers return success-shaped JSON without doing work | `src/DAL/Queue.hs` lines with `processJob` and helpers | OPEN |
| DEBT-004 | PARTIALLY RESOLVED: `DAL.Repository.RBAC.checkUserAppPermissionRepo` was `return True`; now a parameterised, fail-closed DB query (cycle 2). `Surypus.RBAC.Store` is still in-memory (`IORef`). Tenant context was one global `unsafePerformIO` IORef; now per-`ThreadId` (cycle 3). | source + 13 + 4 tests | PARTIAL |
| DEBT-007 | CONFIRMED: `STATE.md` / `ROADMAP.md` claim v1.0 complete while README says prototype; both marked SUPERSEDED | `git diff` of both files | OPEN (historical notices retained) |
| DEBT-001/002/005/006 | Not re-inspected in this session; no claim made | — | UNVERIFIED |

## Register rules

- Do not promote historical leads to confirmed defects without inspecting current code.
- For confirmed items, include direct evidence (paths, symbols, tests, or reproducible failure), impact, remediation, priority, and Beads issue.
- Beads is the primary task tracker; do not create a markdown task backlog.
- Close or archive debt entries only when remediation is verified.