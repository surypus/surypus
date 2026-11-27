# Autonomous progress

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
works but the app has no password). Tenant context still uses a global
`unsafePerformIO` IORef — concurrency leak, next P0.

## Cycle 1 (2026-11-27)

S-01: authorization middleware made fail-closed; pure decision module,
injectable verifier, segment-boundary public paths, 16 regression tests.
`stack test` 1234/0/3. Commit `9c0368e`.
