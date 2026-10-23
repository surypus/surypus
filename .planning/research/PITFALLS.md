# Pitfalls Research

**Domain:** ERP — double-entry accounting, VAT, inventory; Haskell + PostgreSQL + HTMX + LiquidHaskell
**Researched:** 2026-10-23
**Confidence:** HIGH for codebase-specific findings (read directly from `src/`, `sql/`, tests, CI); MEDIUM for external ecosystem claims (verified web search and primary documentation)

> **Scope bias.** This file intentionally focuses on failure modes that can break *this* milestone: one end-to-end path on real PostgreSQL with a proven `Σ debit = Σ credit` invariant. Generic web-security advice is omitted unless it intersects with that path.

**Phase labels** are descriptive. Map them to the actual roadmap numbers; the ordering constraints are what matter.

| Label | Working name | Purpose |
|-------|--------------|---------|
| P1 | Bootstrap & schema truth | Real `main`, pool, health, one migration runner, fail-fast startup |
| P2 | Money & tax canon | One money type, explicit rate units, delete duplicate engines |
| P3 | Accounting canon & invariant | One ledger schema/write path, DB-enforced balance |
| P4 | Inventory & end-to-end posting | One `Stock`, atomic bill/payment/stock/ledger path |
| P5 | HTMX UI | Server-rendered fragments, idempotent mutations, fresh totals |
| P6 | RBAC & auth hardening | Default-deny route matrix, real role store, audit |
| P7 | Verification & release gate | Blocking DB tests, honest LH status, schema snapshot |

---

## Critical Pitfalls

### Pitfall 1: Two `Decimal`s and a `Double` in a `Decimal` costume

**What goes wrong:**
The codebase has two incompatible types both named `Decimal`, and the module named as the canonical accounting engine imports the wrong one.

- `Surypus.CoreTypes.Decimal` is `newtype Decimal = Decimal Double` (`src/Surypus/CoreTypes.hs:14`).
- `Finance.Tax` (and `Core.Payroll.Calculation`) import `Data.Decimal.Decimal`, the fixed-point type (`src/Finance/Tax.hs:19`).
- `Finance.Accounting` — the module PROJECT.md calls the accounting authority — imports `Surypus.CoreTypes (Decimal)` (`src/Finance/Accounting.hs:23`), i.e. the `Double` wrapper.
- Money still crosses the domain as `Double`: `DAL.Types.billTotal`, `lineAmount`, `accTurnAmount`, `stockQtty`; `Surypus.Types.Common.Money = Money Double` (`:103`); `Finance.Ledger.Amount = Amount Double` (`:40`).
- The database stores `NUMERIC(18,2)`, but inserts use `PersistDouble`. Every Haskell ↔ SQL hop is a silent precision change.
- Two orphan `ToJSON`/`FromJSON` instances for `Data.Decimal.Decimal` (`src/Finance/Tax.hs:126-132`) plus one for `Surypus.CoreTypes.Decimal`; JSON semantics depend on which module is linked.
- Tests import both types: `test/Finance/AccountingSpec.hs` uses `Surypus.CoreTypes`, `test/QuickCheckInvariantsSpec.hs` uses `Data.Decimal`. A test can "prove" a property about a different numeric representation than production.

Because both types have `Num`/`Fractional` (or equivalent) instances and the same name, changing one import compiles cleanly and silently changes the arithmetic.

**Why it happens:**
Consolidation is half-done. The original code used `Double`; a later "fixed precision" change introduced `Data.Decimal` in one subtree without deleting the first type. GHC has no built-in "no `Double` for money" check, and `-Wall` does not warn about type aliases that look alike.

**How to avoid:**
- Choose one representation. Recommended: `newtype Money = Money Integer` (minor units) plus a `Currency` scale, or `Data.Decimal` with one fixed scale and one explicit rounding function. Do not keep both.
- Put it in one module (`Surypus.Money`). Export smart constructors and `moneyToMinor` / `minorToMoney`, not `unMoney`. Do not derive `Num`/`Fractional` for `Money`; force callers through named operations (`addMoney`, `mulRate`, `allocate`).
- Use distinct types at every boundary: `Money`, `Quantity`, `UnitPrice`, `RatePercent`, `RateFraction`. A function that accepts `Money` cannot accidentally receive a quantity.
- Delete `Surypus.CoreTypes.Decimal`, `Surypus.Types.Common.Money`, and `Finance.Ledger.Amount` in the same commit that removes them from `exposed-modules`. A leftover module is a loaded gun.
- CI gate: `grep -rn "Double" src/Finance src/Core/Accounting src/DAL/Types.hs` must be reviewed or empty for money fields. Add `{-# DEPRECATED "use Money" #-}` to the old types and compile with `-Werror=deprecations`.
- DB mapping test: write a value with three decimal places and assert that the round-trip is exact or rejected — never silently rounded.

**Warning signs:**
- `import Surypus.CoreTypes (Decimal)` anywhere in accounting or tax.
- A money field typed `Double` under `src/Finance`, `src/Core/Accounting`, or `DAL.Types`.
- Tests comparing money with `abs (a - b) < 0.01`; the tolerance is hiding the type problem.
- Two `instance ToJSON Decimal` declarations in the tree.
- `fromIntegral` / `toRational` at a module boundary.
- `PersistDouble` in an insert of an amount.

**Phase to address:**
P2. Must land before P3; otherwise the balance invariant is proven about `Double` and has to be redone.

---

### Pitfall 2: Tax-rate units — percent vs fraction, and clamping instead of failing

**What goes wrong:**
Three tax engines disagree about what a "rate" is, and all of them return a plausible number for the wrong unit.

- `Core.Tax` accepts a fraction `0.0–1.0` (`ValidTaxRate`, `applyTax`, `applyTaxInclusive`; `src/Core/Tax.hs:43-63`).
- `Finance.Tax` accepts a percentage `0–100` (`TaxRate`, `calcVAT`, `calcVATFromInclusive`; `src/Finance/Tax.hs:41-92`).
- `System.Cache.calcVATStrict` divides by 100 over `Double` (`src/System/Cache.hs:79-80`).
- Constructors reject the other convention: `mkTaxBracket` rejects `20`, `mkTaxRate` rejects `0.2`.
- Both `applyTax` and `calcVAT` clamp invalid input to `0` rather than returning an error. A 20% rate passed to `Core.Tax` yields `0` tax — indistinguishable from a legitimate zero-rated sale. A `0.2` rate passed to `Finance.Tax` yields `0.2%`, not `20%`.
- The database column is `tax_rates.rate NUMERIC(5,4)` (`sql/migrations/V001__core_schema.sql:117-121`). `NUMERIC(5,4)` maxes at `9.9999`, so a percentage of `20` cannot be stored; a fraction of `0.20` fits. Nothing in the schema states which convention is intended.
- `Finance.Bill.calculateBillTotal` uses `rate / 100` (`src/Finance/Bill.hs:70-82`), while `Finance.Tax` uses `(amount * rate) / 100` — same unit by coincidence, different code paths and different rounding.

**Why it happens:**
"Rate" is a bare number with no phantom unit. The original `Core.Tax` was fraction-based; the later `Finance.Tax` was percentage-based; both were kept. Clamping was added to satisfy non-negativity refinements, which converted a loud error into a silent zero.

**How to avoid:**
- Define `newtype RatePercent = RatePercent Decimal` (0–100) and `newtype RateFraction = RateFraction Rational` (0–1), with exactly one `percentToFraction` and one `fractionToPercent`. No `Num` instance that lets the two mix.
- Keep exactly one VAT module. Delete the other from `src/` and `exposed-modules`; do not leave a compatibility re-export.
- Never clamp an invalid rate to zero. Return `Left (InvalidRate r)` from the smart constructor and from the calculation boundary. A loud `400` beats a silent zero.
- DB: `rate_percent NUMERIC(7,4) CHECK (rate_percent >= 0 AND rate_percent <= 100)` or an integer basis-points column. Name the column for its unit; never a bare `rate`.
- Boundary tests: `0`, `20`, `100`, `120`; `calcVAT 100 (RatePercent 20) == 20`; `calcVATFromInclusive 120 (RatePercent 20) == 20`; `calcPriceWithVAT 100 20 == 120`; and the fraction equivalents. Assert that `120` is rejected, not clamped.
- Log/display the unit: `rate_percent` in JSON and UI, not `rate`.

**Warning signs:**
- `/100` or `*100` in more than one module.
- Any function returning `0` for an out-of-range rate.
- Tests that only ever use `0.2` or only `20`, never both in a conversion test.
- `numeric field overflow` when inserting a 20% rate.
- Tax amount is `0` on a nonzero invoice, or equals the whole subtotal.
- A JSON field called `rate` with no unit.

**Phase to address:**
P2, before any bill posting. A single mis-unit invoice contaminates the ledger and the trial balance.

---

### Pitfall 3: The balance invariant is checked in memory, not in the ledger

**What goes wrong:**
The project can have a green `validateTransaction` test while the database contains no ledger rows, or rows that no one can prove are balanced.

- `Finance.Accounting.validateTransaction` checks `totalDebit /= totalCredit` over `Decimal` and rejects an empty list (`src/Finance/Accounting.hs:88-100`). That is a useful pure guard, but:
  - In this module `Decimal` is the `Double` wrapper (Pitfall 1), so the equality is float equality.
  - It does not reject an entry with both `debit > 0` and `credit > 0`, a zero-value entry, two entries on the same account, or a non-positive account id. A single entry with `debit = credit = 100` passes.
  - `Finance.Types.doubleEntryBalance` uses exact `==` on `Double`; `trialBalanceZero` uses `< 0.01`; `Domain.Accounting.Events` has no check at all. Three modules, three different rules.
- `journal_entries` has no transaction/group id (`sql/migrations/V001__core_schema.sql:81-93`): `id, account_id, debit, credit, amount, currency, date, description, posted`. A global `SUM(debit) = SUM(credit)` can hold while every individual transaction is unbalanced, because the database cannot identify a transaction group.
- A second schema, `ledger_entries` (`sql/migrations/V256__domain_organization_final.sql:147-160`), has `debit_amount`/`credit_amount` and `document_type`/`document_id`, but no constraint trigger and a `tenant_id UUID` that does not match the BIGINT tenant scheme used elsewhere.
- The read path queries `acc_turn` (`src/Surypus/API/Accounting.hs:77`) and the write path inserts into `acc_turns` (`src/DAL/MutationsORM.hs:519`). Neither table is created by the migrations — they exist only in `sql/archive/procedures.sql`. The pure validator can pass while the actual read/write fails with `relation "acc_turn" does not exist`.
- `BillService.postBill` computes `AccTurn`s and returns them in `PostSuccess.createdAccTurns`, but never inserts them. It inserts the bill into `DAL.DB` (an `IORef`) and emits an event (`src/Service/BillService.hs:87-110`, `142-...`). The invariant is satisfied in the response value, not in the database.
- `Domain.Accounting.Events.rebuildBalance` ignores the account code: `accCode `seq` sum (map extractAmount events)`. A replay across multiple accounts returns a meaningless total (`src/Domain/Accounting/Events.hs:16-17`).

**Why it happens:**
The team proved the easy, pure part and assumed the write path would call it. The physical schema was never designed around a transaction group, and seven different accounting implementations each had a different notion of "transaction". `Either Text ()` made the no-op look like success (Pitfall 4).

**How to avoid:**
- Design the ledger around a group:
  - `ledger_transaction(id, posted_at, currency, source_type, source_id, idempotency_key UNIQUE)`
  - `ledger_entry(id, transaction_id REFERENCES ledger_transaction, account_id, debit_minor BIGINT, credit_minor BIGINT, currency)`
  - Amounts as `BIGINT` minor units or `NUMERIC(18,2)`; never `DOUBLE PRECISION`.
- Constraints:
  - `CHECK (debit_minor >= 0 AND credit_minor >= 0)`
  - `CHECK (NOT (debit_minor > 0 AND credit_minor > 0))`
  - `CHECK (debit_minor + credit_minor > 0)`
  - `CHECK (transaction_id IS NOT NULL)`
  - A `DEFERRABLE INITIALLY DEFERRED` constraint trigger that sums `debit_minor` and `credit_minor` per `transaction_id` at `COMMIT` and raises if they differ. PostgreSQL constraint triggers must be `AFTER ROW`; a non-deferred trigger fires after the first leg and rejects a valid multi-leg entry.
- One write path: `postJournal :: LedgerTransaction -> SqlPersistT IO ()`, called inside one `withTransaction`. Nothing else may insert into `ledger_entry`. Add a DB role/privilege rule if possible.
- Integration test: open a raw connection, insert an unbalanced group bypassing Haskell, `COMMIT`, and assert failure. Insert a balanced group and assert the expected row count. This test is the receipt for the invariant.
- Reconciliation query: `SELECT transaction_id, SUM(debit_minor) - SUM(credit_minor) AS diff FROM ledger_entry GROUP BY 1 HAVING SUM(debit_minor) <> SUM(credit_minor)` must return zero rows. Run it in CI, at startup, and as a health check.
- Collapse the duplicate tables/types (`journal_entries`, `ledger_entries`, `acc_turn`, `acc_turns`) to one physical table and one Haskell type. Delete the losers from `exposed-modules` and `src/`.
- Fix `rebuildBalance` to filter by account, or delete the module and use the single read model.

**Warning signs:**
- No `transaction_id` / `group_id` in the ledger table.
- A test that only calls `validateTransaction` and never queries the database.
- `Right ()` from a posting function.
- `SUM(debit) = SUM(credit)` as the only invariant (global, not per transaction).
- Table names differing by one character (`acc_turn` vs `acc_turns`).
- `createdAccTurns` in an API response while `SELECT count(*) FROM ledger_entry` is `0`.
- Different balance tolerances in different modules (`==` vs `0.01`).
- `relation "..." does not exist` on a fresh database.

**Phase to address:**
P3. This is the phase gate: no "end-to-end" claim until the database refuses an unbalanced commit.

---

### Pitfall 4: Stub-shaped success — `Right ()`, `return True`, `putStrLn`

**What goes wrong:**
Large parts of the system report success without doing anything, and the test suite is written to accept that.

- A case-insensitive grep of `src/**/*.hs` for `stub|placeholder|Phase 1:` returns **151** matches on 2026-10-23. The codebase map says **181** across a wider net; the discrepancy is itself a sign that the count is not governed.
- Concrete examples:
  - `Core.Services.Accounting.validateTransaction = Right tx`; `processTransactionWithEvents = Right ()`; `processTransactionWithEvents' = Right []` (`src/Core/Services/Accounting.hs:24-37`).
  - `DAL.Repository.RBAC.checkUserAppPermissionRepo _ _ _ = return True` (`:23`).
  - `Production.ServiceManager.runJobQueueOnce/runCronOnce` only `putStrLn`; `type Pool = ()`.
  - `Surypus.EventBridge.publishEvent` only logs; `unsubscribeEvent = pure ()`; `getHandlerQueue` always `Nothing`.
  - `DAL.Production.getWorkOrder` always `Nothing`; `updateWorkOrder` always `Right "ok"`.
  - `System.Tracing.endSpan = pure ()`; `Surypus.Metrics.flushMetrics = pure ()`.
- Tests reinforce the illusion: `test/Finance/AccountingSpec.hs` asserts `processTransaction ... shouldBe Right ()`. No test queries a row count, an audit row, or an event store after the call. A handler can return `200` and the only observable is the `Either`.
- `Either Text ()` is the perfect stub type: it carries no evidence that anything happened. `Right ()` is indistinguishable from "did nothing".

**Why it happens:**
Scaffolding kept the build green while the schema and API were being designed. "Phase 1" markers were treated as documentation rather than debt. The unit return type made the no-op look intentional.

**How to avoid:**
- Make non-implementation loud: `Left NotImplemented` or `error "not implemented: ..."`. Never `Right ()` / `return True` / `pure ()` for an unimplemented effect. A crash is better than a false success.
- Return evidence, not unit: `postBill :: ... -> IO (Either ServiceError PostedBill)` where `PostedBill` contains the persisted bill id, the ledger transaction id, and row counts. If there is nothing to return, the function is not a service.
- Delete stubs from `exposed-modules` and from `src/` in the same commit. Dead code that compiles is still reachable.
- Add a CI "stub budget": count matches and fail if the number increases. Keep an explicit allowlist with owner and phase; a shrinking allowlist is better than a vague promise.
- Effect assertions in tests: after posting, `SELECT count(*) FROM ledger_entry WHERE transaction_id = ?` must be `> 0`; after a permission check, an audit row must exist; after a job run, the job status must change.
- Startup self-check: `main` fails fast if the DB pool, permission checker, or ledger writer is a stub. Do not start a server that cannot enforce.
- Contract test per route: status + DB effect + audit effect.

**Warning signs:**
- `Right ()` in a service signature; `return True`; `pure ()`; `putStrLn`; `-- TODO`.
- A test that only checks `isRight` / `isLeft`.
- A route returning `200` with an empty database.
- A "success" log line with no corresponding row.
- `type Pool = ()` or another placeholder type synonym.
- Haddock that says "in a full implementation..." — a stub confession.
- A `*Stub` record type in a production path (`BillStub`, `StockStub`).

**Phase to address:**
P1 (make `main` fail fast) and every phase gate. Add a dedicated stub-kill slice before P4; do not let stubs survive into the end-to-end demo.

---

### Pitfall 5: RBAC fails open — default-allow, prefix matching, and an always-True repository

**What goes wrong:**
Authentication works, authorization does not. Any authenticated user can reach routes that were never mapped to a permission.

- `checkUserAppPermissionRepo _ _ _ = return True` (`src/DAL/Repository/RBAC.hs:23`) — the repository that sounds authoritative always grants.
- `requiredPermissionForPathMethod` returns `Nothing` for unmapped routes, and `withAuthzResolverAdvanced` does `Nothing -> app request respond` (`src/Surypus/API/AuthMiddleware.hs:80-89`). Routes such as `graphql`, `payments`, `dashboard`, `auth/me`, `bill-templates`, `audit`, `reports`, and any future `/ui/...` route are open to anyone with a valid token.
- Public-path matching is `any (T.isPrefixOf path) publicPaths` (`:62`). A configured `/api/v1/auth` makes `/api/v1/auth/anything` public; `/api/v1` makes the whole API public.
- `Surypus.RBAC.checkAdminStatus _ = pure False`; `permCheckerRef` is a global `unsafePerformIO IORef` and `setPermissionChecker` has no callers, so `requirePermission` always returns `Left "Permission checker not initialized"` (`src/Surypus/RBAC.hs:140-157`). Meanwhile the request path never calls it.
- `generateToken` writes `"role": []` (`src/Surypus/JWT/Token.hs:92-98`), so `checkPermission userRoles perm` is always false; only the DB checker could matter, and it is not wired.
- A second `authMiddleware` in `Server.hs` verifies the JWT but does not authorize; it runs before `withAuthzResolverAdvanced`, so a reviewer can easily believe authorization is present.
- HTMX routes will live under `/ui/...` (or similar), which the route map does not know at all. Every mutating UI endpoint is fail-open by default.
- Even if roles are put into the JWT, a token issued before a role change keeps the old role until expiry; there is no revocation/refresh path that resolves current roles.

**Why it happens:**
Default-allow is the path of least resistance when adding routes. The `True` stub was added to unblock development. Authentication (who are you?) was confused with authorization (may you do this?). The route map is a hand-maintained second copy of the Servant API, so it drifts immediately.

**How to avoid:**
- **Default-deny.** `Nothing -> respond 403`, with a small, exact-match public allowlist (`/api/v1/health`, `/api/v1/health/db`, `/api/v1/login`, static assets). Normalize the path and match segments, not prefixes.
- Derive the authorization table from the Servant API type, or keep an explicit list plus a test that enumerates every route and asserts it maps to a permission. A new route must fail the test until it is mapped.
- One middleware that authenticates *and* authorizes. Delete the second `authMiddleware`; if both remain, document the order and test it.
- Inject the checker in `main`; if it is missing, exit non-zero. Never start with `permCheckerRef = Nothing`.
- Implement the repository against one role schema. The DB currently has `role`/`user_role` (V006), `roles`/`user_roles`/`role_permissions` (V001), `rbac_dynamic_roles`/`rbac_scoped_permissions` (V009), and `user_roles_v2` (V256) — pick one and delete or archive the rest. Return `Either Denied ()` with a reason for the audit log, not a bare `Bool`.
- Resolve roles server-side by `sub` on every request (or cache with a short TTL and a revocation check). The JWT role claim is a cache, not the source of truth.
- Test matrix: for each route, anonymous → `401`, wrong role → `403`, right role → expected success. Include `/ui` mutations, reports, audit, and GraphQL. Loop over the route list; this is the cheapest insurance in the project.
- Audit every deny and every allow for mutating routes. The audit sink must be the DB, not an in-memory `IORef`.

**Warning signs:**
- `Nothing -> app request respond` in an auth middleware.
- `T.isPrefixOf` on public paths.
- `return True` / `pure True` in a permission repository.
- `checkAdminStatus _ = pure False` or `"role": []` in a token.
- A new route in `Server.hs` with no matching entry in `Authorization.hs`.
- Tests only cover `401` (missing token), never `403` (wrong role).
- A storekeeper can `POST /api/v1/bills` because the route is unmapped.
- Four different role table families in `sql/migrations/`.

**Phase to address:**
P1 for default-deny and fail-fast startup; P6 for the role model and the complete matrix. **No mutating UI route ships before P6.**

---

### Pitfall 6: Migration drift — duplicate versions, no checksums, partial success recorded as success

**What goes wrong:**
The database that developers use and the database a fresh environment builds are not the same, and the runner cannot tell.

- `sql/migrations/` contains **359** `V*.sql` files. There are duplicate version numbers (`V001` twice, `V1005` twice, `V183`–`V189` multiple) and 22 numeric gaps. The runner keys on the numeric version only (`sql/migrations/init_db.sh`), so the second file for a version is silently treated as already applied.
- `schema_version` has no checksum. Editing an applied migration is undetected.
- The runner does `ON CONFLICT (version) DO UPDATE SET success = TRUE`. A previously failed migration can be marked successful without re-running.
- Each file is applied with `psql -f` and no `ON_ERROR_STOP=1`. A mid-file SQL error can leave a partial schema and still be recorded as applied, because `psql` exit status is not the SQL status by default.
- There is no per-migration transaction. A failed multi-statement file leaves partial objects behind.
- `Surypus.App.Main` writes `V001__rbac_basic_schema.generated.sql` … into `sql/migrations/` at startup, colliding with hand-written versions and mutating the source tree.
- `Surypus.DB.Schema.runMigrations` is a second migration mechanism next to `sql/migrations/`. `DAL.Schema` is hand-maintained and claims to be generated. `config/schemas/` holds 197 byte-identical copies and `config/schema_*.sql` 203 more.
- Concrete drift already present:
  - `src/Surypus/RefreshTokenRepo.hs` writes `user_sessions`, but `V005__refresh_tokens.sql` creates `refresh_tokens`.
  - `acc_turn` / `acc_turns` are only in `sql/archive/procedures.sql`, not in any migration.
  - `job_queue` DDL is inline in `DAL.Queue.initializeQueue`, not in a migration.
  - `ledger_entries` (`V256`) uses `tenant_id UUID` while most other tables use `BIGINT`.

**Why it happens:**
Migrations accumulated organically from multiple branches and generators. The runner was optimized for "apply everything" rather than "prove the schema". Files written at startup were convenient. `CREATE TABLE IF NOT EXISTS` made repeated runs quiet, which also hid definition changes.

**How to avoid:**
- Freeze a baseline: one directory (`sql/migrations/`), one runner, one `schema_migrations(version, description, checksum, applied_at, success)` table. Delete or archive `config/schemas/`, `config/schema_*.sql`, and the generated-at-startup path.
- Renumber duplicates to fresh, unique, monotonically increasing versions *before* the next deploy. Never edit an applied file. Flyway's rule is the right one: restore the original and add a new forward migration.
- Runner requirements:
  - `psql -v ON_ERROR_STOP=1` (or an equivalent SQL client setting).
  - One transaction per file, or an explicit `BEGIN`/`COMMIT` with rollback on error.
  - Verify the checksum before applying; fail on mismatch.
  - Record success only after commit.
  - Fail on duplicate versions and on unexpected gaps.
- CI: create an empty database, apply all migrations, run schema assertions, `pg_dump --schema-only`, compare to a committed snapshot. Repeat against a database restored from the previous release to catch drift.
- Never generate migrations at application startup. Generation is a developer command, reviewed and committed.
- Add a migration linter: duplicate versions, filename/version mismatch, uncommitted DDL in Haskell (`grep -rn "CREATE TABLE" src/`), and `IF NOT EXISTS` on tables that should already exist.
- Document the canonical schema: `sql/schema.sql` generated from migrations, never hand-edited.

**Warning signs:**
- `ls sql/migrations/V* | sed ... | sort | uniq -d` is non-empty.
- A fresh DB is missing a table the dev DB has.
- `relation "user_sessions" does not exist`, `relation "acc_turn" does not exist`, `relation "acc_turns" does not exist`, `relation "job_queue" does not exist`.
- `CREATE TABLE IF NOT EXISTS` masking a changed definition.
- An applied migration modified after the fact, with no checksum to catch it.
- App startup writes files into `sql/migrations/`.
- `runMigrations` called from `main` or a service.
- `psql` prints `ERROR` but the script continues and reports success.
- `schema_migrations.version` is `VARCHAR(10)` while versions like `V1005` and `V000__schema_version` exist.

**Phase to address:**
P1 (schema truth), and gate every phase that changes schema. P4 cannot be called "on real PostgreSQL" until a fresh database builds cleanly from migrations alone.

---

### Pitfall 7: LiquidHaskell friction — a green check that proves nothing, about the wrong types

**What goes wrong:**
The project's headline "proven debit = credit" can become a non-blocking, skipped CI step whose annotations do not typecheck and whose subject is not the runtime representation.

- LiquidHaskell officially supports **one GHC version per release**. The install matrix maps GHC `9.6.3` → `liquidhaskell-0.9.6.3`, `9.8.2` → `0.9.8.2`, `9.14.1` → `0.9.14.1.1`. The project pins `lts-22.21` (GHC `9.6.5`). `liquidhaskell.yaml` says "GHC 9.6.x" and also claims 9.14+ is required. LH `0.9.14.1` explicitly **removed stack support**.
- `stack install liquidhaskell --resolver lts-22.21 2>/dev/null || echo "skipped"` followed by `if command -v liquid` means a green check can mean "not verified" (`.github/workflows/liquidhaskell-verify.yml:40-52`).
- No module has `{-# OPTIONS_GHC -fplugin=LiquidHaskell #-}`. The `{-@ ... @-}` annotations are inert under `stack build`; `liquid` must be run explicitly, or the plugin must be enabled.
- `Finance.Accounting`'s headline spec references `sumDebits v == sumCredits v`, but `sumDebits` and `sumCredits` are not defined in the module — only local `totalDebit`/`totalCredit` in a `where` clause. LH cannot typecheck an unknown measure; the annotation is aspirational.
- `Data.Decimal.Decimal` is third-party and opaque to LH without `LHAssumptions` / reflection / measures. `Double` is modelled as a mathematical real, not IEEE-754, so a proof about `Double` does not imply the runtime `Double` is exact. The types that carry money are the hardest ones to refine.
- Blanket `{-@ LIQUID "--reflection" @-}` and `--ple` on typeclass-heavy modules increase checker time; `--no-termination` is already used in two modules.
- A proof of `validateTransaction` only says "if this pure function returns `Right`, the in-memory list balances". It says nothing about the database write, the deferred trigger, or whether the write path calls it.

**Why it happens:**
"Formally verified" is both a project goal and a marketing claim. The annotations were written before the toolchain was pinned. CI was made non-blocking to keep the build green. The easiest functions to annotate are pure helpers, not the write path.

**How to avoid:**
- Make **runtime enforcement the primary gate**: DB constraint trigger + property tests + an integration test that attempts an unbalanced commit. LH is supplementary evidence, not the safety net.
- If LH is required, isolate it:
  - A separate `verify` package or cabal flag with an exact GHC/LH pair.
  - `liquidhaskell` in `build-depends`; `{-# OPTIONS_GHC -fplugin=LiquidHaskell #-}` only in that package.
  - A CI job that **fails** if `liquid` is missing. Do not `|| echo skipped`.
  - Pin a real pair, e.g. GHC `9.6.6` + `liquidhaskell-0.9.6.3.1` with the matching `liquidhaskell-boot`, `liquid-fixpoint`, `smtlib-backends`, `smtlib-backends-process` in `extra-deps`, or move the whole project to a GHC with a matching LH. Do not mix.
- Design for proof: `Money` as `Integer` minor units is far easier for LH than `Data.Decimal` or `Double`. Define `sumDebits :: [Entry] -> Integer` and `sumCredits :: [Entry] -> Integer`, and prove `validate = Right t ==> sumDebits t == sumCredits t`. Put the measures in the same module or an `LHAssumptions` module.
- Keep the refined core pure and small: no IO, no DB, no `Decimal`. Prove the ledger algebra; test the boundary.
- Be honest in docs and CI: if the job skips, say "annotations present, not verified". Remove "formally verified" from the README until the job is blocking.

**Warning signs:**
- A green `liquidhaskell` check with a "skipped" line in the log.
- `command -v liquid` is false in CI.
- Resolver GHC patch version ≠ LH's supported GHC.
- LH errors about unknown `sumDebits` / `sumCredits`.
- Refined functions that are not called by the write path.
- Proofs about `Double` or `Data.Decimal` that rely on arithmetic laws.
- LH taking so long that it is moved to `allow_failure`.
- `liquidhaskell.yaml` claims a different GHC than `stack.yaml`.

**Phase to address:**
P2 (choose proof-friendly money), P7 (run and gate). Do not make P3's completion depend on LH; make it depend on the DB test.

---

### Pitfall 8: HTMX server-rendered state bugs — duplicate POSTs, invisible errors, stale fragments

**What goes wrong:**
There is no HTMX in the repository yet (a grep finds none; `web/` is static JS), so these are design-time traps. They are easy to introduce and hard to see in a demo.

- **Duplicate submissions.** A double-click, a retry, or a flaky network sends two `POST /bills`; there is no idempotency key. `hx-disabled-elt` is a UI hint, not a server guarantee; the second request can already be in flight. Result: two bills, two ledger transactions, double stock movement.
- **4xx/5xx are not swapped.** htmx's default `responseHandling` does not swap `400`/`500` responses. A `422` validation fragment is invisible; the user sees nothing and clicks again. (htmx quirks.)
- **3xx + response headers.** htmx response headers (`HX-Redirect`, `HX-Location`) are not available on `3xx` because the browser follows the redirect. A login redirect can be swapped into a table cell. Return `200` with `HX-Redirect`, or do a full-page redirect for auth.
- **Full page into a fragment.** Returning the layout instead of the partial produces nested `<html>`, duplicate forms, and duplicate IDs. htmx expects an HTML fragment; the server must branch on `HX-Request`.
- **Stale adjacent state.** Swapping only the bill row leaves the stock badge, trial balance, and account totals stale. Use `hx-swap-oob` / `<hx-partial>` for every affected region, or re-render the whole workspace. "Stock changed but balance didn't" is the classic.
- **History/back button.** htmx snapshots the DOM in `localStorage`; after a post, navigating back can show the pre-post balance. Set `historyCacheSize: 0` / `hx-history="false"`, or re-render on restore. Authenticated pages should not be cached.
- **CSRF.** htmx sends normal cookie-backed requests. `HX-Request` is not a CSRF token. Use a per-session CSRF token in `hx-headers` and `SameSite` cookies; do not rely on the custom header.
- **XSS.** No HTML templating dependency is in `Surypus.cabal` yet. Manual `"<div>" <> userText` is an injection. Use Lucid/Blaze/Shakespeare with auto-escaping; never concatenate user data into HTML.
- **Auth gap.** `/ui/...` routes are not in `requiredPermissionForPathMethod`, so they are fail-open (Pitfall 5). The HTMX layer must be part of the same route/permission matrix.
- **GET side effects.** `hx-get` for a delete/like is a state change over GET; prefetch or a crawler can trigger it. Mutations must be `POST`/`DELETE` with CSRF.

**Why it happens:**
HTMX makes the happy path feel trivial. The failure modes are at the browser/server boundary and in the *second* request. The framework deliberately does not enforce business idempotency.

**How to avoid:**
- Idempotency key per form render (hidden UUID) + unique constraint / `ON CONFLICT`; return the same result for a replay. For bills: `UNIQUE (idempotency_key)`.
- `hx-disabled-elt="this"` **plus** server-side uniqueness. Never rely on the button state.
- Configure `responseHandling` to swap `422` (validation) and keep `500` non-swapped with an error toast. Return fragments for errors.
- Use `HX-Redirect` for auth/session expiry; `HX-Refresh` after a successful post if the page state is broad; `HX-Trigger` to refresh dependent panels.
- One `renderWorkspace` that returns bill + stock + ledger + totals, with OOB swaps for regions outside the target. Keep IDs stable across swaps.
- `Cache-Control: no-store` on authenticated HTML; disable history cache or revalidate on restore.
- CSRF token in `hx-headers` on `<body>`, `SameSite=Lax/Strict`, and a server-side check on every mutating request.
- Auto-escaping templates; a test that posts `<script>` and asserts it is escaped.
- E2E tests: double-click submit → one bill/one ledger transaction; invalid form → error fragment visible; back button → current balance; wrong role → `403` fragment.

**Warning signs:**
- Two rows with the same business key after a double-click.
- A `422` response with an empty page / no visible error.
- The login page rendered inside a fragment.
- The stock badge updates but the trial balance does not.
- Browser back shows an old balance.
- `hx-get` on a mutating action.
- `"<div>" <> userInput` in Haskell.
- `/ui/bills` returns `200` to a `storekeeper` because the route is unmapped.
- No `HX-Request` branch: the same handler returns a full page for both.

**Phase to address:**
P5. Idempotency and posting atomicity must already exist in P3/P4; the UI cannot fix a non-atomic backend.

### Pitfall 9: Non-atomic posting — the bill row commits, the ledger and stock do not

**What goes wrong:**
`Service.BillService.postBill` performs a sequence of effects with no transaction around them, and two of the four "effects" are pure values returned to the caller rather than writes.

- Step 1 inserts the bill into `DAL.DB`, which is an in-memory `IORef`, not PostgreSQL (`src/Service/BillService.hs:87-95`).
- Step 2 computes `AccTurn`s; Step 3 computes `[(GoodsId, Double)]`; neither is persisted. They are returned in `PostSuccess.createdAccTurns` / `updatedStock` (`:102-108`).
- Step 4 appends a `BillPosted` event to PostgreSQL. If it returns `Left`, the function returns `Left` — but the bill insert already happened and is never rolled back. There is no compensation, no outbox, no retry.
- No module in `src/` calls `withTransaction` or persistent's `transaction`. Every write is its own autocommit.
- `emitBillPostedEvent` hard-codes `eventSequenceNumber = 1` (`:218`). The second event for the same aggregate either violates `UNIQUE (aggregate_id, aggregate_type, sequence_number)` or overwrites, depending on the schema. Event ordering is not derived from state.
- `updateStockLevels` is `map (\l -> (blGoodsId l, blQty l))` (`:181-183`) — it does not read current stock, does not check availability, does not write, and cannot fail. Negative stock is undetectable.
- `calculateLineAmount` clamps a negative line to `0` (`:130-133`). `createAccountingEntries` then debits `sum(lineAmount) - discount` and credits the caller-supplied `total` (`:140-175`). If the clamped sum and `total` disagree, the two entries are unbalanced **by construction**, and nothing checks it.
- Concurrency: two simultaneous posts for the same goods both read the same stock, both succeed, and the second overwrites the first. There is no `SELECT ... FOR UPDATE`, no serializable retry, no DB `CHECK` on the resulting balance.
- Retry: a client retry (or an HTMX double-submit, Pitfall 8) creates a second bill and a second event. There is no idempotency key.

**Why it happens:**
The pure computation was written first and the persistence was stubbed. Each step was added separately, and each one "worked" in its own unit test. The response type carries the computed values, which makes the demo look complete without any rows. `liftIO` makes it easy to interleave effects without a transaction boundary.

**How to avoid:**
- One transaction per business operation: `transaction $ do insertBill; insertStockMovements; postLedger; appendEvent`. Persistent's `transaction` rolls back on exception; convert every `Left` into a thrown error or an explicit `rollback`.
- Persist, then read back, then respond. `PostSuccess` must be built from rows that were committed, not from `let` bindings. If a field is not persisted, it does not belong in the response.
- Add a transactional outbox: `outbox(id, aggregate_type, aggregate_id, event_type, payload, published_at)`. Insert in the same transaction; a background worker publishes. Never publish to an external system before commit.
- Idempotency: `bills(idempotency_key UUID UNIQUE)`. On conflict, return the existing bill and its ledger transaction — same status, same body.
- Stock as movements, not a mutable counter:
  - `stock_movement(id, goods_id, warehouse_id, qty_delta NUMERIC, bill_id, created_at)`
  - `stock_balance` is a view or a materialized table updated by trigger.
  - A `BEFORE INSERT` trigger computes the new balance and raises if it would go below zero (or below a configured minimum).
  - Lock the goods row (`SELECT ... FOR UPDATE`) before the availability check, or run at `SERIALIZABLE` and retry on `40001`.
- Sequence numbers: `COALESCE(MAX(sequence_number), 0) + 1` computed inside the same transaction as the append, with `UNIQUE (aggregate_id, aggregate_type, sequence_number)`. Do not accept a caller-supplied sequence.
- Reject invalid lines instead of clamping: `qty > 0`, `price >= 0`, `discount <= qty * price`, `discount >= 0`. A clamp is a silent business decision.
- Failure-injection test: force a failure after the bill insert and after the stock insert; assert `SELECT count(*)` is `0` for bill, movement, entry, and event.

**Warning signs:**
- `insertBill` / `insert_` / `rawExecute` calls separated by other `IO` actions with no `transaction` wrapper.
- A response record with fields that have no corresponding table column.
- `Left` returned after a previous write in the same function.
- `eventSequenceNumber = 1` or any literal sequence.
- `UPDATE stock SET qty = qty - ?` with no `WHERE qty >= ?`.
- Two concurrent posts produce a negative balance or a lost update.
- A retry produces two bills with the same number.
- `accTurns` in the response while the ledger table is empty.
- `stockQtty` in `DAL.Types` with no movement history.

**Phase to address:**
P4. Requires P3's ledger table and write path first; the transaction boundary must include both.

---

### Pitfall 10: No rounding policy — the database rounds, the app does not, and the invoice does not add up

**What goes wrong:**
Money is computed as unrounded `Double`, persisted into `NUMERIC(18,2)`, and rounded by PostgreSQL using a different rule than the one Haskell uses elsewhere.

- `calculateBillTotal` (`src/Finance/Bill.hs:79-84`) sums `qty * price` and `qty * price * rate / 100` with no rounding at all. It returns `(total, tax)` as `Double`.
- `roundToCurrency` (`src/Finance/Currency.hs:59-68`) converts to `Rational` and uses Haskell's `round`, which is **round-half-to-even** (banker's rounding). PostgreSQL `numeric` rounds **half away from zero**. The same `0.005` becomes `0.00` in Haskell and `0.01` in SQL.
- There is no statement of whether tax is computed per line and summed, or on the subtotal. The two differ once rounding is applied; Russian VAT invoices require line totals that sum exactly to the invoice total.
- `curPrecision` exists on `Currency` but is never consulted when posting. A 2-decimal currency and a 3-decimal currency use the same path.
- FX: the ledger amount could be the rounded converted total or the converted rounded total; the code does neither explicitly. `curRate` is `Double`.
- Discounts are subtracted before tax in `calculateBillTotal`? No — tax is computed on the undiscounted line, and `calculateLineAmount` clamps afterward. The tax base and the line total can disagree.
- Nothing enforces `SUM(line.amount) = bill.subtotal` or `subtotal + tax = total`, so a 1-cent drift is invisible until a customer or an auditor adds the lines.
- Reports that `SUM(NUMERIC)` in SQL and screens that `sum` `Double` in Haskell can disagree by cents on the same data.

**Why it happens:**
Rounding is treated as a formatting concern. Every developer knows "round money", but the decisions that matter — where, when, in which direction, and how the remainder is allocated — are never written down. `Double` makes the problem invisible until the numbers are large or the lines are many.

**How to avoid:**
- Write a one-page money policy and put it in `docs/` next to the code:
  - document currency and its scale (RUB = 2),
  - storage in integer minor units (`BIGINT`) or `NUMERIC(18,2)` — one, not both,
  - rounding mode (pick one; half-even is defensible for calculations, half-up for presentment — but only one is allowed to produce stored values),
  - the rounding point (per line, then allocate the remainder to the total),
  - the tax point (per line vs per invoice) and the tax base (before or after discount),
  - the FX point (convert then round, once).
- Implement `allocate :: Money -> [Rational] -> [Money]` using the largest-remainder method. Property: `sum (allocate total weights) == total` for arbitrary positive totals and weights; every part is within one minor unit of its exact share.
- Round exactly once, at the boundary where `Money` becomes a stored value, in one function. Never let the database be the rounder: if the column is `NUMERIC(18,2)` and the value has more decimals, that is a bug, not a feature. Reject it with a check or round explicitly before insert.
- Add DB checks:
  - `CHECK (line_amount_minor >= 0)`
  - trigger: `SUM(line_amount_minor) = bill_subtotal_minor`
  - trigger: `bill_subtotal_minor + bill_tax_minor = bill_total_minor`
- Golden tests with hand-computed values: `0.005`, `0.015`, `3 × 0.005`, `20% of 0.01`, `100.00 with 20% and a 3.33 discount`, a 3-decimal currency, and an FX conversion. Assert cents, not `Double` equality.
- Cross-check Haskell and PostgreSQL in one test: compute in Haskell, insert, read back, compare minor units. Any difference is a policy bug.
- Reports read persisted minor units. They do not recompute from `Double`.

**Warning signs:**
- `round` / `floor` / `ceiling` in more than one module.
- `fromRational` / `toRational` at several boundaries.
- Tests comparing money with `shouldBe` on `Double`, or with a `0.01` tolerance.
- Invoice lines that do not sum to the printed total.
- A total that changes when the same invoice is re-opened.
- `numeric field overflow` or a silent extra decimal in `psql`.
- The UI shows `100.00`, the ledger shows `99.99`.
- No `CHECK` relating line sums to the bill total.
- Tax computed on the pre-discount amount.

**Phase to address:**
P2 (policy, `Money`, `allocate`), enforced in P4 (bill/invoice/ledger), audited in P7 (golden tests).

---

### Pitfall 11: The test suite proves the stubs, not the system

**What goes wrong:**
The suite is large and green, but the tests that would catch the previous ten pitfalls are either skipped by default, written against the in-memory double, or assert the stub's return value.

- `MigrationDryRunSpec` asserts that `generateV001` … `generateV028` are non-empty strings (`test/MigrationDryRunSpec.hs:7-22`). It never connects to PostgreSQL, never applies a file, and covers 28 generated strings against **359** migration files.
- `DAL.DBSpec` tests `DAL.DB`, the in-memory `IORef` seeded with three persons. The suite's "database" tests never touch `postgresql`.
- `DAL.EventStoreIntegration` and `Infrastructure.EventStore.AccountingIntegration` call `pendingWith` unless `SURYPUS_TEST_DATABASE_URL` is set (`test/DAL/EventStoreIntegration.hs:22-28`, `test/Infrastructure/EventStore/AccountingIntegration.hs:56`). In CI without the variable they are pending — Hspec exits `0`, and the badge is green. The only real PostgreSQL tests are opt-in.
- `Finance.AccountingSpec` asserts `processTransaction ... shouldBe Right ()`, i.e. it encodes the stub as the expected behavior. `Right ()` carries no evidence, so there is nothing else to assert.
- QuickCheck generators construct records directly and use raw `Double` / `Data.Decimal`, bypassing smart constructors. The properties are proven about values the production path may reject, and the generators never produce the invalid values the smart constructors exist to reject.
- The coverage gate fails open: `stack hpc-codecov ... || echo "..."`, and the parser catches every exception with `# Don't fail the build if coverage parsing fails` (`.github/workflows/coverage-gate.yml:61-106`). `fail_ci_if_error: false` on the upload. Coverage is high because stubs execute; 151 stub markers inflate the denominator's numerator.
- No test asserts a row count, a balance, an audit row, or a response body after a mutating call. A handler can return `200` with an empty database and every test passes.

**Why it happens:**
Integration tests are slow and need infrastructure, so they were made optional. The in-memory DAL was convenient and then became the only DAL under test. `Either Text ()` gives the assertion almost nothing to check. Coverage was adopted as a proxy for correctness, and a proxy that fails open is worse than none.

**How to avoid:**
- Make the database mandatory in CI:
  - a `postgres:16` service container,
  - a job that creates an empty database, runs the migration runner, and runs the integration suite,
  - no `pendingWith` for core paths. If the database is unavailable in CI, the job fails.
- Meta-test the suite: grep for `pendingWith` and fail above a documented count (ideally zero for Finance/Service/DAL). A skipped test is a failing test that lies.
- Delete `DAL.DB` from production code. Keep an explicitly named `InMemoryBillStore` only as a test double, and have at least one spec run the same scenarios against PostgreSQL.
- Assert effects, not `Either`:
  - after `postBill`: `SELECT count(*) FROM bills`, `ledger_entry`, `stock_movement`, `outbox` all `> 0`;
  - the ledger group balances;
  - the stock balance equals initial + movement;
  - a second identical request returns the same bill id and does not add rows.
- Property tests go through smart constructors. Add a companion generator for invalid values and assert `Left` / rejection. Test the boundary, not just the happy path.
- Mutation check for each critical invariant: comment out the balance check (or the stock guard) and confirm at least one test fails. If the suite stays green, the test is decoration.
- Coverage gate fails closed: if `coverage.json` is missing or unparsable, `exit 1`. Measure coverage on `Finance.*`, `Service.*`, `DAL.*`, and `Surypus.API.*`, not the whole tree.
- One end-to-end test through HTTP: `POST /bills` → assert DB rows → `GET /bills/{id}` shows the posted totals → `GET /trial-balance` sums to zero.

**Warning signs:**
- `pendingWith` in a core spec; "0 examples, N pending" in the log.
- A spec importing `DAL.DB` or `*InMemory`.
- `shouldBe Right ()` / `isRight` as the only assertion.
- `MigrationDryRunSpec` passing while a fresh database cannot be built.
- Coverage above 80% with dozens of stubs.
- Tests that pass with PostgreSQL stopped.
- No test file mentions a connection string.
- The suite never inserts into `ledger_entry`.
- A CI job with `|| echo`, `|| true`, or `continue-on-error`.

**Phase to address:**
P1 (make the DB test path real) and P7 (blocking gate). Every phase gate should require an effect assertion, not just a green build.

## Technical Debt Patterns

| Shortcut | Immediate Benefit | Long-term Cost | When Acceptable |
|----------|-------------------|----------------|-----------------|
| Keep `DAL.DB` (in-memory `IORef`) as the production store | No database needed to demo | No durability, no transactions, no concurrency; every "it works" is false | Never in `src/` reachable from `main`; test double only |
| `Either Text ()` / `Right True` service returns | Compiles fast, no type design | Success carries no evidence; stubs are indistinguishable from real work | Never for a service that has an effect |
| Two money types / three tax engines kept "for compatibility" | No big-bang refactor | Silent unit and precision changes; tests prove the wrong type | Never — delete in the same commit as the replacement |
| `Double` for money | Convenient arithmetic, JSON-friendly | Rounding drift, float equality in invariants, DB/app divergence | Only at the presentation edge, converted one-way from minor units |
| `CREATE TABLE IF NOT EXISTS` for domain tables | Re-runs are quiet | Hides definition changes; schema drift | Only for extensions, roles, and idempotent bootstrap objects |
| Migrations generated at application startup | New environment "just works" | Source tree mutated, version collisions, non-reproducible builds | Never — generation is a reviewed developer command |
| Hand-maintained `DAL.Schema` mirroring SQL | Type-level access | Guaranteed to drift from migrations | Only if generated from the migrations and diffed in CI |
| Non-blocking LiquidHaskell job (`|| echo skipped`) | Build stays green | "Formally verified" claim is false; annotations rot | During exploration only, never in a release gate |
| `max 0` clamps on money/quantity | Satisfies a non-negativity refinement | Turns invalid input into a plausible wrong number | Only with an explicit business rule and a log entry |
| Inline DDL in application code (`DAL.Queue.initializeQueue`) | One less file | Schema unknown to the migration runner; drift | Never — DDL belongs in a migration |
| Global `unsafePerformIO IORef` for the permission checker | Easy global access | Untestable, never initialized in production, fails closed at the wrong layer | Never — inject from `main` |
| Skipping DB tests locally via env var | Fast inner loop | The only real tests are opt-in in CI too | Locally yes; in CI never |

## Integration Gotchas

| Integration | Common Mistake | Correct Approach |
|-------------|----------------|------------------|
| PostgreSQL `NUMERIC(18,2)` ↔ `Double` | Inserting `PersistDouble` and letting the DB round | Convert to integer minor units (or a fixed-scale `Decimal`) before insert; assert the round-trip |
| PostgreSQL rounding | Assuming `round` in Haskell and `numeric` rounding agree | Pick one mode in Haskell and make the stored value already exact; never rely on the column to round |
| `psql -f migration.sql` | No `ON_ERROR_STOP`; a mid-file error is ignored and the file is recorded as applied | `psql -v ON_ERROR_STOP=1`, one transaction per file, record success only after commit |
| Persistent/esqueleto | `rawExecute` / `runDb` called outside `transaction`; each statement autocommits | Wrap the whole use case in `transaction`; pass the same connection through |
| `PersistDouble` → `Int64` helpers (`DAL.EventStore`, `DAL.Queue`) | `round` silently truncates or banker's-rounds an id/amount | Parse integers as integers; never route an id or an amount through `Double` |
| Event store | Hard-coded `sequence_number = 1`; publishing before commit | Derive the sequence inside the transaction; use a transactional outbox |
| HTMX | Expecting `4xx`/`5xx` fragments to be swapped | Configure `responseHandling` for `422`; return fragments with the error status the client handles |
| HTMX + redirects | `HX-Redirect` on a `3xx`; the browser follows it and htmx never sees the header | Return `200` with `HX-Redirect`, or do a full-page redirect for auth |
| JWT | Trusting the `role` claim after a role change or revocation | Resolve roles server-side per request (or short TTL + revocation check); the token is a cache |
| Redis | Using the cache as the source of truth for balances or sessions | Cache derived values with explicit invalidation; the DB is authoritative |
| LiquidHaskell | Mixing a GHC patch version with a different LH release; `stack` with LH ≥ 0.9.14 | Pin an exact supported pair (e.g. GHC 9.6.6 + `liquidhaskell-0.9.6.3.1`) or move GHC; use cabal for the verify package |
| Time zones | Posting a bill by local `Day` while the DB stores `timestamptz` | Store the accounting date as `date` and the event time as `timestamptz`; convert once, in one zone |
| FX | Converting with today's rate for a document dated last month | Store the rate and its date on the document; post the base amount computed at document date |
| Redis / external services in tests | `pendingWith` when the service is absent | Test doubles for unit tests; a CI service container for the integration job |

## Performance Traps

| Trap | Symptoms | Prevention | When It Breaks |
|------|----------|------------|----------------|
| Recomputing the trial balance with `SUM` over the whole ledger on every page | Page latency grows linearly with history | Period balances / materialized totals updated in the posting transaction | ~10⁵–10⁶ ledger rows |
| N+1 queries in an HTMX fragment (one balance query per row) | 50 rows → 51 queries; the page "feels slow" then times out | One aggregate query with `GROUP BY`, or a joined view | ~100 rows per fragment |
| Global `SUM(debit) = SUM(credit)` as the health check | Full table scan on every health probe | Per-transaction constraint trigger + an indexed reconciliation query scoped by date | ~10⁶ rows |
| Loading the ledger into Haskell to validate it | Memory spikes; GC pauses; OOM in CI | Validate in the DB; stream if you must export | ~10⁵–10⁶ rows |
| Missing indexes on `ledger_entry(transaction_id)`, `(account_id, date)`, `event(aggregate_id, sequence_number)` | Sequential scans; lock waits | Add them in the same migration as the table; verify with `EXPLAIN` | ~10⁵ rows |
| Per-request migration check or schema introspection | Startup and request latency; lock contention | Run migrations as a deploy step, not per request | Any concurrent load |
| Rebuilding the whole HTMX workspace on every keystroke | Network and render churn; flicker | Debounce, target the smallest fragment, OOB only the dependent regions | ~10 concurrent users |
| LiquidHaskell on typeclass-heavy modules in the main build | 10–30 min CI; developers disable it | Separate `verify` package, small refined core, no `--reflection` blanket | First full CI run |
| `unsafePerformIO` global caches without invalidation | Stale permissions/prices after a change | Explicit cache with TTL and invalidation on write | First role or price change |
| Serial full-suite runs against one shared database | Flaky failures, cross-test contamination | Per-test schema or transaction rollback; parallel-safe fixtures | As soon as tests run in parallel |

## Security Mistakes

| Mistake | Risk | Prevention |
|---------|------|------------|
| Default-allow authorization (`Nothing -> app request respond`) | Any authenticated user reaches every unmapped route, including `/ui` mutations, reports, audit, GraphQL | Default-deny; exact-match public allowlist; a test that enumerates every route |
| Prefix-matched public paths (`T.isPrefixOf`) | `/api/v1/auth` makes `/api/v1/auth/anything` public; `/api/v1` makes everything public | Segment-aware exact matching after path normalization |
| Permission repository returns `True` | Complete authorization bypass that looks implemented | Real query against one role schema; `Either Denied Reason`, never `Bool` |
| Mutable or deletable ledger rows | History can be rewritten; fraud is undetectable | Append-only table: `REVOKE UPDATE, DELETE`; corrections are reversal entries; trigger rejects `UPDATE`/`DELETE` |
| No `posted_by` / `posted_at` on the ledger transaction | Cannot attribute a posting or investigate a discrepancy | Store actor, timestamp, source, correlation id, and idempotency key |
| Trusting roles embedded in a JWT | A revoked or downgraded user keeps access until expiry | Server-side role resolution per request; short TTL; revocation list |
| Missing tenant/company scope on `GET /bills/{id}` | Cross-tenant data disclosure (IDOR) | Scope every query by the authenticated company; test with two tenants |
| CSRF on cookie-authenticated HTMX mutations | A third-party page can post a bill as the logged-in user | Per-session CSRF token in `hx-headers` + server check; `SameSite=Lax/Strict` |
| Manual HTML string concatenation | Stored XSS via customer name or bill description | Auto-escaping templates (Lucid/Blaze/Shakespeare); test with `<script>` input |
| String-built SQL in reports/filters | SQL injection | Parameterized `rawSql` / esqueleto; never interpolate user text |
| Backdated postings into a closed period | Silent restatement of reported financials | Period-close table; reject postings to closed periods unless an explicit reopen is audited |
| Accepting negative quantity/price/discount | Inventory inflation, negative bills, ledger manipulation | Smart constructors + DB `CHECK`s; reject, do not clamp |
| PII (names, INN, passport data) in logs and error responses | Privacy exposure in log aggregation | Structured logging with field allowlist; redact at the boundary |
| Application connects as a superuser | A bug or injection can drop the audit trail | Least-privilege role; separate migration role; `REVOKE` on audit tables |

## UX Pitfalls

| Pitfall | User Impact | Better Approach |
|---------|-------------|-----------------|
| Validation errors not swapped by htmx (`422`) | The form appears to do nothing; the user clicks again and duplicates the bill | Render an error fragment with `422` and configure `responseHandling`; disable the button as a hint only |
| "Posted" badge shown before commit | The user believes the bill exists; a refresh shows it gone | Render the badge from the persisted row after commit; never optimistically mark posted |
| One panel updates, related panels go stale | Stock changed but the trial balance did not; the user trusts the wrong number | `hx-swap-oob` for every derived region, or re-render the workspace |
| Money shown without scale or currency | `100` is ambiguous between 100.00 and 100.000; users assume the wrong one | Always render with currency code and fixed scale; format from minor units |
| Ambiguous dates (`01.02.2026`) | Mis-posted accounting period | ISO `YYYY-MM-DD` in inputs and API; localized display only |
| Bare "rate" with no unit | A user enters `20` where `0.2` is expected (or vice versa) | Label `%`, validate the range, show the computed tax immediately |
| "Delete bill" for a posted document | Users expect deletion; accounting requires a reversal | Offer "Cancel/Reverse" with a reason; keep the original visible and linked |
| Double-click creates two bills with no message | Duplicate payable, duplicate stock receipt | Server idempotency; on replay show the existing bill, not a new one |
| Browser back shows a pre-post balance | The user makes a decision on stale data | `Cache-Control: no-store` on authenticated HTML; disable/revalidate the htmx history cache |
| No indication of a closed period | The posting fails with a raw DB error or silently succeeds into the wrong period | Show the period status in the form; disable posting and explain |
| Stock warnings after the fact | The user only learns of a shortage after posting | Check availability in the form (advisory) and enforce it in the transaction (authoritative) |
| Mixed languages in one screen | Confusion and support load | One i18n catalog; no hard-coded strings in handlers or templates |

## "Looks Done But Isn't" Checklist

- [ ] **Ledger posting:** the response contains `AccTurn`s but `SELECT count(*) FROM ledger_entry` is `0` — verify by posting through the real HTTP route and querying the DB, not by reading the return value.
- [ ] **Balance invariant:** a test passes `validateTransaction`, but an unbalanced `COMMIT` inserted via `psql` succeeds — verify by bypassing Haskell entirely and asserting the constraint trigger rejects it.
- [ ] **Money precision:** `billTotal` is a `Double`, the column is `NUMERIC(18,2)`, and no test checks the round-trip — verify by inserting `0.005`, `1.005`, and `123456789.99` and comparing stored minor units.
- [ ] **Tax rate:** a 20% rate produces either `0` or `0.2%` on some path — verify by calling every tax entry point with both `20` and `0.2` and asserting which is rejected.
- [ ] **Stub removal:** `grep -rniE "stub|placeholder|not implemented|Right \(\)" src/` is non-empty — verify the count is zero on the end-to-end path and the remainder is allowlisted with an owner.
- [ ] **Authorization:** `POST /api/v1/bills` with a storekeeper token returns `200` — verify the full route matrix: anonymous `401`, wrong role `403`, right role success, including `/ui/*`.
- [ ] **Migrations:** `stack test` is green but a fresh empty database cannot be built — verify `createdb surypus_ci && ./migrate && psql -c '\dt'` and compare with the committed schema snapshot.
- [ ] **Migration runner:** editing an applied file or adding a duplicate version goes unnoticed — verify the checksum check fails and the duplicate-version check fails.
- [ ] **Test suite:** the log contains "pending" for PostgreSQL tests — verify the CI job runs with a database and exits non-zero when it is unavailable.
- [ ] **Coverage:** the badge is green but `coverage.json` was never produced — verify the gate fails closed on a missing file.
- [ ] **LiquidHaskell:** the CI job is green and the log says "skipped" — verify `liquid` is on `PATH` and the job fails without it.
- [ ] **HTMX double submit:** two clicks create two bills — verify with a deliberate double `POST` and a unique idempotency key.
- [ ] **HTMX error path:** a `422` renders a blank page — verify the validation fragment is visible in the browser, not just in `curl`.
- [ ] **Stock:** the response lists `updatedStock` but `stock_movement` is empty — verify the balance equals initial + receipts − issues after a post and a reversal.
- [ ] **Event store:** two posts for one aggregate both claim `sequence_number = 1` — verify the unique constraint and the derived sequence.
- [ ] **Atomicity:** killing the process mid-post leaves a bill with no ledger entry — verify with failure injection at each step.
- [ ] **Period close:** a bill can be posted into a closed month — verify the posting is rejected with a domain error, not a DB error.
- [ ] **Audit:** a denied request leaves no trace — verify an audit row exists for both allow and deny on mutating routes.
- [ ] **Reports:** the trial balance in the UI equals the SQL `SUM` — verify they are computed from the same persisted minor units.

## Recovery Strategies

| Pitfall | Recovery Cost | Recovery Steps |
|---------|---------------|----------------|
| Two `Decimal`s / `Double` money | HIGH | Freeze money changes; introduce `Money` in minor units; convert the DB with an explicit migration; delete the old types from `exposed-modules`; re-run all money tests against the new type. Expect to redo tax and ledger proofs. |
| Tax-rate unit mismatch | MEDIUM | Identify all stored rates; if the column is `NUMERIC(5,4)`, stored values are fractions — rename to `rate_fraction` or migrate to `rate_percent` with `× 100`; recompute affected invoices and issue corrections; add boundary tests. |
| Unbalanced/absent ledger rows | HIGH | Stop posting; snapshot the DB; rebuild the ledger from source documents into a new table with a transaction id; reconcile per document; reverse and re-post differences; never patch balances by hand. |
| Stub-shaped success discovered late | MEDIUM | Convert every stub on the milestone path to `error "not implemented"` or a real implementation; add effect assertions; re-run the E2E path; publish an honest status. |
| RBAC fail-open | HIGH | Ship default-deny immediately (may break clients — coordinate); enumerate routes; implement the real repository; rotate tokens if roles were trusted from the JWT; audit access logs for the exposure window. |
| Migration drift | HIGH | Freeze the schema; dump the production schema; diff against migrations; write a baseline migration that reproduces production; renumber duplicates; add checksums; rebuild a fresh DB and compare. Data loss is possible if columns differ — back up first. |
| LiquidHaskell job is decorative | LOW–MEDIUM | Remove the claim from the README; pin a supported GHC/LH pair in a separate package; make the job blocking or delete it; keep the DB trigger as the real invariant. |
| HTMX duplicate/stale state | MEDIUM | Add idempotency keys and a unique constraint; delete duplicate rows created during the window; fix `responseHandling`; add OOB swaps; add `no-store`; run the E2E double-submit test. |
| Non-atomic posting | HIGH | Introduce the transaction boundary and outbox; reconcile bills against ledger/stock/events; reverse orphaned bills; add failure-injection tests. |
| Rounding drift | MEDIUM | Choose the policy; add `allocate`; recompute stored totals from lines where the difference is a cent; issue credit notes for customer-facing differences; add golden tests. |
| False-confidence tests | MEDIUM | Add the CI database; remove `pendingWith` from core paths; replace `Either`-only assertions with row-count assertions; fail the coverage gate closed; run a mutation check on each invariant. |

## Pitfall-to-Phase Mapping

| # | Pitfall | Prevention Phase | Verification |
|---|---------|------------------|--------------|
| 1 | Two `Decimal`s / `Double` money | P2 | `grep` finds no money-typed `Double` in `Finance`/`Core`/`DAL.Types`; one `Money` type; round-trip test at 3 decimals |
| 2 | Tax percent vs fraction | P2 | Boundary tests for `0`, `20`, `100`, `120`, `0.2`; `tax_rates` column name states the unit; invalid input returns `Left` |
| 3 | Invariant only in memory | P3 | Raw `psql` unbalanced commit is rejected by a deferred constraint trigger; reconciliation query returns zero rows |
| 4 | Stub-shaped success | P1 + every gate | Stub count on the E2E path is zero; `Right ()` absent from service signatures; startup fails fast on a stub dependency |
| 5 | RBAC fails open | P1 (default-deny) / P6 (model) | Route matrix test: `401` anonymous, `403` wrong role, success right role; `/ui/*` included |
| 6 | Migration drift | P1 | Fresh DB built from migrations alone; `pg_dump --schema-only` diff is empty; duplicate versions and checksum mismatch fail the runner |
| 7 | LiquidHaskell friction | P2 (types) / P7 (gate) | `liquid` runs in CI and the job fails without it; the refined core is pure and uses `Money`; DB trigger is the primary gate |
| 8 | HTMX state bugs | P4 (idempotency) / P5 (UI) | Double-submit creates one bill; `422` fragment visible; back button shows current balance; `/ui` is in the permission matrix |
| 9 | Non-atomic posting | P4 | Failure injection at each step leaves zero rows; one transaction spans bill + stock + ledger + outbox; retry is idempotent |
| 10 | No rounding policy | P2 (policy) / P4 (enforce) | `sum (allocate total weights) == total`; line sums equal the bill total in the DB; Haskell and SQL agree on `0.005` |
| 11 | False-confidence tests | P1 / P7 | PostgreSQL test job is mandatory in CI; zero `pendingWith` on core paths; mutation of the balance check breaks a test |

**Ordering constraints implied by the table:**

1. P1 must establish schema truth and a failing-fast server before any feature claims.
2. P2 must precede P3 — a proof about the wrong money type is thrown away.
3. P3 must precede P4 — posting atomicity needs a ledger table worth committing to.
4. P4 must precede P5 — the UI cannot fix a non-atomic backend.
5. P6 must precede any mutating `/ui` route, but default-deny belongs in P1.
6. P7 is a gate, not a phase where problems are discovered.

## Sources

**Codebase (read directly, HIGH confidence):**

- `.planning/PROJECT.md`, `.planning/codebase/CONCERNS.md`, `.planning/codebase/TESTING.md`
- `src/Surypus/CoreTypes.hs`, `src/Finance/Accounting.hs`, `src/Finance/Tax.hs`, `src/Finance/Bill.hs`, `src/Finance/Currency.hs`
- `src/Core/Tax.hs`, `src/Core/Services/Accounting.hs`, `src/Service/BillService.hs`
- `src/DAL/Repository/RBAC.hs`, `src/Surypus/API/AuthMiddleware.hs`, `src/Surypus/RBAC.hs`, `src/Surypus/JWT/Token.hs`
- `src/DAL/EventStore.hs`, `src/DAL/Queue.hs`, `src/DAL/MutationsORM.hs`, `src/Surypus/API/Accounting.hs`
- `sql/migrations/V001__core_schema.sql`, `sql/migrations/V256__domain_organization_final.sql`, `sql/migrations/init_db.sh`, `sql/archive/procedures.sql`
- `test/MigrationDryRunSpec.hs`, `test/DAL/DBSpec.hs`, `test/DAL/EventStoreIntegration.hs`, `test/Finance/AccountingSpec.hs`, `test/QuickCheckInvariantsSpec.hs`
- `.github/workflows/liquidhaskell-verify.yml`, `.github/workflows/coverage-gate.yml`

**External (verified via web search and primary docs, MEDIUM confidence):**

- LiquidHaskell installation and GHC support matrix — https://ucsd-progsys.github.io/liquidhaskell/install.html
- LiquidHaskell changelog (stack support removed in 0.9.14.1) — https://github.com/ucsd-progsys/liquidhaskell/blob/develop/CHANGELOG.md
- htmx quirks and response handling — https://htmx.org/docs/#response-handling and https://htmx.org/quirks/
- PostgreSQL `CREATE TRIGGER` (constraint triggers, `DEFERRABLE`) — https://www.postgresql.org/docs/current/sql-createtrigger.html
- Flyway validation/checksum semantics — https://documentation.red-gate.com/flyway/reference/commands/validate
- Double-entry constraint and rounding discussions — Beancount precision docs (https://beancount.github.io/docs/), XVICA and Square engineering write-ups on ledger design
- ERP rounding/allocation notes — ERP5 `Decimal` allocation documentation

**Confidence notes:** the code-level findings are reproducible with the commands cited in each pitfall. The external claims are directionally stable but version-specific; re-check the LH/GHC pair at the start of P2 and P7.

---
*Pitfalls research for: ERP — double-entry accounting, VAT, inventory (Haskell + PostgreSQL + HTMX + LiquidHaskell)*
*Researched: 2026-10-23*
