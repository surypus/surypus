# Phase 1: Bootstrap & Schema Truth — Research

**Researched:** 2026-10-23
**Domain:** Haskell service bootstrap + PostgreSQL schema reconstruction
**Confidence:** HIGH for repo facts, MEDIUM for runner/library choice, MEDIUM for env-contract details

<phase_requirements>

## Phase Requirements

| ID | Description (verbatim from REQUIREMENTS.md) | Research Support |
|----|---------------------------------------------|------------------|
| BOOT-01 | Сервер запускается: `app/Main.hs` читает конфигурацию из env, собирает пул соединений и поднимает Warp на настраиваемом порту | §Server Bootstrap; `apiServer` signature pinned; `Surypus.DB.Pool.mkDBConfig` must be exported; `app/Main.hs` is 7 lines of `putStrLn` today |
| BOOT-02 | `GET /api/v1/health` возвращает 200 и отражает реальное состояние БД, а не константу | §Health Endpoint; current handler returns a constant; `/health/db` throws instead of 503 |
| BOOT-03 | Миграции применяются одним каноническим runner'ом с checksum-леджером и advisory lock; повторный запуск идемпотентен | §Migration Runner; library + pre-flight + lock design |
| BOOT-04 | Дублирующиеся префиксы миграций разрешены, сборка схемы с нуля на пустой БД проходит; существующие V001/V256-конфликты `bills`/`accounts`/`payments` закрыты forward-миграцией | §Migration Corpus Audit (measured 329/359 apply, 30 fail); §Canonical Corpus Policy; §bills/accounts/payments reconciliation table |
| BOOT-05 | CI поднимает реальный PostgreSQL, применяет миграции и гоняет `stack test` — без `pendingWith` на ключевых тестах | §Validation Architecture; measured baseline `1010 examples, 0 failures, 3 pending`; env-var mismatch found |
| BOOT-06 | Один тулчейн (GHC 9.6.5 / LTS 22.21) во всех конфигурациях: `stack.yaml`, `cabal.project`, Dockerfile, devcontainer, CI | §Toolchain Truth; five sources audited, three are wrong |

</phase_requirements>

## Project Constraints (from AGENTS.md)

These have the same authority as locked decisions. The planner must not produce tasks that violate them.

| Directive | Consequence for Phase 1 |
|-----------|-------------------------|
| **Haskell is the project language.** Agda/Coq/Idris/Souffle/Datalog/Prolog allowed; OCaml/Clojure only as last resort; **no other languages without explicit approval** | The migration runner, config loader and toolchain check must be Haskell (`scripts/check-toolchain.sh` is shell, which is acceptable as tooling, not as application code) |
| Build with `stack build`; test with `stack test`; targeted runs via `--match` | CI and plans use stack only; do not introduce cabal as a build path |
| Haskell2010, `-Wall`, 2-space indent, 100-col lines | New modules must compile warning-free under the existing `-Wall` |
| Use `Text` not `String` for user data; `Int64` for database IDs; no `undefined` | Reinforces the BIGINT tenant decision |
| Hspec for unit tests, QuickCheck for properties | New specs follow the existing `spec :: Spec` pattern registered in `test/Test.hs` |
| `bd` (beads) is the only issue tracker; **no markdown TODO lists** | Plans must not create TODO files; discovered work becomes `bd create` |
| Haddock + doctest for public API changes; regenerate module graph; `mkdocs build --strict` must pass | New public modules (`Surypus.Config`, `Surypus.DB.Migrate`) need Haddock headers; `mkdocs build --strict` is a phase-gate step |
| Never commit secrets; `.env.example` holds placeholders only | `SURYPUS_JWT_SECRET` must have no committed value; CI uses a dummy value |
| Session end requires `git push` to succeed | Applies to the executor, not the planner |

**Conflict to resolve inside this phase:** AGENTS.md documents migrations at `config/migrations/V001…V010`. That directory **does not exist** (`ls config/migrations` → no such file or directory); the real corpus is `sql/migrations/`. The phase must update AGENTS.md rather than create a second migration directory.

## Summary

Phase 1 exists because the repository currently **cannot** back any claim about behaviour with a reproducible database. The server executable is a two-line `putStrLn`; the health endpoint is a constant `200`; `sql/migrations/` is a 359-file corpus that does **not** build a working schema on an empty database; and the compiled Haskell code is written against table shapes that no migration produces.

Three measurements taken in this session define the phase:

1. `stack build --test --no-run-tests` **succeeds** and `stack test` **passes** with `1010 examples, 0 failures, 3 pending`. The tree is currently buildable — but only with uncommitted local edits to `src/` and `test/` present. Phase 1 must not assume the committed tree is green.
2. Applying every file in `sql/migrations/` to a **fresh** PostgreSQL 18 database with `psql -v ON_ERROR_STOP=1 --single-transaction` yields **329 applied / 30 failed**. The corpus is not a build, it is an accumulation.
3. The ordering used by every existing script (`ls | sort`) is **lexicographic**, so `V1000`…`V1009` execute *between* `V100` and `V101` — the event-store schema is created before the migrations that assume the older event-store shape.

The single highest-leverage decision is therefore **not** "write a better runner". It is **quarantine the legacy corpus and publish a small canonical one**, then point one runner at it. A perfect runner over 359 unreconciled files still produces a schema that does not match the code.

**Primary recommendation:** Move `sql/migrations/*.sql` to `sql/archive/legacy-migrations/`, create a canonical `sql/migrations/` containing `V001__bootstrap.sql` (full final shape, `CREATE TABLE IF NOT EXISTS`) and `V002__schema_truth_forward.sql` (idempotent `ALTER TABLE … ADD COLUMN IF NOT EXISTS` reconciliation for pre-existing databases), and drive it with a `migrate` subcommand of the existing `surypus-server` executable built on `postgresql-migration-0.2.1.8` (checksum ledger, per-step transactions, already in LTS 22.21) plus a pre-flight duplicate/naming check and `pg_try_advisory_lock`.

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Env loading + fail-fast validation | Process bootstrap (`app/Main.hs` + `Surypus.Config`) | — | Nothing else may read env for required settings; one `Config` record flows down |
| Connection-pool lifecycle | Process bootstrap | Database | `Surypus.DB.Pool` owns creation/teardown; `warp` shutdown must close it |
| HTTP serving | HTTP / WAI (`warp` + `servant-server`) | — | Already implemented in `Surypus.API.Server`; Phase 1 only wires it |
| Health / readiness | HTTP handler | Database | Handler must *probe* the DB; DB itself owns truth about availability |
| Schema versioning + migration execution | Ops / CLI (`migrate` subcommand) | Database (advisory lock, DDL, ledger) | Migration is an operational action, not a request path; never auto-run on boot |
| Migration corpus (DDL truth) | Database | — | SQL files are the only source of schema truth; no ORM auto-migration |
| Toolchain pinning | Build / CI | — | A single version must be asserted by a script, not by documentation |
| Test database lifecycle | CI | Ops scripts | CI creates the DB, runs the same runner, then runs `stack test` |

## Migration Corpus Audit

### Inventory

`sql/migrations/` contains **359 `V*.sql` files** plus `init_db.sh` (360 directory entries) [VERIFIED: `ls sql/migrations | wc -l`].

Duplicate numeric prefixes (normalised: leading zeros ignored, so `V001` and `V1` collide) [VERIFIED: `ls | sed -E 's/^(V[0-9]+[a-z]?)__.*/\1/' | sort | uniq -d`]:

| Prefix | Files |
|--------|-------|
| `V001` | `V001__core_schema.sql`, `V001__generated_orm.sql` |
| `V1005` | `V1005__event_store_snapshots.sql`, `V1005__payroll_results.sql` |
| `V180` | `dashboard_kpi_views`, `distributed_cache` |
| `V181` | `crm_schema`, `sharding_strategy` |
| `V182` | `crm_companies_contacts`, `intelligent_retry`, **`notifications`** (three files) |
| `V183` | `circuit_breaker`, `orders` |
| `V184` | `bulk_operations`, `documents` |
| `V185` | `audit_comprehensive`, `crm_rbac_permissions` |
| `V186` | `crm_event_sourcing`, `multi_tenant_isolation` |
| `V187` | `bank_statement_import`, `data_lineage` |
| `V188` | `integration_config`, `time_travel` |
| `V189` | `final_system_check`, `integration_health` |
| `V347` | `V347__consolidated.sql`, `V347a__rbac_stubs.sql` |

A second corpus exists outside the runner's view: `sql/event/`, `sql/core/`, `sql/aggregate/`, `sql/projection/`, `sql/procedures/`, `sql/seeds/`, `sql/test/`. `V100__event_sourcing_init.sql:2-9` states that the event-sourcing schema is applied by those files and that `V100` only verifies it — but no runner in the repo ever applies them from that directory.

### Measured empty-database build

Method: fresh database `surypus_probe2` on PostgreSQL 18.6; each file applied in sorted order with `psql -v ON_ERROR_STOP=1 --single-transaction -f <file>` (i.e. **strictly better** than every existing script, which omits `ON_ERROR_STOP`).

Result: **329 succeeded, 30 failed, 359 total** (`APPLIED=329 FAILED=30`) [VERIFIED: probe run 2026-10-23].

Dominant failures:

| Failure | Files | Root cause |
|---------|-------|------------|
| `column "tenant_id" does not exist` on `event_store` | `V101`, `V106`, `V111`, `V113`, `V114`, `V115`, `V118`, `V120`, `V141`, `V150`, `V151` | `V1000` creates `event_store` without `tenant_id`; `V016`'s RLS loop skips it because the table does not exist yet |
| `event_append function not created` / `event_store table not created` | `V100` | The real DDL is in `sql/event/V001__event_store.sql`, never applied |
| `relation "aggregates" does not exist` | `V129`, `V133`, `V135`, `V156`, `V158`, `V172`, `V179` | `aggregates` lives in `sql/aggregate/V001-V002`, never applied |
| `relation "event_outbox" / "event_dlq" / "projections" / "projection_stock_balance" does not exist` | `V110`, `V125`, `V127`, `V130`, `V258` | Tables are never created by any file in `sql/migrations/` |
| `relation "notification_prefs" does not exist` | `V1003` | Depends on `V182__notifications.sql`, which is shadowed by the duplicate `V182` ordering |
| `function health_record(...) does not exist` | `V168`, `V229` | Cascade from `V130` failing |

A representative error line for the report: `psql:sql/migrations/V101__event_store_indexes.sql:5: ERROR: column "tenant_id" does not exist`.

### Root causes (all reproduced)

1. **Lexicographic ordering.** `ls sql/migrations/V*.sql | sort` places `V1000__event_store_schema.sql` at index 19 and `V100__event_sourcing_init.sql` at index 27 [VERIFIED: `grep -n` over sorted list]. Byte order, not numeric order.
2. **The event-sourcing DDL is in a directory no runner reads.**
3. **Schema drift between `V1000` and `DAL.EventStore`** (missing `event_schema_version`).
4. **Duplicate prefixes** where the second file silently no-ops (`CREATE TABLE IF NOT EXISTS`).
5. **Missing extensions** for quarantined feature files: `postgis` (`V218`), `vector` (`V231`, `V249`) — neither is installed locally.

### Canonical Corpus Policy

**Decision: quarantine + baseline + forward migration.** `repair-all-359` is rejected on the evidence above: it requires reconstructing the event-sourcing stack, resolving 13 duplicate prefixes and re-ordering ~40 files, and it still leaves the ORM-vs-DDL mismatch untouched.

1. `git mv sql/migrations/V*.sql sql/archive/legacy-migrations/` and `git mv sql/migrations/init_db.sh sql/archive/` — untouched content, preserved for reference and old branches.
2. Create `sql/migrations/V001__bootstrap.sql`: the **final** shape, all `CREATE TABLE IF NOT EXISTS`, extensions `pgcrypto` + `uuid-ossp`, `tenant_id BIGINT NOT NULL DEFAULT 0` everywhere.
3. Create `sql/migrations/V002__schema_truth_forward.sql`: only idempotent reconciliation (`ADD COLUMN IF NOT EXISTS`, `CREATE INDEX IF NOT EXISTS`, `CREATE OR REPLACE FUNCTION`), so an existing legacy database converges to the same shape. On a fresh database every statement is a no-op.
4. Naming rule: `^V([0-9]{3,})__([a-z0-9_]+)\.sql$`; numeric ordering by parsed integer; equal numbers are a hard failure.
5. The runner **only** reads `sql/migrations/`; `--dir` may not point outside the repository root.

**Shape reconciliation the canonical pair must settle** (this is BOOT-04's "forward migration" requirement):

| Table | `V001__core_schema` | `V256__domain_organization_final` | What compiled code expects | Canonical decision |
|-------|--------------------|-----------------------------------|----------------------------|--------------------|
| `bills` | `id BIGINT`, `number TEXT UNIQUE`, `date`, `currency`, `total_amount`, `status` [VERIFIED: V001:95-102] | `id UUID`, `tenant_id UUID`, `bill_number`, `bill_date`, `counterparty_id`, `total_amount`, `vat_amount`, `status` [VERIFIED: V256:230-241] | `DAL.MutationsORM:180` → `bill_number, bill_date, customer_id, vendor_id, warehouse_id, currency_id, bill_status, bill_type, subtotal, tax_amount, total_amount, paid_amount, notes, created_at, updated_at`; `Surypus.API.Dashboard:67` → `status`, `total_amount` | Base V001; `ADD COLUMN IF NOT EXISTS` every ORM column plus `tenant_id BIGINT`; legacy columns stay nullable |
| `accounts` | `id BIGINT`, `code TEXT UNIQUE`, `name`, `type`, `currency`, `description`, `is_active`, timestamps [VERIFIED: V001:68-78] | only `chart_of_accounts` (different concept) [VERIFIED: V256:134-143] | no direct SQL in Phase 1 | Keep `accounts`; add `tenant_id BIGINT`; do **not** create `chart_of_accounts` (Phase 3 decision) |
| `payments` | `id BIGINT`, `payment_ref UUID`, `bill_id BIGINT`, `amount`, `status`, `created_at`, `confirmed_at`, `settled_at` [VERIFIED: V001:105-114] | none | `DAL.MutationsORM:363` → `bill_id, amount, payment_date, payment_method, created_at` | `ADD COLUMN IF NOT EXISTS payment_date`, `payment_method`; keep legacy columns |
| `tax_rates` | `code TEXT PRIMARY KEY`, `rate NUMERIC(5,4)`, `effective_from`, `active` [VERIFIED: V001:117-122] | `id SERIAL`, `tenant_id UUID`, `tax_name`, `tax_rate`, `tax_type`, `is_active`, `valid_from`, `valid_to` [VERIFIED: V256:191-202] | Phase 2 owns the money/VAT canon | Keep V001 shape + `tenant_id BIGINT`; do not create the `SERIAL id` variant |
| `event_store` | absent | `V1000` creates 10 columns **without** `event_schema_version` [VERIFIED: V1000:5-16 — `CREATE TABLE IF NOT EXISTS event_store (` through `);`, columns `id, aggregate_id, aggregate_type, event_type, event_version, event_data, event_metadata, sequence_number, occurred_at, created_at`] | `DAL.EventStore:136-145` inserts `aggregate_id, aggregate_type, event_type, event_version, event_schema_version, event_data, event_metadata, sequence_number, occurred_at, created_at` | Canonical table is the code's 10 columns **plus** `tenant_id BIGINT NOT NULL DEFAULT 0` |

## Standard Stack

### Core

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| GHC | 9.6.5 | Compiler | Locked by `stack.yaml` resolver `lts-22.21` [VERIFIED: stack.yaml:1] and by BOOT-06 |
| Stackage LTS | 22.21 | Dependency set | `LTS Haskell 22.21 (ghc-9.6.5)`, published 2024-05-06 [VERIFIED: stackage.org/lts-22.21] |
| stack | 3.7.1 (installed) | Build driver | Only build system actually used by CI and Dockerfile |
| warp | 3.3.31 (LTS) | HTTP server | Already a dependency of the `surypus-server` executable [VERIFIED: Surypus.cabal:455-469] |
| servant-server | 0.20.x | API type-level routing | `apiServer` already defines the whole API; do not replace it in Phase 1 |
| persistent + persistent-postgresql | 2.14.x / 2.13.x | App data access | Existing library dependency; `apiServer` takes a `ConnectionPool` from it |
| postgresql-migration | 0.2.1.8 | Migration executor + checksum ledger | In LTS 22.21 [VERIFIED: stackage snapshot lts-22.21]; MD5 checksum of every applied script, `schema_migrations` ledger, per-step transactions [CITED: hackage.haskell.org/package/postgresql-migration-0.2.1.8] |
| postgresql-simple | 0.7.0.0 | Connection + ledger queries for the runner | Transitive dependency of `persistent-postgresql`; in LTS 22.21 [VERIFIED: stackage snapshot lts-22.21]; `withTransaction` documented [CITED: hackage.haskell.org/package/postgresql-simple-0.7.0.0] |
| optparse-applicative | 0.18.1.0 | `migrate` subcommand parsing | In LTS 22.21 [VERIFIED: stackage snapshot lts-22.21]; avoids hand-parsing `getArgs` |

### Supporting

| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| hspec | 2.11.8 | Test framework | All phase tests; already the project standard [VERIFIED: stackage snapshot lts-22.21; Surypus.cabal:546 — `, hspec` in `surypus-test` build-depends] |
| resource-pool | 0.4.0.0 | Pool underneath persistent | Do not touch directly; `Surypus.DB.Pool.closePool` already wraps it |
| cryptonite | 0.30 | (optional) SHA-256 if the team rejects MD5 | Only if the ledger checksum must be SHA-256; otherwise use the library's MD5 |
| psql (client) | 15+ | CI/debug only | Never the production migration path after Phase 1 |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| `postgresql-migration` | Hand-written runner on `postgresql-simple` | `postgresql-simple.execute_` cannot run a multi-statement `.sql` file (libpq `PQexecParams` path). Hand-writing a splitter is the single most error-prone part of a runner (dollar-quoted `DO $$ … $$`, strings, `COPY`). Rejected. |
| `postgresql-migration` | `psql -f` per file | Works (and is what the repo does today) but the advisory lock lives in a different session per file and error reporting is stderr text. Rejected as the production path; acceptable inside CI setup only. |
| `postgresql-migration` | `persistent`'s `runMigration` (`src/Surypus/DB/Schema.hs:115`) | Dead TH-based path, no ledger, no checksums, and it describes an ORM subset, not the real schema. Rejected. |
| Canonical baseline + forward migration | Repair all 359 files | Measured: 30 hard failures and multiple silent `CREATE TABLE IF NOT EXISTS` no-ops. Would require rewriting the event-sourcing stack. Rejected; document as rejected. |
| `BIGINT` tenant ids | `UUID` tenant ids | 115 migration occurrences vs 4, and *all* compiled Haskell uses `Int64`. Choosing UUID would require rewriting `DAL.Database`, JWT claims, and `MultiTenancy/*` in Phase 1. Rejected. |

**Installation:**

No package install step — all three are in LTS 22.21, so no `extra-deps` entry is needed. Edit `Surypus.cabal`:

```cabal
-- library (`surypus`) build-depends
    , postgresql-migration >=0.2 && <0.3
    , postgresql-simple    >=0.7 && <0.8
    , optparse-applicative >=0.18 && <0.19

-- executable `surypus-server` build-depends
    , optparse-applicative >=0.18 && <0.19
```

The executable's current `build-depends` is `base, Surypus, wai, wai-extra, warp, aeson, text, bytestring, http-types, time, directory, filepath, Decimal, network` [VERIFIED: Surypus.cabal:455-469] — it depends on the library, so only the parser package must be added there. (Alternative that adds nothing to the executable: put the whole `ParserInfo` in `Surypus.CLI` and expose `parseCommand :: IO Command`; then the parser dependency stays inside the library.)

## Package Legitimacy Audit

The GSD package-legitimacy seam (`query package-legitimacy check`) supports npm/PyPI/crates only and **cannot** be applied to Haskell packages. Verification below was performed against the Stackage LTS 22.21 snapshot YAML (`raw.githubusercontent.com/commercialhaskell/stackage-snapshots/master/lts/22/21.yaml`) and Hackage.

| Package | Registry | In LTS 22.21 | Source Repo | Verdict | Disposition |
|---------|----------|--------------|-------------|---------|-------------|
| `postgresql-migration` | Hackage | `0.2.1.8` | github.com/andrevdm/postgresql-migration | OK (low downloads: 1618 total / 26 in last 30 days; tested with GHC 9.6.1; revised 2026-01-11) [CITED: hackage] | Approved — **explicit acceptance recorded in Phase 1** (plan 01-02 task 1, autonomous; low-download-count risk accepted, no `checkpoint:human-verify` required) |
| `postgresql-simple` | Hackage | `0.7.0.0` | github.com/haskellari/postgresql-simple | OK | Approved |
| `optparse-applicative` | Hackage | `0.18.1.0` | github.com/pcapriotti/optparse-applicative | OK | Approved |
| `resource-pool` | Hackage | `0.4.0.0` | github.com/haskellari/resource-pool | OK (already an indirect dep) | Approved |
| `hspec` | Hackage | `2.11.8` | github.com/hspec/hspec | OK (already used) | Approved |
| `postgresql-libpq` | Hackage | `0.10.0.0` | github.com/haskellari/postgresql-libpq | OK — **only if** the library route is abandoned and direct libpq `exec` is chosen | Held in reserve |

**Packages removed due to [SLOP] verdict:** none.
**Packages flagged as suspicious [SUS]:** none. `postgresql-migration` carries a "verify" note for download count, not for legitimacy.

## Toolchain Truth

BOOT-06 requires GHC 9.6.5 / LTS 22.21 in **five** places. Current state:

| Source | Current value | Verdict |
|--------|---------------|---------|
| `stack.yaml:1` | `resolver: lts-22.21` (⇒ GHC 9.6.5) | ✅ correct |
| `cabal.project` | no `with-compiler`, no `index-state` | ❌ resolves against whatever `ghc` is on PATH (9.10.3 locally) |
| `Dockerfile:9` | `FROM haskell:9.14.1` | ❌ GHC 9.14.1 |
| `.devcontainer/devcontainer.json:8` | `"ghcVersion": "9.6.6"` | ❌ 9.6.6 |
| `.github/workflows/ci.yml:34-37` | `curl … get.haskellstack.org \| sh -s - -f` then `stack setup --no-nix` | ⚠️ correct GHC via resolver, unpinned stack version |
| `.github/workflows/postgres-integration.yml:37-40` | `haskell-actions/setup@v2` with `stack-version: 'latest'` | ❌ drifting stack |

Required edits:

- `cabal.project`: add `with-compiler: ghc-9.6.5` (and, if `cabal build` is to be reproducible at all, `index-state: 2024-05-06T00:00:00Z` — the LTS 22.21 publication date).
- `Dockerfile`: `FROM haskell:9.6.5` (verified to exist on Docker Hub) — the builder then no longer needs `--install-ghc`.
- `.devcontainer/devcontainer.json`: `"ghcVersion": "9.6.5"`.
- Both workflows: pin `stack-version: '3.7.1'` (the version installed here) instead of `latest`.
- `scripts/check-toolchain.sh` greps all five and exits non-zero on any mismatch; it runs as a CI step **before** `stack build`, so drift is a red build rather than a paragraph in AGENTS.md.

Note: `stack.yaml` deliberately has no `system-ghc: true`. Do not add it — the machine GHC is 9.10.3 and would silently be used.

## Architecture Patterns

### System Architecture Diagram

```
                ┌──────────────────────────────────────────────┐
  env vars ────▶│ app/Main.hs                                  │
 (PORT,         │  1. loadConfig  ──fail-fast──▶ die "missing…"│
  DATABASE_URL, │  2. initLogger / initMetrics                 │
  SURYPUS_JWT_  │  3. createPool (Surypus.DB.Pool)             │
   SECRET)      │  4. parse args (optparse-applicative)        │
                └───────┬───────────────────────┬──────────────┘
                        │                       │
             args == "migrate"          args == (none) | "serve"
                        │                       │
                        ▼                       ▼
        ┌───────────────────────────┐   ┌──────────────────────────────┐
        │ Surypus.DB.Migrate.run    │   │ apiServer pool logger metrics│
        │  a. pre-flight (pure)     │   │   publicPaths checkPerm      │
        │     · filename grammar    │   │        │                     │
        │     · duplicate numbers   │   │        ▼                     │
        │  b. pg_try_advisory_lock  │   │ Warp.runSettings (port)      │
        │  c. ledger read           │   └──────────┬───────────────────┘
        │  d. per-file: BEGIN       │              │
        │     · execute file        │              ▼
        │     · INSERT ledger row   │   ┌──────────────────────────────┐
        │     · COMMIT              │   │ healthEndpoint (WAI wrapper) │
        │  e. unlock                │   │  /api/v1/health   ─┐         │
        └─────────────┬─────────────┘   │  /api/v1/health/db ─┴▶ probe │
                      │                 └──────────┬───────────────────┘
                      ▼                            │
        ┌───────────────────────────┐              ▼
        │ PostgreSQL                │   ┌──────────────────────────────┐
        │  surypus_schema_migrations│   │ SELECT 1  ── ok  ──▶ 200     │
        │  pg_try_advisory_lock     │   │           ── fail ─▶ 503     │
        │  canonical DDL            │   └──────────────────────────────┘
        └───────────────────────────┘
```

Data flow for the acceptance path: `stack run` → env → pool → Warp → `GET /api/v1/health` → `SELECT 1` → `200`; stop PostgreSQL → same request → `503`.

### Recommended Project Structure

```
app/
└── Main.hs                    # thin: config → args → serve | migrate
src/
└── Surypus/
    ├── Config.hs              # NEW: Config record + loadConfig (fail-fast)
    ├── DB/
    │   ├── Pool.hs            # export mkDBConfig + connString; prefer DATABASE_URL over DB_*
    │   ├── Migrate.hs         # NEW: runner (pre-flight, lock, ledger, execute)
    │   └── Schema.hs          # DELETE the dead runMigrations TH path
    └── API/
        └── Server.hs          # healthEndpoint returns real DB status
sql/
├── archive/
│   └── legacy-migrations/     # all 359 legacy *.sql moved here, untouched
└── migrations/               # canonical, ONLY these two
    ├── V001__bootstrap.sql
    └── V002__schema_truth_forward.sql
test/
├── Surypus/ConfigSpec.hs      # NEW: fail-fast + defaults
├── DB/MigrationRunnerSpec.hs  # NEW: integration, real PG
└── API/HealthSpec.hs          # NEW: 200 / 503 / payload
```

### Pattern 1: Canonical corpus with a forward-reconciliation pair

**What:** `V001__bootstrap.sql` describes the *final* shape using `CREATE TABLE IF NOT EXISTS`. `V002__schema_truth_forward.sql` uses only idempotent `ALTER TABLE … ADD COLUMN IF NOT EXISTS` / `CREATE INDEX IF NOT EXISTS`, so it converges any pre-existing database created by the legacy corpus onto the same shape.

**When to use:** Always, for Phase 1. Fresh DB → `V001` creates everything, `V002` no-ops. Legacy DB → `V001` no-ops, `V002` repairs.

**Why not "drop and recreate":** `docker/docker-compose.yml` mounts `./sql` into `/docker-entrypoint-initdb.d` and there is a persisted `postgres_data` volume; existing developer databases and the `surypus` database on this machine must survive.

### Pattern 2: Runner is an explicit subcommand, never automatic on boot

**What:** `surypus-server` with no args serves; `surypus-server migrate [--dry-run|--check]` migrates.

**Why:** BOOT-01 acceptance is literally `stack run`. Adding a second executable makes bare `stack run` ambiguous ("Multiple executables found"), breaking the acceptance criterion. A subcommand keeps exactly one executable and satisfies BOOT-03.

### Pattern 3: Health probes the database on every request

**What:** `/api/v1/health` runs `SELECT 1` through the pool inside `try`/`catch`, returns `200 "OK"` on success and `503 "DB UNAVAILABLE"` on failure (constant body — no driver text). `/api/v1/health/db` becomes an alias (or is removed) to avoid two answers to the same question.

**Why:** `healthEndpoint` is applied *outside* `servantApp` (`baseApp = healthEndpoint connPool servantApp`), so health bypasses rate limiting, metrics, correlation, tenant, auth and authz. That is correct for a liveness probe, but it means the handler itself is the only place availability can be reported.

### Pattern 4: One `Config` record, validated once

**What:** `loadConfig :: IO Config` reads all env, applies defaults only where a default is genuinely safe, and `die`s with a list of *all* missing required variables (not the first).

**Why:** today `mkDBConfig` silently defaults `DB_PASSWORD` to `surypus_password` and `SURYPUS_JWT_SECRET` fails later, on the first token operation, with `error`. Requirement 5 of the phase is "Старт падает быстро и с понятным сообщением".

### Pattern 5: Toolchain asserted by a script

**What:** `scripts/check-toolchain.sh` greps the five locations and exits non-zero on any mismatch; CI runs it as a step before `stack build`.

**Why:** BOOT-06 is a consistency property across five files; prose in AGENTS.md does not enforce it, and three of the five are wrong today.

### Anti-Patterns to Avoid

- **`CREATE TABLE IF NOT EXISTS` as conflict resolution.** It converts a schema conflict into a silent no-op. `bills` is defined twice (`V001:95`, `V256:230`) with incompatible columns; the second definition never runs and nothing reports it.
- **Lexicographic ordering.** `V1000` sorts before `V100`. Never order migrations by `ByteString`/`String`; parse the numeric part.
- **Shelling out to `psql` per file without `ON_ERROR_STOP`.** `scripts/setup_test_db.sh` does exactly this; `ci.yml`'s sibling workflow adds `|| echo "Migration $f skipped"`, which hides every failure.
- **Two ledgers.** `sql/migrations/init_db.sh` maintains both `schema_version` (Flyway-like) and `schema_migrations`; `ON CONFLICT (version) DO UPDATE SET success = TRUE` rewrites history rather than detecting a changed file.
- **Starting the server on a schema you did not verify.** Do not call `runMigrations` from `Main`. A server that boots on a wrong schema is worse than a server that refuses to boot.

## Server Bootstrap

`app/Main.hs` is seven lines that print two strings [VERIFIED: app/Main.hs:1-7]. The pieces it must compose already exist and are exposed by the library:

| Step | Call | Evidence |
|------|------|----------|
| 1 | `Surypus.Config.loadConfig` (new module) | `Surypus.DB.Pool.mkDBConfig` is **not exported** (`module Surypus.DB.Pool (DBConfig(..), Pool(..), createPool, closePool, runQuery, poolStats)`) [VERIFIED: src/Surypus/DB/Pool.hs:3-10]. `connString :: DBConfig -> Text` already exists but is likewise unexported [VERIFIED: src/Surypus/DB/Pool.hs:64-69]. Export both, and make `mkDBConfig` prefer `DATABASE_URL` when it is set, falling back to `DB_*` for one release |
| 2 | `Surypus.API.Logger.initLogger :: LogLevel -> IO Logger` | [VERIFIED: src/Surypus/API/Logger.hs:43] |
| 3 | `Surypus.Metrics.initMetrics :: IO Metrics` | [VERIFIED: src/Surypus/Metrics.hs:22] — **not** `System.Metrics.initMetrics`, which is a different, also-exposed type (`System.Metrics.Metrics` has `requestsTotal`/`responses4xx`/`responses5xx`), while `apiServer` imports `Surypus.Metrics (Metrics, renderPrometheus)` [VERIFIED: src/Surypus/API/Server.hs:76] |
| 4 | `Surypus.DB.Pool.createPool :: IO Pool` then `poolConn :: Pool -> ConnectionPool` | [VERIFIED: src/Surypus/DB/Pool.hs:38-40,73-79] |
| 5 | `Surypus.API.Server.apiServer :: ConnectionPool -> Log.Logger -> Metrics -> [Text] -> (Int64 -> Text -> IO Bool) -> IO Application` | [VERIFIED: src/Surypus/API/Server.hs:183]; `Surypus.API.Server` exports only `apiServer` [VERIFIED: src/Surypus/API/Server.hs:11] |
| 6 | `Warp.runSettings (setPort port defaultSettings) app` | `warp` is already in the executable's build-depends [VERIFIED: Surypus.cabal:455-469] |

Three traps specific to this codebase:

- **Do not call `DAL.Database.createPool`** — it is hard-wired to `host=localhost port=5432 dbname=surypus user=postgres password=postgres` [VERIFIED: src/DAL/Database.hs:43] and has no `withTransaction`.
- **`checkPermission` must be default-deny.** `withAuthzResolver` uses `(\_ _ -> pure False)` as its default [VERIFIED: src/Surypus/API/AuthMiddleware.hs:91]; pass the same. Phase 6 replaces it.
- **Close the pool.** Wrap the server in `bracket Pool.createPool Pool.closePool`; otherwise a restart in the same process (tests) leaks connections.

## Health Endpoint

Current behaviour [VERIFIED: src/Surypus/API/Server.hs:210-220]:

```haskell
"/api/v1/health" -> respond $ W.responseLBS status200 […] "OK"          -- constant
"/api/v1/health/db" -> do
    result <- runSqlPool (rawSql "SELECT 1 as health" []) connPool      -- throws if DB down
```

Required behaviour:

- Both paths run the same probe (`SELECT 1` through the pool) inside `try`.
- Success → `200`, body `OK`. Failure → `503`, body `DB UNAVAILABLE`. No driver message, no DSN, no stack trace in the response.
- **Contract drift to settle:** `docs/API.md:480-483` documents `GET /api/v1/health` as JSON `{ "status": "ok", "timestamp": "…" }`, and `STATE.md:25,40` claims `{status:"ok", db:"ok"}`, while the code returns plain text. `/api/v1/health/db` currently answers `DB OK` / `DB ERROR` [VERIFIED: src/Surypus/API/Server.hs:215-219]. Choose one contract, implement it, and update `docs/API.md` + `STATE.md` in the same change — otherwise BOOT-02 is "green" against a document that describes a different endpoint.
- Health is applied **outside** `servantApp` (`baseApp = healthEndpoint connPool servantApp` [VERIFIED: Server.hs:207]), so it bypasses auth, tenant, metrics and rate limiting. That is intended for liveness; do not "fix" it by moving health inside the middleware stack.
- The pool is lazy: `createPostgresqlPool` does not prove connectivity. A health check is the first real proof that the DSN works, which is why it is the Phase 1 acceptance signal.
- Docker `HEALTHCHECK` uses `curl -f`, so `503` correctly fails the container health check [VERIFIED: Dockerfile:70-71 — `HEALTHCHECK … CMD curl -f http://localhost:8080/api/v1/health || exit 1`].

## Migration Runner

**Command surface:** `surypus-server migrate [--dir DIR] [--dry-run] [--check]` (one executable; see Pitfall 5).

**Lifecycle:**

1. **Pre-flight (pure, no connection).** List the directory, parse `^V([0-9]{3,})__([a-z0-9_]+)\.sql$`, normalise numeric prefixes (`V001` ≡ `V1`), sort numerically, reject unparseable names and duplicate numbers. This is the only part we write ourselves, because the error messages are part of BOOT-03.
2. **Connect** using `DATABASE_URL` (`postgresql-simple` accepts a libpq URI directly).
3. **`pg_try_advisory_lock(hashtext('surypus.migrate'))`** on that connection. `False` ⇒ exit non-zero immediately. Never the blocking variant.
4. **Ledger read** via the library (`optTableName = "surypus_schema_migrations"`), so the legacy `schema_migrations` table from `init_db.sh` is neither read nor clobbered.
5. **Apply each pending file in one transaction**, including its ledger row. Commit, then move on. A failure rolls back that file only; earlier files remain applied — which is correct and is why the ledger must be inside the same transaction.
6. **Unlock** (`pg_advisory_unlock`) and exit `0`.

**Required semantics (each row is a test in `test/DB/MigrationRunnerSpec.hs`):**

| Scenario | Expected behaviour |
|----------|--------------------|
| Empty database, `migrate` | `V001`, `V002` applied in numeric order; ledger has exactly two rows |
| `migrate` again | Exit `0`, zero DDL executed, ledger unchanged (idempotent) |
| An applied file was edited | Exit non-zero **before** any DDL; message names the file and says checksum mismatch |
| Two files share a numeric prefix | Pre-flight exit non-zero; **no connection is opened** |
| A second process runs concurrently | Exit non-zero; message names the advisory lock |
| A file fails halfway | That file's transaction rolls back; no ledger row; earlier files stay applied |
| `--check` | Connect, report pending/out-of-date files, exit `0`/`1`, no DDL |
| `--dry-run` | Print the ordered plan; no connection at all |

**Error messages (assert these substrings):**

- `FATAL: duplicate migration number 1: V001__core_schema.sql, V001__generated_orm.sql`
- `FATAL: migration V002__schema_truth_forward.sql changed after it was applied (checksum mismatch)`
- `FATAL: another migration is running (advisory lock surypus.migrate is held)`
- `FATAL: migration V003__x.sql failed: ERROR: …`

**What the library owns vs what we own:**

| Concern | Owner | Why |
|---------|-------|-----|
| Reading and executing `.sql` files (incl. `DO $$ … $$`) | `postgresql-migration` | Naive statement splitting is the classic failure mode |
| Checksum computation and comparison | `postgresql-migration` (MD5) | Documented behaviour: an edited script is a runtime error |
| Ledger table + row writes | `postgresql-migration` (`optTableName`) | Avoids a second bespoke ledger |
| Transaction boundary per file | `postgresql-migration` (`TransactionPerStep`) | DDL is transactional in PostgreSQL; use it |
| Filename grammar, duplicate detection, ordering | `Surypus.DB.Migrate.preflight` (ours) | Specific error messages required by BOOT-03 |
| Advisory lock | `Surypus.DB.Migrate` (ours, one query) | Not provided by the library |
| Exit codes and top-level error formatting | `app/Main.hs` | CLI contract |

**Deliberately out of scope for Phase 1:** down-migrations, per-migration checksums in a custom table, seeding, and any automatic migration at server boot.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Executing a multi-statement SQL file | A `splitOn ";"` splitter | `postgresql-migration` `MigrationDirectory` | `DO $$ … $$` blocks, `BEGIN … END`, dollar quoting, string literals and comments all break naive splitters; `postgresql-simple.execute_` sends via `PQexecParams` and rejects multiple commands |
| Checksum ledger | New table + manual md5 calls | `postgresql-migration` ledger (`optTableName`) | It already records script, checksum, timestamps and fails on mismatch |
| Advisory locking | A lock file / pid file | `pg_try_advisory_lock(hashtext('surypus.migrate'))` | Lock must die with the connection; file locks survive crashes and lie across containers |
| Connection pooling | New pool | `resource-pool` via `persistent` (`Surypus.DB.Pool`) | Already present, already used by `apiServer` |
| CLI parsing | `getArgs` pattern matching | `optparse-applicative` | Subcommands, `--help`, exit codes for free |
| HTTP serving | New server loop | `warp` + `servant-server` | Already wired; Phase 1 only needs `runSettings` |
| Health JSON/format | A new response envelope | Plain text `OK` / `DB UNAVAILABLE` | Matches the existing contract and the Docker `HEALTHCHECK` (`curl -f`) |

**Key insight:** the runner's *execution* is the only place where hand-rolling is dangerous. Duplicate detection, filename grammar and `--check` are ~40 lines of pure code and should be ours, because the error messages are part of the requirement.

## Runtime State Inventory

This is a schema-migration phase, so runtime state matters: files on disk are only half the truth.

| Category | Items Found | Action Required |
|----------|-------------|------------------|
| **Stored data** | A local `surypus` database exists (user `surypus`). Any DB initialised by `init_db.sh` contains `schema_version` and `schema_migrations` ledgers plus a partially applied legacy corpus. Local probe DB `surypus_probe2` contains 329 applied files. | `V002` must be idempotent over these; the runner must not treat `schema_version` as its ledger. Drop probe DBs after use. |
| **Live service config** | `docker/docker-compose.yml` mounts `./sql` into `/docker-entrypoint-initdb.d` with a persisted `postgres_data` volume; `postgres:16-alpine` — older than the local server (18.6). | Document `docker compose down -v` for a clean rebuild; align the compose image with the CI image (see Open Questions). |
| **OS-registered state** | None — no systemd units, launchd plists, pm2 or Task Scheduler entries reference this project. Verified by absence of such files in the repo. | None. |
| **Secrets / env vars** | `SURYPUS_JWT_SECRET` (required by `getSigningKey`), `SURYPUS_TEST_DATABASE_URL`, `SURYPUS_TEST_REDIS_URL`, `DB_*`. `.env.example` advertises `JWT_SECRET`, `APP_PORT`, `DATABASE_URL` — none of which the code reads. | Rename in `.env.example` + `ENV_VARS.md`, or add aliases in `loadConfig`. Never log the DSN (it contains the password). |
| **Build artifacts** | `sql/migrations/V001__generated_orm.sql` is a checked-in generated file. `src/Surypus/App/Main.hs` is an **exposed library module with a `main`** that writes `V001__rbac_basic_schema.generated.sql` … into a target directory. Running it against `sql/migrations/` would inject duplicate `V001`–`V028`. | Quarantine `V001__generated_orm.sql` with the legacy corpus; delete or clearly mark `Surypus.App.Main` as non-executable in a later phase; never generate into the canonical directory. |
| **Runtime-generated SQL** | `src/Surypus/Domain/RBACCanon/Migration.hs` produces DDL strings used by `MigrationDryRunSpec` only. | No action in Phase 1; keep the spec green. |

## Common Pitfalls

### Pitfall 1: Lexicographic ordering silently reorders the schema
**What goes wrong:** `sort` places `V1000__event_store_schema.sql` at position 19, before `V100__event_sourcing_init.sql` at position 27.
**Why it happens:** every existing script uses shell glob + `sort`, which is byte order.
**How to avoid:** parse `^V([0-9]+)__` to an `Integer`, sort by it, and fail on equal values.
**Warning signs:** "column tenant_id does not exist" from `V101` even though `V1000` "created" `event_store`.

### Pitfall 2: `CREATE TABLE IF NOT EXISTS` hides a real conflict
**What goes wrong:** `V001` creates `bills(id BIGINT, number, date, currency, total_amount, status)`; `V256` declares `bills(id UUID, tenant_id UUID, bill_number, …)`. The second never applies, and `DAL.MutationsORM` inserts into columns that exist in neither.
**Why it happens:** `IF NOT EXISTS` was used as a merge strategy.
**How to avoid:** exactly one definition per table in the canonical corpus; reconciliation only via explicit `ALTER TABLE … ADD COLUMN IF NOT EXISTS`.
**Warning signs:** `column "bill_number" of relation "bills" does not exist` at runtime.

### Pitfall 3: Tenant type drift UUID vs BIGINT
**What goes wrong:** 115 `tenant_id UUID` occurrences in migrations vs 4 `BIGINT`, while every line of executable Haskell uses `Int64` (`DAL.Database:30`, JWT `ucTenantId :: Maybe Int64`).
**Why it happens:** the domain migrations (`V256`) were generated from a different model than the application.
**How to avoid:** canonical `tenant_id BIGINT NOT NULL DEFAULT 0`; `app.current_tenant_id() RETURNS BIGINT` (already correct in `V016`) is the single helper.
**Warning signs:** `operator does not exist: uuid = bigint`.

### Pitfall 4: `event_store` is missing a column the code writes
**What goes wrong:** `V1000` creates `event_store` without `event_schema_version`; `DAL.EventStore.appendEvent` inserts ten columns including `event_schema_version`.
**Why it happens:** schema and code evolved separately.
**How to avoid:** canonical `event_store` must contain exactly the ten columns used at `src/DAL/EventStore.hs:136-145`.
**Warning signs:** `column "event_schema_version" of relation "event_store" does not exist`.

### Pitfall 5: `stack run` becomes ambiguous
**What goes wrong:** adding `executable surypus-migrate` makes bare `stack run` fail with "Multiple executables found", breaking success criterion 1 verbatim.
**Why it happens:** stack requires `--exec`/argument when more than one executable exists. [ASSUMED — standard stack behaviour, not re-run this session]
**How to avoid:** keep one executable; implement migrations as a subcommand.
**Warning signs:** CI step `stack run` fails before Warp starts.

### Pitfall 6: Test DB env var mismatch
**What goes wrong:** `.github/workflows/postgres-integration.yml:81` exports `DATABASE_URL`, while the specs read `SURYPUS_TEST_DATABASE_URL` (`test/DAL/EventStoreIntegration.hs:22`), so DB tests stay `pending` even with a live database.
**Why it happens:** two naming conventions grew independently.
**How to avoid:** one variable, set by CI, asserted by a test that fails (not pends) when a DB is expected.

### Pitfall 7: Hspec argument parsing
**What goes wrong:** `stack test --test-arguments "--color=never"` fails with `option '--color' doesn't allow an argument` before any test runs (observed this session).
**Why it happens:** hspec's `--color` is a flag, not an option with a value.
**How to avoid:** use `--color` or `--no-color`; never `--color=…` in CI.

### Pitfall 8: Docker/devcontainer toolchain drift
**What goes wrong:** `Dockerfile:9` is `FROM haskell:9.14.1`; `.devcontainer/devcontainer.json:8` is `"ghcVersion": "9.6.6"`; `stack.yaml` resolves to 9.6.5; the system `ghc` on this machine is 9.10.3.
**Why it happens:** each file was written at a different time.
**How to avoid:** `scripts/check-toolchain.sh` + CI step; `cabal.project` gets `with-compiler: ghc-9.6.5`.

### Pitfall 9: Ledger table name collision
**What goes wrong:** `sql/migrations/init_db.sh` already creates `schema_migrations(version, description)`. The migration library defaults to the same name with a different column set.
**Why it happens:** Flyway-shaped and library-shaped ledgers collide.
**How to avoid:** set `optTableName = "surypus_schema_migrations"`; drop the legacy ledgers inside `V002` only after a successful canonical run (or leave them untouched and ignore them).

### Pitfall 10: Advisory lock that blocks forever
**What goes wrong:** `pg_advisory_lock` waits indefinitely if a previous run crashed mid-transaction in another session.
**Why it happens:** blocking variant used for convenience.
**How to avoid:** `pg_try_advisory_lock`; on `false`, exit non-zero with "another migration is running".

### Pitfall 11: Health endpoint reports 500 instead of 503
**What goes wrong:** `runSqlPool (rawSql …)` throws `SqlError` when PostgreSQL is down; WAI turns it into a 500, and the Docker `HEALTHCHECK` semantics become ambiguous.
**Why it happens:** no exception handling in `healthEndpoint` (`src/Surypus/API/Server.hs:210-220`).
**How to avoid:** `try`/`catch` around the probe, log at `Warn`, return `503` with a constant body (no DSN, no driver message).

### Pitfall 12: Migration runner mutates the working tree
**What goes wrong:** `Surypus.App.Main.main` writes generated SQL into a chosen directory. If ever run with `sql/migrations` as the target, it injects `V001`–`V028` duplicates.
**Why it happens:** an alternate `main` shipped inside the library's exposed modules.
**How to avoid:** canonical corpus is write-protected by convention and by the pre-flight duplicate check (it would fail loudly). Remove the module in a later phase.

## Code Examples

### Fail-fast config (`src/Surypus/Config.hs`)

```haskell
{-# LANGUAGE OverloadedStrings #-}
module Surypus.Config
  ( Config(..)
  , loadConfig
  ) where

import Data.Text (Text)
import qualified Data.Text as T
import Surypus.API.Logger (LogLevel (..))
import System.Environment (lookupEnv)
import System.Exit (die)

data Config = Config
  { cfgPort        :: !Int
  , cfgDatabaseUrl :: !Text
  , cfgJwtSecret   :: !Text
  , cfgLogLevel    :: !LogLevel
  }

-- | Read configuration, failing once with *every* problem found.
loadConfig :: IO Config
loadConfig = do
  mPort  <- lookupEnv "PORT"
  mDbUrl <- lookupEnv "DATABASE_URL"
  mJwt   <- lookupEnv "SURYPUS_JWT_SECRET"
  mLevel <- lookupEnv "LOG_LEVEL"

  let port  = maybe (Right 8080) readPort mPort
      level = maybe (Right Info) readLevel mLevel
      missing =
        [ "DATABASE_URL"       | Nothing <- [mDbUrl] ] <>
        [ "SURYPUS_JWT_SECRET" | Nothing <- [mJwt]   ]
      problems =
        [ "missing required environment variable(s): " <> unwords missing
        | not (null missing) ] <>
        [ "PORT is not a valid port number: " <> s | Left s <- [port] ] <>
        [ "LOG_LEVEL must be one of debug|info|warn|error: " <> s | Left s <- [level] ]

  case problems of
    [] -> pure ()
    _  -> die ("FATAL: " <> unlines problems <> "See .env.example for the full list.")

  pure Config
    { cfgPort        = either (const 8080) id port
    , cfgDatabaseUrl = T.pack (maybe "" id mDbUrl)
    , cfgJwtSecret   = T.pack (maybe "" id mJwt)
    , cfgLogLevel    = either (const Info) id level
    }
  where
    readPort s = case reads s of
      [(n, "")] | n > 0 && n < 65536 -> Right n
      _                              -> Left s
    readLevel s = case T.toLower (T.pack s) of
      "debug" -> Right Debug
      "info"  -> Right Info
      "warn"  -> Right Warn
      "error" -> Right Error
      _       -> Left s
```

`LogLevel` is re-exported by `Surypus.API.Logger` [VERIFIED: src/Surypus/API/Logger.hs:5,33 — exports `LogLevel (..),` and declares `data LogLevel = Debug | Info | Warn | Error deriving (Show, Eq, Ord, Enum, Bounded)`]. Reuse it rather than defining a second enum.

### Thin entrypoint (`app/Main.hs`)

```haskell
{-# LANGUAGE OverloadedStrings #-}
module Main (main) where

import qualified Surypus.API.Logger as Log
import qualified Surypus.API.Server as API
import qualified Surypus.Config as Cfg
import qualified Surypus.DB.Migrate as Migrate
import qualified Surypus.DB.Pool as Pool
import qualified Surypus.Metrics as Metrics
import Control.Exception (bracket)
import Data.Text (Text)
import Network.Wai.Handler.Warp (runSettings, setPort, defaultSettings)
import Options.Applicative
import System.IO (hSetBuffering, stdout, BufferMode(..))

data Command = Serve | Migrate Migrate.Options

opts :: ParserInfo Command
opts = info (parser <**> helper) (fullDesc <> progDesc "Surypus server")
  where
    parser = flag' Serve (long "serve" <> help "start the HTTP server (default)")
         <|> hsubparser (command "migrate"
               (info (Migrate <$> Migrate.optionsParser) (progDesc "apply pending migrations")))
         <|> pure Serve

main :: IO ()
main = do
  hSetBuffering stdout LineBuffering
  cmd <- execParser opts
  cfg <- Cfg.loadConfig
  logger <- Log.initLogger (Cfg.cfgLogLevel cfg)
  metrics <- Metrics.initMetrics
  case cmd of
    Migrate mo -> Migrate.run cfg mo
    Serve      ->
      bracket Pool.createPool Pool.closePool $ \pool -> do
        app <- API.apiServer (Pool.poolConn pool) logger metrics publicPaths
                            (\_ _ -> pure False)      -- default-deny until Phase 6
        runSettings (setPort (Cfg.cfgPort cfg) defaultSettings) app

-- The exact `apiServer` signature is
--   ConnectionPool -> Log.Logger -> Metrics -> [Text] -> (Int64 -> Text -> IO Bool) -> IO Application
-- [VERIFIED: src/Surypus/API/Server.hs:183]
publicPaths :: [Text]
publicPaths = ["/api/v1/health", "/api/v1/health/db", "/api/v1/metrics", "/api/v1/login"]
```

### Health handler with a real probe

```haskell
healthEndpoint :: ConnectionPool -> Application -> Application
healthEndpoint connPool app req respond =
  case W.rawPathInfo req of
    "/api/v1/health"    -> probe
    "/api/v1/health/db" -> probe
    path -> if "/api/v1/reports/download/" `DT.isPrefixOf` TE.decodeUtf8 path
              then Reports.serveReportFile (DT.replace "/api/v1/reports/download/" "" (TE.decodeUtf8 path)) req respond
              else app req respond
  where
    probe = do
      r <- try (runSqlPool (rawSql "SELECT 1" []) connPool)
              :: IO (Either SomeException [Single Int64])
      case r of
        Right [Single 1] -> respond $ W.responseLBS status200 [] "OK"
        _                -> respond $ W.responseLBS status503 [] "DB UNAVAILABLE"
```

### Pre-flight (pure, testable without a database)

```haskell
-- | Parse, validate and order migration files. Pure so it can be unit tested.
preflight :: [FilePath] -> Either [String] [(Integer, FilePath)]
preflight files =
  let parsed = [(n, f) | f <- files, Just n <- [versionOf f]]
      bad    = [f | f <- files, versionOf f == Nothing]
      dupes  = [ (n, fs) | (n, fs) <- M.toList (M.fromListWith (<>) [(n, [f]) | (n, f) <- parsed])
                         , length fs > 1 ]
  in case (bad, dupes) of
       ([], []) -> Right (sortOn fst parsed)
       _        -> Left $
         [ "unnamed migration (expected V<number>__<name>.sql): " <> f | f <- bad ] <>
         [ "duplicate migration number " <> show n <> ": " <> intercalate ", " fs | (n, fs) <- dupes ]

versionOf :: FilePath -> Maybe Integer
versionOf f = case stripPrefix "V" (takeFileName f) of
  Just rest | (digits, '_':'_':_) <- break (== '_') rest
            , not (null digits), all isDigit digits -> Just (read digits)
  _ -> Nothing
```

### Runner (shape only; exact library constructors per Hackage module docs)

```haskell
run :: Cfg.Config -> Options -> IO ()
run cfg opts = do
  files <- listDirectory (optDir opts)
  case preflight files of
    Left errs -> die (unlines ("FATAL: migration pre-flight failed:" : errs))
    Right ordered
      | optDryRun opts -> mapM_ (putStrLn . snd) ordered
      | otherwise -> withConnection cfg $ \conn -> do
          locked <- query_ conn "SELECT pg_try_advisory_lock(hashtext('surypus.migrate'))"
          case locked of
            [Only True] -> do
              runMigration conn
                defaultOptions { optTableName         = "surypus_schema_migrations"
                               , optTransactionControl = TransactionPerStep }
                (MigrationDirectory (optDir opts))
              _ <- query_ conn "SELECT pg_advisory_unlock(hashtext('surypus.migrate'))"
              pure ()
            _ -> die "FATAL: another migration is running (advisory lock surypus.migrate held)"
```

### CI job (real PostgreSQL)

```yaml
  build:
    runs-on: ubuntu-latest
    services:
      postgres:
        image: postgres:16
        env:
          POSTGRES_USER: surypus
          POSTGRES_PASSWORD: surypus_password
          POSTGRES_DB: surypus_test
        ports: ['5432:5432']
        options: >-
          --health-cmd pg_isready --health-interval 10s
          --health-timeout 5s --health-retries 5
    env:
      DATABASE_URL: postgresql://surypus:surypus_password@localhost:5432/surypus_test
      SURYPUS_TEST_DATABASE_URL: postgresql://surypus:surypus_password@localhost:5432/surypus_test
      SURYPUS_JWT_SECRET: ci-only-not-a-real-secret
    steps:
      - uses: actions/checkout@v7
        with: { submodules: recursive }
      - uses: haskell-actions/setup@v2
        with: { enable-stack: true, stack-version: '3.7.1' }
      - run: ./scripts/check-toolchain.sh
      - run: stack --no-nix build --test --no-run-tests --no-haddock-deps
      - run: stack --no-nix run -- migrate
      - run: stack --no-nix test
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Flyway-style `schema_version` maintained by shell | Library ledger on the same connection as the DDL | Phase 1 | Checksums and per-step transactions become possible |
| `sort` on filenames | Parse numeric version, sort numerically | Phase 1 | `V1000` stops jumping ahead of `V100` |
| 359 ad-hoc migrations | 2 canonical files + archived corpus | Phase 1 | Empty-DB build becomes a single command |
| Health returns constant `200` | Health probes `SELECT 1` | Phase 1 | Readiness is real; Docker `HEALTHCHECK` becomes meaningful |
| GHC version stated in prose | Asserted by `scripts/check-toolchain.sh` in CI | Phase 1 | Drift becomes a red build |

**Deprecated/outdated:**
- `src/Surypus/DB/Schema.hs:115 runMigrations` — dead TH migration path, no callers in the server path.
- `src/Infrastructure/Migration.hs` — types only; no execution.
- `sql/migrations/init_db.sh` — dual-ledger shell script; superseded, move to `sql/archive/`.
- `Makefile` `migrate` target, which applies **only** `V100__event_sourcing_init.sql` — actively misleading.
- `Surypus.App.Main` — an exposed library module with a `main` that writes SQL files.

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | The team accepts `postgresql-migration` (low download count) as the executor | Standard Stack | Planner must instead build a libpq-based executor; +1–2 tasks | Accepted — low-download-count risk accepted at Phase 1 planning time (explicit decision, plan 01-02 task 1); libpq reserve retained |
| A2 | `DATABASE_URL` is the canonical database variable (not `DB_*`, not `PG*`) | Summary / Config | `.env.example` and Docker must be rewritten again; low risk, mechanical |
| A3 | `PORT` is the canonical port variable (`APP_PORT` deprecated) and `LOG_LEVEL` (default `info`) is the canonical log level | Config | Docker already exports `PORT`, so this is the lower-cost choice; an unrecognised `LOG_LEVEL` value makes startup fail |
| A4 | `SURYPUS_JWT_SECRET` stays required even before auth exists | Config / Security | If the team wants a dev default, Phase 6 inherits a weak-secret habit |
| A5 | Legacy corpus is *archived*, not deleted | Canonical Corpus Policy | Nothing is lost; the archive is still referenced by docs and old branches |
| A6 | `tenant_id = 0` default is acceptable for existing rows | Forward migration | If a real tenant exists, the backfill needs a mapping; there is no such data locally |
| A7 | PostgreSQL 16 is the supported floor (CI + compose) | Environment | Local is 18.6; features used must stay 16-compatible |
| A8 | `cabal.project` is not a supported build path, only a toolchain declaration | Toolchain Truth | If someone runs `cabal build`, `index-state` pinning becomes mandatory |

**If this table is non-empty, the planner must gate the corresponding decision behind a `checkpoint:human-verify` or an explicit task note.**

## Open Questions (RESOLVED)

1. **Exact set of required env vars.**
   - What we know: `.env.example` lists `DATABASE_URL`, `JWT_SECRET`, `APP_PORT`; code reads `DB_*` and `SURYPUS_JWT_SECRET`.
   - What's unclear: whether `DB_*` must keep working for existing deployments.
   - Recommendation: canonical `DATABASE_URL` + `SURYPUS_JWT_SECRET` required, `PORT`/`LOG_LEVEL` optional; keep `DB_*` as a documented fallback for one release.
   - **RESOLVED**: canonical `DATABASE_URL` + `SURYPUS_JWT_SECRET` required; `DB_*` fallback kept for one release (Phase 1 plans 01-01 task 1/3).

2. **PostgreSQL target version.**
   - What we know: local server 18.6; CI and compose use 16.
   - What's unclear: whether 18-only features are wanted (none are used today).
   - Recommendation: pin CI + compose to `postgres:16` and state "16+" in docs; do not test against 18 in CI this phase.
   - **RESOLVED**: CI + compose pinned to `postgres:16`; docs say "16+"; plans 01-04 task 3 and 01-05 task 1 adopt it.

3. **Fate of `DAL.Database` / `DAL.Pool` / `Surypus.DB.Pool` (three pool modules).**
   - What we know: `apiServer` imports `DAL.Pool`; `DAL.Database.createPool` has a hard-coded DSN and a global tenant `IORef`.
   - What's unclear: whether Phase 1 should delete them or Phase 6.
   - Recommendation: Phase 1 only routes the *server* through `Surypus.DB.Pool`; deleting the duplicate pool modules belongs to Phase 6 (auth/tenant), so the phase does not balloon.

4. **Does `chart_of_accounts` / `ledger_entries` survive?**
   - What we know: created only by `V256`, referenced by zero Haskell modules.
   - Recommendation: do not create them in the canonical corpus; they are Phase 3 replacement targets.

5. **`stack run` acceptance literal.**
   - What we know: success criterion says `stack run`; two executables break it.
   - Recommendation: one executable + `migrate` subcommand; record this in the plan so the verifier does not add a second executable.

6. **AGENTS.md is stale about migrations.**
   - What we know: AGENTS.md documents `config/migrations/V001..V010`; that directory does not exist (`ls config/migrations` → no such directory) and the real corpus is `sql/migrations/`.
   - Recommendation: update AGENTS.md in the same commit that introduces the canonical corpus.

7. **Health response format: plain text or JSON?**
   - What we know: code returns plain text `OK` / `DB OK`; `docs/API.md:480-483` documents `{ "status": "ok", "timestamp": … }`; `STATE.md:25,40` claims `{status:"ok", db:"ok"}`; the Docker `HEALTHCHECK` only needs `curl -f`, so it is format-agnostic.
   - What's unclear: whether any external monitor parses the body.
   - Recommendation: keep plain text (smallest change, matches the current binary contract and `HEALTHCHECK`), serve both paths from one probe, and correct `docs/API.md` + `STATE.md` in the same commit. If JSON is wanted, do it once for both paths and add a test asserting the exact keys.
   - **RESOLVED**: JSON locked to `{"status":"ok","db":"ok"}` / 503 `{"status":"error","db":"down"}` by `01-SKELETON.md` walking-skeleton contract; plans 01-01 task 2 adopt it; docs corrected in 01-05 task 3.

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| stack | Build | ✓ | 3.7.1 | — |
| GHC (stack-managed) | Build | ✓ | 9.6.5 | — |
| GHC on PATH | `cabal build` only | ✓ (wrong) | 9.10.3 | set `with-compiler: ghc-9.6.5` |
| PostgreSQL server | App + tests | ✓ | 18.6 (Ubuntu) | — |
| `psql` | CI/debug | ✓ | 18.6 | — |
| `pgcrypto` extension | `gen_random_uuid()` | ✓ | 1.4 | `uuid-ossp` `uuid_generate_v4()` |
| `uuid-ossp` extension | Legacy DDL | ✓ | 1.1 | `pgcrypto` |
| `postgis` extension | 1 legacy file only | ✗ | — | file is quarantined with the legacy corpus |
| `vector` extension | 2 legacy files (malformed DDL) | ✗ | — | quarantined |
| Redis | `EventStreamSpec`, `RedisCacheSpec` | ✓ | `PONG` | tests already skip when `SURYPUS_TEST_REDIS_URL` is unset |
| Docker | Dockerfile / compose verification | ✗ | — | CI runner provides it; local verification deferred |
| `sudo -u postgres psql` | Local DB provisioning for tests | ✓ | — | `psql -U surypus` with password |

**Missing dependencies with no fallback:** none for Phase 1 scope.
**Missing dependencies with fallback:** `postgis`/`vector` (legacy files quarantined), Docker (verify in CI).

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | hspec 2.11.8 + QuickCheck (already in `surypus-test`) |
| Config file | none — `test/Test.hs` is the aggregate `main` |
| Quick run command | `stack test --test-arguments "--match MigrationRunner"` |
| Full suite command | `stack test` |
| Measured baseline (2026-10-23) | `1010 examples, 0 failures, 3 pending` |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| BOOT-01 | `loadConfig` fails with all missing vars named; `PORT` parses | unit | `stack test --test-arguments "--match Config"` | ❌ Wave 0 (`test/Surypus/ConfigSpec.hs`) |
| BOOT-01 | Server binds and answers on `PORT` | smoke (CI) | `stack run &` + `curl -f localhost:$PORT/api/v1/health` | ❌ Wave 0 (shell step in CI) |
| BOOT-02 | Health 200 when DB reachable | integration | `stack test --test-arguments "--match Health"` | ❌ Wave 0 (`test/API/HealthSpec.hs`) |
| BOOT-02 | Health 503 when DB unreachable | integration | same spec, pool pointed at `port=1` | ❌ Wave 0 |
| BOOT-03 | Re-running migrations is a no-op | integration | `stack test --test-arguments "--match MigrationRunner"` | ❌ Wave 0 (`test/DB/MigrationRunnerSpec.hs`) |
| BOOT-03 | Edited applied file ⇒ non-zero + checksum message | integration | same spec | ❌ Wave 0 |
| BOOT-03 | Duplicate numeric prefix ⇒ pre-flight failure, no DB touch | unit | same spec (pure `preflight`) | ❌ Wave 0 |
| BOOT-03 | Concurrent run ⇒ advisory-lock failure | integration | same spec (two connections) | ❌ Wave 0 |
| BOOT-04 | Empty DB builds from canonical corpus | integration | `stack run -- migrate` on a scratch DB | ❌ Wave 0 (CI step) |
| BOOT-04 | `bills`/`accounts`/`payments` have the columns the code uses | integration | `information_schema.columns` assertions | ❌ Wave 0 |
| BOOT-05 | CI job with real PG; DB tests run, not pend | CI | workflow run | ⚠️ exists but misconfigured (`postgres-integration.yml`) |
| BOOT-06 | Five toolchain sources agree | unit (shell) | `./scripts/check-toolchain.sh` | ❌ Wave 0 |

### Sampling Rate

- **Per task commit:** `stack build --test --no-run-tests` + `stack test --test-arguments "--match <module>"`
- **Per wave merge:** `stack test` (full suite; DB tests require `SURYPUS_TEST_DATABASE_URL`)
- **Phase gate:** `stack build` + `stack test` + `stack run -- migrate` on a fresh DB + `curl` health check, all green before `/gsd-verify-work`

**TDD ordering** (`.planning/config.json` sets `workflow.tdd_mode: true`): `preflight` is pure, so write its spec first and let the duplicate/naming cases drive the parser. `ConfigSpec` likewise comes before `Surypus.Config`. The runner integration spec is written against a scratch database and starts red (`migrate` does not exist yet) — that is the intended first failing test.

### Wave 0 Gaps

- [ ] `test/Surypus/ConfigSpec.hs` — covers BOOT-01 / BOOT-06 env contract (note: `test/ConfigSpec.hs` already exists but tests `Surypus.Domain.Config.Config` defaults, not env loading — do not overwrite it)
- [ ] `test/API/HealthSpec.hs` — covers BOOT-02 (200/503, no exception leakage)
- [ ] `test/DB/MigrationRunnerSpec.hs` — covers BOOT-03 / BOOT-04 (pre-flight unit tests + live-DB integration tests)
- [ ] `test/Test.hs` — register the three new specs
- [ ] `Surypus.cabal` — add `DAL.EventStoreSpec` to `surypus-test` `other-modules` (file exists at `test/DAL/EventStoreSpec.hs` but is absent from the cabal file; `grep -n EventStoreSpec Surypus.cabal` returns nothing)
- [ ] `scripts/check-toolchain.sh` — covers BOOT-06
- [ ] CI: add a PostgreSQL service to `ci.yml`, set both `DATABASE_URL` and `SURYPUS_TEST_DATABASE_URL`, run `migrate` before `stack test`
- [ ] Test-DB provisioning helper that creates a scratch database per run (`surypus_test_$GITHUB_RUN_ID` or a truncate), so migration tests never depend on leftover state

*(Existing infrastructure covers the remaining 1010 examples; no framework install needed.)*

## Security Domain

`security_enforcement` is enabled with `security_asvs_level: 1`.

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | no (Phase 6) | — |
| V3 Session Management | no (Phase 6) | — |
| V4 Access Control | partial | `/api/v1/health` is intentionally unauthenticated; `checkPermission` must be default-deny (`\_ _ -> pure False`) so no route accidentally inherits allow |
| V5 Input Validation | yes | Migration filenames validated by a strict regex; `DATABASE_URL`/`PORT` validated before use; no string concatenation of unchecked paths into SQL |
| V6 Cryptography | yes | Never hand-roll; JWT via `jose`, checksums via the migration library (MD5 is corruption detection, **not** a security control — say so in the plan) |
| V7 Error Handling & Logging | yes | Never log the DSN (contains password); health returns a constant body, never driver text |
| V14 Configuration | yes | Secrets only from env; no default `SURYPUS_JWT_SECRET`; fail-fast at startup |

### Known Threat Patterns for this stack

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| SQL injection through a migration filename or path | Tampering | Whitelist `^V[0-9]+__[a-z0-9_]+\.sql$`; resolve inside the canonical dir only; `doesFileExist` after normalisation |
| Credential leakage in startup logs | Information Disclosure | Log `host:port/dbname` only; never `DATABASE_URL` |
| Path traversal via `--dir` | Tampering | Reject `..`, absolute paths outside the repo root |
| Unauthenticated health endpoint used for reconnaissance | Information Disclosure | Fixed body `OK` / `DB UNAVAILABLE`; no version, no error detail |
| Migration lock denial of service | Denial of Service | `pg_try_advisory_lock` (fail fast), never blocking `pg_advisory_lock` in CI |
| Half-applied migration after crash | Tampering | One transaction per file including the ledger insert; record only after `COMMIT` |
| Secrets committed in `.env` | Information Disclosure | `.env` gitignored; `.env.example` contains placeholders only |

## Sources

### Primary (HIGH confidence)
- `stack.yaml:1` — `resolver: lts-22.21`
- `https://www.stackage.org/lts-22.21` — "LTS Haskell 22.21 (ghc-9.6.5)", published 2024-05-06
- `https://raw.githubusercontent.com/commercialhaskell/stackage-snapshots/master/lts/22/21.yaml` — package versions: `postgresql-simple-0.7.0.0`, `postgresql-migration-0.2.1.8`, `optparse-applicative-0.18.1.0`, `resource-pool-0.4.0.0`, `hspec-2.11.8`, `postgresql-libpq-0.10.0.0`
- `src/Surypus/API/Server.hs:183,207,210-220` — `apiServer` signature, `baseApp = healthEndpoint connPool servantApp`, constant health response
- `docs/API.md:480-483`, `STATE.md:25,40` — health documented as JSON but implemented as plain text
- `src/Surypus/DB/Pool.hs:3-10,27-60,64-69` — `DBConfig`, unexported `mkDBConfig` and `connString`, `DB_*` defaults
- `src/DAL/Database.hs:30,43` — `IORef (Maybe (Int64, Int64))`, hard-coded DSN
- `src/Surypus/JWT/Token.hs:73-78` — `SURYPUS_JWT_SECRET` fail-fast
- `src/DAL/EventStore.hs:136-145` — ten-column `event_store` INSERT
- `sql/migrations/V001__core_schema.sql:68,95,105,117` — accounts/bills/payments/tax_rates
- `sql/migrations/V256__domain_organization_final.sql:134,191,230` — conflicting shapes
- `sql/migrations/V016__rls_policies.sql:8-12,42` — `app.current_tenant_id() RETURNS BIGINT`
- `sql/migrations/V015__tenants_table.sql:20` — `tenant_id BIGINT NOT NULL DEFAULT 0`
- `sql/migrations/V1000__event_store_schema.sql:6-18` — event_store without `event_schema_version`
- `src/DAL/MutationsORM.hs:180,363` — ORM column expectations for `bills` / `payments`
- `.github/workflows/ci.yml:34-45`, `.github/workflows/postgres-integration.yml:60-81`
- `Dockerfile:9`, `.devcontainer/devcontainer.json:8`, `.env.example:6-24`
- Live measurements this session: `stack build --test --no-run-tests` (pass), `stack test` (1010/0/3), migration probe on `surypus_probe2` (329 applied / 30 failed)

### Secondary (MEDIUM confidence)
- `https://hackage.haskell.org/package/postgresql-migration-0.2.1.8` — MD5 checksums, `schema_migrations`, `optTableName`, per-step transactions, tested with GHC 9.6.1
- `https://hackage.haskell.org/package/postgresql-simple-0.7.0.0` — `withTransaction`, `execute_`, `SqlError`

### Tertiary (LOW confidence)
- Exact `postgresql-migration` export names used in the code sketch (`MigrationDirectory`, `TransactionPerStep`, `optTableName`) — derived from the package README; confirm against module docs at implementation time.

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — versions verified against the LTS snapshot; the only judgement call is `postgresql-migration` (MEDIUM, A1)
- Architecture: HIGH — derived from reading the actual bootstrap modules and the API server signature
- Pitfalls: HIGH — every pitfall in this document was reproduced or directly observed in the repo (probe, `sort`, greps)
- Migration policy: HIGH for "legacy corpus is broken" (measured); MEDIUM for the exact canonical DDL, which Phase 2+ owns

**Research date:** 2026-10-23
**Valid until:** 2026-11-22 (30 days; Haskell/GHC ecosystem is slow-moving, but the repo's migration corpus may change under active development)
