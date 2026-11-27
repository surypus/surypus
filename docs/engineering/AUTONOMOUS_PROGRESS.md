# Autonomous progress

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
