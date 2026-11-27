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
- **Decision:** Do not invent Beads IDs or claim task state. Keep
  `NEXT_ACTIONS.md` as the handoff record required by `HERMES.md` §16, explicitly
  marked as not a task tracker.
- **Evidence:** command output recorded in `VERIFICATION_LOG.md`.
- **Consequences:** task IDs must be reconciled with Beads once Dolt is healthy.

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