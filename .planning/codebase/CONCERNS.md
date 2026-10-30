---
last_mapped_commit: 7bd87f6f9f0abbbaddaeb0e604b8ff8fe2ff4c41
last_mapped_at: 2026-10-23
---
<!-- refreshed: 2026-10-23 -->

# Codebase Concerns

**Analysis Date:** 2026-10-23

## Tech Debt

**Server entry point is a placeholder (API is unreachable):**
- Issue: `app/Main.hs` is 7 lines and only prints `"Surypus ERP prototype (Phase 1)"`. It never calls `Surypus.API.Server.apiServer`, never opens a pool, never binds a port. The Docker image's `CMD ["surypus-server"]` therefore starts a process that exits immediately.
- Files: `app/Main.hs`, `src/Surypus/API/Server.hs:183`, `Dockerfile:75`
- Impact: The entire Servant API, GraphQL shim, WebSocket handler, and background workers are dead code in the shipped binary. Every route documented in `API_DOCUMENTATION.md` is unavailable.
- Fix approach: Write a real `main` that reads env config, builds the pool (`DAL.Pool`), constructs `Metrics`, wires `publicPaths`/`checkPermission`, and runs `runSettings` on `Warp`. Add a startup smoke test asserting the process binds and `/api/v1/health` returns 200.

**Pervasive stub modules presented as implemented:**
- Issue: 181 `stub`/`placeholder`/`Phase 1:` markers across `src/`. Several are functionally inert yet exported and consumed.
- Files:
  - `src/Production/ServiceManager.hs` — `type Pool = ()`; `runJobQueueOnce`/`runCronOnce` only `putStrLn`; the "daemon" performs no work.
  - `src/Surypus/EventBridge.hs:60-74` — `publishEvent` only logs, `unsubscribeEvent` is `pure ()`, `getHandlerQueue` always returns `Nothing`; subscribers never receive an event.
  - `src/Core/Services/Accounting.hs:23-39` — `validateTransaction` always `Right`, `emitEntryEvent`/`processTransactionWithEvents` always `Right ()`, `processTransactionWithEvents'` always `Right []`.
  - `src/DAL/Production.hs` — `getWorkOrder` always `Nothing`, `updateWorkOrder` always `Right "ok"`.
  - `src/DAL/Repository/RBAC.hs:24-25` — `checkUserAppPermissionRepo` **always returns `True`**.
  - `src/EventBus.hs:40,54` — `-- TODO: Send to Kafka`.
- Impact: Callers cannot distinguish "succeeded" from "did nothing". The RBAC repository stub is an authorization bypass if ever wired.
- Fix approach: Either delete these modules from `exposed-modules` or convert the stubs to `error "not implemented"` so misuse is loud. Replace `checkUserAppPermissionRepo` with `Surypus.RBAC.Store` lookups or remove it.

**Duplicate `Decimal`/money representations and conflicting tax engines:**
- Issue: Two incompatible `Decimal` types coexist and two VAT engines use different rate conventions.
  - `src/Surypus/CoreTypes.hs:14` — `newtype Decimal = Decimal Double`.
  - `src/Finance/Tax.hs:19` imports `Data.Decimal (Decimal)` (fixed-point), and declares orphan `ToJSON`/`FromJSON` instances for it at `src/Finance/Tax.hs:126-132`.
  - `src/Core/Tax.hs` — rates are fractions `0.0–1.0` over `Double` (`applyTax`, `applyTaxInclusive`).
  - `src/Finance/Tax.hs:41-92` — rates are percentages `0–100` over `Data.Decimal.Decimal` (`calcVAT`, `calcVATFromInclusive`).
  - `src/Surypus/Types/Common.hs:103` — `newtype Money = Money Double`, documented as "fixed precision" but is a `Double`.
  - `src/Finance/Ledger.hs:40` — a third money wrapper `newtype Amount = Amount Double`.
- Impact: A rate passed to the wrong engine is off by 100×. Values cross module boundaries as `Double`, so cent-level rounding drift is unauditable. The orphan JSON instances make serialization semantics package-global and easy to break.
- Fix approach: Standardise on one money type for the domain (`Data.Decimal` or a scaled `Integer`), delete `Surypus.CoreTypes.Decimal`/`Money`/`Amount`, move JSON instances next to the type (or use `newtype` wrappers), and keep exactly one VAT module with an explicit unit documented in the type (`RatePercent` vs `RateFraction` newtypes).

**Duplicated accounting / double-entry implementations:**
- Issue: At least seven overlapping representations of ledger, journal, and balance logic:
  - `src/Finance/Accounting.hs` (`LedgerEntry`/`Transaction`, `validateTransaction`)
  - `src/Finance/Journal.hs` (`JournalEntry`, `Double` amounts, `calculateJournalBalance`)
  - `src/Finance/Ledger.hs` (`AccTurn`, `Amount`, `calculateAccountBalance`)
  - `src/Finance/Types.hs` (`AccTurn`, `Balance`, `doubleEntryBalance`, `accountBalanceInvariant`, `trialBalance`)
  - `src/Domain/Accounting/Events.hs` (`AccountingEvent`, `rebuildBalance`)
  - `src/Core/Accounting/ReadModel.hs` (projection/replay)
  - `src/Infrastructure/EventStore/Accounting.hs` (typed event store + replay)
  - `src/Core/Services/Accounting.hs` (stub wrapper over `Finance.Accounting`)
- Impact: Each copy has slightly different invariants and payload shapes. A fix in one does not propagate. `Finance/Accounting.hs:88` checks `sumDebits == sumCredits`, `Finance/Types.hs:146` does `totalDebit == totalCredit` on `Double`, and `Domain/Accounting/Events.hs` has no balance check at all.
- Fix approach: Designate `Infrastructure.EventStore.Accounting` + `Core.Accounting.ReadModel` as the single write/read path, make `Finance.Types` the only pure invariant module, and delete or demote the rest to `deprecated` with no exports.

**Three incompatible `Stock` types and four stock modules:**
- Issue: `Inventory.Stock.Stock` (7 fields, `src/Inventory/Stock.hs:17`), `DAL.Types.Stock` (4 fields, `src/DAL/Types.hs:575`), `DAL.DB.StockStub` (5 fields, `src/DAL/DB.hs:53`). Logic is split across `src/Inventory/Stock.hs`, `src/Inventory/StockOps.hs`, `src/Inventory/Operations.hs`, `src/Core/Inventory.hs`, `src/Infrastructure/EventStore/Inventory.hs`.
- Impact: Field-name collisions (`sQtty`, `stockQtty`) silently differ in meaning; the API `Stock` drops reservations and cost, so reports built from it disagree with `Inventory.Stock`.
- Fix approach: One persisted `Stock` record in `DAL.Types`, one smart constructor with invariants (`mkStock`), and `Inventory.*` operating only on it. Remove `DAL.DB` entirely.

**Four job-queue implementations and one no-op scheduler:**
- Issue: `src/System/JobQueue.hs` (Redis + in-process workers), `src/System/Jobs.hs` (in-memory runner), `src/DAL/Queue.hs` (Postgres `job_queue`), `src/Infrastructure/Redis/TaskQueue.hs` (Redis task queue), plus the no-op `src/Production/ServiceManager.hs`.
- Impact: No single source of truth for retry, dead-letter, or status semantics. `DAL.Queue` also creates its table with inline DDL (`src/DAL/Queue.hs:140`) that drifts from migrations.
- Fix approach: Pick `DAL.Queue` (Postgres) as the canonical queue, delete the Redis/in-memory duplicates, and move the `job_queue` DDL into a migration.

**`DAL.DB` in-memory database still wired into a service:**
- Issue: `src/DAL/DB.hs` holds hardcoded seed data in `IORef`s (`dbPersons`, `dbGoods`, `dbBills`, `dbStock`) and exports `Database`/stub records. `src/Service/BillService.hs:21` imports it and constructs `BillStub` at line 92.
- Impact: A service path can silently operate on process-local fake data; state is lost on restart and invisible to other instances.
- Fix approach: Remove the `import DAL.DB` from `BillService`, delete `DAL.DB` and `test/DAL/DBSpec.hs`, or isolate it under `test/` as a fixture.

**God module with weak typing:**
- Issue: `src/Surypus/API/Server.hs` is 911 lines and produced 101 `-Wmissing-signatures` warnings in the last recorded build (`build.log`, 2026-10-22).
- Impact: Route type, handlers, auth glue, and helper SQL live in one file; changes are merge-conflict prone and handlers are inferred rather than specified.
- Fix approach: Split by resource (`Server/Auth.hs`, `Server/Bills.hs`, …) following the existing `Surypus.API.CRM` split, and add explicit signatures to every top-level binding.

**Repository hygiene and duplicated schema copies:**
- Issue: 895 tracked SQL files; `config/schemas/` contains 197 byte-identical copies of `config/*.sql`; `config/schema_*.sql` (203 files) duplicates `sql/migrations/` content.
- Files: `config/schemas/`, `config/*.sql`, `sql/migrations/`
- Impact: Reviewers cannot tell which schema is authoritative; edits land in the copy that is never applied.
- Fix approach: Keep only `sql/migrations/` plus a `sql/schema.sql` snapshot generated from it; delete `config/schemas/` and the one-off `config/schema_*.sql` files.

**Source tree pollution and documented paths that do not exist:**
- Issue: `src/.claude/CLAUDE.md`, `src/.planning/research/*.md`, and `src/AGENTS.md` live inside the library source dir. `AGENTS.md` documents `config/migrations/V001…V010` and `config/migrations/init_db.sh`, but `config/migrations/` does not exist (migrations are in `sql/migrations/`). `AGENTS.md` also references `src/APIServer.hs`, which does not exist.
- Impact: Agents and contributors follow wrong instructions; `stack sdist` would ship agent metadata.
- Fix approach: Move agent docs to the repo root or `.agents/`, delete `src/.claude`/`src/.planning`, and correct `AGENTS.md` paths.

**Aspirational CI and verification claims:**
- Issue: 81 workflow files under `.github/workflows/`, most non-gating. `.github/workflows/liquidhaskell-verify.yml:40-52` silently skips verification when `liquid` is unavailable (`stack install … 2>/dev/null || echo skipped`, then `if command -v liquid`). `.github/workflows/haskell-hlint.yml:29` ends with `|| true`. `.hlint.yaml` ignore rules reference modules that no longer exist (`Core.PriceList`, `Core.Currency.Operations`, `DB.TechCard`, `Domain.Asset`, `APIServer`).
- Impact: "Formally verified" and "lint clean" cannot be inferred from a green check. `liquidhaskell.yaml` itself states the verifier needs GHC 9.14+ while `stack.yaml` pins GHC 9.6.5.
- Fix approach: Make one required workflow that runs `stack build --test` and `hlint src/` without `|| true`; fail on missing `liquid` or remove the LH workflow and downgrade claims to "annotations present".

## Known Bugs

**Login can never succeed against a registered user:**
- Symptoms: `POST /api/v1/login` always returns 401 for users created via `POST /api/v1/register`.
- Files: `src/Surypus/API/Server.hs:559-560` (register stores `SHA256(password)`), `src/DAL/Mutations.hs:231-245` (`authenticateUser` compares `userPassword user == Just password`, where `userPassword` is the stored hash and `password` is the raw request value).
- Trigger: Register, then log in with the same credentials.
- Workaround: None; compare `hashPassword supplied` against the stored hash, or call a constant-time verifier.

**Refresh-token flow returns an empty access token:**
- Symptoms: `validateRefreshToken` succeeds but `tpAccessToken = ""`; `rtUserId` is `const 0`.
- Files: `src/Surypus/JWT.hs:91-92`, `src/Surypus/JWT.hs:131-145`
- Impact: Refresh yields an unusable token and loses the user identity binding.
- Workaround: Regenerate an access token inside `validateRefreshToken` using the returned `userId`.

**Refresh-token storage targets a table migrations never create:**
- Symptoms: `relation "user_sessions" does not exist` in a migration-managed database.
- Files: `src/Surypus/RefreshTokenRepo.hs:20-27` (writes `user_sessions`), `sql/migrations/V005__refresh_tokens.sql` (creates `refresh_tokens`), `config/schema_complete.sql:417` (only place `user_sessions` is defined)
- Impact: Token persistence fails at runtime; also `rotateStoredRefreshToken` deletes every session for the user, logging out all devices.
- Workaround: Point the repo at `refresh_tokens` or add a migration that creates `user_sessions`; rotate per-token rather than per-user.

**Backup endpoint dumps the wrong database:**
- Symptoms: `pg_dump` fails or dumps nothing.
- Files: `src/Surypus/API/Server.hs:910` — DSN is `postgresql://localhost:5432/surupus` (note the typo `surupus`), with no credentials and no SSL.
- Impact: Backup feature is broken and leaks a local DSN in source; the handler also returns the first 1000 chars of `stdout`, which is not a backup.
- Workaround: Use `DATABASE_URL` from config, stream to a file, and return a path.

**`rebuildBalance` ignores the account code:**
- Symptoms: Balance for account `A` includes movements from account `B`.
- Files: `src/Domain/Accounting/Events.hs:16-17` — `rebuildBalance accCode events = accCode `seq` sum (map extractAmount events)`; the code is only forced, never used to filter.
- Trigger: Replay events spanning more than one account.
- Workaround: Filter `EntryCreated` by the account field before summing. `test/Phase2Phase3/AccountingEventsSpec.hs` only uses a single account, so it does not catch this.

**`formatAmount` crashes on an empty currency symbol and ignores precision:**
- Symptoms: `Prelude.head: empty list` for a currency with `curSymbol = ""`; output renders `3.0` instead of `3.00` for precision 2.
- Files: `src/Finance/Currency.hs:75` (`T.head (curSymbol cur)`), `src/Finance/Currency.hs:60-67` (`round` is banker's rounding; `10 ^ curPrecision` throws `Negative exponent` for a negative precision).
- Workaround: Validate `curSymbol`/`curPrecision` in a smart constructor; use `T.uncons` and a fixed-point formatter.

**Job queue claims are not worker-safe:**
- Symptoms: All workers claim jobs as `worker-1`; a new `status` value crashes the row decoder.
- Files: `src/DAL/Queue.hs:192` (hardcoded `PersistText "worker-1"`), `src/DAL/Queue.hs:357` (`read (T.unpack status)` partial parse)
- Impact: Worker identity metrics/lease logic are wrong; an unexpected status aborts dequeuing with a `Prelude.read` exception.
- Workaround: Generate a per-worker UUID; map status with an explicit `case` returning a default/`Either`.

**Generated migrations collide with hand-written ones:**
- Symptoms: Files written at startup are silently skipped or overwrite ordering assumptions.
- Files: `src/Surypus/App/Main.hs:47-…` writes `sql/migrations/V001__rbac_basic_schema.generated.sql` … `V028__*.generated.sql` into the source tree on every run.
- Impact: Version numbers (`V001`, `V002`, …) collide with `V001__core_schema.sql` etc.; the runner keys on version alone, so one file per version is applied. It also mutates a git working tree from application startup.
- Workaround: Generate to a build directory and give generated files distinct high version numbers, or make generation a CLI subcommand, not startup.

**Event-bridge subscriptions never deliver:**
- Symptoms: `subscribeEvent` returns a queue that never receives events.
- Files: `src/Surypus/EventBridge.hs:49-74`
- Impact: Any consumer relying on event fan-out silently misses everything.
- Workaround: Implement dispatch by reading `Subscription` queues on publish, or remove the module.

## Security Considerations

**Tenant isolation uses a process-global `IORef` (cross-tenant data leak):**
- Risk: `tenantContextVar` is a single `IORef` shared by all request threads, despite the comment "Thread-local tenant context". Concurrent requests overwrite each other; `tenantMiddleware`'s `bracket_` clears the context while another request is still using it. Queries then run with another tenant's `app.tenant_id`.
- Files: `src/DAL/Database.hs:27-40`, `src/MultiTenancy/Middleware.hs:38-62`
- Current mitigation: None; `runDb` reads the global var (`src/DAL/Database.hs:48-64`).
- Recommendations: Pass tenant/user explicitly through the DB action, or use `MyThreadId`-keyed storage / `ReaderT` per request. Never use a global `IORef` for request-scoped security context.

**Tenant context is not exception-safe and mixes session/transaction scoping:**
- Risk: `runDb` clears `app.tenant_id` only after `action` returns; on exception the connection is returned to the pool with context still set. It also issues `SET SESSION app.tenant_id = ''` (`src/DAL/Database.hs:60`) which is not transaction-local, unlike `set_config(..., TRUE)`.
- Files: `src/DAL/Database.hs:48-64`, `src/DAL/Database.hs:68-79`
- Recommendations: Wrap in `finally`/`bracket`; use only transaction-local `set_config`; reset in `finally` before returning the connection.

**RBAC fails open for unmapped routes:**
- Risk: `withAuthzResolverAdvanced` allows the request whenever `requiredPermissionForPathMethod` returns `Nothing`. Routes such as `graphql`, `payments`, `dashboard`, `auth/me`, `bill-templates`, `audit`, and `reports` are not mapped (`src/Surypus/API/Authorization.hs:101-121`). Any authenticated user can call them regardless of role.
- Files: `src/Surypus/API/AuthMiddleware.hs:80-89`, `src/Surypus/API/Authorization.hs:101-121`
- Current mitigation: A second `authMiddleware` in `src/Surypus/API/Server.hs:168-181` enforces authentication only.
- Recommendations: Default-deny: return 403 when a route is unmapped and add an explicit allowlist for public routes.

**Public-path matching is prefix-based:**
- Risk: `any (T.isPrefixOf path) publicPaths` (`src/Surypus/API/AuthMiddleware.hs:62`) treats any path with a public prefix as public. A configured `/api/v1/auth` opens `/api/v1/auth/anything`; `/api/v1` opens the whole API.
- Recommendations: Match exact normalized paths (or segment-wise), and keep public paths to a small explicit list.

**Hardcoded database credentials in library code:**
- Risk: `src/DAL/Database.hs:43` and `src/DAL/ORMPool.hs:15` embed a full libpq DSN including user and password; `sql/migrations/init_db.sh` sets `PGPASSWORD` literally in ~10 commands.
- Files: `src/DAL/Database.hs:43`, `src/DAL/ORMPool.hs:15`, `sql/migrations/init_db.sh:17,20,32,41,57,64,94,100,108`
- Current mitigation: Credentials are development defaults, but they ship in the binary and the container.
- Recommendations: Read `DATABASE_URL`/`DB_*` from the environment at startup, fail if absent, and rotate the default credentials. (Values intentionally not reproduced here.)

**Default JWT signing secret is exported:**
- Risk: `defaultSecretKey = "surypus-dev-secret-key-change-in-production"` is exported from `src/Surypus/JWT/Token.hs:16,58-59` and imported by `src/Surypus/API/AuthMiddleware.hs:20`. `getSigningKey` also uses `error` when `SURYPUS_JWT_SECRET` is unset (`src/Surypus/JWT/Token.hs:73-78`), which can crash the process during token verification.
- Current mitigation: The active middleware path uses `getSigningKey`; the fallback constant is unused but reachable via the exported API.
- Recommendations: Delete `defaultSecretKey`, return `Either` from `getSigningKey`, and validate secret length/entropy at startup.

**Password hashing is unsalted SHA-256 or a fake KDF:**
- Risk: `hashPassword` in `src/Surypus/API/Server.hs:559-560` is a single unsalted SHA-256. `src/Infrastructure/Encryption.hs:41-69` claims PBKDF2 but uses a fixed salt `"deadbeef"`, caps iterations at `min iter 1000`, and defines `xor = (+)`. Comparison is plain `==` (`src/DAL/Mutations.hs:243`), not constant-time.
- Current mitigation: None.
- Recommendations: Use `cryptonite`'s `Crypto.KDF.PBKDF2` or `bcrypt`/`argon2` with a per-user random salt, constant-time comparison, and a versioned hash prefix.

**Encryption stubs silently return plaintext:**
- Risk: `src/Infrastructure/Encryption.hs:23-37` uses an all-zero key/IV and `encrypt`/`decrypt` are identity functions. `src/Infrastructure/EncryptionAdvanced.hs:27-60` returns plaintext with a zero tag and `secureWipe` is a no-op. Any caller that stores "encrypted" data stores it in the clear.
- Files: `src/Infrastructure/Encryption.hs:21-37`, `src/Infrastructure/EncryptionAdvanced.hs:27-60`, `src/System/Secrets.hs:44-56` (plaintext `TVar` store, comment says "placeholder")
- Current mitigation: These modules currently have no production callers, so the risk is latent.
- Recommendations: Remove them from `exposed-modules` until implemented, or make every stub return `Left "not implemented"` so no caller can mistakenly rely on it.

**Refresh tokens are stored in plaintext:**
- Risk: `src/Surypus/RefreshTokenRepo.hs:20-27` inserts the raw token into `user_sessions.token`; a database read yields directly usable refresh tokens.
- Recommendations: Store a SHA-256/HMAC of the token and compare hashes; add expiry cleanup and per-device rows.

**Row-level security is ineffective under the default connection:**
- Risk: `sql/migrations/V016__rls_policies.sql` enables RLS with policies `USING (tenant_id = app.current_tenant_id())`, but `createPool` connects as the `postgres` superuser (`src/DAL/Database.hs:43`), which bypasses RLS. Policies use `ENABLE` (not `FORCE`), so table owners also bypass them. Application queries almost never filter `tenant_id` (27 occurrences in `src/`, mostly inserts).
- Files: `sql/migrations/V016__rls_policies.sql`, `src/DAL/Database.hs:43`, `src/DAL/Queries.hs`
- Recommendations: Connect as a non-owner role with only DML grants, use `FORCE ROW LEVEL SECURITY`, add tenant predicates to every query as defence in depth, and test cross-tenant reads.

**Secrets committed in deployment configuration:**
- Risk: literal database/admin passwords appear in tracked compose and Grafana files: `docker-compose.yml:11,49,73`, `docker/docker-compose.yml:13,143,228` (Grafana admin), `config/grafana/datasources/datasources.yml:18`.
- Current mitigation: Values look like development defaults; `.env` is git-ignored and `.env.example` values are placeholders (verified).
- Recommendations: Replace with `${VAR:?required}` interpolation or Docker secrets, rotate anything that was ever real, and add these paths to the `secret-guard` checks. (Values intentionally not reproduced here.)

**Authorization by path prefix, role claim always empty:**
- Risk: `generateToken` writes `"role": []` (`src/Surypus/JWT/Token.hs:95`), so `checkPermission userRoles` always fails and only the DB checker matters; `CHECK` is skipped entirely when `checkPerm` is not wired. `checkAdminStatus` is `pure False` (`src/Surypus/RBAC.hs:156-157`) and `setPermissionChecker` is never called anywhere, so `requirePermission` always returns `Left "Permission checker not initialized"`.
- Files: `src/Surypus/JWT/Token.hs:92-98`, `src/Surypus/RBAC.hs:138-157`, `src/Surypus/API/Server.hs:183-208`
- Recommendations: Put real roles in the token (or resolve roles by `sub` server-side), initialise the checker during startup and fail fast if absent, and remove dead bypass helpers.

**SQL identifier concatenation:**
- Risk: `src/DAL/Procedures.hs:35,46` builds `CALL <procName>(?)` / `SELECT <funcName>(?)` by concatenation. `src/MultiTenancy/Provisioning.hs:50,57` concatenates table names into `CREATE POLICY`. Parameters are bound, but identifiers are not.
- Files: `src/DAL/Procedures.hs:33-48`, `src/MultiTenancy/Provisioning.hs:44-58`
- Recommendations: Validate identifiers against `pg_catalog`/an allowlist, or use `format('%I', ...)` server-side. Do not accept caller-provided names.

**JSON error bodies built by string concatenation:**
- Risk: `"{\"error\":\"" ++ err ++ "\"}"` in `src/Surypus/API/AuthMiddleware.hs:78` embeds JWT library error text unescaped, producing malformed JSON and a reflected-content vector.
- Recommendations: Encode with `Aeson.encode` and a typed error record.

**Path traversal / header injection surface in report download:**
- Risk: `serveReportFile` derives `filename` from the raw URL path and passes it into `Content-Disposition` (`src/Surypus/API/Reports.hs:210-217`). File lookup is UUID-keyed, so traversal is blocked, but CRLF in the header value is not validated.
- Recommendations: Validate the filename against `^[0-9a-f-]{36}\.pdf$` before use.

## Performance Bottlenecks

**Synchronous subprocesses inside request handlers:**
- Problem: PDF generation calls `weasyprint` and backup calls `pg_dump`, both blocking the Servant worker for the duration.
- Files: `src/Surypus/API/Reports.hs:189-201` (`readProcessWithExitCode "weasyprint"`), `src/Surypus/API/Server.hs:908-911` (`readProcess "pg_dump"`)
- Cause: No job queue hand-off despite four queue implementations existing.
- Improvement path: Enqueue a report/backup job (`DAL.Queue`), return `202 Accepted`, and stream results from object storage.

**Report artifacts accumulate without bound:**
- Problem: `reportFilesRef :: IORef (Map Text FilePath)` grows forever (`src/Surypus/API/Reports.hs:87-89`); generated PDFs under `/tmp/surypus-reports` are never deleted; `serveReportFile` never removes an entry.
- Cause: No TTL/eviction.
- Improvement path: Store metadata in Postgres with `expires_at`, delete files on a scheduled sweep, and bound the map (LRU or DB-backed).

**Rate-limiter state grows per client key:**
- Problem: `rlsIpWindows`/`rlsTenantWindows` are `TVar (Map key (Seq UTCTime))` and keys are only pruned when that key is seen again (`src/Surypus/API/RateLimiter.hs:123-145`).
- Cause: No global sweep.
- Improvement path: Periodic compaction of stale keys, or a bounded LRU/cuckoo structure.

**Polling workers with fixed sleeps:**
- Problem: `threadDelay` polling loops in `src/DAL/Queue.hs:250`, `src/System/Jobs.hs:221-226`, `src/System/JobQueue.hs:83`, `src/Production/ServiceManager.hs:38-40`, `src/System/Scheduler.hs:128`.
- Cause: No `LISTEN/NOTIFY` or blocking dequeue.
- Improvement path: Use `LISTEN/NOTIFY`/`SELECT … FOR UPDATE SKIP LOCKED` with a condition variable; make intervals configurable.

**Fixed small connection pool:**
- Problem: Both pool constructors hardcode 10 connections (`src/DAL/Database.hs:43`, `src/DAL/ORMPool.hs:15`); there is no per-request pool acquisition metric.
- Cause: No configuration surface.
- Improvement path: Read pool size/timeout from env (`.env.example` already defines `DB_POOL_SIZE`/`DB_POOL_TIMEOUT`, currently unused).

**Very large build/test surface:**
- Problem: 381 exposed modules in one library; last build produced 721 local warnings (`build.log:…`), dominated by 101 missing signatures in one module; `dist-newstyle` is 299 MB and `.stack-work` is 560 MB in the working tree.
- Cause: Single monolithic library with no internal package boundaries.
- Improvement approach: Split into `surypus-core`, `surypus-dal`, `surypus-api` packages to parallelise builds and enforce layering; add `ghc-options: -Wall -Werror=incomplete-patterns` in `Surypus.cabal` (currently `-Wall` exists only via `stack.yaml` `$locals`, so `cabal build` sees no warnings).

## Fragile Areas

**Two schema layers with a name collision on `Entity`:**
- Files: `src/DAL/Schema.hs` (hand-maintained records, exports `Schema`, `Entity`, `Field`, `EntityField`), `src/Surypus/DB/Schema.hs:33-117` (Template Haskell `persistLowerCase` entities, re-exports `DAL.Schema` and hides `CurrencyEntity`)
- Why fragile: `DAL.Schema.Entity` shadows `Database.Persist.Entity` conceptually; `DAL.Schema` says "Generated from dsl/schema.yaml — DO NOT EDIT MANUALLY" yet 22 declarations are marked `Phase 1: stub`. `Surypus.DB.Schema` also provides `runMigrations` (line 115-117), a second migration mechanism alongside `sql/migrations/`.
- Safe modification: Add fields in both places or, better, collapse to the Persistent schema and generate the SQL from it. Never call `runMigrations` in production.
- Test coverage: `test/Contract/SchemaSpec.hs` validates `dsl/schema.yaml` only, not `DAL.Schema` drift.

**Migration runner cannot express collisions or rollbacks:**
- Files: `sql/migrations/init_db.sh`, `sql/migrations/V*.sql`
- Why fragile: 359 migration files; 12 duplicated version numbers (`V001`, `V1005`, `V180`, `V181`, `V182` ×3, `V183`–`V189`, see `sql/migrations/`); 22 numeric gaps; the runner keys `schema_version` by version string only, so the second file for a version is silently treated as applied. There are no checksums, so editing an applied migration is undetected, and there is no per-migration transaction/rollback. `Surypus.App.Main` can add `.generated.sql` files that match the same `V*.sql` glob.
- Safe modification: Before adding a migration, check `ls sql/migrations/V<next>__*`; renumber collisions to a fresh high number; never edit an applied file. Prefer adding checksums (`sha256`) and applying each file in a transaction.
- Test coverage: `test/MigrationDryRunSpec.hs` exists; it cannot catch duplicate-version skipping.

**Global mutable state via `unsafePerformIO`:**
- Files: `src/DAL/Database.hs:29-31`, `src/Surypus/RBAC.hs:140-142`, `src/Surypus/API/Reports.hs:87-89`
- Why fragile: Initialisation order is invisible; tests share state; nothing resets between requests or test cases. `permCheckerRef` is never initialised (`setPermissionChecker` has no callers), so permission checks fail closed while appearing "configured".
- Safe modification: Replace each with an explicit handle passed through `Env`/`ReaderT`. If one must remain, add a reset hook for tests.

**Partial functions on external data:**
- Files: `src/DAL/Queue.hs:357` (`read` on DB status), `src/Finance/Currency.hs:75` (`T.head` on symbol), `src/Finance/Currency.hs:62` (`10 ^ curPrecision`, negative exponent throws), `src/Surypus/JWT/Token.hs:77` (`error` on missing env)
- Why fragile: Failures surface at runtime on data that type-checks.
- Safe modification: Replace with `readMaybe`/`T.uncons`/validated smart constructors, and keep validation at the boundary.
- Test coverage: `test/Finance/CurrencySpec.hs` covers conversion/rounding but not empty symbols or negative precision.

**`Finance.Types` floating-point invariants:**
- Files: `src/Finance/Types.hs:141-146` (`totalDebit == totalCredit` on `Double`), `src/Finance/SheetDiffs.hs:17-18` (tolerance `0.01` only)
- Why fragile: A balanced entry can fail due to binary rounding; different modules use different tolerances (exact vs `0.01`).
- Safe modification: Compare rational/scaled integers with an explicit epsilon constant shared across modules.
- Test coverage: `test/Domain/InvariantsSpec.hs` covers some properties but not exact-equality balance.

**`data Stock` generators can construct invalid states:**
- Files: `test/Domain/InvariantsSpec.hs:157-167` generates arbitrary doubles (including negatives/NaN) for `Stock`, then asserts non-negativity properties; `src/Inventory/Stock.hs:39-49` is the only validating constructor.
- Why fragile: Properties can pass vacuously or fail depending on generator ranges; `NaN` comparisons silently break both.
- Safe modification: Generate through `mkStock` (returning `Maybe`) and discard `Nothing`, or clamp with `arbitrary `suchThat``.
- Test coverage: `test/Inventory/StockSpec.hs` exists (per `TASKS.md`), but the domain-invariant generator bypasses the smart constructor.

**Test suite breadth vs suite wiring:**
- Files: `test/Test.hs`, `Surypus.cabal:475-543`
- Why fragile: 63 specs wired, 1010 examples pass, but 3 are `pendingWith` for live Redis/Postgres (`test/DAL/EventStoreIntegration.hs:26`, `test/Infrastructure/EventStore/AccountingIntegration.hs:56`, `test/Infrastructure/Redis/EventStreamSpec.hs:41`, `test/Core/Accounting/RedisCacheSpec.hs:48`). Those paths are effectively untested in CI. `test/DAL/EventStoreSpec.hs` exists but is not in `other-modules`.
- Safe modification: Run Postgres/Redis service containers in CI and convert `pendingWith` to failures when the env var is absent in CI; delete or wire the orphan spec.

## Scaling Limits

**Single-process, single-instance assumptions:**
- Current capacity: In-memory queues, scheduler, rate limiter, load-balancer registry, and tenant context are all process-local (`src/System/Jobs.hs`, `src/System/Scheduler.hs`, `src/Surypus/API/RateLimiter.hs`, `src/System/LoadBalancer.hs`, `src/DAL/Database.hs`).
- Limit: Any horizontal scaling breaks rate limits (each replica allows the full quota), job processing (work is not shared unless `DAL.Queue` is used), and tenant isolation (the global `IORef` is per-process, so it is "safe" only by accident within one request thread — and unsafe across threads).
- Scaling path: Move all shared state to Postgres/Redis (queues, rate limits, tenant), and make the app stateless.

**Database connection ceiling:**
- Current capacity: 10 connections per process (`src/DAL/Database.hs:43`).
- Limit: A handful of concurrent report/backup requests exhausts the pool and blocks health checks and auth queries.
- Scaling path: Configurable pool (`DB_POOL_SIZE`), a separate pool for long-running jobs, and PgBouncer in front of Postgres.

**Report storage:**
- Current capacity: Unbounded `/tmp` files and an unbounded in-memory map (`src/Surypus/API/Reports.hs:87-89,189-201`).
- Limit: Disk fills; the process OOMs after enough reports.
- Scaling path: Object storage (S3-compatible) with signed URLs and a retention policy.

## Dependencies at Risk

**`Data.Decimal` orphan JSON instances:**
- Risk: `src/Finance/Tax.hs:126-132` defines package-global `ToJSON`/`FromJSON` for a third-party type. If another dependency (or a future `Decimal` release) defines them, the build breaks with duplicate instances.
- Impact: Serialization of all `Decimal` values depends on which module happens to be linked.
- Migration plan: Wrap in a local `newtype Money = Money Decimal` with its own instances, or use `Data.Aeson`'s `Scientific` at boundaries.

**`cryptonite` + `jose` JWT stack:**
- Risk: `cryptonite` is in maintenance mode and pinned to `==0.30` in `cabal.project`; `jose` is constrained `<0.11`.
- Impact: Security fixes may not land; Haskell 9.14/LH tooling is incompatible with the current GHC 9.6.5 pin.
- Migration plan: Move to `crypton`/`jose` newest, and align `stack.yaml`/Docker base image with the chosen GHC.

**External binaries not declared:**
- Risk: `weasyprint` (PDF) and `pg_dump` (backup) are invoked at runtime but neither is installed in the runtime image (`Dockerfile:44-50` installs only `libpq5`, `ca-certificates`, `curl`, `dumb-init`).
- Impact: Report generation and backup fail with `ENOENT` in production while working on a developer machine.
- Migration plan: Install `weasyprint`/`postgresql-client` in the runtime stage, or replace with an in-process renderer and `pg_dump` sidecar; pin versions.

**Stack resolver vs Docker base image:**
- Risk: `Dockerfile:8` uses `haskell:9.14.1`, but `stack.yaml` resolves `lts-22.21` (GHC 9.6.5); `stack setup --install-ghc` downloads a second toolchain.
- Impact: Bloated images and a GHC version that differs from `liquidhaskell.yaml`'s stated 9.14 requirement.
- Migration plan: Pin the builder to the resolver's GHC, or move to `cabal` + `ghcup` with a single toolchain.

**Eight-plus agent/editor directories tracked:**
- Risk: `.agents/`, `.claude/`, `.codex/`, `.gemini/`, `.opencode/`, `.windsurf/`, `.kilo/`, `.qwen/`, `.trae/`, `.junie/`, `.hermes/`, `.augment/`, `.codebuddy/`, `.cursor/`, `.kiro/` all contain duplicated GSD tooling (see `.gitignore` ignoring only some). `git ls-files` shows 11,427 tracked files, 816 of them generated docs.
- Impact: Review noise, large clone, security surface from committed hook scripts (`secrets.cjs`, `gsd-secret-read-guard.js`).
- Migration plan: Keep one agent config, git-ignore the rest, and remove generated caches from tracking.

## Missing Critical Features

**Real RBAC permission store:**
- Problem: `Surypus.RBAC` has no DB-backed store wired; `setPermissionChecker` is never called; `checkAdminStatus` is `pure False`; `DAL.Repository.RBAC` always returns `True`.
- Blocks: Any meaningful authorization; `TASKS.md` TASK-019 tracks this.
- Needed: `user_role`/`role_permission` tables (already in `sql/migrations/V006`/`V007`), a `Surypus.RBAC.Store` checker injected in `main`, and route coverage for every resource.

**Refresh-token rotation/revocation:**
- Problem: `rtUserId = const 0`, empty access token on refresh, plaintext tokens, wrong table.
- Blocks: Session security, multi-device login, logout-everywhere (`TASKS.md` TASK-020).

**Working event bus / background daemon:**
- Problem: `EventBridge` is a stub, `ServiceManager` is a no-op, `EventBus` has Kafka TODOs, and the four queues are unwired.
- Blocks: Async reports, notifications, scheduled jobs, integration sync.

**Real GraphQL:**
- Problem: `src/Surypus/API/GraphQL.hs:48-56` parses only the first whitespace-delimited token as an "operation"; there is no parser, schema, or resolver layer.
- Blocks: Any GraphQL client; the advertised `/api/v1/graphql` endpoint is non-functional.

**Server startup and configuration:**
- Problem: No `main` that constructs the app; `Surypus.Domain.Config.Config` only has `rcLogLevel`/`rcMaxWorkers` and ignores `.env.example`'s 23 variables.
- Blocks: Deployment, health checks, Graceful shutdown, metrics endpoint exposure.

**Multi-tenancy provisioning:**
- Problem: `src/MultiTenancy/TenantConfig.hs:45,60,67` are TODOs; tenant creation/schema provisioning is not implemented end-to-end. `resolveTenantFromJWT` rejects tokens without `tenant_id`, but `generateToken` always writes a numeric (possibly 0) tenant.
- Blocks: Onboarding a second tenant safely.

## Test Coverage Gaps

**78% of exposed modules are never imported by any test:**
- What's not tested: 300 of 381 exposed modules, including all of `Commerce.*` (except 10), most of `DAL.*` (`DAL.Mutations`, `DAL.MutationsORM`, `DAL.Queries`, `DAL.Schema`, `DAL.Queue`, `DAL.Procedures`), `HR.*` (except `HR.Operations`/`HR.Person`), `Integration.*`, `Production.*`, `Security.*`, `Messaging.*`, and `Surypus.API.*` handlers.
- Files: `Surypus.cabal:25-405` vs `test/**/*.hs`
- Risk: Refactors of handlers, DAL SQL, and migrations break silently; the 1010 passing examples cover mostly pure domain helpers.
- Priority: High

**Authentication and authorization paths:**
- What's not tested: `handleLogin`, `handleRegister`, `handleAuthMe`, `withAuthzResolverAdvanced`, `requiredPermissionForPathMethod` default branch, `Surypus.RBAC`, `DAL.Repository.RBAC`.
- Files: `src/Surypus/API/Server.hs:558-597`, `src/Surypus/API/AuthMiddleware.hs`, `src/Surypus/RBAC.hs`
- Risk: The login-always-fails bug and the fail-open route gap above are both uncovered.
- Priority: High

**Migrations and schema drift:**
- What's not tested: duplicate version detection, applied checksums, RLS policy presence, `user_sessions` vs `refresh_tokens`, `job_queue` DDL, tenant predicates.
- Files: `sql/migrations/`, `test/MigrationDryRunSpec.hs`
- Risk: A fresh production database diverges from the one developers use.
- Priority: High

**Queue/worker concurrency:**
- What's not tested: `DAL.Queue` dequeue under contention, retry/dead-letter transitions, duplicate `worker_id`, partial `read` on unknown status.
- Files: `src/DAL/Queue.hs`, `src/System/JobQueue.hs`, `src/Infrastructure/Redis/TaskQueue.hs`
- Risk: Job loss or duplicate processing in production.
- Priority: Medium

**External integrations:**
- What's not tested: `External.EGAIS`, `External.VETIS`, `External.Jasper`, `External.Pentaho`, `External.UHTT`, `Integration.EDI`, `Integration.BankStatement`, `Integration.Hub`.
- Files: `src/External/`, `src/Integration/`
- Risk: Adapter contract changes break silently; no recorded HTTP fixtures.
- Priority: Medium

**Tenant isolation under concurrency:**
- What's not tested: two simultaneous requests with different `tenant_id` sharing `tenantContextVar`.
- Files: `src/DAL/Database.hs`, `src/MultiTenancy/Middleware.hs`
- Risk: Cross-tenant leakage, the highest-severity latent bug in the codebase.
- Priority: High

---

*Concerns audit: 2026-10-23*
