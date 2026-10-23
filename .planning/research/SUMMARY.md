# Project Research Summary

**Project:** Surypus — ERP на Haskell (товары и склад, счета, двойная бухгалтерия, НДС)
**Domain:** Small-business ERP — accounting + inventory, brownfield stabilization on real PostgreSQL
**Researched:** 2026-10-23
**Confidence:** HIGH (codebase-verified findings, pinned toolchain) / MEDIUM on two open decisions (money internals, UI auth mechanism)

## Executive Summary

Surypus is not a greenfield ERP and should not be built like one. It is a large Haskell codebase (381 exposed modules in one package) with a partially correct domain and a **consolidation failure**, not a missing architecture: two `Decimal` types (one of them `Double` in disguise), three VAT engines with incompatible rate units (a real 100× bug), seven double-entry implementations, three `Stock` types, four job queues, 151–181 stub markers, an in-memory DAL still reachable from the bill service, and a 7-line `app/Main.hs` that never starts the server. The only reliable way forward — confirmed independently by architecture and pitfall research — is to **choose one canonical owner per domain, delete the losers in the same commit, and route every write through one transaction gateway**. Adding a layer, a second API, or an effect system on top of the current duplication reproduces the problem one level up.

The recommended build is a strangler sequence with strict dependency order: boot the real server and a trustworthy migration path first, then money and VAT units, then the ledger with its transaction boundary, then stock and the master data, then the full goods → receipt → invoice → payment → ledger → stock slice, then real RBAC, then the Lucid/HTMX UI, and finally the verification gate. The stack is deliberately conservative: GHC 9.6.5 / LTS 22.21 (the only toolchain already present and the only one with a compatible LiquidHaskell), Servant + Warp, persistent/esqueleto (no hasql rewrite), `Data.Decimal` for money, `jose` 0.11 + `crypton`, Argon2id passwords, an in-repo `surypus-migrate` runner on `postgresql-simple`, and vendored htmx 2.0.11 with no JS build chain.

The dominant risks are not library choices — they are **false success signals**. `Right ()`, `return True`, `pendingWith`, `|| echo "skipped"`, and `CREATE TABLE IF NOT EXISTS` all make a broken system look green. Mitigation is uniform and non-negotiable: the database must reject an unbalanced commit (deferred constraint trigger), every posting must be one transaction with an idempotency key, authorization must be default-deny with a route-enumeration test, migrations must be checksummed and single-ledgered, CI must own a real PostgreSQL instance, and the LiquidHaskell job must fail the build or the "verified" claim must be removed. One decision remains genuinely open and blocks Phase 2: whether `Money` stores `Data.Decimal` at fixed scale or scaled `Integer` minor units. Research recommends `Data.Decimal` at the boundary with all arithmetic defined over the mantissa (`Integer`) — this satisfies PROJECT.md's constraint and makes the proof tractable.

## Key Findings

### Recommended Stack

Standardize on **GHC 9.6.5 / Stackage LTS 22.21**. Everything needed is in the snapshot except `password` 3.1.1.0 (one extra-dep), and `liquidhaskell-0.9.6.3.1` accepts `ghc ^>= 9.6`. A toolchain move to LTS 24.64 / GHC 9.10.3 / LH 0.9.10.1.2 is a legitimate but separate milestone — doing it now would change 381 modules, `aeson`, `persistent`, and `esqueleto` at the same time as stabilizing behavior.

**Core technologies:**
- **GHC 9.6.5 + Stack (`lts-22.21`)** — the project's acceptance command is `stack test`; align Cabal, Dockerfile (currently 9.14.1), devcontainer (9.6.6), and CI (9.10.3) to this one version.
- **`servant` 0.20.1 + `servant-server` 0.20 + `warp`/`wai`** — `SurypusApi` is already a Servant type and `apiServer` a WAI `Application`; replacing either is pure risk.
- **`lucid` 2.11 + `servant-lucid` 0.9.0.6 + vendored htmx 2.0.11 + `wai-middleware-static`** — server-rendered HTML with no npm/bundler; view fragments are one Lucid function each.
- **`persistent` 2.14.6.1 + `persistent-postgresql` 2.13.6.1 + `esqueleto` 3.5.11.2** — 23 entities and the tenant `set_config` logic already depend on this trio; a hasql migration buys nothing in a stabilization milestone.
- **`Decimal` 0.5.2 + a canonical `Money` newtype** — exact base-10; scale 2 for money, scale 6 for rates, `Int64` for quantities; never `Num`/`Fractional` on `Money`.
- **`jose` 0.11 + `crypton` 0.34** — one crypto backend; `cryptonite` is deprecated and collides on module names.
- **`password` 3.1.1.0 (`Data.Password.Argon2`)** — replaces the unsalted SHA-256 password path; rehash on successful login.
- **In-repo `surypus-migrate` on `postgresql-simple` 0.7.0.0** — checksummed ledger, advisory lock, per-file transaction, duplicate-prefix rejection; `runMigration` cannot represent a 360-file SQL history.
- **`liquidhaskell` 0.9.6.3.1 + `z3` in a separate CI job** — never a `-fplugin` in the normal build.

**Explicitly rejected:** `cryptonite`, unsalted SHA-256, `runMigration`/`runMigrationUnsafe`, `persistent-migration`/`postgresql-simple-migration` (stale since 2021), `servant-auth-server` (duplicates the existing middleware), `servant-static-th`, `lucid2`, `blaze-html`, `hasql` in the transactional path, `hedis`/Redis queues, `websockets`, an effect system, and any JS framework.

### Expected Features

Scope is one working vertical path, judged against a real ERP user — not a feature count: `goods → goods receipt → sales invoice → customer payment → ledger entries → stock balance`. Two consequences are table stakes even though PROJECT.md does not name them: a **counterparty mini-master** (a receipt needs a supplier, an invoice a customer) and **stock issue on invoice posting** (without an `ISSUE` movement plus COGS, the balance never decreases and the "end-to-end" claim is half true).

**Must have (table stakes):**
- Goods catalog (code, name, unit, category, default VAT rate, sale price, active flag) — every document line depends on it; deactivate, never hard-delete.
- Counterparty mini-master (`SUPPLIER`/`CUSTOMER`/`BOTH`, optional INN/KPP) — no CRM fields.
- One seeded warehouse; stock keyed by `(goods_id, warehouse_id)` so multi-warehouse stays additive.
- Goods receipt with lines and atomic posting — the only legitimate way stock enters.
- Append-only stock movement ledger (`RECEIPT`/`ISSUE`/`ADJUSTMENT`) with a **derived** balance; moving-average cost; hard negative-stock block.
- Sales invoice with lines, per-line VAT, DB-side monotonic numbering, draft → posted, posted immutability.
- Payment against an invoice (partial allowed), `Dr Cash / Cr AR`, settlement derived from posted payments.
- Seeded flat chart of accounts (~10–15 accounts) **plus a system-account role map** (`inventory`, `ar`, `ap`, `cash`, `vat_output`, `revenue`, `cogs`) so posting rules never hardcode account ids.
- Automatic posting templates for receipt/invoice/payment and an atomic balanced journal write with source-document links.
- Ledger by account and a trial balance (opening/turnover/closing) computed **only** from posted entries, with the discrepancy surfaced as a hard error — never a tolerance.
- Local login/session, three fixed roles (`admin`, `accountant`, `storekeeper`), **default-deny** route authorization, admin user management.
- Server-rendered UI shell plus a canonical seed and one-command smoke scenario.

**Should have (competitive / trust differentiators):**
- Machine-checked ledger invariant — only if the check gates CI; otherwise do not claim "verified".
- Exact decimal money + typed VAT units (`RatePercent`/`RateFraction`) — kills cent drift and the 100× bug.
- Idempotent posting (unique key on document + posting sequence) — a double-click cannot double-post.
- Full document → journal → stock traceability, and a rebuildable stock balance.
- Single binary, Postgres-only, no Redis/Kafka/JS build — genuine operational advantage for a small team.
- Russian statutory fit (НДС 20%, RUB, account codes 41/50/51/60/62/68.02/90.01/90.02 as data) — MEDIUM confidence, needs product-owner sign-off.

**Defer to v1.x:** posted-document reversal/credit notes, manual stock adjustment, outbound supplier payments, opening balances, leaf-account creation, audit-log viewer, CSV export.

**Defer to v2+ / never in v1:** multi-warehouse and transfers, FIFO/lots/serials, multi-currency and FX, purchase orders and 3-way match, period close and lock dates, bank reconciliation, custom roles and field-level permissions, PDF/Excel/dashboards, public REST/GraphQL, discounts and price lists, barcodes, import tooling, event sourcing as the write model, and any async posting queue.

### Architecture Approach

The codebase has an **authority problem, not an architecture problem**: every domain concept has several plausible owners, so each new feature picks the nearest copy. Layering is conventional but not enforced — one Cabal package, 381 exposed modules, no import firewall, API handlers calling `DAL.MutationsORM` directly. The fix is to remove competitors and install one mechanically traceable gateway: **three rings (pure domain → one write gateway → two sibling adapters) plus a build-time boundary check**. Critically, "one write path" is about **transactions**: there is currently **no `withTransaction` anywhere in `src/`**, so a bill create, its lines, its postings, and its event are four independent commits on four pooled connections.

**Major components:**
1. **`Surypus.Domain.Money` / `Surypus.Domain.Vat`** — pure; money type, rounding policy, `RatePercent`/`RateFraction` with the single legal conversion; no IO, no SQL, no `Double`.
2. **`Finance.Ledger`** — canonical `Transaction`/`JournalEntry` with a hidden constructor and `mkTransaction :: ... -> Either LedgerError Transaction`, so an unbalanced transaction is unconstructible. Equality on exact minor units, never `Double` and never a `0.01` tolerance.
3. **`Inventory.Stock`** — one canonical `Stock`/`Qty` with `applyMovement` and non-negativity invariants; the generated `DAL.Types` row stays a DTO.
4. **`DAL.Schema` / `DAL.Row.*` / `DAL.Queries` / `DAL.EventStore` / `DAL.Queue`** — persistence is dumb on purpose (SQL in, rows out); `appendEvent` must become `Event -> SqlPersistT IO ()` so it can join the caller's transaction.
5. **`App.Tx`** — the only owner of the connection pool: `runWrite` opens one transaction, sets tenant/user **transaction-locally** (`set_config(..., TRUE)`), and returns post-commit effects.
6. **`App.Billing` / `App.Inventory` / `App.Accounting` / `App.Queries` / `App.Authz`** — command orchestration, the single writer of ledger turns, read models, and default-deny permission resolution.
7. **`Web.UI` (Lucid + HTMX) and `Web.Api` (Servant JSON)** — sibling adapters over the same services; the UI must never call the JSON API over HTTP and must never import `DAL.*`.

**Patterns that carry the design:** functional core / imperative shell per aggregate; smart constructors with hidden constructors ("unrepresentable, not merely validated"); sibling adapters rather than a chain; one transaction gateway with post-commit effects (transactional outbox); unit-safe rate types with **no** `Num` instances; and the import firewall expressed as a **test**, not a convention. The ledger tables are the source of truth; `event_store` is an audit/outbox log, not the balance authority — which also removes Redis from the correctness path. A facade that re-exports both old and new implementations is the primary anti-pattern: it is exactly how seven ledger implementations survived.

### Critical Pitfalls

1. **Two `Decimal`s and a `Double` in a `Decimal` costume** — `Surypus.CoreTypes.Decimal` wraps `Double`, `Finance.Accounting` (the module PROJECT.md calls authoritative) imports it, while `Finance.Tax` imports `Data.Decimal`. Same name, silent arithmetic change on a one-line import edit. *Avoid:* one `Money` type in one module, hidden constructor, named operations only (`addMoney`, `mulRate`, `allocate`), delete the losers from source **and** `exposed-modules` in the same commit, plus a boundary spec that fails if `Double` appears in a money/rate signature.
2. **Tax-rate units: percent vs fraction, and clamping instead of failing** — `Core.Tax` takes `0–1`, `Finance.Tax` takes `0–100`, `System.Cache` divides by 100 over `Double`; both clamp invalid input to `0`, so a 20% rate passed to the fraction engine yields zero tax indistinguishable from a zero-rated sale. The DB column `NUMERIC(5,4)` cannot even store `20`. *Avoid:* `RatePercent`/`RateFraction` newtypes with no `Num`, one VAT module, `Left (InvalidRate r)` instead of clamping, a unit-named column (`rate_percent NUMERIC(7,4) CHECK 0..100`), and boundary tests for `0`, `20`, `100`, `120`, `0.2`.
3. **The balance invariant is checked in memory, not in the ledger** — `validateTransaction` passes while the database holds no rows (or rows that no one can prove balanced); `journal_entries` has no transaction/group id, so a global `SUM(debit) = SUM(credit)` can hold while every individual entry is unbalanced; `acc_turn`/`acc_turns` exist only in `sql/archive/procedures.sql`. *Avoid:* `ledger_transaction` + `ledger_entry` with a *deferred* `AFTER ROW` constraint trigger that sums per `transaction_id` at COMMIT, per-row `CHECK`s, one write path, and an integration test that tries an unbalanced commit through raw `psql`.
4. **Stub-shaped success — `Right ()`, `return True`, `putStrLn`** — 151–181 markers in `src/`; `Core.Services.Accounting.validateTransaction = Right tx`, `checkUserAppPermissionRepo _ _ _ = return True`, `Production.ServiceManager.runJobQueueOnce` only prints, and `test/Finance/AccountingSpec.hs` asserts the stub as expected behavior. *Avoid:* make non-implementation loud (`error`/`Left NotImplemented`), return evidence (`PostedBill` with ids and row counts, not unit), delete stubs from the exposed set, add a shrinking "stub budget" in CI, and fail `main` fast if a required dependency is a stub.
5. **RBAC fails open** — `Nothing -> app request respond` allows every unmapped route; public paths are matched with `T.isPrefixOf`; `generateToken` writes `"role": []`; a second middleware authenticates but does not authorize; `/ui/*` is not in the route map at all. *Avoid:* default-deny with an exact-match public allowlist, one middleware that authenticates **and** authorizes, a route-enumeration test that forces every new route to be mapped, one role schema (four role-table families exist today), and a full matrix: anonymous → 401, wrong role → 403, right role → success, including `/ui` mutations.
6. **Migration drift** — 359–360 files, duplicate prefixes (`V001` ×2, `V1005`, `V183`–`V189`), 22 gaps, no checksums, `ON CONFLICT DO UPDATE SET success = TRUE`, `psql -f` without `ON_ERROR_STOP`, no per-file transaction, dual `schema_version`/`schema_migrations` ledgers, and app startup writing files into `sql/migrations/`. *Avoid:* one directory, one runner, one checksummed ledger, advisory lock, duplicate rejection, `--baseline`/`--dry-run`/`--check`, a fresh-DB build in CI compared against a committed `pg_dump --schema-only` snapshot.
7. **HTMX state bugs and non-atomic posting** — duplicate POSTs create two bills and two ledger transactions; htmx does not swap `4xx`/`5xx` by default; `HX-Redirect` on a `3xx` is never seen; swapping one row leaves stock and trial balance stale. And in `BillService.postBill` the bill goes into an in-memory `IORef`, the `AccTurn`s and stock deltas are returned to the caller rather than written, so a later event failure leaves a committed bill with no ledger. *Avoid:* per-render idempotency key with a unique constraint, `responseHandling` for `422`, `hx-swap-oob` for dependent regions, `Cache-Control: no-store`, and one transaction spanning document + lines + stock + ledger + outbox, with failure injection at each step.
8. **False-confidence tests and a decorative LiquidHaskell job** — `pendingWith` for every real PostgreSQL test, `MigrationDryRunSpec` checking 28 generated strings against 359 files, a coverage gate that swallows parse errors, and a `liquid` job hidden behind `|| echo "skipped"` whose annotations reference undefined `sumDebits`/`sumCredits` and the wrong `Decimal`. *Avoid:* mandatory `postgres:16` CI service, zero `pendingWith` on core paths, effect assertions (row counts, balances, idempotent replay), a coverage gate that fails closed, and either a blocking pinned LH±GHC pair (`9.6.x` + `0.9.6.3.1`) or no "verified" claim — with the DB trigger as the real safety net.

## Implications for Roadmap

The three research files converge on the same dependency DAG with different labels. Merged (and deliberately opinionated):

### Phase 1: Bootstrap & Schema Truth
**Rationale:** Nothing downstream is verifiable while `app/Main.hs` prints two lines and `apiServer` has no importer, and no feature claim survives a database that cannot be rebuilt from migrations. This is step 0 in all three research files.
**Delivers:** real `app/Main.hs` + `App.Env` + env-driven config (`DB_*`, `SURYPUS_JWT_SECRET`, fail fast); one `mkPool` with no hard-coded DSN; `/api/v1/health` → 200 from `stack run`; `surypus-migrate` with checksums, advisory lock, per-file transaction, duplicate-prefix rejection; `sql/migrations/` as the single canonical directory (PROJECT.md/AGENTS.md must be corrected — `config/migrations/` does not exist); duplicate renumbering; deletion of `config/schemas/` (197 copies) and startup-generated migrations; a fresh-DB schema snapshot in CI; `stack test` baseline recorded; Docker/devcontainer/CI aligned to GHC 9.6.5; default-deny skeleton + fail-fast startup checks + a stub budget.
**Addresses:** "server starts", "single migration path", "schema as source of truth" (PROJECT.md Active).
**Avoids:** Pitfall 4 (stub success), Pitfall 5 (fail-open default), Pitfall 6 (migration drift), Pitfall 11 (false-confidence tests).
**Uses:** GHC 9.6.5/LTS 22.21, `postgresql-simple` in the migrate executable only, `warp`/`wai`.
**Implements:** `App.Env`, `App.Tx` skeleton (pool ownership), `DAL.Schema` as the only entity mapping.

### Phase 2: Money & VAT Canon
**Rationale:** VAT is arithmetic over money. Doing VAT before money means writing rate code against two competing money types and rewriting it — the exact churn this milestone exists to avoid. A proof about the wrong money type is thrown away.
**Delivers:** `Surypus.Domain.Money` (canonical `Money`, scale 2, hidden constructor, `addMoney`/`subMoney`/`sumMoney`/`mulRate`/`allocate`, one documented half-up rounding policy, `PersistField` via `PersistRational` + `SqlNumeric 18 2`, JSON as **string**, strict `FromHttpApiData`); `Surypus.Domain.Vat` (`RatePercent`/`RateFraction`, one conversion, no `Num`, no clamping); deletion of `Surypus.CoreTypes.Decimal`, `Surypus.Types.Common.Money`, `Finance.Ledger.Amount`, the `Core.Tax` fraction engine, and the orphan `Decimal` JSON instances; DB rate column named for its unit; boundary spec (no `Double` in money/rate signatures) and 100× regression tests.
**Addresses:** "единый канон денег", "единый канон НДС", exact decimal money differentiator.
**Avoids:** Pitfall 1, Pitfall 2, Pitfall 10 (rounding policy), Pitfall 7's "wrong subject" failure.
**Uses:** `Decimal` 0.5.2, `aeson` 2.1.2.1, `http-api-data` 0.5.1.
**Implements:** `Surypus.Domain.Money`, `Surypus.Domain.Vat`.

### Phase 3: Ledger Canon & Transaction Gateway
**Rationale:** The ledger is the first place that genuinely needs a multi-row atomic write, so `App.Tx` lands here — not earlier (an abstraction with no caller is how four job queues happened) and not later (posting atomicity needs a ledger table worth committing to).
**Delivers:** `Finance.Ledger` with hidden `Transaction` + `mkTransaction` (replaces `Finance.Types`, `Finance.Accounting`, `Finance.Journal`, `Finance.Ledger`, `Core.Services.Accounting`); `ledger_transaction`/`ledger_entry` physical schema with per-row `CHECK`s and a **deferred** balance trigger; `App.Tx.runWrite`/`runRead` with `withTransaction`, transaction-local `set_config` for tenant/user passed as arguments (removing the process-global `IORef`), and post-commit effects; `DAL.EventStore.appendEvent :: Event -> SqlPersistT IO ()`; deletion of `rebuildBalance` and the `acc_turn`/`acc_turns` split; failure-injection and rollback tests (0 rows, 0 events).
**Addresses:** "единый канон учёта", `DAL` as the only write path, the ledger half of the balance invariant.
**Avoids:** Pitfall 3 (in-memory invariant), Pitfall 9's transaction gap, Anti-Pattern 2 (per-function checkout) and 5 (publish before commit).
**Uses:** `persistent`/`esqueleto` transactions, PostgreSQL constraint triggers, `sql/migrations`.
**Implements:** `Finance.Ledger`, `App.Tx`, `App.Accounting`, `DAL.Row.Ledger`.

### Phase 4: Master Data & Inventory Canon
**Rationale:** A receipt must produce postings, so the ledger must already be correct; stock movement without postings is the current half-wired state. Master data first, because every document line references a good, a party, and a warehouse.
**Delivers:** one `Inventory.Stock` + `DAL.Row.Stock` (deleting `Inventory.StockOps`, `Inventory.Operations`, `DAL.DB` and its spec, `DAL.Types.Stock` hand edits); goods catalog, counterparty mini-master, one seeded warehouse, units of measure, deactivate-not-delete lifecycle; stock movement ledger + derived balance + movement history; moving-average cost; hard negative-stock block; goods receipt document with atomic posting (stock in + AP); `DAL.Queue` on PostgreSQL with DDL in a migration replacing `System.JobQueue`/`System.Jobs`/`Infrastructure.Redis.TaskQueue` (small, independent slice, parallelizable with Phase 3/5).
**Addresses:** goods catalog, counterparties, warehouse, receipt, stock ledger/balance, unit canon, queue canon.
**Avoids:** Pitfall 9 (mutable stock counter, no `FOR UPDATE`), Pitfall 4 (`DAL.DB` fixture), the "three `Stock` types" duplication.
**Uses:** `persistent`/`esqueleto`, `Decimal` scale 2 for costs, `bigint` for quantities.
**Implements:** `Inventory.Stock`, `App.Inventory`, `DAL.Queue`.

### Phase 5: Billing, Payments & Trial Balance (the acceptance path)
**Rationale:** This is the milestone's definition of done, proven over JSON/HTTP before any HTML exists — a JSON assertion is automatable in the test suite; an HTML assertion needs a browser harness. Proving it here also forces the services to be adapter-agnostic.
**Delivers:** sales invoice with lines, per-line VAT, DB-side numbering (sequence or `UPDATE ... RETURNING`), draft → posted, posted immutability; automatic `ISSUE` + COGS in the same transaction; payment against invoice with partial settlement derived from posted payments; overpayment rejection; seeded flat chart of accounts + account-role map + three posting templates; ledger by account and trial balance from posted entries only, discrepancy as hard error; document-level idempotency keys; canonical seed + one-command smoke scenario asserting trial balance = 0 and stock = initial + receipts − issues; HTTP end-to-end test against real PostgreSQL.
**Addresses:** invoice, stock issue/COGS, payment, chart of accounts, posting rules, balanced journal, ledger drill-down, trial balance, seed/smoke.
**Avoids:** Pitfall 3, Pitfall 9, Pitfall 10 (line sums vs total), Pitfall 11 (assert effects, not `Either`), the `max(number)+1` race.
**Uses:** `esqueleto` joins and `rawSql` aggregates through the same `SqlBackend`, `hspec-wai`/`http-client`.
**Implements:** `App.Billing`, `App.Queries`, `DAL.Queries`.

### Phase 6: Auth & RBAC (real store, default-deny)
**Rationale:** A form that posts `POST /ui/bills/42/post` is a write endpoint; shipping it behind today's fail-open authorization creates a new unauthenticated write surface and forces auth to be retrofitted mid-flight. This phase must complete before any mutating UI route.
**Delivers:** one role schema (`roles`/`permissions`/`role_permissions`/`user_roles`) with the other three families archived; `App.Authz` resolving roles from the DB per request (JWT claim is a cache, never the source of truth); Argon2id password storage + rehash-on-login; server-side session (`user_sessions`, `HttpOnly`/`Secure`/`SameSite=Lax`) for the UI with CSRF double-submit; `SURYPUS_JWT_SECRET` required at startup (≥32 bytes) for `/api/v1`; deletion of `checkUserAppPermissionRepo`, the `unsafePerformIO` permission registry, and the duplicate `authMiddleware`; route-enumeration test covering `/api/v1/*` **and** `/ui/*`: anonymous 401, wrong role 403, right role success.
**Addresses:** login/session, three fixed roles, permission matrix, default-deny, admin user management, audit fields (`created_by`/`posted_by`/`posted_at`).
**Avoids:** Pitfall 5 in full, prefix-matched public paths, `"role": []`, trusting the JWT role claim.
**Uses:** `jose` 0.11, `crypton` 0.34, `password` 3.1.1.0, `cookie` 0.4.6.
**Implements:** `App.Authz`, `Web.UI` session middleware.

### Phase 7: HTMX UI
**Rationale:** The UI depends on all of the above; building it as a final layer is correct **only** if it is delivered as per-document vertical slices, not one big-bang screen set. Authorization already exists, so every page ships closed by default.
**Delivers:** `Web.UI` as a plain WAI `Application` under `/ui` composed with `serve api` in one Warp app (do not grow `SurypusApi`, already 911 lines); `/static` via `wai-middleware-static` with vendored `htmx.min.js` 2.0.11 and one CSS file; Lucid layout + list/detail/form patterns for goods, receipts, invoices, payments, ledger, trial balance, users; fragment-or-page from one handler on `HX-Request`; POST-Redirect-GET for non-HTMX; `hx-swap-oob` for stock/ledger/total regions; `responseHandling` for `422`; idempotency keys and double-submit E2E test; `Cache-Control: no-store`; auto-escaping only (no `"<div>" <> userText`); invoice HTML with a print stylesheet (no PDF).
**Addresses:** server-rendered UI shell, usable UI for all three roles, invoice view/print, Russian-labelled money/date display.
**Avoids:** Pitfall 8 in full, Anti-Pattern 4 (HTML handlers that compute) and 6 (god API type).
**Uses:** `lucid`, `servant-lucid`, `cookie`, `http-api-data`, `wai-middleware-static`, htmx 2.0.11.
**Implements:** `Web.UI.{Routes,Layout,Bills,Stock,Ledger}`.

### Phase 8: Verification Gate & Proof
**Rationale:** Proof last, deliberately — the toolchain pairing needs work that must not block a working system, and the DB trigger (Phase 3) is the primary enforcement. This phase converts the claim into evidence or removes the claim.
**Delivers:** separate `verify` package/job pinned to GHC 9.6.x + `liquidhaskell-0.9.6.3.1` + `z3`; proof of `mkTransaction` (`Right t ==> sumDebits t == sumCredits t`) and non-negative ledger amounts over a mantissa-based `Money`; the job **fails** if `liquid` is missing; CI gate that fails closed (coverage, migration snapshot, integration suite); `doctest`, Fourmolu-vs-stylish-haskell resolved to one, Hoogle/Mermaid docs regenerated per AGENTS.md; honest README status.
**Addresses:** "инвариант Σ дебет = Σ кредит проверяется и доказан", `stack test` green, smoke run on real PostgreSQL.
**Avoids:** Pitfall 7 in full, Pitfall 11's fail-open gates, the `|| echo "skipped"` pattern.
**Uses:** `liquidhaskell` 0.9.6.3.1, `z3`, `doctest` 0.22.2, `fourmolu` 0.14.
**Implements:** `liquid/` spec module + CI workflow.

### Phase Ordering Rationale

- **Boot and schema truth first** because no feature claim is verifiable on a hand-built dev database or a server that does not start (`apiServer` has no importer today).
- **Money before VAT, VAT before ledger** because VAT is arithmetic over money and the ledger sums money; reversing this guarantees rewrite.
- **`App.Tx` with the ledger, not before** — it needs a multi-row write to protect.
- **Ledger before stock, stock before billing** — a receipt must post; a sale must issue stock and book COGS.
- **JSON slice before HTML** — the acceptance criterion must be automatable and it keeps services adapter-agnostic.
- **RBAC before any mutating UI route** — fail-open UI mutations are a new unauthenticated write surface, not a UI bug.
- **Proof last and supplementary** — the DB constraint trigger is the safety net; LH is evidence, not enforcement.
- **Deletion discipline per phase:** a shim is allowed only at a *stored* boundary. A phase is not complete while `grep` still finds the loser in `src/` or `exposed-modules`.

### Research Flags

Phases likely needing deeper research during planning:
- **Phase 3 (Ledger & `App.Tx`):** `withTransaction` inside `runSqlPool` interacting with transaction-local `set_config`, plus the exact deferred `AFTER ROW` constraint-trigger shape and `persistent`'s exception/rollback semantics. Claims here came from source reading, not from docs (Context7 unavailable), so re-check before planning.
- **Phase 2 (Money):** the open `Data.Decimal`-vs-scaled-`Integer` decision must be settled first; it determines every downstream type and the feasibility of Phase 8.
- **Phase 6 (Auth):** UI session-vs-JWT was not researched in depth; CSRF double-submit details and session revocation need a short spike.
- **Phase 8 (Proof):** the list-of-entries `sum` measure for `Transaction` is unverified against a real LH run — start with a one-function spike on `mkTransaction` before promising the invariant.

Phases with standard patterns (skip `/gsd-plan-phase --research-phase`):
- **Phase 1:** Stack/Migration/Haskell-toolchain patterns are well documented and already resolved in STACK.md.
- **Phase 2:** `Decimal`/money-type patterns are settled; only the internal representation decision is open.
- **Phase 4:** CRUD + append-only movement ledger + derived balance is textbook.
- **Phase 5:** double-entry posting templates and numbering are standard; the research already names the three templates and the numbering mechanism.
- **Phase 7:** Lucid + HTMX fragment patterns are established; only the per-document page inventory needs planning, not research.

## Confidence Assessment

| Area | Confidence | Notes |
|------|------------|-------|
| Stack | HIGH | Every chosen library verified in `lts-22.21` and against the repo's own `stack.yaml`; `PersistRational → numeric` mapping verified in `persistent-postgresql` source; LH pairing `ghc ^>= 9.6` verified. MEDIUM only for `servant-lucid` (small, old, but bounds fit) and the in-repo migration runner (straightforward, but the duplicate history needs decisions). |
| Features | HIGH for table stakes, MEDIUM for differentiators | Table stakes corroborated by standard accounting practice and the repo's own V256 schema; differentiators are product-positioning judgement; Russian statutory account codes inferred, not confirmed by the product owner. |
| Architecture | HIGH for target structure and strangling order, MEDIUM for HTMX/Lucid and proof tooling | Grounded in direct reads of `src/`, `.planning/codebase/ARCHITECTURE.md`, and `CONCERNS.md`; the "no `withTransaction` anywhere" finding was grep-verified. HTMX/Lucid and strangler-fig claims were cross-checked only once. |
| Pitfalls | HIGH for codebase findings, MEDIUM for ecosystem claims | Every code-level pitfall is reproducible with the cited commands (151 stub markers, 359–360 migration files, duplicate `V001`, `checkUserAppPermissionRepo = True`). External claims (LH install matrix, htmx response handling, Flyway checksum semantics, PostgreSQL constraint triggers) are version-specific and should be re-checked at Phase 2/8 start. |

**Overall confidence:** HIGH for *what to do and in what order*; MEDIUM for two open decisions.

### Gaps to Address

- **Money internal representation (blocking, Phase 2):** PROJECT.md decides `Data.Decimal`; ARCHITECTURE.md and PITFALLS.md push toward scaled `Integer` minor units for provability. Recommended resolution: canonical `Money` over `Data.Decimal` at fixed scale 2, with **all arithmetic defined at the mantissa level** (`moneyMinor :: Money -> Integer`) and `Data.Decimal` only for parse/display. This satisfies the PROJECT.md constraint and gives LH an `Integer` theory. Record the decision in PROJECT.md Key Decisions before Phase 2 planning; do not let it drift into Phase 3.
- **Migration directory mismatch (blocking, Phase 1):** PROJECT.md/AGENTS.md say `config/migrations/`, which does not exist; the real history is `sql/migrations/` (359–360 files). Make `sql/migrations/` canonical and update both documents — do not maintain two paths.
- **`tenant_id` type conflict:** `ledger_entries` (V256) uses `UUID` while most other tables use `BIGINT`. Settle this in the Phase 1 schema-truth migration.
- **Duplicate prefix policy:** `V001` ×2, `V1005` ×2, `V183`–`V189`, 22 gaps. Decide renumber-vs-allowlist before the runner is trusted; never edit an applied file.
- **Event-sourcing depth:** the recommended architecture demotes the event store to audit/outbox. If replayable projections are ever wanted, `rebuildBalance`'s account-filter bug must be fixed first. Treat as a recorded decision, not an open question for v1.
- **`DAL.Types` generator ownership:** `dsl/schema.yaml` + `surypus-codegen` generate `DAL.Types`; whether to invert generation (rows from canonical domain types) was not evaluated and materially affects Phase 4 planning.
- **UI auth mechanism:** server-side session for the UI vs JWT cookie. Recommended: opaque session row for the UI, `jose` JWT for `/api/v1`, one `App.Authz` resolving roles from the DB per request. Confirm during Phase 6 planning.
- **Russian statutory chart of accounts:** seed codes (41/50/51/60/62/68.02/90.01/90.02) need product-owner confirmation before they become data.
- **`servant-lucid` risk:** tested only to GHC 8.10 historically; fallback is a ~15-line local `MimeRender HTML (Html a)` instance. Decide at Phase 7 planning time if it fails to build.

## Sources

### Primary (HIGH confidence)
- `.planning/PROJECT.md` — scope, constraints, recorded decisions.
- `.planning/codebase/ARCHITECTURE.md`, `.planning/codebase/CONCERNS.md`, `.planning/codebase/TESTING.md` — current layering, duplicates, defects, test gaps.
- Repo source read directly: `app/Main.hs`, `src/Surypus/CoreTypes.hs`, `src/Surypus/Types/Common.hs`, `src/Finance/{Types,Tax,Accounting,Bill,Currency}.hs`, `src/Core/Tax.hs`, `src/Core/Services/Accounting.hs`, `src/Service/BillService.hs`, `src/DAL/{Types,Schema,Database,MutationsORM,EventStore,Queue}.hs`, `src/DAL/Repository/RBAC.hs`, `src/Surypus/API/{Server,AuthMiddleware,Authorization,Goods,Payment,Accounting}.hs`, `src/Surypus/{RBAC,JWT/Token,RefreshTokenRepo}.hs`, `src/Inventory/Stock.hs`, `src/Domain/Accounting/Events.hs`.
- Repo SQL and CI: `sql/migrations/` (359–360 files; duplicate `V001`, `V180`–`V189`, `V1005`; dual `schema_version`/`schema_migrations`), `sql/migrations/V001__core_schema.sql`, `sql/migrations/V256__domain_organization_final.sql`, `sql/migrations/init_db.sh`, `sql/archive/procedures.sql`, `sql/seeds/demo_seed.sql`, `.github/workflows/liquidhaskell-verify.yml`, `.github/workflows/coverage-gate.yml`.
- Repo tests: `test/Finance/AccountingSpec.hs`, `test/QuickCheckInvariantsSpec.hs`, `test/MigrationDryRunSpec.hs`, `test/DAL/{DBSpec,EventStoreIntegration}.hs`, `test/Infrastructure/EventStore/AccountingIntegration.hs`.
- `stack.yaml`, `stack.yaml.lock`, `Surypus.cabal`, `cabal.project`, `liquidhaskell.yaml`, Dockerfile, devcontainer.
- Hackage `.cabal` files and pages: `servant` 0.20.1, `servant-server` 0.20, `servant-lucid` 0.9.0.6, `lucid` 2.11.x, `persistent` 2.14.6.1, `persistent-postgresql` 2.13.6.1, `esqueleto` 3.5.11.2, `Decimal` 0.5.2 (including the literal-scale warning and `roundTo`/`divide`/`allocate` semantics), `jose` 0.11/0.13, `crypton` 0.34, `password` 3.1.1.0, `liquidhaskell` 0.9.6.3.1 / `liquidhaskell-boot` 0.9.6.3, `postgresql-simple` 0.7.0.0, `cryptonite` (deprecated tag).
- Stackage snapshots `lts-22.21` (GHC 9.6.5), `lts-23.28`, `lts-24.64` (GHC 9.10.3).
- LiquidHaskell GHC support policy (one GHC per release) and `INSTALL.md` (`stack install`, `stack exec -- liquid`, `GHC_PACKAGE_PATH`).
- PostgreSQL `CREATE TRIGGER` documentation — constraint triggers, `DEFERRABLE INITIALLY DEFERRED`, `AFTER ROW`.
- `persistent-postgresql` `Database/Persist/Postgresql/Internal.hs` — `PersistRational → numeric` mapping.

### Secondary (MEDIUM confidence)
- htmx 2.0.11 registry metadata and htmx docs/quirks — `responseHandling`, `HX-Redirect` on `3xx`, history cache, OOB swaps; htmx template-fragment and server-examples essays.
- Strangler-fig mechanics (facade, thin slices, decommissioning) — microservices.io, catio.tech.
- Serving HTML from Servant with Lucid/Blaze — mmhaskell.com.
- Flyway validate/checksum semantics — documentation.red-gate.com.
- Docker Hub `haskell` image tags; GHC end-of-life status — endoflife.date/ghc.
- Fixed-point/minor-unit money and rounding — Wikipedia fixed-point arithmetic, evanjones.ca/floating-point-money.html.
- Small-ERP feature comparisons — SimpleERP, ineed.now, Really Simple ERP, Celerp, SaleSprint; MVP scoping and ERP scope-management write-ups.
- Double-entry constraint and rounding discussions — Beancount precision docs, XVICA/Square ledger write-ups, ERP5 `Decimal` allocation docs.

### Tertiary / needs validation (LOW)
- Russian statutory chart-of-accounts codes and НДС presentation conventions — inferred from repo docs and `НДС 20%` tests; confirm with the product owner.
- `servant-lucid` 0.9.0.6 on GHC 9.6.5 — bounds fit, but no evidence of a recent GHC 9.6 build; fallback is a local `MimeRender` instance.

---
*Research completed: 2026-10-23*
*Ready for roadmap: yes*
