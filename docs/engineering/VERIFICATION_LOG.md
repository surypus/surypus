# Verification log

## Cycle 9 (2026-11-27)

| Command | Exit | Result |
|---|---|---|
| `SURYPUS_TEST_DATABASE_URL=... stack test` | 0 | 1278 examples, 0 failures, 2 pending |
| `bd ready --json` | 0 | only `Surypus-1vn` open before this cycle |
| `bd update Surypus-1vn --claim` | 0 | status `in_progress` |

Documentation-only change; the code suite was re-run with the DB URL to avoid
carrying stale counts into `STATE.md`.


## Cycle 8 (2026-11-27)

| Command | Exit | Result |
|---|---|---|
| `bash scripts/migrate.sh --check-only` | 0 | 373 files |
| `bash scripts/ci-dry-run-mig.sh` (fresh DB) | 1 (before fix) | `relation "bills" does not exist` — locale sort placed V001b before V001__core_schema |
| same after `LC_ALL=C` | 0 | `ALL_MIGRATIONS_LOAD_OK`, 374 files including procedures.sql |
| `TEST_PG_CONN=... bash scripts/ci-migration-verification.sh` | 1 → 0 | two CI flag errors fixed (`-m`, `--color`); final run: 10 examples, 0 failures |
| `stack test` | 0 | 1272 examples, 0 failures, 4 pending |

Throwaway database `surypus_mig_probe` was created and dropped; no user data
was touched. HLint reports 2 pre-existing parse errors in unrelated files; the
script records them and continues, as before.


## Cycle 7 (2026-11-27)

| Command | Exit | Result |
|---|---|---|
| `psql "postgresql:///surypus?host=/var/run/postgresql&user=dominicusin" -c 'select 1'` | 0 | peer-auth role works |
| `SURYPUS_TEST_DATABASE_URL=... stack test` | 0 | **1273 examples, 0 failures, 2 pending**; RBAC and event-store integration ran |
| `stack test` (no DB URL) | 0 | 1267 examples, 0 failures, 4 pending |
| `bd close Surypus-38p` / `bd dolt push` | 0 | closed; Push complete |


## Cycle 6 (2026-11-27)

| Command | Exit | Result |
|---|---|---|
| `bd update Surypus-6ob --claim` | 0 | status `in_progress` |
| `stack test` | 0 | **1266 examples, 0 failures, 3 pending** |
| `bd close Surypus-6ob` | 0 | status `closed` |
| `bd dolt push` | 0 | `Push complete.` |

Build errors during implementation (fixed and re-run): hidden modules
`Crypto.Hash.SHA256` / `Data.ByteArray` (added `memory`, removed SHA import),
and `AuthTag` requiring `BA.Bytes` rather than strict `ByteString`.


## Cycle 5 (2026-11-27)

| Command | Exit | Result |
|---|---|---|
| `dolt clone https://doltremoteapi.dolthub.com/dominicusin/Surypus-bd` | 0 | 5297 chunks, 104 issues, schema v66 |
| `bd ready --json` (after DB placed in `.beads/dolt/Surypus`) | 0 | works; stale Dolt servers had to be stopped first |
| `bd migrate schema` | 0 | `Schema already at v66` |
| `bd create` ×5 | 0 | issues `9c2`, `6ob`, `38p`, `bnj`, `1vn` created |
| `bd update Surypus-9c2 --claim` | 0 | status `in_progress` |
| `stack test` | 0 | **1263 examples, 0 failures, 3 pending** |
| `bd close Surypus-9c2` | 0 | status `closed` |
| `bd dolt push` | 0 | `Push complete.` |

Note: `bd bootstrap` still fails because it uses the DoltHub web URL with the
old dolt 2.4.2 client (`rpc error: code = Unimplemented`). The API endpoint
`doltremoteapi.dolthub.com` works; this is the recovery procedure.


## Bootstrap import (2026-11-27)

- Archive `surypus-hermes-bootstrap.zip`: integrity verified with `unzip -t`
  (9 entries, no errors); files listed above were imported.
- The archive claims a GitHub integration write returned HTTP 403. That is the
  archive author's record; I did not reproduce it and make no claim about it.
- `bd ready --json` → error: `database "Surypus" not found on Dolt server at
  127.0.0.1:38891`. `bd doctor` → 71 passed, 13 warnings, 3 errors. Beads was
  therefore unusable as the task tracker in this session.
- `git merge origin/main` → conflict in `HERMES.md` (add/add); resolved by
  taking main's version, commit `696c412`.
- `bd bootstrap` → `Bootstrap failed: clone from remote via server ... rpc
  error: code = Unimplemented`. `bd init --reinit-local --from-jsonl`
  (isolated copy) → refused: remote has Dolt history; `--discard-remote`
  required. Destructive reinit not executed; Beads recorded as BLOCKED.

All commands in the clean worktree at
`/home/dominicusin/.hermes/cache/scratch/surypus-audit`.

## Cycle 4 (2026-11-27)

| Command | Exit | Result |
|---|---|---|
| `stack test` (after S-05) | 0 | **1260 examples, 0 failures, 3 pending** |

## Cycle 3 (2026-11-27)

| Command | Exit | Result |
|---|---|---|
| `stack test` (after S-09) | 0 | **1258 examples, 0 failures, 3 pending** |
| `sudo -u postgres psql -d surypus` permission-SQL probe | 0 | viewer + `read:persons` → `t`; viewer + `delete:persons` → `f`; unknown user → `f`. All inserts rolled back. |

First attempt failed to compile (`putMVar resume` missing its unit argument);
fixed and re-run. The two-thread interleaving test asserts tenant 1 and tenant
2 contexts are simultaneously distinct.

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
