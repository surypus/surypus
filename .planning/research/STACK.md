# Stack Research

**Domain:** Haskell ERP — accounting + inventory, brownfield stabilization on real PostgreSQL
**Researched:** 2026-10-23
**Confidence:** HIGH for the toolchain, persistence, money, and auth primitives; MEDIUM for the UI glue and the migration runner (both are small, local decisions)

---

## TL;DR — the stack to standardize on

Stay on **GHC 9.6.5 / Stackage LTS 22.21** for this milestone. It is the only toolchain that is already present in the repo, has every library the ERP needs in the snapshot, and has a LiquidHaskell release that accepts it (`liquidhaskell-0.9.6.3.1`, `ghc ^>= 9.6`).

| Concern | Standardize on | Version (LTS 22.21) | Confidence |
|---|---|---|---|
| Compiler / build | GHC + Stack, resolver `lts-22.21` | GHC 9.6.5, Stack 3.x | HIGH |
| HTTP API | `servant` + `servant-server` | 0.20.1 / 0.20 | HIGH |
| HTTP runtime | `warp` + `wai` + `wai-extra` | 3.3.31 / 3.2.4 / 3.1.14 | HIGH |
| Server-rendered HTML | `lucid` + `servant-lucid` | 2.11.20230408 / 0.9.0.6 | HIGH (lucid) / MEDIUM (servant-lucid) |
| Browser interactivity | vendored **htmx 2.0.11** (`htmx.min.js`) | 2.0.11 | HIGH |
| PostgreSQL | `persistent` + `persistent-postgresql` + `esqueleto` | 2.14.6.1 / 2.13.6.1 / 3.5.11.2 | HIGH |
| Fixed-point money | `Decimal` (`Data.Decimal`) | 0.5.2 | HIGH |
| Migrations | in-repo `surypus-migrate` executable on `postgresql-simple` | 0.7.0.0 | MEDIUM |
| JWT | `jose` | 0.11 | HIGH |
| Crypto backend | `crypton` (replace `cryptonite`) | 0.34 | HIGH |
| Password hashing | `password` + `Data.Password.Argon2` | 3.1.1.0 (extra-dep) | MEDIUM |
| RBAC | in-repo DB tables + Servant middleware, no library | — | HIGH |
| Refinement checking | `liquidhaskell` + `z3`, separate CI job | 0.9.6.3.1 | HIGH |
| JSON | `aeson` | 2.1.2.1 | HIGH |
| Logging | `katip` + `monad-logger` | 0.8.8.0 / 0.3.40 | HIGH |

**The one-sentence rationale:** this is a stabilization milestone, not a rewrite — keep the working Servant/persistent spine, replace the unsafe edges (Double money, cryptonite, unsalted SHA-256, `runMigration`, stale migration scripts), and add Lucid/HTMX as a thin server-rendered layer.

---

## Recommended Stack

### Core Technologies

| Technology | Version | Purpose | Why Recommended | Confidence |
|---|---|---|---|---|
| GHC | 9.6.5 | Compiler | Already the resolver compiler; LiquidHaskell 0.9.6.3.1 is built for `ghc ^>= 9.6`; changing GHC now would change the whole dependency set at once | HIGH |
| Stack | 3.x (2.15+ works) | Build/test driver | `stack test` is the project's acceptance command; `stack.yaml.lock` already pins the snapshot | HIGH |
| `servant` / `servant-server` | 0.20.1 / 0.20 | Typed HTTP API | `SurypusApi` is already a single Servant type; replacing it is pure risk with no payoff | HIGH |
| `warp` / `wai` / `wai-extra` | 3.3.31 / 3.2.4 / 3.1.14 | Server runtime + middleware | `apiServer` is already a WAI `Application`; `Main.hs` only needs `runSettings` | HIGH |
| `lucid` | 2.11.20230408 | HTML DSL | Monadic, HTML5-first, safe escaping, trivial HTMX attributes; `servant-lucid` supports `< 2.12` | HIGH |
| `servant-lucid` | 0.9.0.6 | `HTML` content type for Servant | Gives `MimeRender HTML (Html a)` without hand-written orphan instances; bounds fit Servant 0.20 and Lucid 2.11 | MEDIUM |
| `persistent` / `persistent-postgresql` | 2.14.6.1 / 2.13.6.1 | ORM / typed persistence | The DAL is already built on it; one pool, one transaction model, one `SqlBackend` | HIGH |
| `esqueleto` | 3.5.11.2 | Typed SQL queries / joins | `Database.Esqueleto.Experimental` is already used in `DAL.Queries`/`DAL.Mutations`; snapshot version avoids API churn | HIGH |
| `Decimal` | 0.5.2 | Fixed-point money | Mandated by PROJECT.md; exact base-10 representation; `divide`/`allocate` guarantee sums | HIGH |
| `jose` | 0.11 | JWT sign/verify | Already the snapshot version; uses `crypton`; the custom middleware already targets its API | HIGH |
| `crypton` | 0.34 | Crypto primitives | Actively maintained successor to `cryptonite`; also the backend of `jose` 0.11 and `password` 3.1.x | HIGH |
| `password` | 3.1.1.0 | Password hashing | Argon2id via `Data.Password.Argon2`; replaces the current unsalted SHA-256 in `Surypus.API.Server` | MEDIUM |
| `aeson` | 2.1.2.1 | JSON | Snapshot version; keep JSON at the API boundary only | HIGH |
| `katip` / `monad-logger` | 0.8.8.0 / 0.3.40 | Structured logging / persistent logging | Already wired; no reason to change | HIGH |

### UI / Server-Rendered Layer

| Library / asset | Version | Purpose | When to Use | Confidence |
|---|---|---|---|---|
| `lucid` | 2.11.20230408 (latest 2.11.20260427 also fits) | HTML generation | Every UI page and HTMX fragment | HIGH |
| `servant-lucid` | 0.9.0.6 | `HTML` content type | `Get '[HTML] (Html ())` routes | MEDIUM |
| `wai-middleware-static` | 0.9.2 | Serve `/static/*` | CSS, vendored htmx, images | HIGH |
| `cookie` | 0.4.6 | Parse/render `Set-Cookie` | JWT session cookie (`HttpOnly`, `Secure`, `SameSite=Lax`) | HIGH |
| `http-api-data` | 0.5.1 | `FromForm` / `ToForm` | HTMX form posts with `FormUrlEncoded` | HIGH |
| htmx (JS, vendored) | 2.0.11 | Partial-page swaps, boosts, polling | All interactive UI; no npm at runtime | HIGH |
| CSS | plain CSS file, or a committed Tailwind 4.3.3 build | Styling | v1: hand-written CSS is enough; do not add a CSS build step to the critical path | MEDIUM |

**Why Lucid, not Blaze.** Blaze (`blaze-html` 0.9.2.0) is mature but its typeclass/`ToMarkup` style is a worse fit for composing HTMX fragments, and it offers no practical advantage for an internal ERP UI. Lucid's `data_ "hx-get" ...` is exactly the ergonomics this UI needs. `lucid2` is a separate fork and is **not** supported by `servant-lucid` (`lucid < 2.12`), so do not introduce it.

**HTMX integration pattern.** Keep the JS tiny and vendor it: `static/htmx.min.js` (2.0.11). No npm, no bundler, no separate frontend project. Forms post `application/x-www-form-urlencoded`; route handlers return either a full Lucid page (normal navigation) or a fragment when `HX-Request: true`. Use the POST-Redirect-GET pattern (303 + `Location`) for non-HTMX form submissions.

### Database Layer

| Library | Version | Purpose | When to Use | Confidence |
|---|---|---|---|---|
| `persistent` | 2.14.6.1 | Entity mapping, CRUD, transactions | All writes/reads through `DAL` | HIGH |
| `persistent-postgresql` | 2.13.6.1 | PostgreSQL backend | The only production backend | HIGH |
| `esqueleto` | 3.5.11.2 | Typed joins/aggregates | Reporting queries and multi-table reads | HIGH |
| `postgresql-simple` | 0.7.0.0 | Direct SQL | **Only** in the standalone `surypus-migrate` executable, never in the request path | MEDIUM |
| `resource-pool` | 0.4.0.0 | Connection pool | Already used by `createPostgresqlPool`; keep one pool type | HIGH |
| PostgreSQL | 16 | Database | Matches the project's documented target | HIGH |

**Decision: keep persistent/esqueleto; do not migrate to hasql or postgresql-simple.**
- The DAL, schema, tests, tenant `set_config` logic, and 23 Persistent entities are already built on `persistent`. A hasql migration would rewrite the entire persistence layer for no functional gain in a stabilization milestone.
- `hasql` 2.0.1.0 is excellent when you want explicit SQL, prepared statements, and minimal abstraction, but it has a different connection/transaction model. Introducing it now would create a second data path that bypasses the tenant `set_config` and the existing `runDb` transaction discipline.
- `postgresql-simple` is fine for a standalone migration tool or ad-hoc scripts; it is not a replacement for the application DAL.
- Use `rawSql`/`rawExecute` through the *same* `SqlBackend` when esqueleto is awkward. That preserves transactions, RLS session variables, and pooling.

**Mandatory DAL fix (stack-level):** `DAL.Database.createPool` hard-codes a DSN and `DAL.Database` stores tenant context in a process-global `IORef`. Replace with one `mkPool :: DBConfig -> IO ConnectionPool` that reads `DB_*` env vars, and pass tenant/user explicitly per request (`runDbWithTenant` or a `ReaderT` context). No library change is required, but without this the server cannot be configured and concurrent requests corrupt each other's tenant scope.

### Money Layer — `Data.Decimal` with a canonical `Money`

| Library | Version | Purpose | Why | Confidence |
|---|---|---|---|---|
| `Decimal` | 0.5.2 | Fixed-point decimal | Exact base-10, variable scale, `divide`/`allocate` guarantee the split sums to the original amount | HIGH |
| `aeson` | 2.1.2.1 | JSON encoding | Encode `Money` as a **string**, never a JSON number | HIGH |
| `persistent` | 2.14.6.1 | DB mapping | `PersistRational` maps to PostgreSQL `numeric`/`money` | HIGH |

**Canonical design (put this in `Surypus.CoreTypes` / one new `Finance.Money` module):**

```haskell
-- invariant: decimalPlaces d == 2  (kopecks)
newtype Money = Money { unMoney :: Decimal }
```

Rules that matter for correctness:

1. **Delete both impostors first.** The repo currently has `Surypus.CoreTypes.Decimal = Decimal Double`, `Surypus.Types.Common.Money = Money Double`, and `Finance.Types` fields typed `Double`. All three must disappear; `Surypus.CoreTypes` should re-export `Data.Decimal (Decimal(..), DecimalRaw(..), roundTo, roundTo', divide, allocate)`.
2. **Do not derive `Num`/`Fractional` for `Money`.** `fromInteger` on `Decimal` yields scale 0, and `/` yields up to 255 decimal places. Expose explicit operations: `addMoney`, `subMoney`, `sumMoney`, `negateMoney`, `mulRate` (rounds to scale 2), and `mkMoney`.
3. **Canonical scale is 2**, because the existing schema uses `NUMERIC(18,2)` / `DECIMAL(15,2)`. Rates and exchange rates use scale 6. Quantities stay `bigint`/`Int64`. Do not migrate the money columns to a different scale in v1.
4. **`Decimal` literals are a trap.** Per the `Decimal` documentation, `10.00 :: Decimal` has **zero** decimal places and `10.10` has one. Always construct via `roundTo 2`/`mkMoney`, never rely on literal syntax for scale.
5. **Rounding must be one policy.** `roundTo` uses `round` (banker's rounding). Russian accounting usually expects half-up. Define `roundHalfUp :: Word8 -> Decimal -> Decimal` (via `roundTo'`) once, test it on positives/negatives/ties, and use it everywhere money is rounded.
6. **Never use `(/)` for money.** Use `divide`/`allocate` to split an amount, and `mulRate` + `roundHalfUp` for VAT. `allocate` is the correct primitive for distributing a discount/rounding remainder across lines.

**DB mapping (`PersistField Money`), in one dedicated module (`DAL.Instances`):**

```haskell
toPersistValue (Money d) = PersistRational (toRational d)
fromPersistValue (PersistRational r) = Right (Money (realFracToDecimal 2 r))
fromPersistValue (PersistDouble x)   = Right (Money (realFracToDecimal 2 x)) -- legacy rows

instance PersistFieldSql Money where
  sqlType _ = SqlNumeric 18 2   -- critical: do NOT default to SqlReal
```

`persistent-postgresql` maps `PersistRational` to the PostgreSQL `numeric` OID (and `money`), so a `numeric(18,2)` column round-trips exactly. Add a property test `fromPersistValue (toPersistValue m) == Right m` for a few thousand generated values. There is no `persistent-decimal` package on Hackage, so this instance is yours to own.

**JSON / HTTP boundary:** encode `Money` as a JSON **string** (`"1234.56"`), not a number; JavaScript numbers are IEEE-754 and will silently corrupt money. Decode strictly (reject exponent notation, more than 2 decimals, `NaN`). For HTMX forms, provide `FromHttpApiData Money` with the same strict parser.

**LiquidHaskell interaction:** LH has **no built-in specification for `Data.Decimal`** (verified: no `Decimal` spec in the `liquidhaskell-boot` 0.9.6.3 include set). Do not write `{v:Decimal | v >= 0}` and expect it to check. Instead define `Money` operations at the mantissa level so LH reasons in `Integer`:

```haskell
{-@ measure moneyMinor :: Money -> Integer @-}
moneyMinor :: Money -> Integer
moneyMinor (Money (Decimal _ n)) = n

addMoney (Money (Decimal _ a)) (Money (Decimal _ b)) = Money (Decimal 2 (a + b))
```

Then the accounting invariant is stated over `moneyMinor` and proved by induction over the entry list. This is the only route that gives a real proof without writing a custom `Data.Decimal` spec.

### Migrations — SQL-first with an in-repo runner

| Option | Version | Verdict | Why |
|---|---|---|---|
| In-repo `surypus-migrate` on `postgresql-simple` | 0.7.0.0 | **Recommended** | Fits the SQL-first constraint, can handle the repo's 360 files and duplicate version prefixes, and needs no JVM/Go runtime |
| `persistent-migration` | 0.3.0 | No | Last upload 2021-09-29; no evidence of checksums/advisory locks; stale |
| `postgresql-simple-migration` | 0.1.15.0 | No | Last upload 2021-04-24; stale |
| `hasql-migration` | 0.3.1 | No | Drags `hasql` in as a second DB stack |
| `persistent`'s `runMigration` / `runMigrationUnsafe` | 2.14.6.1 | No | Diffs TH entities against the live DB; no ledger/checksums; `runMigrationUnsafe` can drop columns; conflicts with a SQL-first schema |
| Flyway / Liquibase / dbmate | — | No | Adds a JVM/Go toolchain; the project language constraint is Haskell |

**Location discrepancy to resolve first:** `PROJECT.md` refers to `config/migrations/`, but that directory does not exist; the actual history is `sql/migrations/` (360 files). Make `sql/migrations/` the single canonical directory and update `PROJECT.md`/`AGENTS.md`, rather than maintaining two paths.

**Required behaviour for `surypus-migrate`:**

- Table `schema_migrations(filename text primary key, checksum text not null, applied_at timestamptz not null default now(), execution_ms integer not null)`.
- Sort by numeric prefix, then filename. **Reject duplicate numeric prefixes** in `--check` mode. The repo currently has duplicates (`V001__core_schema.sql` and `V001__generated_orm.sql`; `V180`–`V189`; `V1005`), so this must be resolved or explicitly allow-listed before the runner is trusted.
- Take `pg_advisory_lock(hashtext('surypus_migrations'))` for the whole run; apply each file in its own transaction; support a `-- +migrate no-transaction` directive for `CREATE INDEX CONCURRENTLY`.
- Verify checksums of already-applied files and fail loudly on drift.
- `--baseline` marks the existing history as applied (for the current database); `--dry-run` prints planned files; `--check` verifies without writing.
- Replace `sql/migrations/init_db.sh` in production. The script currently writes to **two** ledgers (`schema_version` with Flyway-style columns *and* `schema_migrations` with a different schema) and uses `CREATE TABLE IF NOT EXISTS`, so whichever schema is created first wins. Keep a thin `scripts/db-reset.sh` for local development only.

### Authentication and RBAC

| Concern | Standardize on | Version | Why | Confidence |
|---|---|---|---|---|
| JWT | `jose` | 0.11 | Already used; snapshot version; `crypton` backend; HS256 is sufficient for local users | HIGH |
| Crypto | `crypton` | 0.34 | `cryptonite` is tagged **deprecated** on Hackage; do not keep both (module names collide) | HIGH |
| Password hashing | `password` + `Data.Password.Argon2` | 3.1.1.0 | Argon2id is the current OWASP recommendation; replaces unsalted SHA-256 | MEDIUM |
| Session cookie | `cookie` | 0.4.6 | `SetCookie` supports `HttpOnly`, `Secure`, `SameSite` | HIGH |
| RBAC | in-repo tables + `Surypus.API.Authorization` | — | Path+method → `Permission` already exists; a library would duplicate it | HIGH |
| CSRF | in-repo double-submit middleware | — | Needed as soon as auth is cookie-based; `wai-csrf` 0.1 is too old to rely on | MEDIUM |

**Do not adopt `servant-auth-server` (0.4.10.0) for v1.** It is a reasonable package, but it would replace a working custom middleware chain (`metrics → rate limit → correlation → tenant → JWT → RBAC`) and does not model the project's path→permission mapping or tenant resolution. Its main value (cookie/JWT combinators) is a small fraction of what the existing `Surypus.API.AuthMiddleware` + `Surypus.JWT.Token` already do. Revisit only if auth is rewritten from scratch.

**Concrete auth work implied by the stack:**

- Remove `Surypus.JWT.Token.defaultSecretKey`; require `SURYPUS_JWT_SECRET` at startup and fail fast if missing or shorter than 32 bytes.
- Replace `hashPassword pwd = show (hash @ByteString @SHA256 ...)` in `src/Surypus/API/Server.hs` with `Data.Password.Argon2`. Store the encoded hash (`$argon2id$...`) in `users.password_hash`; verify with `checkPassword`. Rehash on successful login when the stored hash is legacy SHA-256/PBKDF2.
- Delete `DAL.Repository.RBAC.checkUserAppPermissionRepo` (currently returns `True`) and back permissions with the existing `roles`/`permissions`/`role_permissions`/`user_roles` tables (V006/V007/V009). Add an integration test that every non-public route returns 401/403 without a valid role.
- Use one `Permission` vocabulary: `admin`, `accountant`, `storekeeper` are roles; permissions are verbs (`goods:read`, `bill:post`, `stock:adjust`, ...). Do not encode HTTP paths in the DB.

### LiquidHaskell

| Tool | Version | Purpose | Why / caveat | Confidence |
|---|---|---|---|---|
| `liquidhaskell` | 0.9.6.3.1 | Refinement type checker | Its `liquidhaskell-boot` requires `ghc ^>= 9.6`; this is the only release compatible with the project's GHC 9.6.5 | HIGH |
| `z3` | 4.8.15+ (4.12/4.15 fine) | SMT solver | LH calls an external solver; pin it in CI and in the verification Docker image | MEDIUM |
| GHC | 9.6.5 | Compiler for LH | LH supports **one GHC version per release** (official policy); do not mix GHC 9.10/9.14 with LH 0.9.6 | HIGH |

**The current verification setup cannot work as written.** `src/Finance/Accounting.hs` uses `{-@ ... sumDebits v == sumCredits v @-}` and `{-@ type NonNeg = {v:Decimal | v >= 0} @-}`, but:

- `sumDebits`/`sumCredits` are **not defined anywhere** in the source or specs — LH cannot check an unknown measure.
- The `Decimal` in scope is `Surypus.CoreTypes.Decimal`, a newtype over `Double`, not `Data.Decimal.Decimal`; `>=` on it is opaque to LH.
- The verification story is internally inconsistent: `liquidhaskell.yaml` documents GHC 9.14 + the latest LH, while `stack.yaml` builds with GHC 9.6.5. The actual workflow (`.github/workflows/liquidhaskell-verify.yml`) uses `lts-22.21` but does not `stack build` first, does not pin the LH version, and hides failures behind `|| echo "LiquidHaskell install skipped"` / an `else` branch that only prints annotations. LH is a GHC plugin and is ABI-coupled to the compiler; as written, this setup cannot prove the stated obligations (and the workflow would still exit 0 if it failed).
- `stack build` does not run the plugin, which is correct, but it also means the annotations have never been validated.

**Recommended setup:**

1. Keep LH **out of the normal `stack build`**. Do not add `-fplugin=LiquidHaskell` to the library's `ghc-options`.
2. In a dedicated CI job (and an optional `liquid` Docker image), install GHC 9.6.5 + `liquidhaskell-0.9.6.3.1` + `z3`, then run `stack exec -- liquid src/Finance/Accounting.hs src/Finance/Money.hs ...` (or a small `cabal` project that depends on the Surypus library if `stack exec` package-path issues appear). `stack install liquidhaskell-0.9.6.3.1` works because the package bounds accept GHC 9.6.x; `liquid-platform` is stale (0.9.2.8) and should not be used.
3. Move the proof to a small, pure core: `Finance.Money` (mantissa-based `Money`) + `Finance.Accounting` (balanced transaction smart constructor). Prove `sumMoney (debits) == sumMoney (credits)` and `moneyMinor >= 0` for ledger entries. Do not attempt to verify the API/DAL layers.
4. Add a `liquid/` spec module with `measure` declarations for `Money`/`Decimal` accessors and any list-sum lemmas; keep it versioned with the code. If a `Data.Decimal` spec proves too costly, the mantissa view makes it unnecessary.

**Upgrade path (do this as a separate milestone, never piecemeal):**

| Variant | GHC | Resolver | LiquidHaskell | Notes |
|---|---|---|---|---|
| **A — v1 default** | 9.6.5 | `lts-22.21` | 0.9.6.3.1 | Lowest risk; everything already in the snapshot except `password` 3.1.1.0 |
| **B — later upgrade** | 9.10.3 | `lts-24.64` | 0.9.10.1.2 (targets GHC 9.10.1, bound `ghc ^>= 9.10`) | Snapshot has `servant` 0.20.3.0, `persistent` 2.17.1.0, `esqueleto` 3.6.0.3, `jose` 0.11, `crypton` 1.0.6, `password` 3.1.0.2, `lucid` latest |

Do **not** jump to GHC 9.14/LH 0.9.14 in this milestone: `liquidhaskell-0.9.14.1.1` targets GHC 9.14.1 only, and the whole 381-module package would have to move at once. Also note the Dockerfile currently pins `haskell:9.14.1`, the devcontainer `9.6.6`, and the docs workflow `9.10.3` — align all of them to the chosen variant before trusting any build.

### Testing and Development Tools

| Tool | Version | Purpose | Notes |
|---|---|---|---|
| `hspec` | 2.11.8 | Unit/property test runner | Existing suite; keep |
| `QuickCheck` | 2.14.3 | Properties | Add money round-trip and RBAC properties |
| `hspec-wai` | 0.11.1 | HTTP-level tests | Test `/api/v1/health`, auth failures, and UI fragments without a live server |
| `http-client` | 0.7.17 | Smoke tests | Drive the real server in the end-to-end script |
| `doctest` | 0.22.2 | Executable Haddock examples | GHC-coupled; run in a separate job, not in `stack test` |
| `fourmolu` | 0.14.0.0 | Formatter | Snapshot version; the repo has Fourmolu config but the Makefile uses `stylish-haskell` — pick one and delete the other |
| `hlint` | 3.6.1 | Lint | Existing CI |
| `ghcid` | 0.8.9 | Fast reload | Optional developer tool |
| HLS | matching GHC 9.6.5 via ghcup | Editor | Do not pin HLS in the cabal file |

---

## Installation

```yaml
# stack.yaml
resolver: lts-22.21
packages:
  - .
extra-deps:
  - password-3.1.1.0     # Argon2id; snapshot has 3.0.4.0, 3.1.x is the crypton line
# keep: allow-newer: false, flags: hashtables/warp as-is
```

```cabal
-- Surypus.cabal (library) — the v1 spine
build-depends:
    base >=4.12 && <5
  , aeson >=2.1 && <2.3
  , bytestring, text >=2.0 && <2.2, time, containers
  , Decimal >=0.5 && <0.6
  , persistent >=2.14 && <2.19
  , persistent-postgresql >=2.13 && <2.15
  , esqueleto >=3.5 && <3.7
  , monad-logger, resource-pool >=0.4 && <0.6
  , servant >=0.20 && <0.21
  , servant-server >=0.20 && <0.21
  , servant-lucid >=0.9 && <0.10
  , lucid >=2.11 && <2.12
  , wai >=3.2 && <3.3, wai-extra >=3.1 && <3.2, warp >=3.3 && <3.5
  , http-types, http-api-data >=0.5 && <0.6
  , cookie >=0.4 && <0.5
  , wai-middleware-static >=0.9 && <0.10
  , jose >=0.11 && <0.12
  , crypton >=0.34 && <1.1   -- 0.34 on LTS 22.21; 1.0.6 on LTS 24.64 (Variant B)
  , password >=3.1 && <3.2
  , katip >=0.8 && <0.9
  , uuid, stm, mtl, transformers, lens, directory, filepath, network
```

```cabal
-- new executable
executable surypus-migrate
  hs-source-dirs: app/migrate
  main-is: Main.hs
  build-depends:
      base
    , postgresql-simple >=0.7 && <0.8
    , optparse-applicative >=0.18 && <0.19
    , text, bytestring, directory, filepath, time, containers
```

Remove unconditionally: `cryptonite` (replaced by `crypton`) and `persistent-template` (TH is in `persistent`). Remove **only if the corresponding modules leave the v1 exposed set**: `hedis` (6 modules), `websockets` (2), `http-conduit`/`http-client`/`http-client-tls` (AI/external integrations), `process` and `temporary` (reports/backup). Keep `random` (used by `System.Retry`/`System.Secrets`/`System.MetricsExport`/`System.Scheduler`), `yaml` (used by `DAL.Schema`), and `lens` (used by the JWT code) unless those modules are removed too.

## Alternatives Considered

| Recommended | Alternative | When to Use Alternative | Why Not Here |
|---|---|---|---|
| `persistent` + `persistent-postgresql` + `esqueleto` | `hasql` 2.0.1.0 + `hasql-pool` 1.5.0.1 | A new service, a high-throughput read path, or a team that prefers explicit SQL and no TH | Rewriting the entire DAL and its 23 entities during stabilization is pure risk; hasql's connection model would coexist badly with `runDb`/tenant `set_config` |
| `persistent`/`esqueleto` | `postgresql-simple` 0.7.0.0 | Small tools, migrations, one-off scripts | No typed schema or composable joins; using it in the request path creates a second transaction/pool discipline |
| `lucid` + `servant-lucid` | `blaze-html` 0.9.2.0 + `servant-blaze` 0.9.1 | Existing Blaze codebase, or a need for maximum render throughput | No Blaze code exists today; Lucid is a better fit for HTMX fragments and has the same Servant integration |
| `servant-lucid` | hand-written `MimeRender HTML (Html a)` orphan instances | `servant-lucid` stops compiling with a future Servant/text version | 0.9.0.6 is a tiny package and its bounds fit; the fallback is ~15 lines |
| `jose` 0.11 + custom middleware | `servant-auth-server` 0.4.10.0 | A greenfield API with no existing auth chain | Would duplicate the current JWT/tenant/RBAC middleware and does not model path→permission mapping |
| `password` 3.1.1.0 + Argon2id | `crypton`'s `Crypto.KDF.Argon2` directly | You want zero extra-deps and are willing to implement salt/encoding/constant-time compare yourself | `password` is a thin, well-tested wrapper; the direct route is only worth it if the dependency audit demands it |
| In-repo `surypus-migrate` | `persistent-migration` 0.3.0 / `postgresql-simple-migration` 0.1.15.0 | You have a simple, duplicate-free migration history | Both are stale (last uploads 2021) and do not address the repo's 360-file, duplicate-prefix history |
| GHC 9.6.5 / LTS 22.21 | GHC 9.10.3 / LTS 24.64 + LH 0.9.10.1.2 | A dedicated toolchain-upgrade milestone after the endpoint works | Changing GHC, 381 modules, `aeson` 2.2, `persistent` 2.17, and `esqueleto` 3.6 at the same time as stabilizing behavior makes failures unattributable |

---

## What NOT to Use

| Avoid | Why | Use Instead |
|---|---|---|
| `Double` for money (including `Surypus.CoreTypes.Decimal = Decimal Double` and `Surypus.Types.Common.Money = Money Double`) | Binary floating point cannot represent 0.10/0.20 exactly; the repo already has a 100× VAT-unit bug from mixed conventions | `Data.Decimal.Decimal` + `Money` newtype at scale 2, explicit rounding policy |
| `cryptonite` 0.30 | Tagged **deprecated** on Hackage; superseded by `crypton`. Keeping both causes ambiguous `Crypto.Hash`/`Crypto.KDF` imports because the module names are identical | `crypton` 0.34; remove `cryptonite` from `build-depends` and from `cabal.project` |
| Unsalted `SHA256` password hashing (`hashPassword` in `Surypus.API.Server`) | Fast general-purpose hash; trivially rainbow-tabled; no per-user salt or work factor | `password` 3.1.1.0 + `Data.Password.Argon2` (Argon2id), rehash on login |
| `persistent-template` 2.12 | Compatibility shim; `Database.Persist.TH` has lived in `persistent` itself for years | Depend on `persistent` only |
| `persistent`'s `runMigration` / `runMigrationUnsafe` in production | Diffs TH entities against the live DB; no checksum ledger, no advisory lock, and `runMigrationUnsafe` can drop columns. It cannot represent the existing 360-file SQL history | The `surypus-migrate` runner described above |
| `persistent-migration` 0.3.0 / `postgresql-simple-migration` 0.1.15.0 | Last releases 2021; no evidence of the checksums/locking this repo needs | In-repo runner on `postgresql-simple` 0.7.0.0 |
| `jose` 0.13 | Requires `crypton >= 1.1`. `password` 3.1.1.0 can only follow it by switching its `memory-dep` flag off, which pulls in `ram` instead of `memory` — an extra-dep not in LTS 22.21 — and `jose` 0.13 is not in the snapshot either. Not worth the churn now | `jose` 0.11 + `crypton` 0.34 (or 1.0.6 on LTS 24.64) + `password` 3.1.1.0 with default `memory-dep` |
| `servant-auth-server` | Duplicates the existing auth middleware; extra abstraction over a 6-line JWT check | Keep `jose` + `Surypus.API.AuthMiddleware` + `Surypus.API.Authorization` |
| `lucid2` | Separate fork; `servant-lucid` requires `lucid < 2.12` and does not support it | `lucid` 2.11.x |
| `blaze-html` / `servant-blaze` | Older typeclass-based API, no HTMX-specific advantage, no existing code | `lucid` + `servant-lucid` |
| `servant-static-th` | Embeds assets via TH; every asset change triggers a recompile and the binary grows | `wai-middleware-static` 0.9.2 |
| `hedis` for the job queue / cache (6 modules currently) | PROJECT.md explicitly replaces Redis/in-memory queues with one PostgreSQL canon; a second datastore adds a failure mode with no v1 benefit | `DAL.Queue` on PostgreSQL (table + `FOR UPDATE SKIP LOCKED`) |
| `websockets` for v1 | Out of scope; the endpoint is not needed to prove the goods→bill→payment→ledger path | Add after the HTTP + DB path is green |
| `http-conduit`, `process`, `temporary` in the request path | AI/report/PDF/backup work is out of scope and runs inline today, tying up Warp workers | Queue jobs, or keep these in a separate tool executable |
| `miso`, `reflex-dom`, GHCJS/WASM, React/Vue/Svelte | Violates the "server-rendered Haskell + HTMX, no separate JS framework" constraint and adds a second build/toolchain | Lucid + HTMX |
| OPA/Rego for v1 RBAC | The repo has Rego files but no Haskell runtime; adding an OPA sidecar adds a network dependency and an extra policy language | DB-backed roles/permissions + a pure `can` function |
| An effect system (`polysemy`, `effectful`, `fused-effects`) | The codebase is plain `IO`/`Handler` with explicit `Env`; introducing an effect layer now would touch every module for no behavioral gain | Keep `IO` + `Env`; fix the tenant `IORef` with explicit per-request context |
| `runMigration`-generated schema as source of truth | The project's constraint is SQL-first, `sql/migrations/` is the source of truth | SQL files + ledger + checksums |

---

## Stack Patterns by Variant

**If the goal is "make the server start" (Phase 0 of this milestone):**
- Keep LTS 22.21/GHC 9.6.5; make `stack build` the only authoritative build.
- Delete the conflicting `cabal.project` constraints (`jose >=0.10 && <0.11`, `cryptonite ==0.30`) or make `cabal.project` mirror the snapshot. Today Stack resolves `jose` 0.11 while Cabal resolves `jose` 0.10 — two different build plans. The same applies to `postgresql-binary` and `crypton`.
- Make `app/Main.hs` read `DB_*` + `SURYPUS_JWT_SECRET`, build one pool, and call `Warp.runSettings` with `apiServer`. Pin `hasql`-free dependencies; no server runner library is needed.
- Align the Dockerfile (`haskell:9.6.5`), devcontainer (`9.6.5`), and CI (`9.6.5`) with the resolver. The current 9.14/9.6.6/9.10.3 mix guarantees a build mismatch.

**If the UI needs to grow beyond a few screens:**
- Keep one Servant API for `/api/v1` (JSON) and a separate `uiApp :: Application` mounted at `/ui` (+ `wai-middleware-static` at `/static`). Do not put Bearer-token middleware in front of the UI; use the JWT cookie + CSRF middleware there.
- Render full pages on normal navigation and fragments on `HX-Request`. Keep the fragment boundary at one Lucid function per component.
- Vendor `htmx.min.js` 2.0.11 and a single CSS file. No Node build in CI.

**If reporting/analytics becomes the next bottleneck:**
- Keep `esqueleto` for typed joins and `rawSql` for hand-tuned reports, both through the same `SqlBackend`.
- Only consider `hasql` for a separate read-only analytics service with its own pool; do not mix it into the transactional DAL.

**If multi-tenancy must be correct under concurrency:**
- Replace the global tenant `IORef` with a per-request `ReaderT`/explicit argument and `runDbWithTenant`. Keep `set_config(..., true)` (transaction-local) and RLS. This is a code change, not a library change — no new dependency is required.

**If GHC 9.6 reaches end-of-life:**
- Move to Variant B (LTS 24.64/GHC 9.10.3/LH 0.9.10.1.2) in one commit series: compiler, resolver, LH, Docker, CI. Do not upgrade `jose` to 0.13 at the same time: it needs `crypton >= 1.1`, which forces `password`'s `memory-dep` flag off and adds `ram` as an extra-dep. Keep `jose` 0.11 + `crypton` 1.0.6 on LTS 24.64.

---

## Version Compatibility

| Package A | Compatible With | Notes |
|---|---|---|
| GHC 9.6.5 | `liquidhaskell` 0.9.6.3.1 | `liquidhaskell-boot-0.9.6.3` requires `ghc ^>= 9.6`; LH supports one GHC per release |
| GHC 9.10.3 | `liquidhaskell` 0.9.10.1.2 | `ghc ^>= 9.10`; Variant B only |
| GHC 9.14.1 | `liquidhaskell` 0.9.14.1.1 | Only if the whole project moves to 9.14; not this milestone |
| `servant` 0.20.1 | `servant-server` 0.20, `servant-lucid` 0.9.0.6 | `servant-lucid` requires `servant >=0.17 && <0.21` |
| `servant-lucid` 0.9.0.6 | `lucid >=2.9.8 && <2.12`, `text <2.2` | Both Lucid 2.11.20230408 (snapshot) and 2.11.20260427 (latest) fit; `lucid2` does not |
| `persistent` 2.14.6.1 | `persistent-postgresql` 2.13.6.1, `esqueleto` 3.5.11.2 | Snapshot-coherent trio; `esqueleto` 3.5.11.2 exposes `Database.Esqueleto.Experimental` |
| `persistent` 2.17.1.0 | `persistent-postgresql` 2.13.7.0, `esqueleto` 3.6.0.3 | LTS 24.64; `esqueleto` 3.6.0.1 is deprecated, use 3.6.0.3 |
| `Decimal` 0.5.2 | `persistent` (any) | No built-in `PersistField`/`ToJSON`; define a `Money` wrapper with `PersistRational`/string JSON |
| `jose` 0.11 | `crypton >=0.31 && <1.1`, `crypton-x509 >=1.7.6` | Snapshot 22.21 has `crypton` 0.34, `crypton-x509` 1.7.6 |
| `jose` 0.13 | `crypton >=1.1` | Needs `password`'s `memory-dep` flag off (pulls `ram`, an extra-dep) — keep `jose` 0.11 on this snapshot |
| `password` 3.1.1.0 | `crypton >=0.31 && <1.1` (default `memory-dep`) | With `crypton >=1.1` it needs `memory-dep: false` + `ram`; not needed for v1. `password` 3.1.0.2 is the LTS 24.64 equivalent |
| `crypton` 0.34 | `jose` 0.11, `password` 3.1.1.0 | One crypto backend; remove `cryptonite` to avoid module collisions |
| `aeson` 2.1.2.1 | `persistent` 2.14.6.1, `servant` 0.20.1 | Variant B moves to `aeson` 2.2.5.1 with `persistent` 2.17 |
| `warp` 3.3.31 | `wai-extra` 3.1.14, `wai` 3.2.4 | Project bounds `<3.5` allow 3.4.x later |
| `postgresql-simple` 0.7.0.0 | PostgreSQL 16 | Migration executable only |

---

## Confidence Assessment

| Area | Level | Reason |
|---|---|---|
| Compiler / resolver (LTS 22.21, GHC 9.6.5) | HIGH | Verified against the Stackage snapshot and the repo's own `stack.yaml`; all chosen libraries are in the snapshot |
| Servant HTTP API | HIGH | Already the project's API; version bounds are stable and in the snapshot |
| Lucid + `servant-lucid` | MEDIUM–HIGH | Lucid is current and in the snapshot; `servant-lucid` is small but old (tested only to GHC 8.10), though its bounds fit. The fallback is a local `MimeRender` instance |
| persistent/esqueleto | HIGH | Existing, snapshot-coherent, and `PersistRational → numeric` was verified in `persistent-postgresql` source |
| Money (`Decimal` + `Money` design) | HIGH | `Decimal` semantics verified from source; the mantissa-based design is the only practical route for LH |
| Migrations (in-repo runner) | MEDIUM | The runner is straightforward, but the repo's duplicate version prefixes and dual ledgers require cleanup decisions |
| JWT / `jose` 0.11 + `crypton` | HIGH | Snapshot-coherent; `cryptonite` deprecation verified; the Stack/Cabal jose split is a real, observable issue |
| Password hashing (`password` 3.1.1.0) | MEDIUM | Latest release, not in LTS 22.21 (one extra-dep); crypton bound fits; Argon2id is the right primitive |
| LiquidHaskell 0.9.6.3.1 | HIGH for version pairing; MEDIUM for Stack integration | `ghc ^>= 9.6` verified; `stack install`/`stack exec -- liquid` is the documented route, but the current annotations and CI are broken and need rework |
| HTMX / UI glue | HIGH | No Haskell dependency; vendored JS 2.0.11 verified from npm |
| RBAC design | HIGH | No library is needed; the existing `Permission`/`Resource` vocabulary and tables are sufficient |

---

## Sources

- Hackage package pages and `.cabal` files (versions, bounds, test-with):
  - `servant` 0.20.1 / `servant-server` 0.20 / `servant-lucid` 0.9.0.6 — https://hackage.haskell.org/package/servant-0.20.1, https://hackage.haskell.org/package/servant-lucid-0.9.0.6
  - `lucid` 2.11.20230408 and 2.11.20260427 — https://hackage.haskell.org/package/lucid
  - `persistent` 2.14.6.1 / `persistent-postgresql` 2.13.6.1 / `esqueleto` 3.5.11.2 — https://hackage.haskell.org/package/persistent-2.14.6.1, https://hackage.haskell.org/package/persistent-postgresql-2.13.6.1, https://hackage.haskell.org/package/esqueleto-3.5.11.2
  - `Decimal` 0.5.2 — https://hackage.haskell.org/package/Decimal-0.5.2 (source: `src/Data/Decimal.hs`, lines 1–100, 138–160, 269–300; literal-scale warning and `roundTo`/`divide`/`allocate` semantics)
  - `jose` 0.11 / 0.13, `crypton` 0.34, `password` 3.1.1.0 — https://hackage.haskell.org/package/jose-0.11, https://hackage.haskell.org/package/crypton-0.34, https://hackage.haskell.org/package/password-3.1.1.0
  - `liquidhaskell` 0.9.6.3.1 and `liquidhaskell-boot` 0.9.6.3 — https://hackage.haskell.org/package/liquidhaskell-0.9.6.3.1, https://hackage.haskell.org/package/liquidhaskell-boot-0.9.6.3 (bound `ghc ^>= 9.6`)
  - `postgresql-simple` 0.7.0.0, `persistent-migration` 0.3.0, `postgresql-simple-migration` 0.1.15.0 — https://hackage.haskell.org/package/persistent-migration-0.3.0 (uploaded 2021-09-29), https://hackage.haskell.org/package/postgresql-simple-migration-0.1.15.0 (uploaded 2021-04-24)
- Stackage snapshots: `lts-22.21` (GHC 9.6.5), `lts-23.28` (GHC 9.8.4), `lts-24.64` (GHC 9.10.3) — https://www.stackage.org/lts-22.21, https://www.stackage.org/lts-24.64, and the snapshot YAMLs under https://github.com/commercialhaskell/stackage-snapshots
- LiquidHaskell support policy (one GHC per release) — https://github.com/ucsd-progsys/liquidhaskell (README, "GHC support policy") and `INSTALL.md` (`stack install`, `stack exec -- liquid`, `GHC_PACKAGE_PATH`)
- `cryptonite` deprecation tag — https://hackage.haskell.org/package/cryptonite (tagged `deprecated`; use `crypton`)
- `persistent-postgresql` `PersistRational → numeric` mapping — `Database/Persist/Postgresql/Internal.hs`, lines 47, 113, 123
- htmx 2.0.11 — https://registry.npmjs.org/htmx.org/latest; Tailwind 4.3.3 — https://registry.npmjs.org/tailwindcss/latest
- Repo evidence: `Surypus.cabal`, `stack.yaml`, `stack.yaml.lock`, `cabal.project`, `sql/migrations/` (360 SQL files; duplicate `V001`, `V180`–`V189`, `V1005`; dual `schema_version`/`schema_migrations` ledgers), `src/DAL/Database.hs` (global tenant `IORef`, hard-coded DSN), `src/Surypus/CoreTypes.hs` (`Decimal Double`), `src/Surypus/Types/Common.hs` (`Money Double`), `src/Finance/Accounting.hs` (undefined `sumDebits`/`sumCredits`), `src/Surypus/API/Server.hs` (unsalted SHA-256)

---

## Roadmap Implications

1. **Phase 0 — one toolchain.** Pin GHC 9.6.5 / LTS 22.21 in Stack, Cabal, Docker, devcontainer, and CI; delete the conflicting `cabal.project` jose/cryptonite constraints; get `stack build` and `stack test` green. This is a prerequisite for every later phase.
2. **Phase 1 — money canon.** Delete `Surypus.CoreTypes.Decimal (Double)`, `Surypus.Types.Common.Money (Double)`, and `Double` money fields in `Finance.Types`. Add `Finance.Money` (`Money` over `Data.Decimal` at scale 2, mantissa-level operations, `PersistField`/JSON/HTTP instances, half-up rounding). This unblocks both the VAT fix and the LH proof.
3. **Phase 2 — database and migrations.** Make `surypus-migrate` the only migration path; resolve duplicate prefixes; one ledger with checksums + advisory lock; one env-driven pool; remove the hard-coded DSN and the tenant `IORef` from the request path.
4. **Phase 3 — auth/RBAC.** `jose` 0.11 + `crypton` 0.34; remove the SHA-256 password path for `password`/Argon2id; delete the always-`True` permission stub; cookie + CSRF for the UI; require `SURYPUS_JWT_SECRET` at startup.
5. **Phase 4 — server-rendered UI.** Add `lucid`, `servant-lucid`, `cookie`, `http-api-data`, `wai-middleware-static`, and vendored htmx 2.0.11; mount `/ui` and `/static` beside `/api/v1`; one end-to-end Lucid/HTMX path (goods → receipt → bill → payment → ledger → stock).
6. **Phase 5 — verification.** Pin `liquidhaskell` 0.9.6.3.1 + z3 in a separate CI job; define the `Money`/`Decimal` measures; prove the balanced-transaction constructor and non-negative ledger amounts. Do not put the plugin in `stack build`.
7. **Defer to the next milestone:** GHC 9.10.3/LTS 24.64 + LH 0.9.10.1.2 (Variant B), Redis removal cleanup for the remaining modules, AI/report/backup executables, and any hasql analytics service.

---

*Stack research for: Surypus ERP (Haskell, PostgreSQL, brownfield stabilization)*
*Researched: 2026-10-23*


