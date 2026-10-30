---
last_mapped_commit: 7bd87f6f9f0abbbaddaeb0e604b8ff8fe2ff4c41
last_mapped_at: 2026-10-23
---
# Technology Stack

**Analysis Date:** 2026-10-23

## Languages

**Primary:**
- Haskell (Haskell2010) - 382 modules under `src/`, library target in `Surypus.cabal`; domain code in `src/Finance/`, `src/Commerce/`, `src/Inventory/`, `src/HR/`, `src/DAL/`, `src/Surypus/`, `src/System/`.
- GHC 9.6.5 via Stack resolver `lts-22.21` (`stack.yaml`, `stack.yaml.lock`); `app/Main.hs` and `README.md` both state GHC 9.6.5.

**Secondary:**
- C++17 - Qt6/QML desktop frontend at `frontend/main.cpp`, `frontend/CMakeLists.txt` (`Qt6::Core`, `Qt6::Qml`, `Qt6::Quick`); QML screens under `frontend/qml/`.
- JavaScript (browser, no build step) - PWA client at `web/js/api.js`, `web/js/app.js`, `web/js/offline.js`, `web/sw.js`; uses global `axios` and Chart.js 4.4.7 loaded from CDN in `web/index.html`.
- Python 3.11 - documentation and repository tooling: `tools/documentation/generate-inventory.py`, `tools/beads-sync-github.py`, `scripts/import_classifiers.py`.
- SQL / PLpgSQL - schema and migrations in `sql/migrations/*.sql`, `config/schema*.sql`, `config/database*.sql`; stored functions in `sql/procedures/`, `sql/aggregate/`.
- Rego - OPA policies `opa/policies/rbac.rego`, `opa/policies/inventory.rego`.
- Protocol Buffers (proto3) - `api/grpc/surypus.proto` (contract only; no Haskell gRPC runtime dependency).
- YAML DSL - `dsl/schema.yaml` (entity generator input), `templates/reports/*.yaml` (report templates).
- OpenAPI 3 / JSON - `openapi/openapi.yaml`, `api/rest/openapi.yaml`, `static/swagger.json`.

## Runtime

**Environment:**
- GHC 9.6.5 (Stack `lts-22.21`) for the library and test suite.
- WAI/Warp HTTP runtime is available via dependencies but is **not wired into an executable**: `app/Main.hs` only prints a banner, and no module calls `Network.Wai.Handler.Warp.runSettings`. The composed application lives in `src/Surypus/API/Server.hs` (`apiServer`, line 183) but has no `main` caller.
- Version drift to be aware of: `Dockerfile` pins `haskell:9.14.1`, `.devcontainer/devcontainer.json` pins GHC `9.6.6`, and `.github/workflows/documentation-deploy.yml` pins GHC `9.10.3`.

**Package Manager:**
- Stack (primary) - `stack.yaml`, `stack.yaml.lock` present; resolver `lts-22.21`; `allow-newer: false`; `extra-deps: []`.
- Cabal (secondary) - `cabal.project`, `cabal.project.local`, `cabal-version: 3.4` in `Surypus.cabal`; `dist-newstyle/` exists from Cabal builds.
- npm is **not** an application runtime dependency; `package.json` contains only `@opengsd/gsd-pi` (GSD workflow tooling), and `node_modules/` is tooling-only.
- Lockfiles: `stack.yaml.lock` present; no `cabal.project.freeze`.

## Frameworks

**Core:**
- Servant `>=0.20 && <0.21` + `servant-server` - typed REST API in `src/Surypus/API/Server.hs` (`type SurypusApi`, line 240) and `src/Surypus/Api.hs`.
- WAI `>=3.2 && <3.3`, `wai-extra`, `http-types` - application types and middleware chain in `src/Surypus/API/Server.hs`, `src/Surypus/API/AuthMiddleware.hs`, `src/Surypus/API/MetricsMiddleware.hs`. `warp >=3.3 && <3.5` is declared in `Surypus.cabal` but no module imports it (no server runner).
- `persistent` `>=2.14 && <2.19`, `persistent-postgresql`, `persistent-template`, `esqueleto` `>=3.5 && <3.7` - ORM/query layer in `src/DAL/` (`DAL.Schema`, `DAL.QueriesORM`, `DAL.MutationsORM`, `DAL.Types`) and `src/Surypus/DB/`.
- `hedis` `>=0.12 && <0.16` - Redis caching, streams and queues in `src/Core/Accounting/RedisCache.hs`, `src/Infrastructure/Redis/EventStream.hs`, `src/Infrastructure/Redis/TaskQueue.hs`, `src/System/JobQueue.hs`, `src/Surypus/WebSocket/RedisPublisher.hs`.
- `websockets` `>=0.12 && <0.14` - real-time channel at `/api/v1/ws` in `src/Surypus/WebSocket.hs`, accepted in `src/Surypus/API/Server.hs` (lines 190-199).
- `jose` `>=0.10 && <0.12` (constraint in `cabal.project`: `jose >=0.10 && <0.11`) plus `lens` and `cryptonite` - JWT HS256 signing/verification in `src/Surypus/JWT/Token.hs`, `src/Surypus/JWT.hs`.
- `katip` `>=0.8 && <0.9` - structured logging in `src/Surypus/API/Logger.hs` (`Katip.Scribes.Handle`).
- `http-conduit` / `http-client` / `http-client-tls` - outbound HTTP in `src/Surypus/API/AI.hs` and `src/Integration/API/ExternalAPI.hs`.
- `aeson` `>=2.1 && <2.3`, `yaml`, `Decimal`, `uuid`, `containers`, `stm`, `mtl`, `transformers` - serialization, money type, IDs, concurrency.

**Testing:**
- Hspec - aggregator entry point `test/Test.hs`; 65 test modules under `test/`; test target `surypus-test` in `Surypus.cabal`.
- QuickCheck - property tests in `test/QuickCheckInvariantsSpec.hs`, `test/Domain/InvariantsSpec.hs`.
- Integration specs gate on `SURYPUS_TEST_DATABASE_URL` / `SURYPUS_TEST_REDIS_URL` (`test/DAL/EventStoreIntegration.hs`, `test/Infrastructure/Redis/EventStreamSpec.hs`, `test/Infrastructure/EventStore/AccountingIntegration.hs`).
- Run commands: `stack test`, `stack test --test-arguments "--match 'VAT'"` (per `AGENTS.md`), or `cabal test` (`Makefile` targets `test-unit`, `test-integration`).

**Build/Dev:**
- Stack (`stack.yaml`), Cabal (`cabal.project`), GNU Make (`Makefile`), Nix flake (`flake.nix`, `flake.lock`).
- Docker multi-stage build - `Dockerfile` (builder `haskell:9.14.1`, runtime `debian:bookworm-slim`); Compose files `docker-compose.yml` (db/redis/api/worker) and `docker/docker-compose.yml` (postgres/opa/redpanda/redis/api/event-publisher/projection-builder/prometheus/grafana).
- GitHub Actions - 83 workflows in `.github/workflows/` (build+test `ci.yml`, `postgres-integration.yml`, `haskell-coverage.yml`, `haskell-hlint.yml`, `haskell-formatting.yml`, `liquidhaskell-verify.yml`, `codeql.yml`, `docker-publish.yml`, `documentation.yml`, `documentation-deploy.yml`, `hackage-publish.yml`, `sbom.yml`).
- Formatting/linting: `fourmolu` and `hlint` (`.hlint.yaml` is the default template; `Makefile` `format` uses `stylish-haskell`); 2-space indent and 100-column guidance in `AGENTS.md`.
- Documentation: MkDocs Material (`mkdocs.yml`, `docs/mkdocs.yml`, `docs/requirements.txt`), Haddock, Hoogle, doctest workflow described in `AGENTS.md`; generated artifacts under `docs/generated/`.

**Formal verification:**
- LiquidHaskell refinement annotations embedded as `{-@ ... @-}` in 28 modules (125 annotation lines), e.g. `src/Finance/Tax.hs`, `src/Finance/Accounting.hs`, `src/Finance/Currency.hs`, `src/Inventory/Stock.hs`, `src/System/Hardware.hs`, `src/Surypus/Refined.hs`.
- Verification job: `.github/workflows/liquidhaskell-verify.yml` (runs `liquid` on Finance/Inventory modules, skips with a warning if unavailable).

## Key Dependencies

**Critical:**
- `persistent` / `persistent-postgresql` / `esqueleto` - all relational persistence; raw SQL is also used heavily (`rawSql`, `rawExecute`) in `src/DAL/`, `src/Surypus/API/Server.hs`, `src/Integration/BankStatement.hs`.
- `servant` / `servant-server` / `wai` - entire HTTP surface; routes declared in `src/Surypus/API/Server.hs`.
- `hedis` - Redis cache, event fan-out, report task queue, Redis job queue.
- `jose` / `lens` / `cryptonite` - authentication tokens; `jose` is constrained to `<0.11` in `cabal.project`, so version bumps require a compatibility check.
- `aeson` - JSON at every API/database/event boundary.
- `Decimal` - money representation (`Money`/`Decimal` usage across `src/Finance/`, `src/Commerce/`).
- `katip` - production logging path.

**Infrastructure:**
- `resource-pool` (via `Data.Pool`) - PostgreSQL connection pools in `src/DAL/Database.hs`, `src/DAL/ORMPool.hs`, `src/Surypus/DB/Pool.hs`.
- `http-conduit` + `http-client-tls` - outbound calls (OpenAI, generic external APIs).
- `stm` - in-memory stores, metrics, rate limiter, secrets store, WebSocket rooms.
- `process` - shells out to `weasyprint` for PDF generation (`src/Surypus/API/Reports.hs:195`) and `pg_dump` for backups (`src/Surypus/API/Server.hs:910`).
- `temporary` - temp files for report rendering (`src/Surypus/API/Reports.hs`).
- `yaml` - DSL schema decoding (`src/DAL/Schema.hs`) and report template config.

## Configuration

**Environment:**
- Database (read by `src/Surypus/DB/Pool.hs:45-50`): `DB_HOST` (default `localhost`), `DB_PORT` (5432), `DB_NAME`, `DB_USER`, `DB_PASSWORD` (development defaults are hardcoded in that module), `DB_POOL_SIZE` (10).
- A second, alternative pool in `src/DAL/Database.hs:44` is a hardcoded localhost DSN with fixed development credentials; it does not read environment variables.
- JWT: `SURYPUS_JWT_SECRET` (required; `src/Surypus/JWT/Token.hs:75` fails startup with a clear error if unset).
- AI: `SURYPUS_OPENAI_API_KEY` (`src/Surypus/API/AI.hs:75`).
- Email: `SMTP_HOST`, `SMTP_PORT`, `SMTP_USER`, `SMTP_PASS`, `SMTP_FROM`, `SMTP_FROM_NAME`, `EMAIL_OUTPUT_FILE` (`src/Email.hs:59-65`).
- Tests: `SURYPUS_TEST_DATABASE_URL`, `SURYPUS_TEST_REDIS_URL` (integration specs only).
- Compose-only variables (not read by Haskell code): `DATABASE_URL`, `REDIS_URL`, `OPA_URL`, `KAFKA_BROKERS`, `APP_ENV`, `POSTGRES_PASSWORD`, `PORT` (`docker/docker-compose.yml`, `docker-compose.yml`).
- Redis is **not** environment-configured in code; defaults are `localhost:6379` database `0` (`src/Core/Accounting/RedisCache.hs:58-70`).
- `.env.example` and `docker/.env.production` exist; contents are intentionally not reproduced here. `.gitignore` ignores `.env` / `.env.*` but keeps `!.env.example`.

**Build:**
- `stack.yaml` / `stack.yaml.lock` - resolver `lts-22.21`, `-Wall` for local packages, hashtables portability flags.
- `cabal.project` - package constraints (`base >=4.16 && <4.22`, `crypton -any`, `cryptonite ==0.30`, `jose >=0.10 && <0.11`, `postgresql-binary >=0.12`).
- `Surypus.cabal` - 566 lines; library with 381 exposed modules, `surypus-server` executable (`app/Main.hs`), `surypus-test` test suite.
- Frontend: `frontend/CMakeLists.txt` (CMake >=3.16, C++17); AppImage packaging in `packaging/AppImage/build-appimage.sh`.
- Docs: `mkdocs.yml` and `docs/mkdocs.yml` point at `docs/` with ReadTheDocs theme and Python 3.11 toolchain (`flake.nix`).

## Project Subprojects

- **Haskell library + tests (primary):** `src/`, `test/`, `app/`, `Surypus.cabal` (382 `src` modules, 65 `test` modules).
- **Code generator:** `tools/surypus-codegen/` (`surypus-codegen.cabal`, `Main.hs`) consumes `dsl/schema.yaml`; documentation helpers in `tools/documentation/`.
- **Qt6/QML desktop client:** `frontend/` (C++17 + QML), packaged as AppImage via `packaging/AppImage/`.
- **PWA web client:** `web/` (vanilla JS, service worker, axios, Chart.js), served as static assets copied by `Dockerfile`.
- **Haskell API client sample:** `clients/haskell/SurypusClient.hs` (standalone, no cabal target; uses `http-client`/`http-client-tls`).
- **API contracts:** `api/grpc/surypus.proto` (gRPC), `api/rest/openapi.yaml`, `openapi/openapi.yaml`, `static/swagger.json`, plus a GraphQL HTTP endpoint implemented ad hoc in `src/Surypus/API/GraphQL.hs`.
- **Database assets:** `sql/` (migrations, aggregates, projections, policies, seeds), `config/*.sql` (legacy/alternate schemas), `config/grafana/` (datasource + dashboard), `prometheus/prometheus.yml`.
- **Policy:** `opa/policies/` (Rego RBAC/inventory rules).
- **Repository task tracking:** `.beads/` (Dolt-backed beads issue tracker), mirrored by `tools/beads-sync-github.py` and `.github/workflows/beads-sync-github.yml`.

## Platform Requirements

**Development:**
- GHC 9.6.5 + Stack (or Cabal 3.10+), `libpq`, `libssl`, `zlib`.
- PostgreSQL 16 and Redis 7 for integration tests and local runs.
- Optional: OPA, Redpanda/Kafka (Compose profile), Qt 6 + CMake for the desktop client, Python 3.11 for docs.
- Nix users can enter the dev shell from `flake.nix` (stack, cabal, HLS, hlint, fourmolu, ghcid, postgresql_16, python311 + mkdocs).

**Production:**
- Container image built from `Dockerfile`, deployed as `surypus-server` on Debian bookworm-slim, port 8080 (`ENV PORT=8080`), `dumb-init`, healthcheck `GET /api/v1/health`.
- Reference deployment: PostgreSQL 16, Redis 7, OPA, Redpanda, Prometheus, Grafana via `docker/docker-compose.yml`; image publication to GHCR via `.github/workflows/docker-publish.yml`.
- Health endpoints implemented in `src/Surypus/API/Server.hs` (`/api/v1/health`, `/api/v1/health/db`); metrics at `/api/v1/metrics`.

**Build status note:** the most recent recorded build log `build.log` ends in a failed `stack build` while compiling the test suite with GHC 9.6.5 (`test/AdditionalTests` / `TranscendenceSpec` warnings, then `ExitFailure 1`). Verify with a fresh `stack build` before relying on binaries.

---

*Stack analysis: 2026-10-23*
