# Surypus Hermes Session Bootstrap

Read this at the beginning of every session.

## Mandatory start-up sequence

1. Read `HERMES.md` (persistent engineering policy).
2. Read `AGENTS.md` (repository conventions, language constraints, Beads workflow).
3. Read `docs/engineering/AUTONOMOUS_PROGRESS.md`.
4. Read `docs/engineering/VERIFICATION_LOG.md`.
5. Read `docs/engineering/DEBT_REGISTER.md` and `DECISIONS.md`.
6. Check Git status, branch, recent commits, and uncommitted work.
7. Inspect Beads using `bd ready --json`, `bd list --json`, and relevant issue detail commands supported by the installed version. Beads is the primary task tracker; do not create a competing markdown backlog.
8. Verify persisted claims against source and CI evidence. Historical notes are pointers, not truth.
9. Select the highest-priority unblocked task; claim it in Beads before starting if supported.
10. Implement, verify, update Beads, and persist state.

## Source-of-truth precedence

1. Explicit repository-owner instruction in the current task
2. `AGENTS.md` repository-specific requirements (including Beads as the sole task tracker)
3. `HERMES.md` engineering policy
4. This bootstrap
5. Progress notes and historical reports

Progress files are handoff/evidence records, not a replacement for Beads. Keep task summaries synchronized without creating duplicate task IDs.


## Session end / interruption protocol

Before yielding, update `AUTONOMOUS_PROGRESS.md` and `VERIFICATION_LOG.md`. Update debt and decision records only when evidence or decisions warrant it. Record active Beads issue, branch, changed paths, checks actually run, failures, and next action. Commit and push per repository policy, after checking for unrelated/user changes.


## Autonomy

Continue safe, reversible work without approval loops. Request owner input only for destructive/irreversible operations, production-impacting actions, credentials, paid services, significant breaking changes, or unresolved product decisions. If blocked, continue independent safe work.


## Evidence discipline

Never claim tests, builds, remote writes, deployments, commits, pushes, or verification unless they completed and their result was checked. Mark unknowns `UNVERIFIED`.