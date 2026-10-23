# Phase 1: Bootstrap & Schema Truth — Pattern Map

**Mapped:** 2026-10-23
**Files analyzed:** 27 (12 new, 12 modified, 3 doc/config remnants)
**Analogs found:** 22 / 27 (5 with no close analog — see bottom)
**Sources:** `01-RESEARCH.md` (authoritative file list), `01-VALIDATION.md` (Wave 0 test files), `ROADMAP.md` (goal/success criteria)

> **Tracked-source gate:** every analog path below is git-tracked (`git ls-files -- <path>` non-empty). No `.gsd/capabilities/*` or other gitignored mirror is referenced.

---

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|-------------------|------|-----------|----------------|---------------|
| `src/Surypus/Config.hs` **(new)** | config | process-bootstrap / transform | `src/Surypus/DB/Pool.hs` (`mkDBConfig`) | role-match |
| `src/Surypus/DB/Migrate.hs` **(new)** | service (CLI+DB) | batch + transactional DDL | `src/DAL/Database.hs` + `src/DAL/EventStore.hs` | partial (no `postgresql-simple` analog) |
| `app/Main.hs` **(modified)** | executable / bootstrap | request-response + subcommand dispatch | `src/Surypus/API/Server.hs` (`apiServer` wiring) + `src/Surypus/DB/Pool.hs` | role-match |
| `src/Surypus/DB/Pool.hs` **(modified)** | utility (resource lifecycle) | request-response (pooled) | itself | exact |
| `src/Surypus/API/Server.hs` **(modified)** | middleware/handler (WAI) | request-response | itself (`healthEndpoint`, `metricsEndpoint`) | exact |
| `sql/migrations/V001__bootstrap.sql` **(new)** | migration | batch DDL | `sql/migrations/V001__core_schema.sql` | exact |
| `sql/migrations/V002__schema_truth_forward.sql` **(new)** | migration | idempotent DDL reconciliation | `sql/migrations/V015__tenants_table.sql`, `V016__rls_policies.sql` | exact |
| `test/Surypus/ConfigSpec.hs` **(new)** | test (unit) | pure | `test/Surypus/API/GraphQLSpec.hs`, `test/ConfigSpec.hs` | exact |
| `test/DB/MigrationRunnerSpec.hs` **(new)** | test (unit + integration) | batch / DB | `test/DAL/EventStoreIntegration.hs` | role-match |
| `test/API/HealthSpec.hs` **(new)** | test (HTTP/WAI) | request-response | `test/Surypus/API/GraphQLSpec.hs` (lazy pool) | partial |
| `test/Test.hs` **(modified)** | test aggregator | — | itself | exact |
| `Surypus.cabal` **(modified)** | build config | — | itself | exact |
| `scripts/check-toolchain.sh` **(new)** | script (CI guard) | file-inspection, exit codes | `scripts/check_schema_uniqueness.sh` | exact |
| `scripts/create_test_db.sh` **(new, Wave 0 helper)** | script (DB provisioning) | batch | `scripts/setup_test_db.sh`, `scripts/ci-dry-run-mig.sh` | role-match |
| `.github/workflows/ci.yml` **(modified)** | CI config | — | `ci.yml` build steps + `postgres-integration.yml` service block | exact |
| `.github/workflows/postgres-integration.yml` **(modified or retired)** | CI config | — | `ci.yml` | role-match |
| `cabal.project` **(modified)** | build config | — | itself | exact |
| `Dockerfile` **(modified)** | container config | — | itself | exact |
| `.devcontainer/devcontainer.json` **(modified)** | dev-env config | — | itself | exact |
| `.env.example` **(modified)** | config documentation | — | itself | exact |
| `Makefile` **(modified)** | ops script | batch | itself (`migrate` target) | exact |
| `src/Surypus/DB/Schema.hs` **(modified)** | dead-code removal | — | itself (`runMigrations`) | exact |
| `AGENTS.md`, `ENV_VARS.md`, `docs/API.md`, `STATE.md` **(modified)** | docs | — | themselves | exact |
| `sql/migrations/V*.sql` (329→359 files) + `init_db.sh` **(moved)** | migration archive | — | `sql/migrations/init_db.sh` (dual-ledger anti-pattern) | exact (move, no edit) |

---

## Pattern Assignments

### `src/Surypus/Config.hs` (config, process-bootstrap)

**Analog:** `src/Surypus/DB/Pool.hs`

**Env-read pattern** (`src/Surypus/DB/Pool.hs:42-60`) — this is the *only* env-reading DB pattern in the tree; copy its `lookupEnv` + `readMaybe` mechanics, but **drop all silent secret defaults** (`password <- maybe "surypus_password"`):

```haskell
mkDBConfig :: IO DBConfig
mkDBConfig = do
  host <- maybe "localhost" T.pack <$> lookupEnv "DB_HOST"
  port <- fromMaybe 5432 . (>>= readMaybe) <$> lookupEnv "DB_PORT"
  name <- maybe "surypus" T.pack <$> lookupEnv "DB_NAME"
  user <- maybe "surypus" T.pack <$> lookupEnv "DB_USER"
  password <- maybe "surypus_password" T.pack <$> lookupEnv "DB_PASSWORD"
  poolSize <- fromMaybe 10 . (>>= readMaybe) <$> lookupEnv "DB_POOL_SIZE"
  let timeout = secondsToNominalDiffTime 30
  pure DBConfig { dbHost = host, ... }
```

**Reuse the existing log-level enum** — do **not** define a second one (`src/Surypus/API/Logger.hs:33`):

```haskell
data LogLevel = Debug | Info | Warn | Error deriving (Show, Eq, Ord, Enum, Bounded)
```

**Fail-fast precedent to improve on** (`src/Surypus/JWT/Token.hs:75-78`) — currently fails on first problem with `error`; `loadConfig` must instead collect *all* problems and `die`:

```haskell
getSigningKey :: IO LBS.ByteString
getSigningKey = do
    mbSecret <- lookupEnv "SURYPUS_JWT_SECRET"
    case mbSecret of
        Nothing -> error "FATAL: SURYPUS_JWT_SECRET environment variable is not set. ..."
        Just s -> pure $ LBS.fromStrict $ TE.encodeUtf8 $ T.pack s
```

**Module header style** (project convention, `src/Surypus/DB/Pool.hs:1-10`):

```haskell
{-# LANGUAGE OverloadedStrings #-}

module Surypus.DB.Pool
  ( DBConfig(..)
  , Pool(..)
  , createPool
  ...
  ) where
```

Haddock on the exported record and on `loadConfig` (AGENTS.md documentation protocol, L2 minimum). RESEARCH §Code Examples gives the full `loadConfig` body to adapt.

---

### `src/Surypus/DB/Migrate.hs` (service, batch + transactional DDL)

**Analogs:** `src/DAL/Database.hs` (connection ownership), `src/DAL/EventStore.hs` (parameterised raw SQL, typed row parsing).

**Pool/connection pattern to *not* copy** (`src/DAL/Database.hs:30-43`) — hard-coded DSN, global `IORef`, no transaction helper. Phase 1 must take a `Config`/DSN argument and a dedicated connection, not this:

```haskell
createPool :: IO ConnectionPool
createPool = runNoLoggingT $ createPostgresqlPool (pack "host=localhost port=5432 dbname=surypus user=postgres password=postgres") 10
```

**Parameterised SQL / typed result pattern** (`src/DAL/EventStore.hs:136-155`) — the house style for raw SQL, including placeholders `?` and `PersistValue` list. The runner's advisory-lock queries should follow the same shape (via `postgresql-simple`'s `query_`/`execute`):

```haskell
appendEvent :: ConnectionPool -> Event -> IO (Either Text ())
appendEvent pool event = do
  now <- getCurrentTime
  let sql = "INSERT INTO event_store (\
            \  aggregate_id, aggregate_type, event_type, event_version, \
            \  event_schema_version, event_data, event_metadata, \
            \  sequence_number, occurred_at, created_at) \
            \VALUES (?, ?, ?, ?, ?, ?::jsonb, ?::jsonb, ?, ?, ?)"
  result <- runDb pool $ rawExecute sql [ PersistInt64 ..., PersistText ... ]
  return $ Right ()
```

**Error-handling envelope** (`src/DAL/EventStore.hs:136,154` / `src/DAL/Classifiers.hs:46-50`): return `Either Text a` from library code, format `FATAL: …` only at `app/Main.hs`. Never `error` inside `Migrate`.

**Division of labour (from RESEARCH §Migration Runner, must be honoured):**

| Concern | Owner |
|---|---|
| filename grammar, duplicate detection, numeric ordering | `preflight` in this module (pure, `Either [String] [(Integer, FilePath)]`) |
| advisory lock (`pg_try_advisory_lock`) | this module (one query) |
| reading/executing `.sql`, checksums, ledger, per-file transaction | `postgresql-migration` (`optTableName = "surypus_schema_migrations"`, `TransactionPerStep`) |
| exit codes and message formatting | `app/Main.hs` |

Do **not** copy `sql/migrations/init_db.sh`'s dual-ledger logic (`schema_version` + `schema_migrations`; `sql/migrations/init_db.sh:8-28`). It is the anti-pattern the library replaces.

**No analog for `postgresql-simple` usage** — there is zero `import Database.PostgreSQL.Simple` in `src/` (only a stale `src/DAL/Database.hi`). Use RESEARCH §Runner + Hackage module docs; do not mimic `persistent` semantics (`runSqlPool`, `rawSql`) for this module.

---

### `app/Main.hs` (executable/bootstrap, subcommand dispatch)

**Current file is a stub** (`app/Main.hs:1-7`) — full replacement required:

```haskell
{-# LANGUAGE OverloadedStrings #-}
module Main where

main :: IO ()
main = do
  putStrLn "Surypus ERP prototype (Phase 1)"
  putStrLn "GHC 9.6.5 | Stack | CI green"
```

**Exact composition contract** (`src/Surypus/API/Server.hs:183`):

```haskell
apiServer :: ConnectionPool -> Log.Logger -> Metrics -> [Text] -> (Int64 -> Text -> IO Bool) -> IO Application
apiServer connPool logger metrics publicPaths checkPermission = do
```

**Default-deny authorizer** — `withAuthzResolverAdvanced publicPaths checkPermission` is applied at `src/Surypus/API/Server.hs:205`. `Main` must pass `(\_ _ -> pure False)` (RESEARCH §Server Bootstrap trap; Phase 6 replaces it). Never pass `(\_ _ -> pure True)`.

**Pool lifecycle** (`src/Surypus/DB/Pool.hs:72-87`):

```haskell
createPool :: IO Pool
createPool = do
  cfg <- mkDBConfig
  pool <- runNoLoggingT $ PG.createPostgresqlPool
    (pack (T.unpack (connString cfg)))
    (dbPoolSize cfg)
  pure (Pool pool)

-- | Close pool
closePool :: Pool -> IO ()
closePool (Pool p) = destroyAllResources p
```

Wrap in `bracket Pool.createPool Pool.closePool $ \pool -> ...` (RESEARCH §Server Bootstrap trap 3).

**Subcommand shape:** single executable, no second `executable` stanza (Pitfall 5 — two executables break bare `stack run`). `Options.Applicative` has **no existing use anywhere in `src/`, `app/`, `test/`** (verified: `grep -rl Options.Applicative` → no files). Use the RESEARCH §Thin entrypoint sketch verbatim rather than searching for a house pattern.

**`publicPaths` value** must match the list at RESEARCH §Thin entrypoint (`health`, `health/db`, `metrics`, `login`) so health stays unauthenticated — consistent with `baseApp = healthEndpoint connPool servantApp` being outside the middleware chain (`src/Surypus/API/Server.hs:199-207`).

---

### `src/Surypus/DB/Pool.hs` (utility, resource lifecycle — modified)

**Changes only:** export `mkDBConfig` and `connString`; prefer `DATABASE_URL` over `DB_*`.

Current export list (`src/Surypus/DB/Pool.hs:3-10`) is missing both:

```haskell
module Surypus.DB.Pool
  ( DBConfig(..)
  , Pool(..)
  , createPool
  , closePool
  , runQuery
  , poolStats
  ) where
```

**Existing connString builder** (`src/Surypus/DB/Pool.hs:63-70`) — keep byte-identical output format for the `DB_*` fallback path; add a `DATABASE_URL` short-circuit *before* it:

```haskell
connString :: DBConfig -> Text
connString cfg =
  "host=" <> dbHost cfg
  <> " port=" <> T.pack (show (dbPort cfg))
  <> " dbname=" <> dbName cfg
  <> " user=" <> dbUser cfg
  <> " password=" <> dbPassword cfg
```

Do **not** log `connString` (contains password). RESEARCH §Security Domain V7.

---

### `src/Surypus/API/Server.hs` (WAI handler — modified)

**Analog:** itself. Current health handler (`src/Surypus/API/Server.hs:210-220`):

```haskell
healthEndpoint :: ConnectionPool -> Application -> Application
healthEndpoint connPool app req respond =
    case W.rawPathInfo req of
        "/api/v1/health" -> do
            respond $ W.responseLBS status200 [("Content-Type", "text/plain")] "OK"
        "/api/v1/health/db" -> do
            result <- runSqlPool (rawSql "SELECT 1 as health" []) connPool
            case result of
                [Single (1 :: Int64)] -> respond $ W.responseLBS status200 [("Content-Type", "text/plain")] "DB OK"
                _ -> respond $ W.responseLBS status503 [("Content-Type", "text/plain")] "DB ERROR"
        path -> do
            let pathStr = TE.decodeUtf8 path
            if "/api/v1/reports/download/" `DT.isPrefixOf` pathStr
                then do
                    let filename = DT.replace "/api/v1/reports/download/" "" pathStr
                    Reports.serveReportFile filename req respond
                else app req respond
```

Required change: both paths → same `probe`, wrapped in `try :: IO (Either SomeException [Single Int64])`, `200 "OK"` / `503 "DB UNAVAILABLE"`, constant body. Keep `status503` import (`Network.HTTP.Types`, already imported at `src/Surypus/API/Server.hs:38`).

**Structural constraint:** `healthEndpoint` is **not exported** — module exports only `apiServer` (`src/Surypus/API/Server.hs:11`). For `test/API/HealthSpec.hs` to test it directly, either add `healthEndpoint` to the export list, or test through `apiServer` (which needs a `Logger`, `Metrics`, `ConnectionPool`, `[Text]`, authorizer). Prefer exporting `healthEndpoint` — smaller, no middleware side effects.

**WAI wrapper pattern to mirror** (`metricsEndpoint`, `src/Surypus/API/Server.hs:222-230`): path match → `respond` → fall through to `app req respond`. Same shape, same Content-Type style.

Do not move health inside the `servantApp` middleware chain (`src/Surypus/API/Server.hs:199-206`); doing so adds auth/rate-limit/tenant to a liveness probe.

---

### `sql/migrations/V001__bootstrap.sql` (migration, batch DDL)

**Analog:** `sql/migrations/V001__core_schema.sql` (final-shape `CREATE TABLE IF NOT EXISTS` corpus — the style is right, the *content* must be reconciled per RESEARCH table).

**Header + sequence + table style** (`sql/migrations/V001__core_schema.sql:1-40`):

```sql
-- Migration V001: Core schema (RBAC, Accounts, Journals, Bills, Payments, Taxes, Event Store)
-- Consolidated from original V001 and Phase 2 tables

CREATE SEQUENCE IF NOT EXISTS users_id_seq;
...
CREATE TABLE IF NOT EXISTS users (
  id BIGINT PRIMARY KEY DEFAULT NEXTVAL('users_id_seq'),
  user_id UUID UNIQUE,
  username TEXT UNIQUE NOT NULL,
  ...
  created_at TIMESTAMPTZ DEFAULT NOW()
);
```

**Shape rules the canonical file must enforce** (from RESEARCH §Migration Corpus Audit reconciliation table):

- `bills`: keep `V001` base (`id BIGINT`, `number`, `date`, `currency`, `total_amount`, `status`) + add every `DAL.MutationsORM:180` column (`bill_number`, `bill_date`, `customer_id`, `vendor_id`, `warehouse_id`, `currency_id`, `bill_status`, `bill_type`, `subtotal`, `tax_amount`, `paid_amount`, `notes`, `created_at`, `updated_at`) + `tenant_id BIGINT NOT NULL DEFAULT 0`.
- `payments`: keep `V001` base (`sql/migrations/V001__core_schema.sql:104-114`) + `payment_date`, `payment_method` (per `DAL.MutationsORM:363`) + `tenant_id`.
- `accounts`: keep `V001` shape (`:67-78`) + `tenant_id`; do **not** create `chart_of_accounts`.
- `tax_rates`: keep `V001` (`:116-122`); do **not** create the `SERIAL id` variant from `V256`.
- `event_store`: exactly the ten columns written by `src/DAL/EventStore.hs:136-145` **plus** `tenant_id BIGINT NOT NULL DEFAULT 0` (i.e. includes `event_schema_version`, which `V1000` omits).
- Extensions: `pgcrypto` + `uuid-ossp` only (no `postgis`, no `vector`).
- Exactly **one** definition per table. `CREATE TABLE IF NOT EXISTS` is not a conflict-resolution tool (RESEARCH Pitfall 2).

`app.current_tenant_id()` stays owned by `V002` (see below), not `V001` — it is a reconciliation helper, and `V016` already defines the correct BIGINT signature.

---

### `sql/migrations/V002__schema_truth_forward.sql` (migration, idempotent DDL)

**Analogs:** `sql/migrations/V015__tenants_table.sql` (idempotent `ADD COLUMN IF NOT EXISTS` + default row) and `sql/migrations/V016__rls_policies.sql` (functions, `DO $$` loops, exception tolerance).

**Idempotent ALTER pattern** (`sql/migrations/V015__tenants_table.sql:19-29`):

```sql
-- Add tenant_id to users table
ALTER TABLE users ADD COLUMN IF NOT EXISTS tenant_id BIGINT NOT NULL DEFAULT 0;
CREATE INDEX IF NOT EXISTS idx_users_tenant ON users (tenant_id);

-- Insert default tenant for existing data
INSERT INTO tenants (id, name, slug, schema_name, is_active)
VALUES (0, 'Default Tenant', 'default', 'public', TRUE)
ON CONFLICT (id) DO NOTHING;
```

**Function pattern** (`sql/migrations/V016__rls_policies.sql:8-27`) — `CREATE OR REPLACE`, `LANGUAGE SQL STABLE`, `COALESCE(NULLIF(current_setting(...)))`:

```sql
CREATE SCHEMA IF NOT EXISTS app;

CREATE OR REPLACE FUNCTION app.current_tenant_id()
RETURNS BIGINT AS $$
  SELECT COALESCE(NULLIF(current_setting('app.tenant_id', TRUE), ''), '0')::BIGINT;
$$ LANGUAGE SQL STABLE;
```

**Constraint:** V002 may use **only** `ADD COLUMN IF NOT EXISTS`, `CREATE INDEX IF NOT EXISTS`, `CREATE OR REPLACE FUNCTION`, `ON CONFLICT DO NOTHING`. No `CREATE TABLE`, no `DROP`, no data rewrite. On a fresh DB every statement must be a no-op.

**Tenant type decision is locked:** `tenant_id BIGINT NOT NULL DEFAULT 0` everywhere (115 UUID occurrences in legacy vs 4 BIGINT, and all Haskell uses `Int64`). Do not reproduce `tenant_id UUID` from `V256`.

---

### `test/Surypus/ConfigSpec.hs` (test, unit)

**Analogs:** `test/Surypus/API/GraphQLSpec.hs` (module/test layout) and `test/ConfigSpec.hs` (naming collision warning).

**Spec module shape** (`test/Surypus/API/GraphQLSpec.hs:1-7`):

```haskell
{-# LANGUAGE OverloadedStrings #-}

-- | Tests for the GraphQL proxy (US-3-4).
-- ...
module Surypus.API.GraphQLSpec (spec) where

import Test.Hspec
...
spec :: Spec
spec = do
  describe "resolveQuery" $ do
    it "rejects an empty query" $ do
      ...
      result `shouldBe` Left "Empty query"
```

**Name collision:** `test/ConfigSpec.hs` (module `ConfigSpec`) already exists and tests `Surypus.Domain.Config.Config` defaults (`test/ConfigSpec.hs:1-11`). The new file is `test/Surypus/ConfigSpec.hs`, module `Surypus.ConfigSpec` — do not overwrite the old one, and register both.

**Testing `loadConfig`:** it reads real env. Either (a) take an injectable lookup (`loadConfigWith :: (String -> IO (Maybe String)) -> IO Config`) and test purely, or (b) use `System.Environment.setEnv/unsetEnv` around each case with `before_`/`after_`. Prefer (a): the "names *all* missing vars" assertion then needs no process-global mutation. `System.Environment` is in `base` — no new test dependency.

---

### `test/DB/MigrationRunnerSpec.hs` (test, unit + integration)

**Analog:** `test/DAL/EventStoreIntegration.hs` — the established "integration spec that pends when no DB" pattern:

```haskell
spec :: Spec
spec = do
  mConn <- runIO (lookupEnv "SURYPUS_TEST_DATABASE_URL")
  case mConn of
    Nothing ->
      it "requires SURYPUS_TEST_DATABASE_URL" $
        pendingWith
          "set SURYPUS_TEST_DATABASE_URL=postgresql://user:pass@host:5432/db \
          \to run the event store integration tests"
    Just url ->
      beforeAll (runNoLoggingT (createPostgresqlPool (BC.pack url) 2)) $
        afterAll closePool EventStoreSpec.spec
```

**Improvement required by BOOT-05:** BOOT-05 says DB tests must *run*, not pend. Structure the spec in two blocks: pure `preflight` cases (always run, no env needed) and integration cases gated on `SURYPUS_TEST_DATABASE_URL` — but in CI the var is set by `ci.yml`, and the phase gate must fail if it is unset. Recommended shape: a single `it "SURYPUS_TEST_DATABASE_URL is set" $ ... shouldSatisfy isJust` only when `CI=true`; otherwise keep the `pendingWith` for local dev.

**Cases to assert** (RESEARCH §Migration Runner table): numeric order on empty DB, idempotent re-run, edited-applied-file checksum failure, duplicate prefix pre-flight failure *without opening a connection*, concurrent advisory-lock failure, mid-file rollback, `--check`, `--dry-run`.

**Error substrings** (assert exactly, RESEARCH §Migration Runner):
- `FATAL: duplicate migration number 1: V001__core_schema.sql, V001__generated_orm.sql`
- `FATAL: migration V002__schema_truth_forward.sql changed after it was applied (checksum mismatch)`
- `FATAL: another migration is running (advisory lock surypus.migrate is held)`
- `FATAL: migration V003__x.sql failed: ERROR: …`

**Scratch-DB isolation:** do not assume leftover state. Use a per-run database name (see `scripts/create_test_db.sh` below) and `beforeAll` to create it, `afterAll` to drop it.

---

### `test/API/HealthSpec.hs` (test, HTTP/WAI)

**Partial analog:** `test/Surypus/API/GraphQLSpec.hs:47-48` — the lazy-pool trick that makes a "DB unreachable" case deterministic and instant:

```haskell
  where
    newPool = runNoLoggingT $ createPostgresqlPool (pack "host=127.0.0.1 port=1 dbname=x user=x password=x") 1
```

`createPostgresqlPool` does **not** connect (RESEARCH §Health Endpoint: "the pool is lazy"), so a pool at `port=1` is a valid "DB down" fixture and the probe returns 503 on first use.

**Required build-depends additions:** `surypus-test` currently has **no `wai`/`wai-extra`/`warp`** in `build-depends` (`Surypus.cabal:543-567` lists base, Surypus, hspec, QuickCheck, text, time, aeson, stm, containers, Decimal, yaml, transformers, bytestring, http-conduit, http-client, http-types, persistent-postgresql, hedis, monad-logger, vector, directory, filepath). To call the WAI `Application` in-process, add `wai` and `wai-extra` (for `Network.Wai.Test`). No existing test uses `Network.Wai.Test` — there is no house pattern here.

**Three cases (BOOT-02):**
1. reachable DB → `status200`, body exactly `"OK"`.
2. unreachable DB (`port=1` pool) → `status503`, body exactly `"DB UNAVAILABLE"`.
3. body must contain no driver text/DSN — assert `body \`shouldNotSatisfy\` T.isInfixOf "postgres"` / no exception message leakage.

Both `/api/v1/health` and `/api/v1/health/db` must produce the same status/body.

---

### `test/Test.hs` (test aggregator — modified)

**Analog:** itself. Add three imports alongside the existing block (`test/Test.hs:6-69`), then three calls in `main` (`test/Test.hs:71-120`). Existing pattern:

```haskell
import qualified ConfigSpec
...
import qualified DAL.EventStoreIntegration

main :: IO ()
main = hspec $ do
  ConfigSpec.spec
  ...
  DAL.EventStoreIntegration.spec
```

New entries: `import qualified Surypus.ConfigSpec`, `import qualified DB.MigrationRunnerSpec`, `import qualified API.HealthSpec`; call `.spec` in `main`. Ordering: keep pure specs before DB-touching ones (existing file already groups loosely; append DB specs near `DAL.EventStoreIntegration`).

---

### `Surypus.cabal` (build manifest — modified)

**Analog:** itself. Four distinct edit points:

**Library deps** (`Surypus.cabal:408-450`; add after `persistent-postgresql` at `:416`):

```cabal
    , postgresql-migration >=0.2 && <0.3
    , postgresql-simple    >=0.7 && <0.8
    , optparse-applicative >=0.18 && <0.19
```

**Exposed modules** (`Surypus.cabal:315-325` — insert alphabetically):

```cabal
    Surypus.API.Server
    ...
    Surypus.Config          -- NEW
    Surypus.DB.Migrate      -- NEW
    Surypus.DB.Pool
    Surypus.DB.Schema
```

**Executable** (`Surypus.cabal:451-472`) — add `optparse-applicative` only if the parser lives in `app/Main.hs`; if it lives in `Surypus.CLI`, nothing is added here (RESEARCH §Installation alternative):

```cabal
executable surypus-server
  default-language: Haskell2010
  hs-source-dirs: app
  main-is: Main.hs
  build-depends:
    base >=4.12 && <5
    , Surypus
    , wai
    , wai-extra
    , warp
    ...
    , network
  default-extensions: OverloadedStrings
```

**Test suite** (`Surypus.cabal:475-567`) — add to `other-modules` (alongside the existing 60+ entries, `:480-542`):

```cabal
      Surypus.ConfigSpec
      DB.MigrationRunnerSpec
      API.HealthSpec
      DAL.EventStoreSpec        -- file exists at test/DAL/EventStoreSpec.hs, currently absent (BOOT-05 / Wave 0)
```

and to `build-depends` (`:543-567`): `wai`, `wai-extra` (for `Network.Wai.Test`). `postgresql-simple` arrives transitively via `Surypus`, but list it explicitly if the spec imports it directly.

---

### `scripts/check-toolchain.sh` (script, CI guard)

**Analog:** `scripts/check_schema_uniqueness.sh` — the strictest shell convention in the repo (strict mode, `ROOT_DIR` resolved from `BASH_SOURCE`, non-zero exit on violation):

```bash
#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
```

**Exit-code discipline** (same file, `:46-52`): print every offending item, then `sys.exit(1)`; print a success line and `exit 0` (`:15`). Mirror that.

**What to grep (five sources, RESEARCH §Toolchain Truth):**

| Source | Assert |
|---|---|
| `stack.yaml:1` | `resolver: lts-22.21` |
| `cabal.project` | `with-compiler: ghc-9.6.5` |
| `Dockerfile:9` | `FROM haskell:9.6.5` |
| `.devcontainer/devcontainer.json:8` | `"ghcVersion": "9.6.5"` |
| `.github/workflows/ci.yml` + `postgres-integration.yml` | `stack-version: '3.7.1'` (not `latest`) |

**Anti-pattern to avoid:** `scripts/setup_test_db.sh:44-49` runs `psql -f` without `ON_ERROR_STOP` and `postgres-integration.yml:69-71` adds `|| echo "Migration $f skipped"`. `check-toolchain.sh` must fail loudly, never "skip".

**Contrast (good pattern):** `scripts/ci-dry-run-mig.sh:51-58` uses `psql "$conn" -v ON_ERROR_STOP=1` and captures the first `ERROR:` line — copy that failure-reporting style if the script ever needs to report multiple mismatches.

---

### `scripts/create_test_db.sh` (script, DB provisioning — new, Wave 0)

**Analog:** `scripts/setup_test_db.sh` (structure/UX) — but **fix its two defects**:

```bash
#!/bin/bash
set -e
DB_NAME="surypus_test"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
...
PGPASSWORD="" psql -h localhost -U "$DB_USER" -d postgres \
  -c "DROP DATABASE IF EXISTS $DB_NAME;" 2>/dev/null || true
```

Defects: (a) hard-coded `postgres` superuser, ignores `DATABASE_URL`; (b) iterates `sql/migrations/V*.sql` with `psql -f` and **no** `ON_ERROR_STOP` (`scripts/setup_test_db.sh:44-49`).

**Required design:** take the admin DSN from `SURYPUS_TEST_ADMIN_URL` (or `DATABASE_URL`), create `surypus_test_${CI_RUN_ID:-$$}`, run `stack run -- migrate`, echo the resulting URL as `SURYPUS_TEST_DATABASE_URL=...`, and **never** loop over SQL files. This is the "scratch-database provisioning helper" in `01-VALIDATION.md:69`.

Use `set -euo pipefail` (the newer convention in `scripts/check_schema_uniqueness.sh`), not `set -e`.

---

### `.github/workflows/ci.yml` (CI — modified)

**Analogs:** service block from `.github/workflows/postgres-integration.yml:16-31`; build steps from current `.github/workflows/ci.yml:20-45`.

**Service block to copy** (`postgres-integration.yml:16-31`):

```yaml
    services:
      postgres:
        image: postgres:16
        env:
          POSTGRES_PASSWORD: postgres
          POSTGRES_DB: surypus_test
          POSTGRES_USER: postgres
        options: >-
          --health-cmd pg_isready
          --health-interval 10s
          --health-timeout 5s
          --health-retries 5
        ports:
          - 5432:5432
```

**Current build steps to keep** (`ci.yml:20-45`) — checkout with submodules, stack cache, `stack --no-nix build --test --no-run-tests --no-haddock-deps`, `stack --no-nix test --test-arguments --color` (note: `--color` is a flag, never `--color=never` — RESEARCH Pitfall 7).

**What must change:**
1. Pin `stack-version: '3.7.1'` — `postgres-integration.yml:40` currently uses `'latest'`.
2. Add `./scripts/check-toolchain.sh` **before** `stack build` (RESEARCH §Code Examples CI job).
3. Set **both** `DATABASE_URL` and `SURYPUS_TEST_DATABASE_URL` (Pitfall 6 — current workflow sets only `DATABASE_URL:81` while specs read `SURYPUS_TEST_DATABASE_URL:22`).
4. Add `stack --no-nix run -- migrate` between build and test.
5. Add a smoke step: `stack run &` then `curl -f http://localhost:$PORT/api/v1/health`.
6. Remove the `|| echo "Migration $f skipped"` / `|| echo "No test found"` fallbacks from any workflow that remains.

**Do not copy:** `db-schema-versioning.yml:56-80` and `health-checks.yml` — both apply all SQL with `psql -f` and swallow errors, and both use `stack-version: 'latest'`.

---

### `cabal.project`, `Dockerfile`, `.devcontainer/devcontainer.json`, `.env.example`, `Makefile` (config — modified)

**Analog:** each file itself. Concrete edits, with the current values verified:

| File | Current | Required |
|---|---|---|
| `cabal.project:4-14` | only `constraints:` block, no compiler pin | add `with-compiler: ghc-9.6.5` (+ optional `index-state: 2024-05-06T00:00:00Z`) |
| `Dockerfile:9` | `FROM haskell:9.14.1 AS builder` | `FROM haskell:9.6.5 AS builder` |
| `.devcontainer/devcontainer.json:8` | `"ghcVersion": "9.6.6"` | `"ghcVersion": "9.6.5"` |
| `.env.example:6-24` | `APP_PORT`, `LOG_LEVEL=INFO`, `DATABASE_URL`, `DB_*`, `JWT_SECRET` | canonical `DATABASE_URL`, `SURYPUS_JWT_SECRET` (placeholder), `PORT`, `LOG_LEVEL=info`; `DB_*` documented as one-release fallback |
| `Makefile:27-36` | `migrate` applies **only** `sql/migrations/V100__event_sourcing_init.sql`; `migrate-test` applies only two `sql/test/` files | delegate to `stack run -- migrate` (the one canonical path); keep `seed` unchanged |

`.devcontainer` and `Dockerfile` edits are pure version-string changes — no structural pattern to copy.

**`Makefile` anti-pattern:** the current `migrate` target is actively misleading (RESEARCH §State of the Art). Replace, do not extend.

---

### `src/Surypus/DB/Schema.hs` (dead-code removal — modified)

Remove `runMigrations` (`src/Surypus/DB/Schema.hs:113-116`):

```haskell
-- | Run all migrations (core + legacy)
runMigrations :: SqlBackend -> IO ()
runMigrations backend = do
  runSqlConn (runMigration migrateCore) backend
```

No callers in the server path (RESEARCH §Standard Stack / §State of the Art). Keep `migrateCore`/TH entities only if still referenced elsewhere; otherwise this becomes an exposed-module cleanup in a later phase. **Do not** wire this into `Main` — RESEARCH anti-pattern: "Starting the server on a schema you did not verify."

---

### `AGENTS.md`, `ENV_VARS.md`, `docs/API.md`, `STATE.md` (docs — modified)

**Analog:** themselves. Required corrections:

- `AGENTS.md` migration section: `config/migrations/V001..V010` **does not exist**; document `sql/migrations/` (V001, V002) + `sql/archive/legacy-migrations/`, and `stack run -- migrate` as the only runner.
- `docs/API.md:480-483` documents health as JSON `{status, timestamp}` while code returns plain text; `STATE.md:25,40` claims `{status:"ok", db:"ok"}`. Pick plain text `OK` / `DB UNAVAILABLE` (RESEARCH recommendation) and correct both files in the same commit.
- `ENV_VARS.md:1-11` lists `JWT_SECRET` and `DB_*`; align with the canonical `SURYPUS_JWT_SECRET` / `DATABASE_URL` / `PORT` / `LOG_LEVEL`.

---

## Shared Patterns

### 1. Environment reading (applies to `Config`, `DB.Pool`)
**Source:** `src/Surypus/DB/Pool.hs:44-50`
```haskell
  host <- maybe "localhost" T.pack <$> lookupEnv "DB_HOST"
  port <- fromMaybe 5432 . (>>= readMaybe) <$> lookupEnv "DB_PORT"
```
Rule for Phase 1: `lookupEnv` + pure parse; defaults **only** for `PORT` (8080) and `LOG_LEVEL` (`info`). Required vars (`DATABASE_URL`, `SURYPUS_JWT_SECRET`) get no default; collect all failures, then one `die`.

### 2. Pool lifecycle (applies to `Main`, `Migrate`, every DB spec)
**Source:** `src/Surypus/DB/Pool.hs:73-87`
`createPool` / `closePool (destroyAllResources)` and `runQuery` = `PS.runSqlPool`. Always `bracket` in the executable; always `afterAll closePool` in specs that allocate a pool (`test/DAL/EventStoreIntegration.hs:33`).

### 3. Lazy pool as a test fixture (applies to `HealthSpec`, `MigrationRunnerSpec`)
**Source:** `test/Surypus/API/GraphQLSpec.hs:48`
`createPostgresqlPool "host=127.0.0.1 port=1 …"` never connects until first use — use it for deterministic "DB unreachable" assertions. Never `pendingWith` for the 503 case.

### 4. Typed raw SQL + `Either` envelope (applies to `DB.Migrate`)
**Source:** `src/DAL/EventStore.hs:136-155`, `src/DAL/Classifiers.hs:46-50`
`let sql = "… ? …"` with a `PersistValue`/parameter list, `Single`/typed row decoding, library function returns `Either Text a`. Adapt to `postgresql-simple` (`query_`, `execute`, `Only`), but keep the shape: SQL as a `let`/`Text` literal with placeholders, never string concatenation.

### 5. Fail-fast with `FATAL:` prefix (applies to `Config`, `Main`, `Migrate`)
**Source:** `src/Surypus/JWT/Token.hs:75-78` (message wording precedent)
All top-level fatal messages begin `FATAL: ` and go to stderr via `System.Exit.die`, never `error` (which adds a call stack and makes the message unusable in CI logs). Library modules return `Left`; only `Main` formats and exits.

### 6. Strict shell + non-zero exit (applies to both new scripts)
**Source:** `scripts/check_schema_uniqueness.sh:1-5` (`#!/usr/bin/env bash`, `set -euo pipefail`, `ROOT_DIR`)
Plus `scripts/ci-dry-run-mig.sh:44-60` for Postgres failure reporting with `-v ON_ERROR_STOP=1`.

### 7. Single executable, explicit subcommand (applies to `Surypus.cabal`, `Main`, CI, Makefile)
**Source:** RESEARCH Pitfall 5 / Pattern 2 — do **not** add `executable surypus-migrate`. Every entry point (`Makefile`, CI, README, acceptance) calls `stack run -- migrate` or bare `stack run`.

### 8. Test registration is a 3-place edit (applies to every new spec)
**Source:** `test/Test.hs:6-69` + `:71-120`, `Surypus.cabal:480-542` (`other-modules`), `Surypus.cabal:543-567` (`build-depends`).
A spec that is not in both `test/Test.hs` and `Surypus.cabal`'s `other-modules` silently never runs. `DAL.EventStoreSpec` is the existing offender — fix it in this phase.

---

## No Analog Found

Files with no close match; the planner must use `01-RESEARCH.md` patterns instead.

| File / concern | Role | Data Flow | Reason |
|---|---|---|---|
| `Surypus.DB.Migrate` transaction/lock mechanics (postgresql-simple) | service | batch + DDL | **Zero** `Database.PostgreSQL.Simple` imports in `src/`; all existing DB code is `persistent`. Use RESEARCH §Runner and Hackage docs; do not imitate `runSqlPool`. |
| `app/Main.hs` CLI parser (`optparse-applicative`) | executable | subcommand dispatch | No `Options.Applicative` import anywhere in the repo. Use RESEARCH §Thin entrypoint verbatim. |
| `postgresql-migration` option records (`optTableName`, `TransactionPerStep`, `MigrationDirectory`) | service | batch | Not used yet anywhere; export names are LOW confidence (RESEARCH §Tertiary). Verify against module docs at implementation. |
| `test/API/HealthSpec.hs` WAI request harness | test | request-response | No test uses `Network.Wai.Test`; `surypus-test` has no `wai`/`wai-extra` dependency. Add both and write the harness from scratch. |
| Advisory-lock concurrency test (two live connections) | test | DB concurrency | No existing test opens two independent connections; `test/DAL/EventStoreIntegration.hs` uses a single pool. Use `postgresql-simple`'s `connect` twice inside the spec. |

---

## Metadata

**Analog search scope:** `app/`, `src/` (`Surypus/`, `DAL/`, `Infrastructure/`), `test/`, `scripts/`, `.github/workflows/`, `sql/migrations/`, plus root build/config files.
**Files scanned:** ~25 candidates; 13 read in full or in targeted sections; 6 workflows inspected; 3 migration SQL files read.
**Git-tracked analogs verified:** 24 paths via `git ls-files -- <path>` (all non-empty). No gitignored mirror paths emitted.
**Pattern extraction date:** 2026-10-23
**Key repo facts that shaped this map:**
- `Surypus.API.Server` exports only `apiServer` → `healthEndpoint` must be exported for a direct HealthSpec.
- `surypus-test` build-depends lacks `wai`/`wai-extra` → HealthSpec needs a cabal edit.
- `sql/migrations/init_db.sh` is a dual-ledger anti-pattern → archive, never imitate.
- No `optparse-applicative`, no `postgresql-simple`, no `Network.Wai.Test` anywhere → three "write from RESEARCH" areas.
