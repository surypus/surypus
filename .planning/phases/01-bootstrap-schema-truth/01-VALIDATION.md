---
phase: "1"
slug: "bootstrap-schema-truth"
status: draft
nyquist_compliant: false
wave_0_complete: false
created: "2026-10-23"
---

# Phase 1 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | hspec 2.11.8 + QuickCheck (existing `surypus-test` suite) |
| **Config file** | none — `test/Test.hs` is the aggregate `main` |
| **Quick run command** | `stack test --test-arguments "--match <Module>"` |
| **Full suite command** | `stack test` (DB specs need `SURYPUS_TEST_DATABASE_URL`) |
| **Estimated runtime** | ~120 s full suite; ~10 s per matched spec |
| **Measured baseline** | `1010 examples, 0 failures, 3 pending` (2026-10-23) |

---

## Sampling Rate

- **After every task commit:** `stack build --test --no-run-tests` plus `stack test --test-arguments "--match <module>"`
- **After every plan wave:** `stack test` against real PostgreSQL (`SURYPUS_TEST_DATABASE_URL` set)
- **Before `/gsd-verify-work`:** full suite green + `stack run -- migrate` on a fresh DB + `curl -f /api/v1/health`
- **Max feedback latency:** 120 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 01-01-01 | 01 | 1 | BOOT-06 | — | Toolchain pinned in all five sources; no floating resolver | unit (shell) | `./scripts/check-toolchain.sh` | ❌ W0 | ⬜ pending |
| 01-02-01 | 02 | 1 | BOOT-01 | T-01-01 | Missing env vars are named in the failure message; secrets never logged | unit | `stack test --test-arguments "--match Surypus.Config"` | ❌ W0 | ⬜ pending |
| 01-02-02 | 02 | 1 | BOOT-01 | — | `PORT` parses; invalid port fails fast | unit | same spec | ❌ W0 | ⬜ pending |
| 01-03-01 | 03 | 2 | BOOT-03 | T-01-02 | Path traversal rejected; filename whitelist enforced | unit | `stack test --test-arguments "--match MigrationRunner"` | ❌ W0 | ⬜ pending |
| 01-03-02 | 03 | 2 | BOOT-03 | — | Duplicate numeric prefix fails pre-flight without touching DB | unit | same spec | ❌ W0 | ⬜ pending |
| 01-03-03 | 03 | 2 | BOOT-03 | T-01-03 | Re-run is a no-op; edited applied file fails with checksum message | integration | same spec (live DB) | ❌ W0 | ⬜ pending |
| 01-03-04 | 03 | 2 | BOOT-03 | T-01-04 | Concurrent run fails on advisory lock (no blocking lock) | integration | same spec (two connections) | ❌ W0 | ⬜ pending |
| 01-04-01 | 04 | 3 | BOOT-04 | — | Empty DB builds from canonical corpus in one command | integration | `stack run -- migrate` on scratch DB | ❌ W0 | ⬜ pending |
| 01-04-02 | 04 | 3 | BOOT-04 | — | `bills`/`payments`/`accounts` expose the columns the ORM writes | integration | `information_schema.columns` assertions | ❌ W0 | ⬜ pending |
| 01-05-01 | 05 | 3 | BOOT-02 | T-01-05 | Health body is constant; no driver text or DSN leaked | integration | `stack test --test-arguments "--match Health"` | ❌ W0 | ⬜ pending |
| 01-05-02 | 05 | 3 | BOOT-02 | — | 200 when DB reachable, 503 when pool points at closed port | integration | same spec (`port=1` case) | ❌ W0 | ⬜ pending |
| 01-06-01 | 06 | 4 | BOOT-05 | — | CI job starts real PostgreSQL, migrates, runs DB specs (none pending) | CI | workflow run | ⚠️ misconfigured | ⬜ pending |
| 01-06-02 | 06 | 4 | BOOT-01 | — | `stack run` binds `PORT`, `curl -f /api/v1/health` succeeds | smoke (CI) | `stack run &` + `curl -f` | ❌ W0 | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `test/Surypus/ConfigSpec.hs` — env contract (BOOT-01, BOOT-06). Note: `test/ConfigSpec.hs` already exists for `Surypus.Domain.Config.Config`; do not overwrite it.
- [ ] `test/API/HealthSpec.hs` — 200/503, no exception leakage (BOOT-02)
- [ ] `test/DB/MigrationRunnerSpec.hs` — pure pre-flight cases + live-DB integration (BOOT-03, BOOT-04)
- [ ] `test/Test.hs` — register the three new specs
- [ ] `Surypus.cabal` — add `DAL.EventStoreSpec` to `surypus-test` `other-modules` (file exists, cabal entry does not)
- [ ] `scripts/check-toolchain.sh` — five toolchain sources agree (BOOT-06)
- [ ] CI — PostgreSQL service in `ci.yml`, both `DATABASE_URL` and `SURYPUS_TEST_DATABASE_URL`, `migrate` before `stack test`
- [ ] Scratch-database provisioning helper so migration tests never depend on leftover state

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Startup message readability on missing env | BOOT-01 | Wording quality is a judgement, not an assertion | Unset `DATABASE_URL`, run `stack run`, confirm the message names every missing variable and contains no DSN |
| Fresh-clone bootstrap following README | BOOT-04 / BOOT-06 | Verifies docs and code agree on the actual commands | In a clean clone: `stack build`, `stack run -- migrate`, `stack run`, open `/api/v1/health` |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 120s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
