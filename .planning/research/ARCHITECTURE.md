# Architecture Research

**Domain:** ERP — accounting + inventory, Haskell (brownfield consolidation)
**Researched:** 2026-10-23
**Confidence:** HIGH for the target structure and strangling order (grounded in direct reads of `src/`, `.planning/codebase/`); MEDIUM for HTMX/Lucid wiring and proof-tooling specifics (external, cross-checked only once)

## Executive Summary

The codebase does not have an architecture problem so much as **an authority problem**. Every domain concept has several plausible owners (`Finance.Types`, `Finance.Accounting`, `Finance.Journal`, `Finance.Ledger`, `Domain.Accounting.Events`, `Core.Accounting.ReadModel`, `Infrastructure.EventStore.Accounting`), so no module can be "the" answer, and each new feature picks whichever copy is closest. `.planning/codebase/ARCHITECTURE.md:264` states the root cause plainly: *"Layering is conventional, not enforced"* — one Cabal package, 381 exposed modules, no import firewall, and API handlers that call `DAL.MutationsORM` directly.

The fix is therefore not a new layer on top. It is **removing competitors, then installing one gateway that is mechanically traceable**. Concretely: three rings (pure domain → one write gateway → two sibling adapters), one transaction boundary, and a build-time check that the boundary is not violated.

Three findings drive the recommended structure:

1. **The "one write path" requirement is about transactions, not modules.** There is currently **no `withTransaction` anywhere in `src/`** — every DAL function calls `runDb` itself, so a bill create, its lines, its postings, and its event are four independent commits on four different pooled connections (`.planning/codebase/CONCERNS.md:280`; verified by grep). A canonical `DAL` module that keeps that shape would still be wrong. The gateway must own the commit.
2. **The balance invariant cannot be proven while money is `Double`-or-`Decimal`-shaped in three places.** `Finance.Types.doubleEntryBalance` compares `Double` sums with `==` (`.planning/codebase/CONCERNS.md:280-285`) while `Finance.Accounting` compares `Decimal` with `/=`, and `Domain.Accounting.Events` checks nothing at all. One canonical module over exact minor units makes the property both testable and provable.
3. **A 100× VAT error is a type error waiting to be made.** `Core.Tax` takes fractions `0.0–1.0` over `Double`; `Finance.Tax` takes percentages `0–100` over `Data.Decimal.Decimal`. Both are exported. A newtype pair with hidden constructors and **no** `Num`/`Fractional` instances is the only mechanism here that survives contact with future code, because it fails at compile time rather than in a reviewer's head.

Recommended shape, in one line: `Web.UI`/`Web.Api` → `App.<Domain>` commands → `App.Tx.runWrite` → `DAL` rows; pure rules live only in `Surypus.Domain.*`, and the HTML UI talks to services directly rather than looping through the JSON API.

## Standard Architecture

### System Overview

```text
┌──────────────────────────────────────────────────────────────────────────┐
│ ADAPTERS (two siblings — no adapter calls another adapter)               │
│  ┌───────────────────────────┐      ┌───────────────────────────────┐    │
│  │ Web.UI  (HTMX fragments)  │      │ Web.Api (Servant, JSON)       │    │
│  │ Lucid views + WAI routes  │      │ decode → service → encode     │    │
│  └─────────────┬─────────────┘      └───────────────┬───────────────┘    │
└────────────────┼────────────────────────────────────┼────────────────────┘
                 │  same Env / same services         │
                 ▼                                    ▼
┌──────────────────────────────────────────────────────────────────────────┐
│ APPLICATION (commands + queries; the only IO-orchestrating ring)         │
│  App.Billing   App.Inventory   App.Accounting   App.Authz  App.Queries   │
│  ┌────────────────────────────────────────────────────────────────────┐  │
│  │ App.Tx.runWrite — ONE transaction. rows + entries + event, or none.│  │
│  └────────────────────────────────────────────────────────────────────┘  │
└────────────────────────────────┬─────────────────────────────────────────┘
                                 ▼
┌──────────────────────────────────────────────────────────────────────────┐
│ PERSISTENCE (dumb on purpose: SQL in, rows out, zero business rules)     │
│  DAL.Schema (Persistent)   DAL.Row.* (row DTOs)   DAL.Queries (reads)    │
│  DAL.Queue (Postgres)      DAL.EventStore (append-only audit log)        │
└────────────────────────────────┬─────────────────────────────────────────┘
                                 ▼
┌──────────────────────────────────────────────────────────────────────────┐
│ PURE DOMAIN (no IO, no Persistent, no Aeson, no pool)                    │
│  Surypus.Domain.Money   Surypus.Domain.Vat   Finance.Ledger              │
│  Inventory.Stock                                                         │
└──────────────────────────────────────────────────────────────────────────┘
```

Dependency direction is strictly downward. The single permitted exception is `DAL.Row.*` importing domain types to build total conversions — a row module may *name* `Money`, but a domain module may never name a `Persistent`/`Entity` type.

### Component Responsibilities

| Component | Owns | Must never do |
|-----------|------|---------------|
| `Surypus.Domain.Money` | The money type, rounding policy, exact arithmetic, JSON instances | IO, SQL, knowledge of tables |
| `Surypus.Domain.Vat` | `RatePercent`, `RateFraction`, the only legal conversion, VAT math | Accept a bare `Double` rate; import `Core.Tax` |
| `Finance.Ledger` (canonical, replaces `Finance.Types`) | `Account`, `JournalEntry`, `Transaction`, `mkTransaction`, `sumDebits`/`sumCredits` | Persist anything; import `DAL` |
| `Inventory.Stock` (canonical) | `Stock`, `Qty`, `mkStock`, `applyMovement`, non-negativity invariants | Read the DB to "check" a balance |
| `DAL.Schema` / `DAL.Row.*` | Table mapping; total `toRow`/`fromRow` | Contain `if` statements that are business rules |
| `DAL.Queries` | Read-only SQL returning row DTOs or report rows | Write |
| `DAL.EventStore` | `appendEvent` **as a `SqlPersistT` action**, replay | Open its own connection |
| `App.Tx` | Transaction boundary, tenant `set_config`, post-commit effect queue | Contain domain rules |
| `App.Billing` / `App.Inventory` / `App.Accounting` | Command orchestration: validate → build pure doc → one `runWrite` → post-commit effects | Render HTML; format HTTP errors |
| `App.Queries` | Read side: balances, stock snapshot, list views for both adapters | Write, or call a command |
| `Web.UI` | Lucid views, fragment routes, form decoding, HTMX headers | Contain a balance calculation or a VAT rule |
| `Web.Api` | Servant type, JSON codecs, status mapping | Import `DAL.*` directly (today's bug, `Server.hs:600`) |
| `App.Authz` | Permission resolution from DB, map route→permission, default-deny | Return `True` on lookup failure |

### Targeted project structure

```text
src/
├── Surypus/Domain/          # PURE. No IO, no Persistent.
│   ├── Money.hs             #   Money, RoundingPolicy, moneyToMinor/moneyFromMinor
│   ├── Vat.hs               #   RatePercent, RateFraction, vatAmount, vatOfInclusive
│   └── Errors.hs            #   DomainError (LedgerError, StockError, VatError)
├── Finance/
│   └── Ledger.hs            # CANONICAL ledger types + mkTransaction (replaces Types/Accounting/Journal/Ledger)
├── Inventory/
│   └── Stock.hs             # CANONICAL stock type + mkStock (replaces Stock/StockOps/Operations)
├── DAL/
│   ├── Schema.hs            # Persistent entities only
│   ├── Row/{Bill,Stock,Ledger,Queue}.hs   # total row <-> domain conversions
│   ├── Queries.hs           # reads
│   ├── EventStore.hs        # appendEvent :: Event -> SqlPersistT IO ()  (no pool arg)
│   └── Queue.hs             # Postgres queue; DDL lives in sql/migrations
├── App/
│   ├── Tx.hs                # runWrite / runRead; tenant scope; post-commit effects
│   ├── Billing.hs           # createBill, postBill  (bill + lines + postings + event, one tx)
│   ├── Inventory.hs         # receiveGoods, issueGoods
│   ├── Accounting.hs        # postTransaction (the ONLY writer of acc_turns)
│   ├── Queries.hs           # read models for UI/API
│   ├── Authz.hs             # role -> permission from DB, default-deny
│   └── Env.hs               # pool, logger, metrics, authz handle — no unsafePerformIO
├── Web/
│   ├── Api/Server.hs        # thin Servant wiring
│   └── UI/{Routes,Layout,Bills,Stock,Ledger}.hs   # Lucid + HTMX
└── app/Main.hs              # config -> pool -> Env -> Warp (API app <> UI app)
```

**Structure rationale.** `Surypus.Domain.*` is a new namespace rather than a reuse of `Finance.*` or `Core.*` because those namespaces are already occupied by losing duplicates; a fresh prefix makes "is this canonical?" answerable by path, and makes the deletion list mechanical. `DAL.Row.*` exists because `DAL.Types` is generator-owned (`"Generated from dsl/schema.yaml / DO NOT EDIT MANUALLY"`, `src/DAL/Types.hs:26`) — the canonical domain type must live outside a generated file, and conversions must be total functions rather than hand-edited generated records.

## Architectural Patterns

### Pattern 1: Functional core, imperative shell (the whole design, applied per aggregation)

**What:** Every business rule is a pure function over domain types; the shell only sequences IO around it.
**When to use:** Always here — accounting is a rules engine with a database attached.
**Trade-offs:** More types to thread (`Command` in, `Either DomainError Doc` out), and the shell can look like ceremony for trivial CRUD. Worth it exactly for the four duplicated domains; overkill for classifier lookups.

```haskell
-- App/Accounting.hs — the only module in the codebase that writes acc turns
postTransaction :: Env -> Tenant -> Ledger.Transaction -> IO (Either AppError PostingId)
postTransaction env ten tx = do
  -- pure gate: cannot construct an unbalanced Transaction at all (see Pattern 2)
  (written, effects) <- Tx.runWrite (envPool env) ten $ do
      pid <- LedgerDao.insertTransaction tx          -- header
      LedgerDao.insertEntries pid (Ledger.txEntries tx)
      ES.appendEvent (toEvent pid tx)                -- same commit; audit/outbox
      pure pid
  runPostCommit env effects                          -- Redis/WebSocket only AFTER commit
  pure written
```

### Pattern 2: Smart constructor + hidden constructor = "unrepresentable, not merely validated"

**What:** `mkTransaction` returns `Either LedgerError Transaction`; the `Transaction` constructor is not exported, so `App.*` can only obtain one through the balance check.
**When to use:** `Transaction`, `RatePercent`, `RateFraction`, `Stock`, `Money` (parse path).
**Trade-offs:** Needs a separate `Unsafe`/`Internal` module for fixtures and row decoding, and `deriving` becomes manual. The payoff is that `validateTransaction` becomes unskippable — today it is skippable in six of seven implementations.

```haskell
module Finance.Ledger
  ( Transaction            -- type only; constructor NOT exported
  , mkTransaction
  , LedgerError(..)
  , sumDebits, sumCredits
  ) where

data Transaction = Transaction
  { txId :: Maybe TransactionId, txDate :: Day, txEntries :: [JournalEntry] }

mkTransaction :: Maybe TransactionId -> Day -> [JournalEntry]
              -> Either LedgerError Transaction
mkTransaction tid d es
  | null es                          = Left EmptyTransaction
  | sumDebits es /= sumCredits es    = Left (Unbalanced (sumDebits es) (sumCredits es))
  | any (not . entryWellFormed) es    = Left MalformedEntry
  | otherwise                        = Right (Transaction tid d es)
```

Equality here is on exact minor units, never `Double` and never `abs (a-b) < 0.01` — a tolerance is what allows a balanced entry to *fail* (`Finance/Types.hs:141-146` uses `==` on `Double`; `SheetDiffs.hs:17` uses `0.01`; two different answers to the same question).

### Pattern 3: Sibling adapters, not a chain

**What:** The HTMX UI and the JSON API are two front doors onto the same `App.*` services. The UI does not call the JSON API over HTTP.
**When to use:** Whenever a project has both an API and an SSR UI.
**Trade-offs:** Two thin mapping layers to maintain and two sets of codec tests. The alternative (UI → HTTP → API) buys "one boundary" but adds serialization round-trips, a base-URL config, and an auth-token dance inside the same process.

For HTMX specifically: return an HTML **fragment** for `HX-Request: true` and a full page otherwise, from the *same* route. This is the standard HTMX pattern (one route serves navigation and partial update; `hx-select` / `HX-Reselect` lets the client pick a sub-tree), and it avoids a parallel `/fragments/...` route tree that inevitably diverges. Lucid or Blaze are the idiomatic Haskell HTML DSLs; `servant-lucid`/`servant-blaze` supply the `MimeRender` instance if you stay in Servant.

Recommendation for this codebase: **mount the UI as a plain WAI `Application` under `/ui`, composed with `serve api` in one Warp app** — do *not* grow `SurypusApi` further. It is already 900+ lines with 101 missing signatures (`.planning/codebase/CONCERNS.md:70-73`), and a type-level route tree is the wrong place to add form-heavy HTML endpoints.

```haskell
-- Web/UI/Routes.hs — fragment-or-page from one handler
billRow :: Env -> BillId -> Handler Html
billRow env bid = do
  isHx <- fmap (== Just "true") (lookup "HX-Request" <$> requestHeaders)
  mb   <- App.Queries.billDetail env bid
  pure $ if isHx then Views.billRow mb else Views.layout "Bill" (Views.billDetail mb)
```

### Pattern 4: One transaction gateway with post-commit effects

**What:** `runWrite` opens exactly one transaction, sets the tenant transaction-locally, runs the writes, and returns a list of effects to perform only after a successful commit.
**When to use:** Every multi-row write. In this codebase that is bills, postings, stock movements, and any event append that must not outlive a rollback.
**Trade-offs:** Effects are described, not executed inline, so an effect can be lost if the process dies between commit and dispatch. That is strictly better than the current inverse (an event published for a transaction that then rolls back) and is the standard transactional-outbox trade.

```haskell
runWrite :: ConnectionPool -> Tenant -> SqlPersistT IO (a, [Effect]) -> IO (Either AppError a)
runWrite pool ten action =
  runSqlPool (withTransaction $ do
      rawExecute "SELECT set_config('app.tenant_id', ?, TRUE)" [PersistText (tenantTxt ten)]
      rawExecute "SELECT set_config('app.user_id',   ?, TRUE)" [PersistText (userTxt ten)]
      action) pool
```

Note what changes versus `DAL.Database.runDb`: `withTransaction` (absent today), `set_config(..., TRUE)` only — no `SET SESSION` leak (`.planning/codebase/CONCERNS.md:154-157`) — and tenant passed as an argument instead of read from the process-global `IORef` that currently lets concurrent requests overwrite each other (`DAL/Database.hs:29-31`).

### Pattern 5: Unit-safe rate types with no arithmetic instances

**What:** Distinct newtypes, hidden constructors, and *deliberately absent* `Num`/`Fractional`/`Real`/`Integral` instances.
**When to use:** Any pair of units that differ by a constant factor (percent/fraction, cents/units, grams/kilograms).
**Trade-offs:** Callers must write `unRatePercent` where they previously wrote a number. That friction is the feature; deriving `Num` on a newtype is what silently re-enables `RatePercent 20 * RateFraction 0.2`.

```haskell
module Surypus.Domain.Vat
  ( RatePercent, mkRatePercent, unRatePercent      -- constructor hidden
  , RateFraction, mkRateFraction, rateAsFraction   -- the ONLY conversion
  , vatAmount, vatOfInclusive, priceWithVat ) where

newtype RatePercent  = RatePercent  Decimal deriving (Show, Eq)   -- no Num
newtype RateFraction = RateFraction Decimal deriving (Show, Eq)   -- no Num

mkRatePercent :: Decimal -> Either VatError RatePercent
mkRatePercent r | r < 0 || r > 100 = Left RateOutOfRange
                | otherwise        = Right (RatePercent r)

rateAsFraction :: RatePercent -> RateFraction
rateAsFraction (RatePercent p) = RateFraction (p / 100)   -- sole conversion site

vatAmount :: Money -> RatePercent -> Money                 -- signature admits one unit only
```

Enforcement that does not rely on discipline: an Hspec "boundary spec" that reads the source of `src/Finance`, `src/Surypus/Domain`, and `src/App` and fails if `Double` appears in a money/rate signature. Cheap, and it is the only mechanism that survives a large single-package build (see Anti-Pattern 1).

### Pattern 6: Import firewall as a test, not a convention

**What:** A test (or CI script) that parses module imports and asserts the layering rules.
**When to use:** Immediately, while everything is one package. `.planning/codebase/ARCHITECTURE.md:263-264` is explicit that 381 modules share one dependency graph with no package-level boundary.

```haskell
-- test/Boundary/ImportsSpec.hs (sketch)
it "pure domain never imports persistence or IO" $ do
  forM_ domainModules $ \m ->
    importsOf m `shouldSatisfy` noneOf ["DAL.", "Database.Persist", "Control.Monad.IO"]
it "only App.Accounting writes acc_turns" $ do
  writers <- modulesMentioning "INSERT INTO acc_turns"
  writers `shouldBe` ["App.Accounting"]
```

Package splitting into `surypus-domain` / `surypus-dal` / `surypus-app` / `surypus-web` is the *strong* version of this boundary and should happen **after** consolidation, not during: moving 381 exposed modules while their canonical owners are still contested multiplies churn for no correctness gain. Record it as a follow-up ADR.

## Data Flow

### Write flow (the only one)

```text
[ HTML form POST /ui/bills/42/post ]        [ JSON POST /api/v1/bills/42/post ]
              │                                          │
              └──────────────┬───────────────────────────┘
                             ▼
              Web.UI handler / Web.Api handler     (decode + authz only)
                             ▼
                     App.Billing.postBill        (command)
                             ▼
        ┌──────────── pure ────────────┐
        │ load bill + lines (DAL.Query)│
        │ Vat.vatAmount / Money.round  │
        │ Ledger.mkTransaction         │  ← unbalanced => Left, nothing written
        └──────────────┬───────────────┘
                       ▼
              App.Tx.runWrite  ──── BEGIN ────────────────────────────┐
                       │           set_config(tenant, local)          │
                       │           UPDATE bills SET status='posted'    │
                       │           INSERT acc_turns (balanced batch)   │
                       │           INSERT stock / lot rows             │
                       │           INSERT event_store (audit)          │
                       │         COMMIT ──────────────────────────────┘
                       ▼
              post-commit effects: Redis publish, WS fan-out, job enqueue
                       ▼
              render fragment (UI)  |  render JSON (API)
```

Rules that make this path *the* path:

- `acc_turns` is written by exactly one module (`App.Accounting`). Any other `INSERT INTO acc_turns` is a defect the boundary test catches.
- The event append is inside the transaction. Today `appendEvent` takes a `ConnectionPool` and calls `runDb` itself (`DAL/EventStore.hs:133`), which makes it physically impossible to append atomically with the business rows. Change the signature to `Event -> SqlPersistT IO ()` and let the caller supply the transaction — a one-line change with large consequences.
- Validation happens *before* `BEGIN` where possible, and inside it where it needs a read (e.g. bill state). On `Left`, no partial rows exist because there was no transaction scope to be partial in.

### Read flow

```text
GET /ui/bills             → App.Queries.listBills  → DAL.Queries (SQL) → Lucid page
GET /ui/bills?hx=1        → same handler            → Lucid fragment
GET /api/v1/bills         → App.Queries.listBills  → aeson             → JSON
GET /ui/ledger/balance/A  → App.Queries.accountBalance → SQL aggregate
```

**Decision: the ledger tables are the source of truth; `event_store` is an audit/outbox log, not the balance authority.** For v1, `accountBalance` is `SELECT sum(debit), sum(credit) FROM acc_turns WHERE account_id = ?` in one statement — always correct, no replay, no Redis, no cache invalidation. The event-sourced read model (`Core.Accounting.ReadModel`, `Infrastructure.EventStore.Accounting`, `Core.Accounting.RedisCache`) becomes a *derived* projection only if and when it is needed. This resolves a real, currently-live divergence: `Domain.Accounting.Events.rebuildBalance` ignores the account code entirely (`CONCERNS.md:117-121`), so replay and SQL disagree today.

Consequences to plan for:
- No `rebuildBalance` in the canonical set. It is a bug holder, not a design.
- Redis stops being on the critical path for correctness. Redis remains optional for fan-out only; if it is down, commits still succeed and balances are still right. This removes the Redis single-point-of-failure from the acceptance path and matches the PROJECT.md decision to drop Redis queues.

### Startup flow

```text
app/Main.hs
  → readConfig (env; fail fast on missing DB_* / JWT secret)
  → createPool (from DAL.Database, DSN from config — not a literal)
  → newMetrics, newLogger
  → App.Authz.newHandle (loads role→permission; fail fast if absent)
  → Env { pool, logger, metrics, authz, publicPaths }
  → Warp.runSettings (Web.Api.application env <> Web.UI.application env)
```

Today `app/Main.hs` prints two lines (`app/Main.hs:4-7`) while `apiServer` has no importer (`ARCHITECTURE.md:235`). **Nothing downstream of this document can be verified until this exists**, which is why it is step 0 rather than step 7.

## Build Order (the strangling sequence)

Dependency DAG — an arrow means "must exist and be green before the next starts":

```text
  [0] boot + CI gate
        │
        ▼
  [1] Money ──► [2] Vat ──► [3] Ledger + App.Tx ──► [4] Stock
                                   │                    │
                                   └────────┬───────────┘
                                            ▼
                                  [5] Queue canon (independent; can run parallel to 3/4)
                                            ▼
                                  [6] Vertical slice over JSON  ◄── the acceptance path
                                            ▼
                                  [7] RBAC real store  ──► [8] HTMX UI
                                            ▼
                                  [9] Balance proof (LiquidHaskell)
```

| # | Phase | Canonical artifact | Deletion list | Exit criterion |
|---|-------|--------------------|---------------|----------------|
| 0 | **Boot** | real `app/Main.hs`, `App.Env`, config from env | — | `/api/v1/health` → 200 from `stack run`; `stack test` baseline recorded |
| 1 | **Money** | `Surypus.Domain.Money` | `Surypus.CoreTypes.Decimal/Money`, `Finance.Ledger.Amount`, `Surypus.Types.Common.Money`, orphan `Decimal` JSON instances in `Finance.Tax` | boundary spec: no `Double` in money signatures; round-trip property tests |
| 2 | **VAT** | `Surypus.Domain.Vat` | `Core.Tax` (fractions), the percentage-half of `Finance.Tax` | every rate in `src/` is a `RatePercent` or `RateFraction`; 100× regression test |
| 3 | **Ledger + `App.Tx`** | `Finance.Ledger`, `App.Accounting`, `App.Tx` | `Finance.Types`, `Finance.Accounting`, `Finance.Journal`, `Finance.Ledger`, `Domain.Accounting.Events.rebuildBalance`, `Core.Services.Accounting` | unbalanced `Transaction` is unconstructible; rollback test leaves 0 rows and 0 events |
| 4 | **Stock** | `Inventory.Stock` + `DAL.Row.Stock` | `Inventory.StockOps`, `Inventory.Operations`, `DAL.DB` (incl. `test/DAL/DBSpec.hs`), `DAL.Types.Stock` hand-edits | one `Stock` type in the tree; `grep -c "data Stock"` = 1 |
| 5 | **Queue** | `DAL.Queue` | `System.JobQueue`, `System.Jobs`, `Infrastructure.Redis.TaskQueue`, `Production.ServiceManager` | DDL only in `sql/migrations`; concurrent claim test with `SKIP LOCKED` |
| 6 | **Vertical slice** | `App.Billing` + `App.Inventory` | `DAL.DB` import in `Service/BillService.hs`, stub `postBillWithAcc` | goods → receipt → bill → payment → postings → balance, asserted over HTTP against real Postgres |
| 7 | **RBAC** | `App.Authz` (DB-backed, default-deny) | `checkUserAppPermissionRepo` stub, `RBAC` `unsafePerformIO` registry, fail-open default branch | unmapped route → 403; the three roles enforced on every write route |
| 8 | **HTMX UI** | `Web.UI.*` | — | the same slice driven through forms; every write goes through an `App.*` command |
| 9 | **Proof** | `Finance.Ledger` refinements | annotation-only specs in `Core.Tax`/`Core.Inventory` that no longer describe canonical code | `liquid` runs in CI and fails the build, or the claim is removed |

### Ordering rationale (why this order and not a "cleaner" one)

- **Money before VAT.** VAT is arithmetic over money. Doing VAT first means writing rate code against two competing money types and then rewriting it — the exact churn the milestone is trying to avoid.
- **`App.Tx` lands with the ledger, not earlier.** The ledger is the first place that genuinely needs a multi-row atomic write (header + entries + cache + event). Introducing a transaction gateway before there is a transaction to protect produces an abstraction with no caller, which is how the four existing job queues happened.
- **Ledger before stock.** A goods receipt must produce postings; stock movement without postings is the current half-wired state (`Infrastructure.EventStore.Inventory` exists alongside `Inventory.Operations`). Getting the ledger right first means the receipt has a correct destination.
- **Vertical slice over JSON before HTML.** The slice is the acceptance criterion. A JSON assertion (`POST` then `GET` balance) is automatable in the test suite; an HTML assertion needs a browser harness. Prove the logic over JSON, then render it. It also forces the services to be adapter-agnostic — the property that keeps the UI thin.
- **RBAC before UI writes.** A form that posts `POST /ui/bills/42/post` is a write endpoint. Shipping it behind today's fail-open authorization (`Authorization.hs:101-121` allows any unmapped path) would create a new unauthenticated write surface, and the UI would then have to be retrofitted with auth mid-flight.
- **Proof last, and deliberately so.** See the pitfall below — the current GHC pin probably cannot run current LiquidHaskell at all, so the proof phase needs toolchain work that must not block the working system.

### Deletion discipline (the part that makes this a strangle and not a facade)

An adapter/shim is permitted only when the old representation is *stored* (DB column, JSON payload, migration). A shim between two in-memory representations is a way of keeping both alive, and in this codebase it is how seven ledger implementations survived.

Rule for every phase: the plan must name the deletions, and the phase is not complete while `grep` still finds the loser. History is in git; keeping dead modules exported "just in case" is what produced `Core.Services.Accounting` (a stub wrapper whose `validateTransaction` always returns `Right`).

## Scaling Considerations

| Scale | Architecture adjustments |
|-------|--------------------------|
| 1 user / smoke test | Current design is correct as-is. Single Warp process, pool of 10, one Postgres |
| 10–100 concurrent users | Pool size from env (`DB_POOL_SIZE` is already in `.env.example`, unused); read queries indexed on `(account_id, date)`; UI renders fragments so responses stay small |
| Multi-instance | Requires: tenant as an argument (done in `App.Tx`), queue in Postgres with `SKIP LOCKED` (phase 5), rate limiter in Postgres/Redis (currently process-local, `CONCERNS.md:300-303`), and no `unsafePerformIO` registries. The design above is stateless by construction except the pool |
| Long-running work | Report export / backup move behind `DAL.Queue` and return `202` — currently they run inside the Warp worker (`Server.hs:908`, `Reports.hs:189`) |

**First bottleneck:** the connection pool (hardcoded 10, `DAL/Database.hs:43`) under report generation. Mitigated by moving reports to the queue, not by raising the number.

**Second bottleneck:** balance queries as data grows. Mitigation is a materialized per-account balance row updated inside the same `runWrite` (still one write path), not an event replay cache.

## Anti-Patterns

### Anti-Pattern 1: A facade that re-exports both implementations

**What people do:** "To avoid breaking callers, `Finance.Ledger` re-exports `Finance.Types` and `Finance.Accounting`."
**Why it's wrong:** Both remain reachable, so both remain used, and they drift: the next fix lands in one of three. This is precisely how the codebase arrived at seven double-entry implementations and two VAT engines.
**Do this instead:** Move call sites in the same phase (the compiler finds them all), then delete and drop from `exposed-modules`. Keep a shim only at a *stored* boundary where a shim is genuinely required.

### Anti-Pattern 2: Per-function connection checkout

**What people do:** Each DAL function takes `ConnectionPool` and calls `runDb` internally.
**Why it's wrong:** A business operation becomes N transactions on N connections. There is no rollback across them, so a failed event append leaves posted bills with no audit row, and a failed posting leaves a posted bill with no entries. This is the current state of every DAL module.
**Do this instead:** DAL functions take `SqlPersistT IO a`; only `App.Tx` owns the pool. Enforce with the boundary spec (`runDb` may be called from exactly one module).

### Anti-Pattern 3: Unit-bearing `Double` in a signature

**What people do:** `calcVat :: Double -> Double -> Double`, documented "rate is a percentage".
**Why it's wrong:** Documentation is not a type. `Core.Tax.applyTax` and `Finance.Tax.calcVAT` are both exported and both correct *by their own convention* — which is the definition of a latent 100× bug.
**Do this instead:** `vatAmount :: Money -> RatePercent -> Money`, constructor hidden, and no `Num` instance on either rate type.

### Anti-Pattern 4: HTML handlers that compute

**What people do:** The view sums line amounts, or formats VAT inline, because "it already has the values".
**Why it's wrong:** The UI becomes a second implementation of the rules — the same failure mode as the duplicate domain modules, one layer up. It also makes the total wrong in a different way than the ledger (display rounding vs posting rounding).
**Do this instead:** `App.Queries` returns a view record whose money fields are already `Money` formatted by one formatter; the view only chooses markup.

### Anti-Pattern 5: Publishing events before commit

**What people do:** Append the event, publish to Redis/WebSocket, then continue writing.
**Why it's wrong:** Subscribers observe events for transactions that roll back, and the read model diverges from the tables with no reconciliation path. `Infrastructure/EventStore/Accounting.hs` does exactly this today.
**Do this instead:** Return `[Effect]` from the transaction and run them after commit; or write them to an outbox table in the same transaction.

### Anti-Pattern 6: Growing the god API type

**What people do:** Add each new HTML route to `SurypusApi`.
**Why it's wrong:** The file is already 911 lines with 101 missing signatures, and every route addition recompiles the whole type-level tree. Form endpoints need no typed client, so the type-level cost buys nothing.
**Do this instead:** A separate WAI `Application` under `/ui`, composed with `serve api` in `main`.

## Integration Points

### Internal boundaries

| Boundary | Communication | Notes |
|----------|---------------|-------|
| `Web.UI` → `App.*` | Direct function call, `Env` argument | Same process, no HTTP. UI must not import `DAL.*` |
| `Web.Api` → `App.*` | Direct function call | Handler is decode → call → encode; the current direct `DAL.MutationsORM` imports are the thing to remove |
| `App.*` → `Surypus.Domain.*` | Pure values | Domain returns `Either DomainError Doc`; App maps to `AppError` |
| `App.Tx` → `DAL.*` | `SqlPersistT IO` | The only holder of `ConnectionPool` after phase 3 |
| `App.*` → `DAL.EventStore` | `Event -> SqlPersistT IO ()` | Signature change from pool-taking to action-returning is mandatory |
| `App.Authz` → `DAL` | `SqlPersistT` via `runRead` | Default-deny on missing mapping |

### External services

| Service | Integration pattern | Notes |
|---------|--------------------|-------|
| PostgreSQL | `persistent` + `esqueleto` reads, `rawSql` for aggregates | Real DB is the acceptance target; migrations in `sql/migrations` only |
| Redis | Optional fan-out after commit | Not on the correctness path once balances come from `acc_turns` |
| HTMX | Static asset, `HX-Request` header detection | No build step, no JS framework — satisfies the Haskell-only constraint |
| `weasyprint` / `pg_dump` | Job queue, not request path | Currently invoked inline and not installed in the runtime image |

## Phase-Specific Architecture Risks

| Phase | Architectural risk | Mitigation |
|-------|-------------------|------------|
| 1 Money | Choosing `Data.Decimal` internally makes the phase-9 proof very hard: LH has no arithmetic theory for `Decimal`, and specs like `{-@ type NonNeg = {v:Decimal | v >= 0} @-}` (`Finance/Accounting.hs:6`, `Finance/Tax.hs:12`) are currently aspirational, not discharged | Represent money internally as **scaled `Integer` minor units** (`newtype Money = Money Integer`), keep `Data.Decimal` as the parse/display type. Exact `==` becomes meaningful and LH can reason about it. **This deviates from the recorded PROJECT.md decision and needs an explicit decision before phase 1 starts** |
| 3 Ledger | `withTransaction` inside `runSqlPool` interacts with the tenant `set_config`; a `SET SESSION` (not `set_config(...,TRUE)`) leaks across pooled connections | Transaction-local `set_config` only; rollback test asserts the next borrower sees no tenant |
| 4 Stock | `DAL.Types` is generator-owned, so the canonical `Stock` cannot live there | Canonical type in `Inventory.Stock`; generated row type stays a DTO with a total conversion |
| 5 Queue | Inline `CREATE TABLE` in `DAL/Queue.hs:140` drifts from migrations | DDL in a numbered migration; `initializeQueue` removed |
| 7 RBAC | `checkUserAppPermissionRepo` returns `True` unconditionally; unmapped routes are allowed | Replace, don't wrap. Default-deny + explicit public allowlist (exact match, not `isPrefixOf` — `AuthMiddleware.hs:62`) |
| 9 Proof | **LH supports exactly one GHC version at a time**, and current LH targets the 9.14 LTS line; `stack.yaml` pins 9.6.5 while `liquidhaskell.yaml` claims 9.14+ | Decide in-phase: bump GHC to the LH-supported version (and re-pin `cryptonite`/`jose`), or pin an older LH that supports 9.6.5 and drop the claim to "annotations type-check". Do not let this block phases 1–8 |
| 8 UI | No `lucid`/`blaze-html`/`servant-lucid` in `Surypus.cabal` today | Add one HTML DSL and one HTMX asset; do not add a JS toolchain |

## Gaps and Open Questions

- **Money representation is an open decision.** PROJECT.md says `Data.Decimal`; the proof requirement pushes toward scaled `Integer`. This document recommends scaled `Integer` internally with `Data.Decimal` at boundaries, but it is a PROJECT-level decision, not a research finding.
- **Event sourcing depth is unresolved.** This architecture demotes the event store to an audit log. If the milestone later wants replayable projections as the balance authority, `Core.Accounting.ReadModel` must be rebuilt against the canonical `JournalEntry` and its `rebuildBalance` account-filter bug fixed first (`CONCERNS.md:117`).
- **`DAL.Types` generator ownership.** Whether `dsl/schema.yaml` + `surypus-codegen` should generate the row layer from the canonical domain types (rather than the reverse) was not evaluated; it materially affects how phase 4 is planned.
- **HTMX asset delivery and CSRF** were not researched in depth. Session/cookie auth for the UI (versus bearer tokens for the API) needs a decision before phase 8.
- **LiquidHaskell spec for `Transaction`** (a list-of-entries measure over `sum`) is unverified against a real LH run; phase 9 should start with a one-function spike (`mkTransaction`) before promising the invariant.
- External searches were cross-checked only once, so HTMX/Lucid and strangler-fig claims are MEDIUM. Context7 was unavailable in this environment (`ctx7` not installed), so no Hackage API docs were consulted directly; `persistent`/`esqueleto` transaction claims come from the code's own imports plus general knowledge and should be re-checked in phase 3.

## Sources

- `.planning/PROJECT.md` — scope, constraints, recorded decisions (direct read, HIGH)
- `.planning/codebase/ARCHITECTURE.md` — current layering, entry points, anti-patterns (direct read, HIGH)
- `.planning/codebase/CONCERNS.md` — duplicate-implementation inventory, security and correctness defects (direct read, HIGH)
- `src/Finance/{Types,Tax,Accounting}.hs`, `src/Core/Tax.hs`, `src/Surypus/CoreTypes.hs`, `src/DAL/{Types,Database,MutationsORM,EventStore,Queue}.hs`, `src/Inventory/Stock.hs`, `src/Service/BillService.hs`, `app/Main.hs` — verified against source (HIGH)
- HTMX fragment/template-fragment patterns — https://htmx.org/essays/template-fragments, https://htmx.org/server-examples (MEDIUM, single cross-check)
- Serving HTML from Servant with Lucid/Blaze — https://mmhaskell.com/blog/2020/3/23/serving-html-with-servant (MEDIUM)
- Strangler fig mechanics (facade, thin slices, decommissioning) — https://microservices.io/post/refactoring/2023/06/21/strangler-fig-application-pattern-incremental-modernization-to-services.md.html, https://www.catio.tech/blog/strangler-fig-pattern (MEDIUM)
- LiquidHaskell GHC-version lockstep ("only one version of GHC at any given time") — https://github.com/ucsd-progsys/liquidhaskell; GHC release status — https://endoflife.date/ghc (MEDIUM)
- Fixed-point/minor-unit money representation and rounding — https://en.wikipedia.org/wiki/Fixed-point_arithmetic, https://www.evanjones.ca/floating-point-money.html (MEDIUM)

---
*Architecture research for: Surypus ERP consolidation*
*Researched: 2026-10-23*
