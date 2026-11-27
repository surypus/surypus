# Recovery point

This file is a **state/recovery record**, not a task tracker. Per `AGENTS.md`,
Beads (`bd`) is the single source of task IDs, priorities, dependencies and
status. Work items below are descriptions only; they are not backlog IDs and
must be created as Beads issues once Beads is healthy.

## Session state (2026-11-27)

- Branch: `autonomous/audit-2026-11-27`
- HEAD: `1af94cf` (after merge `696c412` adopting main's canonical `HERMES.md`)
- Working tree: clean at last check
- Verification: `stack test` → 1260 examples, 0 failures, 3 pending

## Beads blocker

`bd ready --json` fails: `database "Surypus" not found on Dolt server`.
`bd bootstrap --dry-run` plans a clone from
`https://www.dolthub.com/repositories/dominicusin/Surypus-bd`; the real clone
fails with `rpc error: code = Unimplemented`. `bd init --reinit-local
--from-jsonl` refuses because the remote has Dolt history and requires the
destructive `--discard-remote` workflow. No task was claimed and no Beads ID
was invented.

## Where work stopped

Completed and committed in this branch: fail-closed authorization middleware;
real DB-backed permission check; real API server wired into the executable;
per-thread tenant context; unique event IDs; bootstrap documents imported.
Details and evidence are in `AUTONOMOUS_PROGRESS.md` and `VERIFICATION_LOG.md`.

## Next action (not a task ID)

Create Beads issues for the remaining work, then claim the highest-priority
one. Once Beads is available, the first candidates to register are: verification
of the permission query through the Haskell pool (needs a DB role or
`SURYPUS_TEST_DATABASE_URL`), replacement of `DAL.Queue.processJob` stubs,
plaintext secrets in `System.Secrets`, and the competing migration corpora.
Do not treat this paragraph as a queue.
