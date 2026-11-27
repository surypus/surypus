# Hermes persistent engineering policy — Surypus

This file is the standing policy for every autonomous engineering session on
this repository. Read it before touching code. Records are in
`docs/engineering/`; the current worktree is the source of truth for state.

## Session protocol

1. Read this file, `docs/engineering/AUTONOMOUS_PROGRESS.md` and
   `docs/engineering/NEXT_ACTIONS.md`.
2. Inspect Git state and re-verify persisted claims with a real command. A
   claim from a previous session is a hypothesis until re-run.
3. Resume unfinished work. Do not restart planning from scratch.
4. Pick the highest-priority actionable task, implement the smallest complete
   solution, add tests, run them, review the diff, document, commit.
5. Update the persistent state documents before ending or yielding.

## Priorities

P0 security, financial correctness, data loss, tenant isolation, broken
critical flows, migrations. P1 reliability and missing integration tests.
P2 maintainability and performance. P3 new domains.

## Engineering rules

- Evidence over assertion: locate the file, inspect it, check production use,
  find the test, run it, record the exit code.
- Status vocabulary: VERIFIED, IMPLEMENTED, PARTIAL, STUB, BROKEN,
  UNVERIFIED, BLOCKED.
- Never report a stub as complete, never weaken a test to get green, never
  fabricate results, commits or CI status.
- Fail closed on authorization and tenant boundaries. No hardcoded allow
  fallbacks; permission checks are parameterised and DB-backed.
- Prefer the smallest safe correction over a rewrite.
- Do not commit with failing or uncollected checks.
- Do not force-push, rewrite protected history, delete user data or rotate
  production credentials without owner approval. Pushing a feature branch,
  opening a PR, installing dependencies and running the test suite are routine.
- Never ask a user to paste a secret in chat. Use the vault.

## Verification gates

`stack test` (GHC 9.6.5 via Stack; the system GHC 9.10.3 package db is broken).
Integration suites need `SURYPUS_TEST_DATABASE_URL` / `SURYPUS_TEST_REDIS_URL`;
when absent they are pending, not passing.

## Current state pointer

See `docs/engineering/audit/BASELINE.md` for measured facts and
`docs/engineering/VERIFICATION_LOG.md` for exact commands and exit codes.
