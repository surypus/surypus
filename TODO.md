# Surypus TODO — Unified Task List

Первичные (архитектурные инварианты):
  Ц-1  Доказуемая корректность бизнес-инвариантов
  Ц-2  Безопасность как свойство типовой системы
  Ц-5  Haskell-гомогенность стека

Вторичные (бизнес-полнота):
  Ц-3  Покрытие ERP-контура
  Ц-4  SLA-связанные API

Третичные (позиционирование):
  Ц-6  Event Sourcing как аудируемость
  Ц-7  MPL-2.0 как открытость без GPL-вирусности

bd ready



# Surypus TODO — Unified Task List

> All tasks from all sessions consolidated in one place.
> Sources: TODO.md, BACKLOG.md, docs/phase2_phase3_backlog.md, .beads/issues.jsonl

---

## Strategic Goals

1. Корректность по конструкции
   └── LiquidHaskell, рефайнменты, QuickCheck

2. Событийный аудит и воспроизводимость
   └── Event sourcing для бухгалтерии, склада, CRM

3. Мультиарендность и безопасность
   └── RBAC, JWT, шифрование, изоляция тенантов

4. Интеграционная открытость
   └── REST, GraphQL-прокси, EDI, банковские выписки

5. Наблюдаемость в продакшне
   └── Метрики, трассировка, circuit breaker

6. Производительность через типобезопасность
   └──  ORM, строгая типизация запросов
 

### Architecture
- [x] Migrate to proper Hasql parameterized queries (avoid string interpolation for security)
- [x] Add database connection pooling with proper error handling
- [x] Implement repository pattern for DAL layer
- [x] Add input validation layer (validate requests before DB operations)

### Business Logic
- [x] Implement full accounting module (double-entry bookkeeping)
- [x] Implement inventory/stock management with lot tracking
- [x] Implement VAT calculations with multi-rate support
- [x] Add payroll module integration
- [x] Add report generation (Surypus.Reports module)

### API
- [x] Add OpenAPI/Swagger documentation
- [x] Implement rate limiting middleware
- [x] Add request logging and monitoring
- [x] Implement API versioning strategy (Surypus.APIVersioning)
- [x] Add WebSocket support for real-time updates

### Security
- [x] Implement JWT authentication with refresh tokens
- [x] Add role-based access control (RBAC)
- [x] Add audit logging for sensitive operations
- [x] Implement API key authentication for integrations

### Testing
- [x] Add property-based testing with QuickCheck
- [x] Add integration tests for API endpoints
- [x] Add database migration tests (config/migrations/)
- [x] Add performance/load tests (Prometheus metrics)
- [x] Add Surypus.ValidationSpec — comprehensive validation tests (2026-10-07)
  - validateAccTurnInput: 9 unit tests + 1 QuickCheck property
  - validatePersonInput: 3 unit tests
  - validateINN: 5 unit tests + 1 QuickCheck property
  - validateKPP: 3 unit tests + 1 QuickCheck property
  - validateCurrencyInput: 3 unit tests
  - validateGoodsInput: 2 unit tests
  - validateLocationInput: 2 unit tests
  - validatePaymentInput: 3 unit tests
  - validatePriceInput: 3 unit tests
  - validateTaxInput: 4 unit tests
  - JSON roundtrip tests for AccTurnInput and MutationResult
- [x] Fix `calcNetSalaryFromGross` — return 0 for non-positive gross (2026-10-09)
- [x] Fix QuickCheck generators — produce valid domain data: non-negative amounts, woQtyReleased ≤ woQtyPlan, billAmount = Σ lineTotal (2026-10-09)
- [x] Add `instance Arbitrary Text` to TestHelpers (2026-10-09)
- [x] Wired EmailSpec (6 tests): first coverage for Email; fixed latent bug — sendEmail with ecOutputFile printed to stdout instead of writing the file (2026-10-15)
- [x] Full suite green: 160 examples, 0 failures, 6 pending (API stubs) (2026-10-09)
- [x] Fix `checkSlidingWindowWithHeaders` off-by-one in `remaining` (2026-10-09)
- [x] Add System.RateLimiterSpec with 15 tests covering all 4 rate limiter strategies + API middleware logic (2026-10-09)
- [x] Add System.CacheSpec with 17 tests covering System.Cache (calcHitRate, isExpired, calcVATStrict, calcTaxInclusiveStrict, STMCache operations) (2026-10-09)
- [x] Add System.CounterSpec with 15 tests covering System.Counter (nextCounterValue, padding, prefix/suffix, 4 QuickCheck properties) (2026-10-10)
  - 11 unit tests + 4 QuickCheck properties
  - Verified: all 15 tests passing
- [x] Fix Surypus.cabal: add missing modules (Core.Accounting.CacheSpec, JWTSpec, System.CounterSpec) to other-modules, remove duplicate stm/containers deps (2026-10-10)
- [x] Add ConfigSpec, ObservabilitySpec, MigrationDryRunSpec, RBACCanonSpec to cabal test-suite (2026-10-10)
  - 4 new test modules wired into cabal `other-modules` and `Test.hs`
  - All 4 verified via direct GHC compilation (12 examples total, 0 failures)
  - Fixed ConfigSpec: use qualified field access (rcLogLevel/rcMaxWorkers) instead of RecordWildCards pattern
  - Fixed MigrationDryRunSpec: remove references to non-existent generateV029-V040 (only V001-V028 exist)
  - Fixed RBACCanonSpec: remove duplicate V025 check, remove references to non-existent V029-V040
  - Note: full `cabal build` still blocked by pre-existing errors in other library modules (PayrollService, Integration.Health, DAL.Procedures, DAL.MutationsORM)
- [x] Fix committed conflict markers in Surypus.cabal, README.md, stack.yaml (accidentally committed in f4dd61bf "docs: rebuild mkdocs site"); restored from 9ecd00d4 + kept 2 intended changes (2026-10-11)
  - Removed non-existent `Shared.Export.Exporter` from exposed-modules
  - Added all 18 wired test modules to test-suite other-modules (was only 8)
  - Created missing `test/System/SequenceSpec.hs` (11 tests: 7 unit + 4 QuickCheck properties)
  - Restored README.md and stack.yaml from 9ecd00d4 (removed committed conflict markers)
  - Verified via direct GHC compilation: **298 examples, 2 failures (pre-existing RateLimiter timing), 6 pending**
- [x] Add JWTSpec with 22 tests covering Surypus.JWT security-critical module: jwtConfigFromSecret, validateAccessToken, decodeAndValidateToken + QuickCheck security properties (2026-10-09)
  - 17 unit tests + 5 QuickCheck security properties
  - Verified: 22 examples, 0 failures (compiled and run via ghc directly; full cabal build blocked by GHC 9.10.3 vs persistent incompatibility)
- [x] Wire Inventory.StockSpec + Inventory.WarehouseSpec into cabal test-suite (2026-10-12)
  - 9 tests: StockOps receipt/issue/insufficient/transfer/adjustment; Warehouse create/duplicate/read-update-delete/count
  - Fixed 3 genuine compile errors: ambiguous `pure ()` in hspec `it` blocks (Inventory.StockSpec:30, Inventory.WarehouseSpec:24) → `(pure () :: IO ())`; `shouldContain` on `Text` (Inventory.WarehouseSpec:39) → `T.isInfixOf "archived" (wName d) \`shouldBe\` True`
  - Verified by building and running the whole wired suite: **321 examples, 2 failures (pre-existing RateLimiter timing flakes), 6 pending** — both new specs green
- [x] Wire HR.OperationsSpec into cabal test-suite (2026-10-12)
  - 14 tests: validatePersonData (valid request, empty code/name, invalid INN/KPP); createPerson CRUD (create, duplicate-INN conflict, findByINN, findByCode); status transitions (activate/deactivate/block); queries (countPersons, personsByKind)
  - Fixed 1 compile error: ambiguous bare `pure ()` in `it` block (OperationsSpec:158) → `(pure () :: IO ())`
  - Verified by direct GHC build+run of the full Test.hs closure (full `cabal build` still blocked by pre-existing library errors in Surypus.API.BillTemplates et al.): **335 examples, 2 failures (pre-existing idle-machine RateLimiter timing tests), 6 pending** — new spec 14/14 green
  - Audit finding: `test/HR/PersonSpec.hs` is stale against the current API (expects 7-arg `createPerson`, `pIsActive`, `pPersonKindId :: PersonKind` — none exist in `HR.Person`/`HR.Operations`); verified by GHC ("Variable not in scope: pIsActive" + arity errors). Cannot be wired without rewrite — extends TASK-034
- [x] Wire Phase2Phase3.AccountingEventsSpec into cabal test-suite (2026-10-12)
  - 1 test: `rebuildBalance` computes correct result from events (EntryCreated debit 1000 / credit 500 → balance 500.0)
  - Fixed missing export list: `spec` was not exported → added `(spec)` to module header
  - Verified by direct GHC build+run of the full Test.hs closure (full `cabal build` still blocked by pre-existing library errors in Surypus.API.BillTemplates et al.): **336 examples, 2 failures (pre-existing idle-machine RateLimiter timing tests), 6 pending** — new spec green
  - Audit finding: `test/Phase2Phase3/AccountingEventStoreSpec.hs` + `test/Phase2Phase3/ReadModelCacheSpec.hs` are stale — they target an old in-memory `DAL.EventStore` API (`initEventStore`, `EventData{edOldBalance,…}`, `createAccountCreatedEvent`, `createJournalEntryEvent`, `aeAggregateId`, `aeEventType`, `AccountCreated`/`JournalEntryPosted`) that no longer exists; the current `DAL.EventStore` is PostgreSQL-backed (`Event`/`Snapshot` records; `appendEvent`/`getEvents`/`replayAccount` over `ConnectionPool`). Full rewrite against the DB-backed API (needs live DB to run) or deletion — extends TASK-034
- [x] Wire Domain.ProductionPropertySpec into cabal test-suite (2026-10-12)
  - 12 property tests against `Production.Types`: validateTechCard (empty name / invalid status / valid card), validateTechLine (negative qty / invalid scrap % / valid line), validateWorkOrderCore (over-release / negative plan / valid order), mkWorkOrder creates valid orders, released ≤ planned, status in valid range — 100 QuickCheck cases each
  - Fixed 6 compile errors: missing `Arbitrary TechCard`/`Arbitrary TechLine` instances (added; `Arbitrary WorkOrder` reused from TestHelpers via qualified import); `mkWorkOrder` called with 5 args vs real 4-arg signature (dropped stale `processorId`); leftover TemplateHaskell `return []` splice without pragma (removed); ambiguous `choose` result types (annotated `Gen Integer`); `UTCTime` type-only import (→ `UTCTime (..)`); `Bool` vs `Property` mismatch in `prop_statusInValidRange` (→ `property (...)`)
  - Verified by direct GHC build+run of the full Test.hs closure (full `cabal build` still blocked by pre-existing library errors in Surypus.API.BillTemplates et al.): **348 examples, 2 failures (pre-existing idle-machine RateLimiter timing tests), 6 pending** — new spec 12/12 green
  - Audit finding: `test/Integration/ValidationSpec.hs` is stale — `DAL.Types` no longer defines `PersonInput`/`GoodsInput`/`BillInput`/`LocationInput`/`OrderInput`/`PaymentInput`/`PriceInput`/`TaxInput`/`CurrencyInput`/`AccPlanInput` (only `AccTurnInput` remains), and every `validate*Input` in `Surypus.Validation` now takes individual scalar args instead of records. Needs full rewrite — extends TASK-034
- [x] Wire Contract.SchemaSpec into cabal test-suite (2026-10-12)
  - 5 tests: dsl/schema.yaml parses without errors; version field is "1.0.0"; entities defined; entity names unique; every field has name+type
  - Rewrote the spec against aeson 2.x / yaml 0.11: `eitherDecodeFileStrict` (not exported by yaml-0.11) → `decodeFileEither`; `Object` is `KeyMap` → `Data.Aeson.KeyMap.lookup`; `Array` constructors hidden in aeson 2.2.3.0 (`Data.Aeson.Types.Internal` not exposed) → typed `FromJSON` records (`Schema`/`Entity`/`Field`) so missing field keys fail the decode; fixed the unsatisfiable first assertion (`Right (Object HM.empty)` — also invalid under KeyMap) to a parse-success check; added `(spec)` to the module header; added `yaml` to the test-suite build-depends (was a library dep only)
  - Verified by direct GHC build+run of the full Test.hs closure (full `cabal build` still blocked by pre-existing library errors in Surypus.API.BillTemplates et al.): **353 examples, 2 failures (pre-existing idle-machine RateLimiter timing), 6 pending** — new spec 5/5 green; negative check (corrupting dsl/schema.yaml fails all 5 schema tests) proves they are not vacuous
  - Audit finding: `test/DB/RepositoriesSpec.hs` + `test/Integration/PoolSpec.hs` import missing `DB.Connection` (no `src/DB/`); `test/API/{Health,Swagger,Procurement,RBAC}Spec.hs` import missing `App` (Test.MakeTest itself cannot compile); `test/API/ServerV2Spec.hs` collides with `test/API/ServerSpec.hs` on module name; root `test/RBACSpec.hs` is stale against the thin current `Surypus.RBAC`/`Surypus.RBAC.Store` API; `test/DAL/DBSpec.hs` is stale against `DAL.DB`; `test/DAL/IntegrationSpec.hs` imports missing `Test.DAL.Fixtures`; `test/DAL/EventStoreSpec.hs` needs a live `ConnectionPool`. Placeholder-only (zero coverage): `Integration/{Crud,Negative,Property,InventoryLifecycle}Spec.hs`, `API/ServerSpec.hs`, `BridgeSpec.hs`, `SurypusSpec.hs` — extends TASK-034
- [x] Wire Inventory.GoodsSpec into cabal test-suite (2026-10-12) — closes TASK-033
  - 5 tests: create goods + duplicate-code conflict, find by code/barcode, total inventory value, goods for restocking
  - Fixed `goodsForRestocking` semantics (was active-only, ignored `gMinStock`): now active AND `gMinStock > 0` (zero minimum = no restocking policy; `Goods` carries no on-hand quantity — a true below-minimum report needs a stock join with `Inventory.Stock`, follow-up). Exported `goodsForRestocking` + `totalInventoryValue`
  - Spec's old assertion `goodsForRestocking [g1,g2] == [g1]` (documented unsatisfiable) retargeted to the new semantics: g1/g2 (minima 5/50) included, g3 (active, min 0) and g4 (inactive) excluded
  - Fixed 1 compile error (ambiguous bare `pure ()` → `(pure () :: IO ())`) and 1 real bug found by running: `createGoods` crashed with `maximum: empty list` when creating the first goods (lazy `GoodsSuccess g` bindings hid the field forcing; `Eq` in `shouldBe` forced `gId`) → `if null goods then 0 else maximum (map gId goods)`
  - Verified by direct GHC build+run of the full Test.hs closure (full `cabal build` still blocked by pre-existing library errors in Surypus.API.BillTemplates et al.): **358 examples, 2 failures (pre-existing idle-machine RateLimiter timing), 6 pending** — new spec 5/5 green
  - Negative check: the spec compiled against the old active-only filter fails exactly the restocking example (5 examples, 1 failure), so the test pins the new semantics
- [x] De-flake System.RateLimiterSpec + fix inverted `lbCheck` leak predicate (2026-10-12)
  - The 2 known "pre-existing RateLimiter timing" failures are gone: both depended on ~10 ms of real elapsed time between consecutive checks (TokenBucket refill at rate 100/s; LeakyBucket entries aging past the leak window) — failed on idle, passed under load
  - Deterministic rewrites via the exposed TVar timestamps (`tbLastRefill` backdating, `lbQueue` pinning) — same technique as the existing SlidingWindow manual-time-advance test
  - New deterministic tests: `refills proportionally to elapsed time` (rate 0.5: 1 s → 0.5 tokens → denied; 2 s → 1.0 tokens → allowed) and `leaks entries after the window`
  - Library fix: `lbCheck` used `dropWhileL (age < window)` — keeping aged entries and dropping fresh ones, so the queue grew monotonically and the bucket denied everything permanently after `capacity` requests; now `Seq.filter` keeps un-leaked entries (canonical leaky-bucket semantics, doc comment added). `System.RateLimiter` is imported by tests only (the API layer uses the separate `Surypus.API.RateLimiter`) — no production impact
  - Verified by direct GHC build+run of the full Test.hs closure (full `cabal build` still blocked by pre-existing library errors in Surypus.API.BillTemplates et al.): **360 examples, 0 failures, 6 pending** — stable across 4 runs
  - Negative check: the new spec compiled against the pre-fix `lbCheck` (git HEAD) fails exactly the 2 leaky tests, deterministically
- [x] TASK-033: `goodsForRestocking` semantics fixed, functions exported, `test/Inventory/GoodsSpec.hs` wired. Follow-up closed 2026-10-17: the report is now stock-aware — `goodsForRestocking :: [Goods] -> [Stock] -> [Goods]` sums on-hand minus reserved across every location and reports a good only when its available quantity is below `gMinStock`. Goods with no minimum policy, inactive goods, and goods at or above their minimum are excluded. 4 tests cover the join, the cross-location sum, the not-below case, and the empty-stock case.
- [x] Close fail-open validators in `Surypus.Validation` (2026-10-12)
  - `validateBillInput` and `validateOrderInput` returned `Right ()` for **every** input — they were inert guards that read as enforced input validation while accepting empty and whitespace-only codes/names. Both now reject empty and blank text (`FieldRequired`), matching the fail-closed shape of their siblings (`validateGoodsInput`, `validateLocationInput`, `validateTaxInput`).
  - `validatePersonInput` took an INN and a KPP and discarded both (`_inn`, `_kpp`), so a malformed identifier passed as long as the name was well-formed. It now validates `Just` INN/KPP through the same `isValidINN`/`isValidKPP` predicates as `validateINN`/`validateKPP` (`Nothing` still means "not supplied").
  - Class guard added to `Surypus.ValidationSpec`: `validators fail closed on blank input` enumerates all 7 text-taking validators and asserts each rejects blank input while accepting well-formed input — so a future validator cannot silently become unconditional. The pair of assertions also proves the guard is not satisfied by over-broad rejection.
  - Verified by direct GHC build+run of the full Test.hs closure: **371 examples, 0 failures, 6 pending** (baseline 360 → 371; +11 new examples).
  - Negative control: the spec compiled against the pre-fix `src/Surypus/Validation.hs` (git HEAD, verified the compile log names the shadow copy) fails exactly the 7 new discriminating tests and nothing else — the 4 valid-input cases still pass.
  - Zero production callers today (`Surypus.Validation` is imported by tests only), so the fix is behaviour-only for the validation contract; the guards are what `docs/TYPES.md`/`AGENTS.md` already document callers doing (`case validateBillInput input of Left err -> ValidationError`), which previously could never produce a `Left`.
- [x] Strengthen System.CacheSpec eviction semantics + isExpired boundary (2026-10-12)
  - The `respects maxSize` test asserted only the resulting size, so an eviction policy keeping the OLDEST entries would pass unchanged — a vacuous-coverage gap in an already-wired spec
  - Added 3 deterministic tests: `evicts the oldest entry when maxSize is exceeded` (a evicted, c survives), `keeps existing entries when overwriting at capacity` (overwrite at maxSize does not grow the cache), `treats an entry expiring exactly now as not expired` (pins strict `now > expiryTime`)
  - Verified by direct GHC build+run of the full Test.hs closure: **374 examples, 0 failures, 6 pending** (baseline 371 → 374; +3 new examples)
  - Negative check: the spec compiled against a shadow `System.Cache` whose `stmCachePut` keeps the oldest entries (shadow dir first in `-i`, compile log verified to name the shadow file) fails exactly the eviction test — 22 examples, 1 failure
- [x] Wire Phase2Phase3.AccountingReadModelSpec into cabal test-suite (2026-10-12)
  - 9 tests over `Infrastructure.EventStore.Accounting` (the typed accounting event stream): AccountCreated projection; debit/credit balance movement; accumulation + double-entry conservation (ledger sums to 0); reconstruct present/unknown account; unprojected accounts get no phantom snapshot; freeze/unfreeze; EntryReverted/EntryCancelled no-op; debit == credit counts twice; JSON roundtrip of all 6 event variants (persistence contract)
  - The spec was stale beyond small fixes — it targeted the removed in-memory `DAL.EventStore` API (`initEventStore`/`createAccountCreatedEvent`/`createJournalEntryEvent`) and 1-arg replay functions; the current `Core.Accounting.ReadModel` entry points are DB-bound. Rewritten against the pure `replayAccountEvents`/`reconstructAccountBalance` layer — no database, fully deterministic
  - Verified by direct GHC build+run of the full Test.hs closure (full `cabal build` still blocked by pre-existing library errors in Surypus.API.BillTemplates et al.): **383 examples, 0 failures, 6 pending** (374 → 383), stable across 3 runs
  - Negative check: shadow `Infrastructure.EventStore.Accounting` whose credit side does not decrement the balance fails exactly the 3 balance-moving tests — 9 examples, 3 failures
  - Follow-up (new): `Core.Accounting.ReadModel.applyJournalEntryPosted` reads `changeAmount` from the event JSON, but the real producer writes `toJSON (JournalEntryPostedEvent …)` with keys `entryId`/`debitAcc`/`creditAcc`/`amount` — the two replay layers disagree on the event-data schema, so replaying real events through `Core.Accounting.ReadModel` treats every journal entry as 0. **CLOSED 2026-10-12** — see the `Core.Accounting.ReadModelSpec` entry below
- [x] Wire Core.Accounting.ReadModelSpec into cabal test-suite + close the event-schema follow-up (2026-10-12)
  - 9 tests over the JSON replay layer `Core.Accounting.ReadModel` (`applyJournalEntryPosted`/`applyEvent` are pure over plain `ES.Event` records — no database needed, unlike the DB-bound `rebuildAccountBalance`/`getAccountReadModel` entry points that blocked wiring this layer before)
  - Bug fixed: `applyJournalEntryPosted` read a top-level `changeAmount` key, but the real producer (`Infrastructure.EventStore.Accounting.appendAccountingEvent`) stores `toJSON (JournalEntryPostedEvent …)` = `{"tag":"JournalEntryPostedEvent","contents":{"jepEntryId":…,"jepDebitAcc":…,"jepCreditAcc":…,"jepAmount":…}}` (probe-verified) — so every real journal entry replayed through `Core.Accounting.ReadModel` as 0.0 balance (the two replay layers disagreed on the event-data schema)
  - Fix: unwrap `contents`, read `jepAmount` (legacy top-level `changeAmount` payloads still honoured), and apply the double-entry sign from `jepDebitAcc`/`jepCreditAcc` vs the model's `armAccountId` — +amount on the debit side, −amount on the credit side, 0 for bystanders — mirroring the already-tested pure layer `Infrastructure.EventStore.Accounting.applyEvent`; contract documented in a module doc comment. `Core.Accounting.ReadModel` has zero production importers (only the two stale specs under TASK-034), so the fix is behaviour-only for the replay contract
  - Tests: debit posts +amount (balance/debitTotal/eventCount), credit posts −amount (creditTotal), bystander untouched, `applyEvent` dispatch by event type, accumulation of multiple entries, double-entry conservation across both sides (asserts both individual movements AND the sum — a sum-only assertion would pass vacuously against the 0.0 bug), legacy `changeAmount` payloads still apply, empty object and non-object payloads apply zero without crashing
  - Verified by direct GHC build+run of the full Test.hs closure (full `cabal build` still blocked by pre-existing library errors in Surypus.API.BillTemplates et al.): **392 examples, 0 failures, 6 pending** (383 → 392), stable across 2 runs — new spec 9/9 green
  - RED→GREEN: the spec failed 5/9 (exactly the producer-shape tests) against the pre-fix source before the fix; negative check against pre-fix `git HEAD` (shadow dir first in `-i`, compile log verified to name the shadow file) fails exactly those 5 tests and nothing else
  - Audit finding (adds to TASK-034): `test/NewtypeGuardsTest.hs` is an orphan — `Surypus.Types` re-exports only `Surypus.Types.{Bill,Payment,Stock,Person,Goods,Auth,Common}`, none of which defines `AccountBalance`/`StockQty` (grep across `src/` finds neither); `TaxRate` exists only in `Finance.Tax` as a `Decimal` newtype and is not re-exported by `Surypus.Types`; the spec's own comments contradict its expected values (`* 50000` vs "/100"). `test/Domain/TypesSpec.hs` is a placeholder tautology (single `True \`shouldBe\` True`). `test/Domain/ProductionSpec.hs` imports the nonexistent `Domain.Production` and constructs an 11-arg `WorkOrder` with `WO_Draft`/`WO_Released` constructors absent from the real `Production.Types.WorkOrder`. `test/Phase2Phase3/AcceptanceSpec.hs` is 11 `Pending` stubs with a `main` and no export list. `test/Integration/PerformanceSpec.hs` imports real modules (`Core.Tax`, `Surypus.JWT`) but every assertion is wall-clock dependent (`latency < 1.0`, `avgLatency < 0.001`, `opsPerSec > 50/1000/10000`) — flaky by construction per the RateLimiter de-flake lesson; needs a deterministic rewrite before wiring. Also: `Core.Accounting.ReadModel.applyAccountCreated` ignores the producer's `acCode`/`acName`/`acType` (always sets them to `Nothing`) — same schema-mismatch family, deliberately out of scope this run — **CLOSED 2026-10-13, see the entry below**
- [x] Strengthen Core.Accounting.ReadModelSpec: close the applyAccountCreated schema-mismatch follow-up (2026-10-13)
  - Bug fixed: `applyAccountCreated` discarded the producer's payload and always set `armCode`/`armName` to `Nothing`, so a replayed account read model carried no identity — the same schema-mismatch family as `applyJournalEntryPosted`. The real producer stores `toJSON (AccountCreatedEvent ev)` = `{"tag":"AccountCreatedEvent","contents":{"acAccountId":…,"acCode":…,"acName":…,"acType":…,"acParentId":…,"acTimestamp":…}}` (probe-verified with a standalone GHC program; the recorded prose said the keys were `acCode`/`acName`/`acType`, which the probe confirmed)
  - Fix: extract the `contents`-unwrap into the shared `unwrappedFields` helper (now used by both `applyJournalEntryPosted` and `applyAccountCreated` — behaviour identical for the former), read `acCode`/`acName` from it, legacy flat payloads still honoured; contract documented in a module doc comment. `armAccountType` deliberately stays `Nothing`: the producer's `acType` is a Text category ("asset"/"liability") while the read model expects an Int account-type id and no mapping exists anywhere in the codebase — inventing one would fabricate data (a test pins this decision). Same for `armCurrencyId` (the producer event has no currency field). Defining the Text→Int mapping is a follow-up
  - Side fix: the working tree of `src/Core/Accounting/ReadModel.hs` contained a broken uncommitted WIP hunk in `mkInitialModel` (case arms with the record braces left dangling — the file did not parse, so ANY build touching the module failed and the first run silently executed a stale binary). Completed the hunk minimally preserving its intent (explicit `error` on an empty event list instead of a `head` crash); the only caller already rejects the empty case, so it is defence in depth
  - Tests (+6): code+name applied from a real producer-shaped event; balance state/timestamps reset on AccountCreated; dispatch through `applyEvent`; legacy flat payloads still apply; no identity keys → `Nothing`; account type/currency not fabricated from the Text `acType`. Spec helper `mkCreatedEvent` sets `eventAggregateId` from the account id, matching the real producer (`getEventInfo` returns `(acAccountId ev, "account", "AccountCreated")`)
  - Verified by direct GHC build+run of the full Test.hs closure: **398 examples, 0 failures, 6 pending** (392 → 398), stable across 2 runs. Negative check: shadow `Core.Accounting.ReadModel` with ONLY `applyAccountCreated` reverted to the always-`Nothing` version (shadow dir first in `-i`, compile log verified to name the shadow file) fails exactly the 3 code/name-asserting tests and nothing else — the 9 JournalEntryPosted tests still pass, so the check isolates this fix. `Core.Accounting.ReadModel` has zero production importers — behaviour-only fix
- [x] Strengthen Core.Accounting.ReadModelSpec: pin the BalanceAdjusted contract and close the last recorded follow-up (2026-10-13)
  - Follow-up closed: `applyBalanceAdjusted` was the last recorded schema-mismatch family item from the Core.Accounting.ReadModel wiring. Grep across `src/`+`test/` confirms no producer writes a `BalanceAdjusted` variant (`AccountingEvent` has 6 constructors, none of them BalanceAdjusted), so the keys it reads are the documented contract for a future writer, not a live schema — no production behaviour changes
  - Real bug fixed: `bsCurrentBalance = fromMaybe 0.0 newBalance` zeroed the balance whenever a payload carried `changeAmount` but no `newBalance` (a partial payload destroyed the live balance instead of adjusting it). Now: `changeAmount` is applied RELATIVE to the old balance and drives the debit/credit totals (same sign convention as `applyJournalEntryPosted`); `newBalance`, when present, overrides the current balance absolutely. Consistency fix: the applier read a flat payload only while both other appliers go through the shared `unwrappedFields` helper — a tagged-union `BalanceAdjusted` event (the shape any future producer would write, per `appendAccountingEvent`) was read as empty and also zeroed the balance; now both payload shapes are honoured
  - Tests (+7): `changeAmount` relative to old balance (400+250=650, debit total 500+250); negative `changeAmount` to the credit total; `newBalance` absolute set; `newBalance` overrides `changeAmount` for the balance while `changeAmount` still drives the totals; tagged-union payload unwrapped; no adjustment keys → balance unchanged, event count/timestamp still advanced; dispatch through `applyEvent`
  - Verified by direct GHC build+run of the full Test.hs closure: **405 examples, 0 failures, 6 pending** (398 → 405). Negative check: shadow `Core.Accounting.ReadModel` with ONLY `applyBalanceAdjusted` reverted to the git HEAD version (shadow dir first in `-i`, compile log verified to name the shadow file) fails exactly the 5 discriminating tests (relative changeAmount, negative changeAmount, tagged-union, no-keys, dispatch — all zero the balance pre-fix); the 2 `newBalance`-shape tests pass on both sides by design (they pin the absolute-override semantics, which the pre-fix code already had)
- [x] Fix System.Sequence: nextNumber ignored the configured seqStep (2026-10-13)
  - Bug fixed: the `Sequence` record carries a `seqStep` field, but `nextNumber` hardcoded `seqLastNum + 1` and never read it — a sequence configured with step 5 produced 1, 2, 3… instead of 5, 10, 15…. `seqFlags` has no defined bits anywhere in the codebase and is deliberately ignored (documented in the module doc comment). `nextNumber` has zero production callers (grep across `src/`+`test/`: the spec is the only importer — same situation as the System.RateLimiter lbCheck fix), so the fix is behaviour-only for any future DB-backed sequence row
  - Fix: `nextNumber s = seqPrefix s <> show (seqLastNum s + seqStep s) <> seqSuffix s`; the step is applied as-is and may be negative (decrement), zero yields no movement — both pinned by tests; contract documented in the doc comment
  - Tests (+7): 6 unit (step 5 from 0 → DOC-5; step 10 from 42 → DOC-52; negative step -3 → DOC-7; zero step → no movement; step applied before prefix/suffix concatenation; step 1 = default increment) + 1 property (numeric part == last + step across steps [-5,-1,0,1,2,3,5,100], 100 cases)
  - Verified by direct GHC build+run of the full Test.hs closure: **412 examples, 0 failures, 6 pending** (405 → 412), stable across 3 runs. Negative check: shadow `System.Sequence` reverted to the always-+1 git HEAD version (shadow dir first in `-i`, compile log verified to name the shadow file) fails exactly the 5 step-discriminating unit tests + the step property (6 of 23 examples); all 17 pre-existing tests pass on both sides
- [x] Wire Surypus.RBAC.StoreSpec + fix removeGrant and audit-sink defects (2026-10-13)
  - First coverage for `Surypus.RBAC.Store` (IORef-backed, pure IO — no DB needed); the module sits on the TASK-019 critical path (real RBAC store) and had zero tests. Only pre-existing importer: the stale `test/RBACSpec.hs` (not wired, TASK-034), so both fixes are behaviour-only until a DB-backed store lands
  - Real bug 1: `removeGrant` matched on the principal pair only (`pgFrom g == _from && pgTo g == _to`) and discarded its `_grant` argument — revoking one grant of a pair silently revoked ALL grants between the same principals, whatever their permission or expiry. Fix: a stored grant is removed only when its pair matches AND it equals the passed grant (identity revocation; `from`/`to` stay as an explicit scope guard). Same "argument defined but never read" family as the System.Sequence `seqStep` bug
  - Real bug 2: `newRBACStore` accepted an audit callback and threw it away (`_auditCallback`); `writeAuditEntry` only appended to the in-memory log, so the external audit sink was dead code — an audit trail reaching nothing but RAM. Fix: the callback is carried in `RBACStore` and invoked synchronously for every entry after it is logged
  - Tests (+24): roles (empty start, upsert add, same-name replace without duplicates, delete, unknown-name no-op), grants (newest-first prepend, exact-grant revocation, unknown-grant no-op, other pairs untouched), `activeDelegations` (delegator match, recipient match, non-party excluded, expired excluded, expiry==now kept — boundary inclusive, no-expiry kept, `Nothing` = all active grants, `Nothing` still excludes expired), `cleanupExpiredGrants` (removed count + remaining set, expiry==now kept, nothing-expired no-op), audit (newest-first log, sink invoked for every entry, keep-latest-N with removed count, default limit 1000)
  - Verified by direct GHC build+run of the full Test.hs closure: **436 examples, 0 failures, 6 pending** (412 → 436), stable across 2 runs. Negative check: spec compiled against the git HEAD `Surypus.RBAC.Store` (shadow dir first in `-i`, compile log verified to name the shadow file) fails exactly the 3 discriminating tests (exact-grant revocation, unknown-grant no-op — both facets of the pair-only matcher — and the audit-sink invocation); the other 21 tests pass on both sides, so the check isolates the two fixes
- [x] Wire Inventory.OperationsSpec into cabal test-suite (2026-10-13)
  - First coverage for `Inventory.Operations` (pure, exposed, labelled "with Formal Verification"; zero tests and zero importers in `src/`+`test/` before this run)
  - 26 tests: `validateStockOperation` (positive/zero/negative); `processReceipt` (positive into empty balance, positive onto existing balance, zero, negative); `processIssue` (available, exactly the available quantity — boundary, over-available, empty balance, zero, negative); `processTransfer` (source holds it, exactly the source quantity — boundary, over-source, zero, negative, destination quantity does not affect validity); `checkNegativeStock` (strictly-negative only — `qty == 0` excluded, healthy list, empty list); `recalculateBalance` (no lots → 0, sums lot quantities, non-negativity when every lot is non-negative — the module's documented theorem, property over the existing `Arbitrary Lot` instance); class guard: all 4 quantity-taking validators fail closed on qty 0 and −1 and accept qty 5 (same shape as the TASK-035 guard)
  - No latent bug found — the discarded parameters (`_current` and the third argument of `processReceipt`, `_toStock` of `processTransfer`) are legitimately irrelevant to validity (the module defines no capacity concept anywhere); the spec pins that decision rather than inventing capacity semantics
  - Verified by direct GHC build+run of the full Test.hs closure (full `cabal build` still blocked by pre-existing library errors in Surypus.API.BillTemplates et al.): **462 examples, 0 failures, 6 pending** (436 → 462)
  - Negative checks (shadow dirs first in `-i`, compile logs verified to name the shadow files): shadow `validateStockOperation` with the off-by-one `qty < 0` guard fails exactly the zero-rejection example + the class guard (26 examples, 2 failures); shadow `processIssue` without the `qty > current` guard fails exactly the 2 insufficient-stock examples (26 examples, 2 failures)
- [x] Wire Service.WorkflowEngineSpec into cabal test-suite (2026-10-13)
  - First coverage for `Service.WorkflowEngine` (TVar/IO orchestration engine, no DB; zero tests and zero importers in `src/`+`test/` before this run)
  - Real stub fixed: `createWorkflowInstance` discarded the engine, workflow id and description and returned the constant `"stub-instance-id"` without registering anything — `executeWorkflowStep`/`getInstanceStatus`/`cancelWorkflowInstance`/`listWorkflowInstances` could never reach an instance (every execute returned "Instance not found"), so the "full orchestration" the module header advertises was unreachable. Now the instance is registered: id `workflowId <> "-inst-" <> uuid` (unique, traceable), state `InstanceDraft`, step counter 0
  - Decisions pinned (no semantics invented): `desc` is not stored (the engine's `WorkflowInstance` has no description field — a `Workflow` keeps its definition in the `wfDefinition` JSON); `instanceSteps` is empty because nothing registers workflows into `engineWorkflows` (no `addWorkflow` export, `Workflow` has no step list), so a step-less instance completes on its first `executeWorkflowStep`; `WorkflowConfig` is not consulted (creation cannot fail — `IO Text` has no error channel)
  - 12 tests: create→draft registration, unique workflow-traceable ids, description irrelevance, per-workflow id prefixes, unknown-instance rejection, step-less completion, completed-instance rejection, cancelled-instance rejection, cancel removal, cancel no-op, fresh-engine empty list, listing created instance with state
  - Verified by direct GHC build+run of the full Test.hs closure (full `cabal build` still blocked by pre-existing library errors in Surypus.API.BillTemplates et al.): **474 examples, 0 failures, 6 pending** (462 → 474), stable across 4 runs. Negative check: spec compiled against the git HEAD stub `createWorkflowInstance` (shadow dir first in `-i`, compile log verified to name the shadow file) fails exactly the 7 create-registration-discriminating tests; the 5 lifecycle tests that also hold under the stub (unknown instance, cancelled-as-not-found, cancel no-op/removal, fresh engine) pass on both sides, so the check isolates the fix
- [x] Wire System.MetricsCollectorSpec into cabal test-suite + fix NaN average (2026-10-13)
  - First coverage for `System.MetricsCollector` (TVar/IO metrics store, no DB; zero tests in `test/` before this run). The module is exposed but has no production importers — the identically-named `recordMetric`/`aggregateMetrics` in `System.Monitoring`, `System.MetricsExport` and `Integration.Hub.Integration` are unrelated local functions, so the fix is behaviour-only for any future caller
  - Real latent bug fixed: `aggregateMetrics points "avg"` computed `sum / length` unconditionally, so an empty series returned `Right NaN` (probe-verified). NaN compares false against everything, so every `avg < threshold` alert would silently never fire — a fail-silent monitor. Now `avg` rejects an empty series with `Left "Cannot compute avg over an empty metric series"`; `sum`/`count` remain total over the empty series (0), which is well-defined. Documented in the module doc comment
  - Determinism rule established for this module: `recordMetric` stamps each point with `getCurrentTime`, so any assertion about WHICH points survive a range filter or a cleanup cannot be driven through it without depending on wall-clock deltas (the same flaky family as the RateLimiter de-flake). Tests therefore seed the exported `metricsStore` TVar with controlled timestamps via a `seed` helper and query with a `wideRange` anchored at a fixed 2026-01-01 base; `recordMetric` is exercised only for its own effect (a point is appended, carrying the given value and tags) and those four tests use an `alwaysRange` (2000–2100) window, since a `baseTime` window can never contain a wall-clock-stamped point
  - 30 tests: recordMetric (value, tags, accumulation, name separation); queryMetrics (unknown name, inside range, after/before range, exactly on each boundary — pins the inclusive `>= from && <= to` filter, multi-point selection in store order); aggregateMetrics (avg/sum/count on non-empty series, unknown-operation rejection, sum=0 and count=0 on empty series, avg rejects empty series, never-NaN property, sum-matches-fold property, count-matches-length property); cleanupOldMetrics (drops a point exactly on the cutoff — pins the strict `> cutoff` keep rule, keeps a strictly-newer point, removes all when the cutoff is past them, keeps all when the cutoff precedes them, leaves other metric names untouched); exportMetrics (stub returning `Right 0`)
  - Pinned decision: `MapConfig`'s `retentionHours`/`flushIntervalSec` are never read anywhere in `src/`+`test/` — `cleanupOldMetrics` takes its cutoff as an explicit argument, so retention is the caller's policy, not the config's. No semantics invented; `exportMetrics` stays a documented stub
  - Verified by direct GHC build+run of the full Test.hs closure (full `cabal build` still blocked by pre-existing library errors in Surypus.API.BillTemplates et al.): **502 examples, 0 failures, 6 pending** (474 → 502), stable across 3 runs. Negative check: spec compiled against the git HEAD `aggregateMetrics` (shadow dir first in `-i`, compile log verified to name the shadow file) fails exactly the 2 NaN-discriminating tests — `rejects avg over an empty series instead of returning NaN` and the `never yields a NaN average` property
  - Compile errors fixed while wiring: `MetricCollector` vs the real `MetricsCollector` type name (import + signature); `MetricPoint` has no `Show`/`Eq` instance so `points \`shouldBe\` []` does not typecheck → compare `map pointValue points`; a `where` clause cannot attach to an `it` inside a `do` block (parse error) → inline the `isNaN` predicate
- [x] TASK-036: `Inventory.Unit.convertUnit` had two defects, both now fixed and
  covered by real assertions instead of the 5 pending placeholders:
  (1) base→derived divided by `uRatio from` (the base unit's ratio, always 1) instead
  of `uRatio to`, so 5000 m → 5000 "km"; (2) same-unit conversion returned Nothing
  because both guards required a `baseId` link. Also added the missing
  derived→derived path for units sharing a base (1 km → 10 hm). Verified:
  **783 examples, 0 failures, 0 pending**.
- [x] TASK-034: 26 orphaned/stale spec files: 12 import non-existent modules (`Domain.*`, `CRM.Contact/Company/Deal/Activity/Pipeline`, `Core.Document.Types`, `Domain.Document`, `DAL.Fixtures`) — restore or delete; `Phase2Phase3/AccountingEventStoreSpec.hs` + `Phase2Phase3/ReadModelCacheSpec.hs` target the removed in-memory `DAL.EventStore` API — rewrite against the PostgreSQL-backed EventStore or delete; `DAL/TypesSpec.hs` is stale against `DAL.Types` (nonexistent `PersonInput`/`GoodsInput`/`Stock`/`SortDir`/`PaginatedResult`/`DashboardStats`/`*Filter` types, wrong field names, wrong `Bill` arg types) — rewrite before wiring; plus (audit 2026-10-12): `DB/RepositoriesSpec.hs` + `Integration/PoolSpec.hs` (missing `DB.Connection`), `API/{Health,Swagger,Procurement,RBAC}Spec.hs` (missing `App`), `API/ServerV2Spec.hs` (module-name collision), `RBACSpec.hs` (stale thin RBAC API), `DAL/DBSpec.hs` (stale `DAL.DB` API), `DAL/IntegrationSpec.hs` (missing `Test.DAL.Fixtures`), `DAL/EventStoreSpec.hs` (now wired via `DAL.EventStoreIntegration`, which pends without `SURYPUS_TEST_DATABASE_URL`); placeholder-only specs (zero coverage, decide keep-or-delete): `Integration/{Crud,Negative,Property,InventoryLifecycle}Spec.hs`, `API/ServerSpec.hs`, `BridgeSpec.hs`, `SurypusSpec.hs`; plus (audit 2026-10-12, second pass): `NewtypeGuardsTest.hs` (orphan — `AccountBalance`/`StockQty` undefined anywhere in `src/`, `TaxRate` only in `Finance.Tax` and not re-exported by `Surypus.Types`; comments contradict expected values), `Domain/TypesSpec.hs` (placeholder tautology), `Domain/ProductionSpec.hs` (orphan import `Domain.Production`, stale 11-arg `WorkOrder`), `Phase2Phase3/AcceptanceSpec.hs` (11 `Pending` stubs), `Integration/PerformanceSpec.hs` (all assertions wall-clock dependent — needs deterministic rewrite). Follow-up closed 2026-10-13: `applyAccountCreated` now reads the producer's `acCode`/`acName` (see the entry above); the remaining decision is the Text→Int account-type mapping, which no code defines yet.
- [x] Wire System.RetrySpec into cabal test-suite (2026-10-13)
  - First coverage for `System.Retry` (pure, exposed, no DB; zero tests and zero importers in `src/`+`test/` before this run)
  - 17 tests: withRetries (first-attempt success, all-attempts-failure with correct error count, maxAttempts=0 immediate failure, success after N failures, success after 1 failure); withRetriesDelays (first-attempt success, success after delays, all-delays-exhausted failure, empty-delays-list failure); untilSuccessWithTimeout (success, success after failures, all-attempts failure, attempts=0 immediate failure); all 4 retry strategies (FixedDelay, ExponentialBackoff, LinearBackoff, Jitter) succeed after multiple failures
  - No latent bug found
  - Verified by direct GHC build+run of the full Test.hs closure (full `cabal build` still blocked by pre-existing library errors in Surypus.API.BillTemplates et al.): **519 examples, 0 failures, 6 pending** (502 → 519)
- [x] Wire Commerce.PriceSpec into cabal test-suite + fix negative-price clamp and two divide-by-zero guards (2026-10-13)
  - First coverage for `Commerce.Price` (pure pricing/discount/quotation layer, exposed; zero tests and zero importers in `src/`+`test/` before this run — the `Commerce.Price*` siblings are unrelated modules that do not import it)
  - Three real bugs fixed, all fail-silent value corruptions: `applyDiscount`'s percentage branch was unclamped (`price * (1 - dValue/100)`) while the absolute branch clamps, so a discount over 100% returned a negative price — and `calcFinalPrice` applies discounts WITHOUT validating them (it only filters on `dMinSum`, never calls `validateDiscount`), so that negative price reached the final bill; `convertCurrency` divided by `rateTo` unconditionally, so a missing (zero) exchange rate yielded `Infinity`, or `NaN` when the numerator was zero too; `priceWithoutVAT` divided by `1 + vatRate/100` unconditionally, so a −100% rate yielded `Infinity`. Infinity/NaN compare false against everything, so every downstream total, threshold or `validatePrice` check misbehaves silently
  - Fixes: clamp the percentage branch at zero (matching the absolute branch); guard both divisions and return the price unchanged when the divisor is zero — a zero rate means "no conversion", which is what a zero-VAT document means. Contract documented in the module doc comments
  - 41 tests: applyDiscount (percentage/absolute, both branches clamped at zero, discount equal to the price, zero discount, never-negative-and-never-exceeds-original property); calcDiscountPercent (normal, no discount, zero original, negative original); roundPrice (precision 2 and 0, negative amount); convertCurrency (rates, identity, zero target rate, zero/zero → NaN, never-non-finite property); priceWithVAT (rate added, zero rate); priceWithoutVAT (rate stripped, inverse-of-priceWithVAT property, −100% rate, never-non-finite property); findBestQuot (cheapest, empty list, window not started, window expired, both boundary dates exactly today — inclusive, open-ended quotation, below-minimum-quantity filtering, cheapest among the quantity-eligible); calcFinalPrice (all applicable discounts + 2-decimal rounding, `dMinSum` filtering, no discounts, never-negative); validatePrice/validateDiscount/validateQuot (positive/zero/negative, percentage within 0..100, absolute ≥ 0) + a class guard asserting each validator accepts a well-formed value
  - **Coverage-gap lesson**: the never-negative property initially used the default `Double` generator and PASSED against the pre-fix module — QuickCheck's default `Double` distribution concentrates on small magnitudes, so a percentage over 100 was almost never drawn and the property was vacuous against exactly the bug it was meant to catch. The generator is now bounded (`choose (0, 500)` for the percentage value, `choose (0, 5000)` for the absolute value, base `choose (0, 1e6)`) so the discriminating branch is exercised on every run. Same vacuous-coverage family as the System.Cache eviction test
  - Compile errors fixed while wiring: missing `OverloadedStrings` (`Discount`'s `dCode`/`dName` are `Text`, so string literals did not typecheck); an unannotated QuickCheck variable defaulting to `Integer` where `Double` was required in the class guard
  - Verified by direct GHC build+run of the full Test.hs closure (full `cabal build` still blocked by pre-existing library errors in Surypus.API.BillTemplates et al.): **560 examples, 0 failures, 6 pending** (519 → 560), stable across 4 runs. Negative check: the spec compiled against the git HEAD `Commerce.Price` (shadow dir first in `-i`, compile log verified to name the shadow file) fails exactly 5 examples — the clamp test, the never-negative property, and the 3 non-finite-result tests — while the other 36 pass on both sides
- [x] Wire System.CircuitBreakerSpec into cabal test-suite (2026-10-14)
  - First coverage for `System.CircuitBreaker` (pure, TVar/IO-based, no DB; zero tests and zero importers in `src/`+`test/` before this run)
  - 17 tests: initCircuitBreaker (closed start); executeWithCircuitBreaker (success returns Right and stays closed, failure returns Left with error text, opens after failureThresholdCount failures, returns Left "Circuit open" when open, transitions to half-open when resetTimeoutSec elapses, closes on half-open success, re-opens on half-open failure, tracks metrics on success/failure, computes failure rate, does not execute action when open); resetCircuitBreaker (resets to closed, clears failures, resets metrics); disabled state (returns Left, does not execute)
  - Test config uses `resetTimeoutSec = 0` for immediate half-open transition and `resetTimeoutSec = 1` for threshold-triggering tests (a zero window filters older failures from the threshold check)
  - Verified by direct GHC build+run of the full Test.hs closure: **577 examples, 0 failures, 6 pending** (560 → 577)
- [x] Wire Commerce.DiscountSpec into cabal test-suite (2026-10-15)
  - First coverage for `Commerce.Discount` (pure, no DB; zero importers in `src/`+`test/` before this run — behaviour-only module)
  - 13 tests (9 unit + 4 QuickCheck properties): calcDiscount with DTPercent (amount ≥ minAmount → amount × value / 100; amount < minAmount → 0), DTFixed (amount ≥ minAmount → fixed value, independent of amount; amount < minAmount → 0), DTConditional (same formula as DTPercent), boundary (amount == minAmount → discount applied, inclusive ≥), zero-value (all types → 0), prop_discountAmountNonNeg (never negative), DTFixed result == dscValue (property), DTPercent result == amount × value / 100 (property), all-types amount < minAmount → 0 (property)
  - Added `instance Arbitrary DiscountType` (the module exports one for Discount but not its sibling type)
  - No latent bug found — `calcDiscount` is a simple, correct 3-branch function. The 0-importer status means any future caller gets a tested contract.
  - Verified by direct GHC build+run of the full Test.hs closure: **590 examples, 0 failures, 6 pending** (577 → 590)
- [x] Fix System.ValidationSpec QuickCheck generators — ValidEmail and NonBlankText produced values the validators rejected, causing "Gave up after N tests" failures; now generate only valid inputs (2026-10-15)
  - Root cause: `ValidEmail` used `arbitrary :: Gen Char` which produces arbitrary Unicode characters; `NonBlankText` filtered only spaces/tabs but `T.strip` removes all whitespace — both generators could produce values that fail validation
  - Fix: `ValidEmail` now uses `listOf1 (elements (['a'..'z'] ++ ['0'..'9']))` for user/domain and `listOf1 (elements ['a'..'z'])` for TLD; `NonBlankText` uses `listOf1 (elements (['a'..'z'] ++ ['A'..'Z'] ++ ['0'..'9']))` — both produce only values the validators accept
  - Removed unused `import Test.QuickCheck (NonEmptyList (..))` (no longer needed)
  - Verified by `cabal test`: **589 examples, 0 failures** (was 589 examples, 2 failures)
- [x] Wire Core.TaxSpec into cabal test-suite (2026-10-15)
  - First coverage for `Core.Tax` (pure, exposed, 63 lines, 0 importers in `src/`+`test/` before this run — behaviour-only module)
  - 31 tests (24 unit + 7 QuickCheck properties): mkTaxBracket (valid, negative rate, rate > 1.0, negative threshold, rate 0.0, rate 1.0); applyTax (simple, zero rate, full rate, negative rate, rate > 1.0, negative base, zero base, fractional); applyTaxInclusive (extract, zero rate, rate 1.0, negative rate, rate > 1.0, negative gross, zero gross); totalTax (multiple brackets, empty, invalid rates filtered, zero base); properties (non-negativity, boundedness, inclusive extraction, totalTax sum consistency)
  - No latent bug found — `Core.Tax` is a simple, correct 4-function module. The 0-importer status means any future caller gets a tested contract.
  - Verified by direct GHC build+run of the full Test.hs closure: **620 examples, 0 failures, 6 pending** (589 → 620)
- [x] Wire Commerce.CashSessionTempSpec into cabal test-suite (2026-10-15)
  - First coverage for `Commerce.CashSessionTemp` (pure, exposed, 78 lines, 0 importers in `src/`+`test/` before this run — behaviour-only module)
  - 19 tests (16 unit + 3 QuickCheck properties): emptyTempCashCheck (empty check, zero amounts, valid); mkTempCheckLine (accepts amount >= discount, rejects amount < discount, boundary amount == discount, zero/zero); addTempCheckLine + totalAmount (single line, multiple lines, accumulation); totalDiscount (single, multiple); netAmount (empty, single line, multiple lines, consistency with totalAmount - totalDiscount); verifyCheck (empty, valid check); properties (netAmount never negative, totalAmount >= totalDiscount invariant, adding a line increases totalAmount by the line amount)
  - Module exports types without record constructors (opaque) — spec uses only exported functions, no field access
  - No latent bug found — `Commerce.CashSessionTemp` is a simple, correct module. The 0-importer status means any future caller gets a tested contract.
  - Verified: **639 examples, 0 failures, 6 pending** (620 → 639)
- [x] Wire Core.OptimizationSpec into cabal test-suite (2026-10-15)
  - First coverage for `Core.Optimization` (pure, exposed, 78 lines, 0 importers in `src/`+`test/` before this run — behaviour-only module)
  - 23 tests (17 unit + 6 QuickCheck properties): evaluateObjective (dot product, missing variables treated as zero, empty variable map, empty objective coefficients, extra variables ignored, Σi² property); checkConstraint (Leq/Geq/Eq accept/reject/boundary, missing variables as zero, LHS-matches-evaluateObjective property); optimize (converged when all constraints satisfied, non-converged when violated, empty variable map, ALL constraints must pass, empty constraint list, converged⟺allSat property); defOptimizationState (zero initialization, variable map preservation)
  - Exported `defOptimizationState` from `Core.Optimization` (was missing from the export list; zero production callers, no behaviour change)
  - No latent bug found — `Core.Optimization` is a correct 4-function module. The 0-importer status means any future caller gets a tested contract.
  - Verified: **662 examples, 0 failures, 6 pending** (639 → 662)

### DevOps
- [x] Add Docker configuration
- [x] Add CI/CD pipeline
- [x] Add database migrations (flyway/schema migrations)
- [x] Add health check endpoints
- [x] Add metrics (Prometheus)

---

## Phase 2 — Accounts & Journal Entries (ACID)

### Epic: US-2 Login & RBAC
- [x] US-2-1: Login and RBAC (P1, 3SP) — JWT auth with roles/permissions; 200 + token; RBAC per request
- [x] US-2-5: RBAC negative test (P2, 2SP) — non-authorized user gets 403 Forbidden
- [x] US-2-7: OpenAPI Docs (P3, 2SP) — /docs or /swagger.json available and valid
- [x] US-2-6: Health & Readiness (P2, 2SP) — 200 OK with status fields

### Epic: US-2 Account Management
- [x] US-2-2: Create Account (P1, 5SP) — 201 Created; code unique; stored with timestamps
- [x] US-2-3: Read Accounts (P2, 3SP) — 200; accounts contain created account; code unique

### Epic: US-2 Journal & Read Models
- [x] US-2-4: Create Journal Entry (P1, 5SP) — 201 Created; balance updated 5-10s; validates account exists
- [x] US-2-8: Read model account_balances (P2, 5SP) — API reads balances; updates within 5-10s
- [x] US-2-9: Read model ledger_projection (P2, 5SP) — correct totals per account per period
- [x] US-2-10: Dashboard endpoint (P2, 3SP) — /api/v1/dashboard: revenue, stockValue, pendingPayments
- [x] US-2-11: Read-model caching (P2, 3SP) — in-memory TTL 5-10s; cache hits reduce DB load
- [x] US-2-12: Phase 2 Integration tests (P2, 5SP) — all phase-2 tests pass in CI

---

## Phase 3 — Event Sourcing, Redis, GraphQL, WebSocket

### Epic: US-3 Event Sourcing
- [x] US-3-1: Accounts Event Store (P1, 8SP) — accounting_events table; append-only events; replay utility
- [x] US-3-2: Account read-model replay (P1, 5SP) — rebuild balances from event stream

### Epic: US-3 Infrastructure
- [x] US-3-3: Read models Redis cache (P2, 5SP) — Redis TTL cache (5s) wired into the read model; Redis Streams for events still open
- [x] US-3-5: Redis Queue (P3, 5SP) — Redis/Bull for background tasks; retry on failure

### Epic: US-3 API Gateway
- [x] US-3-4: GraphQL Proxy (P2, 5SP) — /graphql returns data consistent with REST; no direct DB access
- [x] US-3-6: WebSocket real-time (P3, 5SP) — WebSocket broadcasts events when keys change
- [x] US-3-7: Proxy usage and client migration plan (P3, 3SP) — GraphQL client integration plan (docs/GRAPHQL_MIGRATION.md)

---

## High Priority

- [x] Add proper parameterized queries instead of string interpolation (security)
- [x] Add filter parameters to paginated queries (connect filter types)
- [x] Add sorting parameters to paginated queries
- [x] Add bill lines endpoint (GET /bills/:id/lines)
- [x] Add order lines endpoint (GET /orders/:id/lines)
- [x] Add sales summary endpoint (GET /sales/summary)
- [x] Add inventory documents endpoint (GET /inventory)
- [x] Implement real dashboard stats from database
- [x] Add JWT authentication middleware to protect endpoints
- [x] Implement login endpoint with JWT token generation
- [x] Add request logging middleware
- [x] Add payments endpoint (GET /payments, GET /bills/:id/payments)
- [x] Add units endpoint (GET /units)
- [x] Add document types endpoint (GET /document-types)
- [x] Add stock summary endpoint (GET /stock/summary)
- [x] Add RBAC types and roles endpoint (GET /roles)
- [x] Implement repository pattern for DAL layer
- [x] Add report generation with JasperReports integration

## Medium Priority

- [x] Add BillLineInput FromJSON instance
- [x] Add PUT/DELETE endpoints for bills and orders
- [x] Add goods prices CRUD endpoints
- [x] Add taxes CRUD endpoints
- [x] Add currencies CRUD endpoints
- [x] Implement API versioning strategy

## Low Priority

- [x] Run hlint and fix warnings
- [x] Add hlint to CI pipeline
- [x] Add pgformatter for SQL formatting

---

## Database Migrations (B1)

- [x] B1-1: Schema columns aligned with procedures.sql
- [x] B1-2: V009__rbac_store.sql — RBAC tables created
- [x] B1-3: V010__production.sql — Production tables created
- [x] B1-4: procedures.sql — Business procedures added
- [x] B1-5: init_db.sh — Order fixed, no hardcoded references

---

## Documentation (B10)

- [x] B10-1: CHANGELOG.md updated with [0.2.0.0] section
- [x] B10-2: AGENTS.md updated with Service Layer, Database Migrations, Job Types
- [x] B10-3: docs/engineering/api-conventions.md created
- [x] B10-4: docs/engineering/testing-guide.md created

---

## New Development Tasks

### Business Logic
- [x] Add multi-currency support
- [x] Add import/export functionality (CSV, Excel)
- [x] Add barcode scanning support (see src/Surypus/RBAC.hs for barcode validation)
- [x] Add email notifications (Core.Notification module)
- [x] Multi-tenancy infrastructure (DAL.Repository.User, Surypus.Tenant)

### API Development
- [x] API versioning strategy implemented
- [x] GraphQL API support (placeholder in Surypus.API.GraphQL)
- [x] WebSocket real-time updates (Surypus.WebSocket)
- [x] Rate limiting improvements (Surypus.API.RateLimit)

### Infrastructure
- [x] Add Prometheus metrics
- [x] Add database migrations (flyway)
- [x] Add integration tests (test/Integration/)
- [x] Add performance/load tests (test/Integration/PerformanceSpec.hs)
- [x] Event Store DB integration (DAL.EventStore)
- [x] Multi-tenancy infrastructure (DAL.Repository.User, Surypus.Tenant)

### Code Quality Tools
#### Haskell (hlint)
- [x] Fix hlint warnings (from ~2951 to 0)
- [x] Add hlint to CI pipeline
- [x] Configure hlint rules in .hlint.yaml
#### SQL (pgformatter)
- [x] Format SQL files in config/
- [x] Add pre-commit hook for SQL formatting
- [x] Add pgformatter to CI pipeline

---

## Frontend Development

### Web Interface
- [x] Expand web/index.html with more pages (Accounting, Payroll, Stock, Locations, Reports)
- [x] Add charts and visualizations
- [x] Add modals for data entry
- [x] Add filter and pagination UI

### Mobile Web Interface
- [x] Expand mobile.html with more pages
- [x] Add responsive design features

### QML Desktop Interface
- [x] Expand Components.qml with reusable components
- [x] Expand Main.qml with dashboard and pages
- [x] Expand main.qml with full application features
- [x] Add CRUD dialogs for entities

---

## Cache Implementation

- [x] Implement functional Core.Accounting.Cache with STM + LRU eviction (2026-10-09)
  - Replaced stub with thread-safe STMCache-backed implementation
  - mkReadModelCache: creates bounded cache with hit/miss statistics
  - getCachedBalance: returns 0.0 on miss, cached value on hit
  - putCachedBalance: inserts/updates entry with LRU eviction at maxSize
  - invalidateCache: removes single entry
  - clearCache: clears all entries
  - cacheStats: tracks hits, misses, and current size
  - Added Core.Accounting.CacheSpec with 15 tests (12 unit + 3 property-based)
  - All 15 cache tests passing

- [x] Make the PostgreSQL event store actually round-trip (US-3-1) (2026-10-16)
  - `DAL.EventStore` was dead code that could never work: `appendEvent` stored
    `show` output (`String "x"`) into a jsonb column instead of JSON, and
    `getEvents`/`getEventsFrom`/`getLatestSnapshot` declared one `Single
    PersistValue` per row while selecting 10-11 columns, so Persistent never
    produced a usable row and `parseEvent` discarded the value entirely.
  - Rewrote the row handling with a 10-column `RawSql` tuple, real JSON encode
    on write, and JSON decode on read. `jsonb` comes back as `PersistByteString`,
    which `persistToText` now decodes instead of dropping.
  - Fixed the snapshot SQL: the table is `event_snapshot` with
    `last_sequence_number`, not `event_snapshots`/`last_seq`.
  - Fixed the migration collision that made the CQRS schema unreachable:
    `V014__event_store.sql` created a *legacy* `event_store` (id, event_name,
    payload), so `V1000`'s `CREATE TABLE IF NOT EXISTS` was silently skipped.
    The legacy log is now `legacy_event_store`, and `V1006__event_store_reconcile.sql`
    renames any pre-existing legacy table on upgraded databases.
  - Wired `DAL.EventStoreSpec` into the suite through `DAL.EventStoreIntegration`
    (pends without `SURYPUS_TEST_DATABASE_URL`). Verified against PostgreSQL 18.6:
    **788 examples, 0 failures, 0 pending**; **784 examples, 0 failures, 1 pending**
    without a database.

- [x] Redis Streams for events (US-3-3 follow-up) (2026-10-16)
  - Added `Infrastructure.Redis.EventStream`: `publishEvent` appends
    `{eventType, data}` to a stream, `readEvents` reads back oldest-first,
    `streamLength` reports the entry count.
  - Wired it into `Infrastructure.EventStore.Accounting`: `mkAccountingEventStore`
    now connects to Redis and `appendAccountingEvent` publishes every appended
    event. PostgreSQL stays the system of record, so an unreachable Redis
    degrades the store to "no stream" instead of failing the write.
  - Tests: `Infrastructure.Redis.EventStreamSpec` (module contract) and
    `Infrastructure.EventStore.AccountingIntegration` (end-to-end through both
    systems). Verified: **798 examples, 0 failures, 0 pending**.

- [x] Implement Redis read-model cache and wire it into the read model (US-3-3) (2026-10-16)
  - Replaced the `createRedisCache _ = return ()` stub with a real hedis-backed cache
  - `balanceKey`: namespaced `surypus:accounting:balance:<id>` key
  - `encodeBalance`/`decodeBalance`: aeson round-trip, `Nothing` for malformed payloads
  - `createRedisCache`: connects with the configured host/port/db, reports failures as `Left`
  - `getCachedBalance`/`putCachedBalance`/`deleteCachedBalance`: TTL-bounded Redis operations
  - `getCurrentBalanceCached` in `Core.Accounting.ReadModel`: cache-first, falls back to replay
  - Added `Core.Accounting.RedisCacheSpec` (8 tests); the Redis round-trip is pending without a server
  - Phase 3 backlog reconciled: US-3-1/2/4/5/6 marked done, US-3-7 still open

- [x] Remove dead stub modules and implement the external API client (2026-10-16)
  - Deleted `DAL.SchemaStubs` (duplicate of the entities in `DAL.Schema`, zero importers)
  - Deleted `JobWorkerApp` (printed "Job worker not implemented", zero importers)
  - `Integration.API.ExternalAPI`: replaced `apiGet`/`apiPost` returning `Left "Not implemented"`
    with a real http-conduit client (explicit Manager, Bearer auth, non-2xx -> Left,
    retry with linear backoff)
  - Added `Integration.API.ExternalAPISpec` (7 tests)
  - Added http-client/http-client-tls/http-types as direct library dependencies

- [x] Write GraphQL client migration plan (US-3-7) (2026-10-16)
  - Documented the 11 REST→GraphQL operation mappings, variable schema, and deprecation timeline
  - Added docs/GRAPHQL_MIGRATION.md and registered it in extra-doc-files

- [x] Remove 6 dead stub modules (2026-10-16)
  - Surypus.Domain.Observability.Domain, Infrastructure.WebSocket.InventoryBroadcast,
    Kafka.Producer, DAL.Migration, System.SchedulerJob, System.HealthCheck
  - All had zero importers (HealthCheck only imported by dead SchedulerJob)
  - All were pure no-ops (return () stubs)
  - 382 exposed modules remaining (was 388)

- [x] Make closePool actually close the pool (2026-10-16)
  - DAL.Database.closePool and DAL.ORMPool.closePool were `return ()` — connections leaked
  - Now delegate to Data.Pool.destroyAllResources
  - Added DAL.PoolSpec (2 tests; pool creation is lazy, so no live database needed)

- [x] Remove the last two dead stubs (2026-10-16)
  - Surypus.Database.Pool: whole module was a stub (createDatabasePool/ping/release/runMigrations), zero importers
  - DAL.Schema.migrateAll: no-op that shadowed the real migration in Surypus.DB.Schema.runMigrations
  - No `return ()` / `undefined` / `TODO` stub patterns remain anywhere in src/

## Stats

| Status | Count |
|--------|-------|
| Done (Phase 2) | 12 |
| Open (Phase 3) | 7 |
| Done (General) | 42 |
| Done (Cache) | 1 |
| Done (System.Cache) | 1 |
| Done (System.Counter) | 1 |
| Done (New: Surypus.RBAC.Store) | 1 |
| Done (JWT) | 1 |
| Done (New: Config+Obs+Mig+RBACCanon) | 4 |
| Done (New: Inventory Stock+Warehouse) | 2 |
| Done (New: HR.Operations) | 1 |
| Done (New: Domain.ProductionProperty) | 1 |
| Done (New: Contract.SchemaSpec) | 1 |
| Done (New: Inventory.Goods) | 1 |
| Done (New: RateLimiter de-flake + lbCheck fix) | 1 |
| Done (New: Surypus.Validation fail-open validators) | 1 |
| Done (New: System.Cache eviction/boundary strengthening) | 1 |
| Done (New: AccountingReadModel replay) | 1 |
| Done (New: ReadModel JSON event-schema fix) | 1 |
| Done (New: BalanceAdjusted contract pinning) | 1 |
| Done (New: Inventory.Operations) | 1 |
| Done (New: Service.WorkflowEngine) | 1 |
| Done (New: System.MetricsCollector + NaN avg fix) | 1 |
| Done (New: System.Retry) | 1 |
| Done (New: Commerce.Price + 3 fixes) | 1 |
| Done (New: System.CircuitBreaker) | 1 |
| Done (New: Commerce.Discount) | 1 |
| Done (New: Core.Tax) | 1 |
| Done (New: Commerce.CashSessionTemp) | 1 |
| Done (New: Inventory.Unit) | 1 |
| Done (New: RedisCache + ReadModel wiring) | 1 |
| Done (New: Stub cleanup + ExternalAPI client) | 1 |
| Done (New: GraphQL migration plan) | 1 |
| Done (Dead stub removal ×6) | 1 |
| Done (New: closePool real teardown) | 1 |
| Done (Dead stub removal ×8) | 1 |
| **Total** | **95** |
