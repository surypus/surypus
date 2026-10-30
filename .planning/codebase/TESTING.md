---
last_mapped_commit: 7bd87f6f9f0abbbaddaeb0e604b8ff8fe2ff4c41
last_mapped_at: 2026-10-23
---
# Testing Patterns

**Analysis Date:** 2026-10-23

## Test Framework

**Runner:** Hspec (unversioned dependency `hspec` in `Surypus.cabal:546`), single `exitcode-stdio-1.0` test suite.

- Test suite: `surypus-test` in `Surypus.cabal`
- `main-is: Test.hs`, `hs-source-dirs: test`
- `default-language: Haskell2010`, no suite-level `ghc-options`
- `hspec-discover` is **not** used — every spec module is imported and invoked manually in `test/Test.hs`

**Property-based:** QuickCheck (`QuickCheck` in `Surypus.cabal:547`), plus `Test.QuickCheck.Monadic` for IO properties. No Hedgehog, no validity-based generators.

**Assertion library:** Hspec expectations (`shouldBe`, `shouldSatisfy`, `shouldReturn`, `shouldNotBe`, `expectationFailure`).

**Run Commands:**

```bash
stack build                                   # build library + test suite
stack test                                    # run all tests
stack test --test-arguments "--match 'VAT'"   # filter by describe/it text
stack test --test-arguments "-m \"НДС 20%\""  # same, regex with spaces
cabal test surypus-test --test-show-details=always   # Makefile path
make test                                     # test-unit + test-integration
stack build --coverage --test --no-run-tests && stack test --coverage
```

Notes:
- `Makefile` `test-unit` and `test-integration` invoke the **same** command (`cabal test surypus-test`); integration coverage is selected by environment variables, not by a separate target.
- `docs/engineering/testing-guide.md` documents `stack test --match "VAT"` and `--quickcheck`; `--match` is not a `stack test` flag (pass it via `--test-arguments`), and `--quickcheck` is not a flag this suite implements. Prefer the commands above.

## Test File Organization

**Location:** separate `test/` tree mirroring the `src/` module tree — tests are never co-located with sources.

```
test/
├── Test.hs                       # manual aggregator (main)
├── Finance/TaxSpec.hs            # module Finance.TaxSpec
├── Finance/AccountingSpec.hs
├── Core/Accounting/CacheSpec.hs
├── Inventory/StockSpec.hs
├── System/RetrySpec.hs
├── DAL/DBSpec.hs
├── DAL/EventStoreSpec.hs         # SpecWith ConnectionPool, run via integration wrapper
├── DAL/EventStoreIntegration.hs  # env-gated wrapper
├── Infrastructure/Redis/EventStreamSpec.hs
├── Domain/InvariantsSpec.hs
├── QuickCheckInvariantsSpec.hs
├── Surypus/ValidationSpec.hs
├── Surypus/API/GraphQLSpec.hs
├── Integration/API/ExternalAPISpec.hs
└── Phase2Phase3/GraphQLProxyBalanceSpec.js   # standalone manual script, not wired into any runner
```

**Naming:**
- File: `<ModuleUnderTest>Spec.hs`; module: `<ModuleUnderTest>Spec` with an explicit export list `(spec)`.
- Exceptions: cross-cutting suites with descriptive names — `test/QuickCheckInvariantsSpec.hs`, `test/Domain/InvariantsSpec.hs`, `test/TranscendenceSpec.hs`, `test/AdditionalTests.hs`, `test/MigrationDryRunSpec.hs`, `test/ObservabilitySpec.hs`.
- One spec per module under test; large domains (e.g. `Inventory`) split into `StockSpec`, `WarehouseSpec`, `GoodsSpec`, `UnitSpec`, `OperationsSpec`.

**Registration (two manual edits required):**
1. Add the module to the `test-suite surypus-test` `other-modules` list in `Surypus.cabal`.
2. Add `import qualified <Module>` and `<Module>.spec` to `test/Test.hs` (`test/Test.hs:6-69` imports, `:72-134` invocations).

Known gap: `test/DAL/EventStoreSpec.hs` is imported by `test/DAL/EventStoreIntegration.hs:13` but is **not** listed in `other-modules` and not invoked from `Test.hs`. List it when touching the event-store tests so the build does not rely on implicit home-module discovery.

## Test Structure

**Standard shape** — export `spec :: Spec`, group with `describe` per function under test, `it` for each behavior:

```haskell
module Core.TaxSpec (spec) where

import Test.Hspec
import Test.QuickCheck
import qualified Data.Text as T
import Core.Tax

spec :: Spec
spec = do
  describe "mkTaxBracket" $ do
    it "rejects a negative rate" $
      mkTaxBracket "bad" (-0.1) 0 `shouldBe` Nothing

  describe "applyTax" $ do
    it "returns 0 for negative base" $
      applyTax 0.20 (-100) `shouldBe` 0.0
```

(`test/Core/TaxSpec.hs:1-35`)

**Naming of examples:**
- `it` descriptions are lowercase verb phrases: "rejects a negative rate", "returns 0 for zero base", "creates a transaction with balanced entries" (`test/Finance/AccountingSpec.hs`).
- `describe` uses the bare function name (`"mkTransaction"`, `"validateTransaction"`) or the module name for the outer group (`describe "Finance.ExchangeRate"`, `test/Finance/ExchangeRateSpec.hs:22`).
- Property groups are nested as `describe "QuickCheck properties"` and each property wrapped in `it ... $ property prop_...` (`test/Finance/AccountingSpec.hs:94-108`). `test/Core/TaxSpec.hs` uses inline lambdas with `property $ \(NonNegative base) ...` instead of named generators.
- Comment banners separate major groups: `-- ============...` (`test/QuickCheckInvariantsSpec.hs:17`).

**Setup/teardown:**
- Resource fixtures use `beforeAll` / `afterAll` with the Hspec `SpecWith a` form (`test/DAL/EventStoreIntegration.hs:30-31`, `test/Infrastructure/Redis/EventStreamSpec.hs:43-45`).
- Environment probing is done once with `runIO` at spec-construction time (`test/DAL/EventStoreIntegration.hs:22`, `test/Infrastructure/Redis/EventStreamSpec.hs:37`).
- Per-example state is created inside the example (`db <- newDatabase`, `cache <- C.mkReadModelCache 10`), never shared.
- A Spec requiring a pool is typed `SpecWith ConnectionPool` and wrapped by a separate integration module (`test/DAL/EventStoreSpec.hs:40`, `test/DAL/EventStoreIntegration.hs`).

## QuickCheck Patterns

**Named generators** with `gen` prefix, returning domain-valid values:

```haskell
genDecimal :: (Integer, Integer) -> Gen Decimal
genDecimal (lo, hi) = fromIntegral <$> choose (lo, hi)

genDecimalNonNeg :: Gen Decimal
genDecimalNonNeg = genDecimal (0, 10000000)
```

(`test/QuickCheckInvariantsSpec.hs:21-25`)

**Named properties** with `prop_` prefix, typed `Property` (256 `prop_` definitions across the suite):

```haskell
-- | Net salary must never be negative
prop_calcNetSalaryNonNeg :: Property
prop_calcNetSalaryNonNeg =
  forAll genDecimalSalary $ \salary ->
    calcNetSalaryFromGross salary >= 0
```

(`test/QuickCheckInvariantsSpec.hs:84-88`)

**Arbitrary instances live in the test module**, not in the library (`test/Domain/InvariantsSpec.hs:42-56`, `test/Inventory/StockSpec.hs:13-18`). Do not add orphan `Arbitrary` instances to `src/` — the header of `test/Domain/InvariantsSpec.hs:2-12` records this rule explicitly.

**IO properties** use `monadicIO` / `run` / `assert` (`test/System/RateLimiterSpec.hs:30,109`, `test/Surypus/MetricsSpec.hs:85`, `test/System/DiscoverySpec.hs:217`).

**Property style choices:** `forAll genX $ \x -> ...` for custom generators; `(===)` for equality with counterexample printing (`test/Inventory/StockSpec.hs:35`); `(.&&.)` to combine invariants (`test/QuickCheckInvariantsSpec.hs`); `NonNegative`/`Positive` modifiers only for numeric shortcuts (`test/Core/TaxSpec.hs:79-90`).

## Mocking

**No mocking library is used** (no HMock, no `tasty-mock`, no `mockery`). Isolation is achieved with in-memory implementations and inert resources:

- In-memory DAL: `DAL.DB` provides `newDatabase`, `insertPerson`, `findPersonById`, etc., used directly by `test/DAL/DBSpec.hs` (`db <- newDatabase`).
- STM-backed components are exercised for real (`Core.Accounting.Cache`, `System.Counter`, `System.RateLimiter`, `Surypus.Metrics`) — no stubbing.
- "Unreachable" connection pools: a pool pointed at a closed port is used to test pre-query failure paths — `createPostgresqlPool (pack "host=127.0.0.1 port=1 dbname=x user=x password=x") 1` (`test/Surypus/API/GraphQLSpec.hs:48`).
- No-op logging: `runNoLoggingT` (`test/DAL/EventStoreIntegration.hs:11`, `test/Surypus/API/GraphQLSpec.hs:12`).
- IO state capture with `IORef` for retry/sequence assertions (`test/System/RetrySpec.hs:29-40`).
- Pure helpers are called directly; the suite prefers real implementations over fakes.

**What to mock:** nothing by default. If an external service (Postgres, Redis, HTTP) is required, gate the test by environment variable instead of faking the client.

**What NOT to mock:** domain logic (`Finance.*`, `Core.*`, `Inventory.*`), STM primitives, and the in-memory DAL — these are the units under test.

## Fixtures and Test Data

- No shared fixture module exists today. `docs/engineering/testing-guide.md` references `test/Fixtures/TestFixtures.hs` and `Integration/APISpec.hs`; neither exists — the guide is stale.
- Data is constructed inline with record or positional syntax at each call site (`test/Finance/AccountingSpec.hs:14-18`).
- Dates: older specs use `read "2024-01-15" :: Day`; newer specs use `fromGregorian 2020 6 1` (`test/Domain/InvariantsSpec.hs:34`). Prefer `fromGregorian`.
- Text: `OverloadedStrings` is enabled in 57 of 65 test files, so string literals are used directly (`"Hello World"` in `test/AdditionalTests.hs`). `T.pack` is only needed where the literal must be forced (`T.pack "New Company"` in `test/DAL/DBSpec.hs`).
- Money/Decimal: be deliberate about which type you use —
  - `Surypus.CoreTypes (Decimal(..))` newtype wrapping `Double` (`test/Finance/AccountingSpec.hs:9`),
  - `Data.Decimal.Decimal` from the `Decimal` package (`test/QuickCheckInvariantsSpec.hs:14`),
  - plain `Double` in `Core.Tax` / `Finance.Tax` tests (`test/Core/TaxSpec.hs`).
  Importing the wrong one produces confusing `Num`/`Ord` errors.
- Unique ids per run to avoid cross-run accumulation: `freshAggId` derives from the current time (`test/DAL/EventStoreSpec.hs:31-34`).

**Where fixtures should go if added:** a new `test/Fixtures/` module listed in `other-modules`; do not place test-only values in `src/`.

## Coverage

**Requirements:** 80% expression coverage enforced by `.github/workflows/coverage-gate.yml` (parses `coverage.json` from `stack hpc-codecov`). Note the gate's parser is wrapped in `try/except` and only warns when parsing fails, so a missing report can pass silently. `CONTRIBUTING.md` also states "Minimum 80% code coverage".

**View Coverage:**

```bash
stack build --coverage --test --no-run-tests
stack test --coverage
stack hpc-codecov --json > coverage.json
```

**Reporting:** `.github/workflows/haskell-coverage.yml` uploads to Codecov (`fail_ci_if_error: false`); `.github/workflows/coverage-gate.yml` additionally comments the percentage on PRs.

## Test Types

**Unit tests (majority):**
- Pure functions and smart constructors, grouped by function name.
- Files: `test/Finance/*`, `test/Inventory/*`, `test/Commerce/*`, `test/Core/TaxSpec.hs`, `test/Surypus/ValidationSpec.hs`.
- Style: one `shouldBe`/`shouldSatisfy` per behavior; branch on `Either` with `isLeft`/`isRight` rather than pattern matching when only the side matters.

**Property-based tests:**
- Central invariants: `test/QuickCheckInvariantsSpec.hs` (payroll, tax, stock, accounting), `test/Domain/InvariantsSpec.hs` (money, discounts, orders, receipts, transfers).
- Per-module properties inside unit specs (`test/Core/TaxSpec.hs`, `test/Finance/ExchangeRateSpec.hs:134-150`, `test/Inventory/StockSpec.hs:26-38`).
- Generators stay inside the LiquidHaskell-declared domain (non-negative quantities, rates 0–100); properties assert preservation of the refinement (`test/Domain/InvariantsSpec.hs:8-12`).

**Integration tests (environment-gated):**
- Pattern: `runIO (lookupEnv ...)`; if unset, register a single `pendingWith` example instead of failing.
  ```haskell
  spec = do
    mConn <- runIO (lookupEnv "SURYPUS_TEST_DATABASE_URL")
    case mConn of
      Nothing -> it "requires SURYPUS_TEST_DATABASE_URL" $ pendingWith "..."
      Just url -> beforeAll (runNoLoggingT (createPostgresqlPool (BC.pack url) 2)) $
                    afterAll closePool EventStoreSpec.spec
  ```
  (`test/DAL/EventStoreIntegration.hs:19-31`)
- Variables: `SURYPUS_TEST_DATABASE_URL`, `SURYPUS_TEST_REDIS_URL` (`test/Infrastructure/EventStore/AccountingIntegration.hs:28-29`, `test/Infrastructure/Redis/EventStreamSpec.hs:37`, `test/Core/Accounting/RedisCacheSpec.hs:48`).
- Live-but-optional service probes degrade to `pendingWith` when connection fails (`test/Core/Accounting/RedisCacheSpec.hs:48`).
- Setup scripts: `scripts/setup_test_db.sh`, SQL fixtures in `sql/test/V001..V010`, `make test-sql` and `make migrate-test`.

**E2E / API tests:**
- No Haskell E2E suite runs a live server. `test/Integration/API/ExternalAPISpec.hs` and `test/Surypus/API/GraphQLSpec.hs` cover wiring without a running server.
- `test/Phase2Phase3/GraphQLProxyBalanceSpec.js` is a manual Node script against `http://localhost:4000/`; it is not referenced by CI, the Makefile, or `package.json`. Do not treat it as automated coverage.

## Common Patterns

**Asserting on `Either` sides:**

```haskell
validateTransaction tx `shouldSatisfy` isRight
mkTaxBracket "bad" 1.5 0 `shouldBe` Nothing
```

(`test/Finance/AccountingSpec.hs:35`, `test/Core/TaxSpec.hs:24`)

**Failing with a useful message instead of `error`:**

```haskell
case mtx of
  Just tx -> processTransaction tx `shouldBe` Right ()
  Nothing -> expectationFailure "mkTransaction returned Nothing"
```

(`test/Finance/AccountingSpec.hs:89-92`)

**`IO` assertions:**

```haskell
validateAccessToken "secret" "not-a-jwt" `shouldReturn` Left "Invalid or expired token"
```

(`test/Surypus/JWTSpec.hs:26-28`)

**Floating-point comparison:** never exact `shouldBe` on fractional results; compare with an epsilon:

```haskell
applyTax 0.13 1000 `shouldSatisfy` \x -> abs (x - 130.0) < 1e-10
```

(`test/Core/TaxSpec.hs:51`)

**Determinism:**
- Do not depend on wall-clock deltas; components with time-dependent behavior document why they are only checked structurally (`test/System/MetricsCollectorSpec.hs:15-19`).
- Completion timestamps are matched by constructor, not value (`test/Service/WorkflowEngineSpec.hs:25-28`).
- Tests must be independent — each creates its own DB/cache/engine.

**Temporary local bindings in patterns** are avoided (`let Just x = ...` appears in `test/Inventory/StockSpec.hs:67-68`); prefer `case`/`expectationFailure` for partial patterns in new tests.

---

*Testing analysis: 2026-10-23*
