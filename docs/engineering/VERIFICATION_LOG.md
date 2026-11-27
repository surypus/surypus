# Verification log

All commands in the clean worktree at
`/home/dominicusin/.hermes/cache/scratch/surypus-audit`.

## Cycle 2 (2026-11-27)

| Command | Exit | Result |
|---|---|---|
| `git fetch origin` + `git status` | 0 | branch `autonomous/audit-2026-11-27` at `9c0368e`, clean |
| `stack test` (session start, re-verification) | 0 | 1234 examples, 0 failures, 3 pending |
| `stack build --test --test-arguments="--match RBAC repository"` | 1 | Hspec rejects a multi-word pattern; the build itself succeeded; used full run instead |
| `stack test` (after S-08) | 0 | 1247 examples, 0 failures, 3 pending |
| `stack test` (after S-02) | 0 | **1254 examples, 0 failures, 3 pending** |
| `env -u DB_HOST -u SURYPUS_JWT_SECRET stack exec surypus-server` | 1 | `SURYPUS_JWT_SECRET is required (fail-fast)` |
| Real server, `curl /api/v1/health` | 0 | HTTP 200 |
| Real server, `curl /api/v1/persons` (no token) | 0 | HTTP 401 |
| Real server, `curl /api/v1/unknown-resource` (no token) | 0 | HTTP 401 |
| Real server, `curl /api/v1/metrics` | 0 | HTTP 200 |

Failed build attempts during implementation (my own errors, fixed and re-run):
`T.notElem` does not exist; `userError` import; missing `persistent` in test
dependencies; missing `IORef` type import; a three-argument throwing lambda;
`rawPathInfo` not imported; an assertion wrongly assumed `SELECT 1` has no
digits. None of these were hidden.

## Cycle 1

| Command | Exit | Result |
|---|---|---|
| `stack build --test --test-arguments="--match AuthMiddleware"` | 0 | 8 examples, 0 failures |
| `stack test` | 0 | 1234 examples, 0 failures, 3 pending |
| System `runghc`/`ghc`/`ghci` | 1 | broken system package db (`hspec` files missing); switched to Stack GHC 9.6.5 |

Not executed: `scripts/check-tenant-rls.sh`,
`scripts/ci-migration-verification.sh`, GitHub CI. No claim is made about them.
