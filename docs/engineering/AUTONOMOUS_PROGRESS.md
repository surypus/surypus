# Autonomous progress

## Cycle 15 (2026-11-27) — posting invariants as properties

- Registered and claimed Beads `Surypus-7oo` (P1). Extracted pure
  `Service.BillPosting.balancedEntries`; production posting now inserts the
  entries from that function. Added QuickCheck properties for two entries,
  debit == credit, non-negative amounts and rejection of negative totals.
- Verification: `stack test` 1279/0/6 without DB; **1287 examples,
  0 failures, 2 pending** with `SURYPUS_TEST_DATABASE_URL`.


## Cycle 14 (2026-11-27) — inventory movements completed

- Claimed Beads `Surypus-px3` (P2). Added migration
  `sql/migrations/V017__inventory_movements.sql` with `bill_posting_lines`
  (BIGINT bill id, the legacy `bill_lines` uses UUID and cannot be joined)
  and `inventory_movements` with a UNIQUE(bill, goods, type) constraint.
  `Service.BillPosting` now issues `issue` movements from lines inside the
  same transaction; bills without lines produce no movement (no fake data).
- `BillLifecycleIntegration` now inserts a line and asserts exactly one stock
  movement, no duplicates on repeated posting, and none for a missing bill.
- `MigrationCorpusSpec` no longer hardcodes the file count; the chain loads
  cleanly on a fresh PostgreSQL (375 files including procedures.sql).
- Verification: 2/0 targeted; full suite **1283 examples, 0 failures,
  2 pending** with DB and 1275/0/6 without.


## Cycle 13 (2026-11-27) — bill posting side effects

- Claimed Beads `Surypus-878` (P1). Added `Service.BillPosting.postBillWithEffects`
  and wired the API `postBill` to it. One explicit transaction inserts two
  balanced `journal_entries`, a `bill_posted` `event_store` row, an
  `audit_log` row and marks the bill posted; failure rolls back, and an
  already-posted bill is a no-op.
- Extended `BillLifecycleIntegration`: asserts debit == credit == bill total,
  exactly one event and one audit row, repeated POST creates no duplicates,
  and a missing bill produces no event.
- Inventory is NOT implemented: the canonical schema has no stock-movement or
  inventory table. Registered as a follow-up Beads issue instead of faking it.
- Verification: targeted 2/0; full suite **1283 examples, 0 failures, 2 pending**
  with DB and 1275/0/6 without. Both passed.


## Cycle 12 (2026-11-27) — last hardcoded pool removed

- Registered and claimed Beads `Surypus-8dr` (P1). `DAL.ORMPool.createPool`
  still hardcoded a localhost connection string with a placeholder password;
  it now delegates to `DAL.Database.createPool`. Added a source-level guard in
  `ConnectionConfigSpec` so the literal cannot return.
- Verification: `stack test` 1275/0/6 without DB; 1283/0/2 with
  `SURYPUS_TEST_DATABASE_URL`. Both passed.


## Cycle 11 (2026-11-27) — regression test for tenant-scoped SQL

- Created and claimed Beads `Surypus-cxr` (P1). Added
  `test/DAL/TenantScopedDbSpec.hs`: asserts `app.tenant_id`/`app.user_id` are
  set by `withTenantContext` + `runDb`, and by `runDbWithTenant`, against a
  live PostgreSQL. Pending without `SURYPUS_TEST_DATABASE_URL`.
- Verification: targeted 2/0; full suite **1282 examples, 0 failures,
  2 pending** with DB and 1274/0/6 without. Both passed.


## Cycle 10 (2026-11-27) — bill slice unblocked; tenant-scoped queries fixed

- Claimed Beads `Surypus-2a5` (P1). Root causes found and fixed:
  1. `DAL.Database.runDb`/`runDbWithTenant` called `rawExecute` on
     `SELECT set_config(...)`, which always throws
     `execute resulted in Col 1-column result`. Every tenant-scoped query
     failed and the permission store silently denied (P0).
  2. `DAL.MutationsORM` bill functions wrote to non-existent columns
     (`bill_number`, `bill_date`, `bill_status`, `updated_at`, ...). Rewritten
     against the canonical columns (`number`, `date`, `status`, `total_amount`,
     `vat_sum`, `obj_type`) with bound parameters.
  3. `Surypus.API.Bills.listBills` returned `QuerySuccess []` and `getBill`
     always `QueryError "Not found"`. Now backed by `DAL.QueriesORM.getBills`
     and `getBillById`.
- Added `test/BillLifecycleIntegration.hs`: create → list → read → post through
  the real Servant app with JWT/admin role and PostgreSQL; cleanup in `finally`.
- Verification: with DB **1280 examples, 0 failures, 2 pending**; without DB
  1273 examples, 0 failures, 5 pending. Both suites passed.


## Cycle 9 (2026-11-27) — authoritative state restored

- Claimed Beads `Surypus-1vn` (P2). Rewrote the top of `STATE.md` and
  `ROADMAP.md` from measured facts; the original v1.0 completion claims are
  retained verbatim below a HISTORICAL heading.
- Current facts recorded: branch `88ee79e` (not merged to `origin/main`),
  387 library / 95 test modules, 1272/0/4 without DB and 1278/0/2 with
  `SURYPUS_TEST_DATABASE_URL`, M0 complete, M1 partial, M2 unverified.
- Beads tracker will be closed after this change; `bd dolt push` pending.
- Build/test not affected (documentation only).


## Cycle 8 (2026-11-27) — one authoritative migration order

- Claimed and closed Beads `Surypus-bnj` (P2). Added
  `scripts/migration-files.sh` as the single ordered list; `scripts/migrate.sh`,
  `scripts/ci-dry-run-mig.sh` and `scripts/ci-migration-verification.sh` now
  consume it. `sql/MIGRATIONS.md` documents the four applied groups and the
  deliberate exclusions (`sql/core` legacy RBAC variant, policy, service,
  archive, test, seeds).
- Root cause of ordering failure: locale-dependent `sort` put
  `V001b__tenant_scoping.sql` before `V001__core_schema.sql` → `relation "bills"
  does not exist`. Fixed with `LC_ALL=C`; chain now loads cleanly.
- Removed a false CI check: the old script globbed `V*.generated.sql` (0 files)
  and applied nothing; removed a duplicate DB dry-run and fixed unsupported
  `stack test -m` / `--color` flags.
- Verification: `bash scripts/ci-migration-verification.sh` with a throwaway
  PostgreSQL DB → `ALL_MIGRATIONS_LOAD_OK`, `MIGRATION_PREFLIGHT_OK: 373 files`,
  10 targeted examples, exit 0. Full suite **1272 examples, 0 failures,
  4 pending**. Five new corpus tests. Probe DB dropped afterwards.


## Cycle 7 (2026-11-27) — permission check on live PostgreSQL

- Claimed and closed Beads `Surypus-38p` (P1). Added
  `test/DAL/RBACRepositoryIntegration.hs`: with `SURYPUS_TEST_DATABASE_URL`
  it inserts probe users, exercises `checkUserAppPermissionRepo` against the
  real schema and cleans up in `finally`. Cases: viewer/read allowed,
  viewer/delete denied, no-role denied, admin allowed.
- Local peer-auth DB role `dominicusin` was granted SELECT/INSERT/DELETE on
  the RBAC tables; no production credential or data was changed.
- Verification: with DB URL **1273 examples, 0 failures, 2 pending**;
  without URL **1267 examples, 0 failures, 4 pending** (new suite pending,
  not passing). `bd dolt push` → Push complete.


## Cycle 6 (2026-11-27) — secrets encrypted at rest

- Claimed and closed Beads `Surypus-6ob` (P1). `System.Secrets` no longer
  stores plaintext: values are sealed with AES-256-GCM-SIV (nonce + tag +
  ciphertext, 28-byte overhead). Key comes from `SURYPUS_SECRETS_KEY` (padded
  to 32 bytes) or a fresh random key when unset; an ephemeral key means no
  cross-restart recovery, which is documented in the module.
- `rotateSecret` seals the new value; `retrieveSecret` fails closed on
  authentication failure; audit entries record key names, never values.
  `generateSecret` now uses `getRandomBytes` instead of `System.Random`.
- Added three tests: no plaintext in store, tampered ciphertext rejected,
  fresh nonce for equal values. `stack test` → **1266 examples, 0 failures,
  3 pending**, exit 0. `bd dolt push` → Push complete.


## Cycle 5 (2026-11-27) — Beads restored, maintenance resumed

- **Beads repaired without destructive reinit.** Direct clone via
  `dolt clone https://doltremoteapi.dolthub.com/dominicusin/Surypus-bd`
  succeeded; the cloned DB was placed at `.beads/dolt/Surypus`. `bd ready`
  works, 104 issues are visible. `bd dolt push` completed — DEC-005's blocker
  is resolved without `--discard-remote`.
- Created Beads issues: `Surypus-9c2` (queue stubs, P1), `Surypus-6ob`
  (plaintext secrets, P1), `Surypus-38p` (DB permission check, P1),
  `Surypus-bnj` (migration corpora, P2), `Surypus-1vn` (state docs, P2).
- **Claimed and closed `Surypus-9c2`**: `processJob` no longer reports success
  for unimplemented job types. `realHandler` is the only source of
  `JobCompleted`; all current types return `JobFailed` with an explicit reason.
  Removed eight success-shaped `process*` stubs. Three tests added.
- `stack test` → **1263 examples, 0 failures, 3 pending**, exit 0.

## Bootstrap import (2026-11-27)

Imported `.hermes/BOOTSTRAP.md`, `DEBT_REGISTER.md` and `DECISIONS.md` from
`surypus-hermes-bootstrap.zip`. The archive's own progress/log snapshots say
"INITIALIZED" and "no tests executed" — that describes the archive author's
setup step only. The verified cycles 1–4 below supersede those statements for
this repository: `stack test` reached 1260 examples / 0 failures / 3 pending.

Upstream `main` gained commit `0a20715` (canonical 1133-line `HERMES.md`) while
this branch was in flight. Merged at `696c412`, adopting main's policy file;
the shorter local policy was discarded, not kept as a competing document.

Owner clarification (2026-11-27): Beads is the single task source; Markdown
engineering files exist for recovery and reporting only. `NEXT_ACTIONS.md` was
rewritten as a recovery point with no task IDs or priorities.

Beads (`bd`) is broken in this worktree: `bd ready --json` fails with
`database "Surypus" not found on Dolt server`; `bd doctor` reports 3 errors,
including database and Dolt permission failures, and still points at
`/home/dominicusin/surypus/.beads`. `bd bootstrap` then failed to clone the
DoltHub remote (`rpc error: code = Unimplemented`); `--reinit-local` requires
the destructive `--discard-remote` workflow, which was not run. No task IDs
were invented or claimed.
`NEXT_ACTIONS.md` remains a handoff record required by `HERMES.md` §16, not a
replacement for Beads.

## Cycle 4 (2026-11-27) — event id stub

- **S-05 (P2)**: `generateEventId` returned the constant
  `event-id-placeholder`; it now uses `Data.UUID.V4.nextRandom`. Added two
  tests (non-empty, 64 unique IDs).
- `stack test` → **1260 examples, 0 failures, 3 pending**, exit 0.

## Cycle 3 (2026-11-27) — tenant isolation

### Implemented
- **S-09 (P0)**: tenant context was a single global `IORef` created with
  `unsafePerformIO` while documented as thread-local. Under concurrency,
  tenant A's context could be read by tenant B's `runDb`. Context is now keyed
  by `ThreadId`; added `withTenantContext` with restoration on scope exit and
  on exceptions, and rewired `MultiTenancy.Middleware` to use it.
- Added four isolation tests, including a two-thread interleaving test that
  proves both tenants keep their own context simultaneously.

### Verified
`stack test` → **1258 examples, 0 failures, 3 pending**, exit 0.

### Outstanding
S-10 (partially verified via psql; Haskell-pool integration still needed), then S-03/S-04/S-05.

## Cycle 2 (2026-11-27) — persistent mode resumed

Verified at start: `stack test` 1234 examples / 0 failures / 3 pending;
worktree clean at `9c0368e`; no `HERMES.md` existed (created now).

### Implemented

- **S-08 (P0)**: replaced the always-`True` `checkUserAppPermissionRepo` with a
  parameterised, validated, fail-closed PostgreSQL permission check. Added
  `splitPermission`, `permissionSql`, `checkPermissionWith` (injectable query
  runner) and 13 tests covering malformed input, wildcards, exceptions, empty
  results and SQL-injection-shaped strings.
- **S-02 (P0)**: replaced the health-probe-only `app/Main.hs` with the real
  Servant server from `Surypus.API.Server`, wired to a DB-backed RBAC store,
  katip logger, metrics and fail-fast environment configuration. Removed the
  hardcoded `password=*** placeholder from `DAL.Database`; added
  `createPoolWith`, `createPoolFromEnv`, `buildConnectionString` with validation
  against connection-string injection, re-exported from `DAL.Pool`.
- Created `HERMES.md` as the persistent engineering policy.

### Changed files

`app/Main.hs`, `src/DAL/Database.hs`, `src/DAL/Pool.hs`,
`src/DAL/Repository/RBAC.hs`, `Surypus.cabal`, `test/Test.hs`,
`test/DAL/RBACRepositorySpec.hs` (new), `test/DAL/ConnectionConfigSpec.hs`
(new), `test/ServerWiringSpec.hs` (new), `HERMES.md` (new),
`docs/engineering/*`.

### Verified

- `stack test` → **1254 examples, 0 failures, 3 pending**, exit 0.
- Real binary, no config → `SURYPUS_JWT_SECRET is required (fail-fast)`, exit 1.
- Real binary on port 18080: `/api/v1/health` 200, `/api/v1/persons` 401,
  `/api/v1/unknown-resource` 401, `/api/v1/metrics` 200.

### Outstanding

Full DB-backed permission check against a live migrated schema is still
UNVERIFIED (no credentials supplied for TCP auth; `sudo -u postgres` peer auth
works but the app has no password). Tenant-context concurrency leak was fixed in cycle 3.

## Cycle 1 (2026-11-27)

S-01: authorization middleware made fail-closed; pure decision module,
injectable verifier, segment-boundary public paths, 16 regression tests.
`stack test` 1234/0/3. Commit `9c0368e`.
