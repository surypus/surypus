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
| 01-01-01 | 01-01 | 1 | BOOT-01 | T-01-01 | Serve: `stack run` поднимает Warp; probe не печатает DSN | smoke (server) | `stack build --test --no-run-tests && ./scripts/smoke-health.sh` | ✅ | ⬜ pending |
| 01-01-02 | 01-01 | 1 | BOOT-02 | T-01-05 | Health JSON константен `{"status","db"}`, без утечки | integration | `stack test --test-arguments "--match API.Health"` | ✅ | ⬜ pending |
| 01-01-03 | 01-01 | 1 | BOOT-01 | T-01-08 | Fail-fast: все пропуски перечислены, секреты не в тексте | unit (config) | `stack test --test-arguments "--match Surypus.Config"` | ✅ | ⬜ pending |
| 01-02-01 | 01-02 | 2 | BOOT-03 | T-01-02 | Pre-flight strict grammar, без SQL-конкатенации имён | unit | `stack build --test --no-run-tests && TEST_URL=$(./scripts/create_test_db.sh) && DATABASE_URL="$TEST_URL" SURYPUS_JWT_SECRET=test-only stack run -- migrate --dir test/fixtures/migrations && test "$(psql "$TEST_URL" -tAc 'SELECT count(*) FROM surypus_schema_migrations' | tr -d ' ')" = "2"` | ✅ | ⬜ pending |
| 01-02-02 | 01-02 | 2 | BOOT-03 | T-01-03 | Advisory lock не блокирует (`pg_try_advisory_lock`) | integration | `stack test --test-arguments "--match DB.MigrationRunner" 2>&1 | tee /tmp/migration-runner.log && grep -Eq '[1-9][0-9]* examples?, 0 failures' /tmp/migration-runner.log` | ✅ | ⬜ pending |
| 01-02-03 | 01-02 | 2 | BOOT-03 | T-01-04 | Checksum mismatch до DDL, откат применения файла | integration | `stack test --test-arguments "--match DB.MigrationRunner" 2>&1 | tee /tmp/migration-runner-int.log && grep -Eq '[1-9][0-9]* examples?, 0 failures' /tmp/migration-runner-int.log && ! grep -rn "runMigrations" src app` | ✅ | ⬜ pending |
| 01-03-01 | 01-03 | 3 | BOOT-04 | T-01-04 | Canonical corpus воспроизводим одной командой | integration | `TEST_URL=$(./scripts/create_test_db.sh) && DATABASE_URL="$TEST_URL" SURYPUS_JWT_SECRET=test-only stack run -- migrate && DATABASE_URL="$TEST_URL" SURYPUS_JWT_SECRET=test-only stack run -- migrate && DATABASE_URL="$TEST_URL" ./scripts/verify-schema.sh` | ✅ | ⬜ pending |
| 01-03-02 | 01-03 | 3 | BOOT-04 | T-01-03 | DB.Schema консистентен с применяемым корпусом | integration | `stack test --test-arguments "--match DB.Schema" 2>&1 | tee /tmp/schema-spec.log && grep -Eq '[1-9][0-9]* examples?, 0 failures' /tmp/schema-spec.log` | ✅ | ⬜ pending |
| 01-03-03 | 01-03 | 3 | BOOT-04 | T-01-SC | Нет второго пути миграций (`config/migrations` запрещён, runner — канон) | docs/shell | `! grep -n "config/migrations" AGENTS.md && grep -q "stack run -- migrate" AGENTS.md && test "$(ls sql/migrations/*.sql | wc -l)" -eq 2` | ✅ | ⬜ pending |
| 01-04-01 | 01-04 | 1 | BOOT-06 | T-01-SC | Toolchain pinned в пяти источниках, drift = красный билд | shell | `./scripts/check-toolchain.sh && stack build --test --no-run-tests` | ✅ | ⬜ pending |
| 01-04-02 | 01-04 | 1 | BOOT-06 | T-01-SC | CI/compose/Dockerfile/devcontainer без floating версий | shell | `./scripts/check-toolchain.sh` | ✅ | ⬜ pending |
| 01-04-03 | 01-04 | 1 | BOOT-06 | T-01-04 | Тестовая БД через `create_test_db.sh`, compose floor `postgres:16` | integration | `TEST_URL=$(./scripts/create_test_db.sh) && psql "$TEST_URL" -tAc "SELECT 1" | grep -qx 1 && ./scripts/check-toolchain.sh` | ✅ | ⬜ pending |
| 01-05-01 | 01-05 | 4 | BOOT-05 | T-01-07 | Ни один workflow/скрипт не проглатывает ошибку, ни тихого pending | CI | `./scripts/ci-local.sh` | ✅ | ⬜ pending |
| 01-05-02 | 01-05 | 4 | BOOT-05 | T-01-07 | DB-спеки выполняются, не pending; EventStoreSpec зарегистрирован | integration | `CI=true stack test --test-arguments "--match DB.EventStore" 2>&1 | tee /tmp/db-eventstore.log && grep -Eq '[1-9][0-9]* examples?, 0 failures' /tmp/db-eventstore.log && ! grep -Eq '[1-9][0-9]* pending' /tmp/db-eventstore.log` | ✅ | ⬜ pending |
| 01-05-03 | 01-05 | 4 | BOOT-05 | T-01-06 | `make migrate` через canonical runner; README/docs/API синхронны | shell | `./scripts/check-no-swallowed-errors.sh && TEST_URL=$(./scripts/create_test_db.sh) && DATABASE_URL="$TEST_URL" SURYPUS_JWT_SECRET=test-only make migrate` | ✅ | ⬜ pending |

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
