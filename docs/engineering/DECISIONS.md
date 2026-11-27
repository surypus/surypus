# Engineering Decisions

## DEC-001 — Persistent Hermes engineering policy

- **Date:** 2026-11-27
- **Context:** Engineering behavior and continuity need to persist across agent sessions.
- **Decision:** Use `HERMES.md` as repository engineering policy and `.hermes/BOOTSTRAP.md` as the mandatory session-start entry point. Keep durable recovery state in `docs/engineering/`.
- **Task tracking:** Beads (`bd`) is the primary source of task IDs, dependencies, and status per existing `AGENTS.md`. Markdown engineering state files are handoff/evidence records only, not a competing backlog.
- **Alternatives:** Markdown-only task backlog; session prompts without repository persistence.
- **Consequences:** Hermes must reread policy and recovery state each session, verify historical claims, and synchronize task references with Beads.
- **Status:** Active.

## DEC-002 — Adopt canonical HERMES.md from main

- **Date:** 2026-11-27
- **Context:** Upstream `main` added `0a20715` (1133-line `HERMES.md`) while
  this branch had created a shorter local policy document. The merge produced
  an add/add conflict.
- **Decision:** Keep main's canonical policy; discard the local variant.
- **Evidence:** merge commit `696c412`; conflict resolved with main's version.
- **Consequences:** one authoritative policy file; bootstrap precedence
  (owner > AGENTS.md > HERMES.md) is preserved.

## DEC-003 — Beads unavailable; markdown files are handoff records only

- **Date:** 2026-11-27
- **Context:** `AGENTS.md` requires Beads as sole tracker, but `bd ready --json`
  failed with `database "Surypus" not found on Dolt server`; `bd doctor`
  reported 3 errors and pointed at another clone's `.beads`.
- **Decision:** Beads remains the sole source of task IDs, priorities,
  dependencies and status. Markdown engineering files are recovery and
  reporting records only; they must not carry a competing queue of task IDs.
  `NEXT_ACTIONS.md` was rewritten as a recovery point with no task IDs.
- **Evidence:** command output recorded in `VERIFICATION_LOG.md`.
- **Consequences:** work descriptions in Markdown are pointers, not backlog
  entries; they are registered as Beads issues once Beads is healthy.

## DEC-004 — Fail-closed authorization and per-thread tenant context

- **Date:** 2026-11-27
- **Context:** Unmapped routes were allowed by middleware; permission repository
  returned `True` unconditionally; tenant context was a global IORef.
- **Decision:** Deny unmapped routes, make the DB permission store the sole
  authority, and key tenant context by `ThreadId` with exception-safe restore.
- **Alternatives:** keep compatibility fallbacks; rely on API middleware only.
- **Consequences:** some previously "working" routes now require a real grant;
  this is intentional. Verified by 16 auth, 13 permission and 4 tenant tests.
- **Status:** Active.

## DEC-005 — No destructive Beads reinitialisation without owner approval

- **Date:** 2026-11-27
- **Context:** The local Dolt database `Surypus` is absent. `bd bootstrap`
  failed to clone the DoltHub remote (`rpc error: code = Unimplemented`), and
  `bd init --reinit-local --from-jsonl` refuses without `--discard-remote`,
  which would overwrite remote Dolt history.
- **Decision:** Do not run the destructive reinit. Record Beads as BLOCKED;
  keep autonomous work limited to safe, reversible changes and recovery-state
  updates.
- **Alternatives:** discard remote history (destructive, externally
  consequential) — requires owner approval; wait for DoltHub access to recover.
- **Evidence:** command output in `VERIFICATION_LOG.md`.
- **Status:** RESOLVED cycle 5 — no destructive reinit was needed. The
  DoltHub API endpoint clone succeeded and `bd dolt push` completed.
