---
last_mapped_commit: 7bd87f6f9f0abbbaddaeb0e604b8ff8fe2ff4c41
last_mapped_at: 2026-10-23
---
# Coding Conventions

**Analysis Date:** 2026-10-23

## Language and Build Baseline

**Primary language:** Haskell (Haskell2010), per `Surypus.cabal` (`default-language: Haskell2010`) and the language constraint in `AGENTS.md`.

**Package:** single cabal package `Surypus` with:
- `library` — 382 exposed modules under `src/`
- `executable surypus-server` — `app/Main.hs`
- `test-suite surypus-test` — `test/Test.hs`

**Build systems:** Stack (`stack.yaml`, resolver `lts-22.21`) and Cabal (`cabal.project`, `cabal.project.local`). Both are supported; CI uses Stack.

**Warnings:** `-Wall` for local packages via `stack.yaml` (`ghc-options: "$locals": -Wall`). No `-Werror`. Only three modules suppress warnings with `{-# OPTIONS_GHC ... #-}`: `src/Production/JobSystem.hs` (`-Wno-unused-imports`), `src/Surypus/JWT.hs` and `src/Surypus/JWT/Token.hs` (`-Wno-deprecations`).

**Language extensions:** declared per-module, one pragma per line at the top of the file. Most common (by occurrence across `src/`):
`OverloadedStrings` (203), `DeriveGeneric` (82), `ScopedTypeVariables` (34), `DuplicateRecordFields` (22), `RecordWildCards` (14), `DeriveAnyClass` (14), `LambdaCase` (13), `DerivingStrategies` (12).
`OverloadedStrings` is effectively mandatory in any module handling `Text`.

## Naming Patterns

**Modules:**
- PascalCase, dot-separated, matching the directory layout: `src/Core/Tax.hs` → `Core.Tax`, `src/Surypus/API/Bills.hs` → `Surypus.API.Bills`.
- Legacy PascalCase file/segment names keep their casing: `src/DAL/QueriesORM.hs`, `src/Surypus/CoreTypes.hs`, `src/Surypus/API/Persons.hs`.
- Test modules are `<Module>Spec`: `test/Finance/AccountingSpec.hs` → `module Finance.AccountingSpec (spec) where`.

**Functions:**
- camelCase: `calcVAT`, `validateTaxRate`, `applyTaxInclusive` (`src/Finance/Tax.hs`, `src/Core/Tax.hs`).
- Smart constructors are `mk` + type name, returning `Maybe`/`Either`:
  `mkTaxBracket :: Text -> Double -> Double -> Maybe TaxBracket` (`src/Core/Tax.hs:30`),
  `mkLedgerEntry` / `mkTransaction` (`src/Finance/Accounting.hs:50`, `:68`),
  `mkTaxRate` (`src/Finance/Tax.hs:29`),
  `mkNonNeg` (`src/Surypus/CoreTypes.hs:34`, `src/Finance/AccPlan.hs:38`).
- Validation predicates are `is` + noun or `validate` + noun: `isValidINN`, `validatePersonInput` (`src/Surypus/Validation.hs`).
- Accessors for newtypes are `un` + type or field: `unDecimal`, `unNonNeg` (`src/Surypus/CoreTypes.hs`), `unTaxRate` (`src/Finance/Tax.hs`).

**Record fields:**
Two coexisting schemes — follow the scheme already used by the module you are editing:
- Abbreviated prefixes derived from the type name (dominant in domain modules): `TaxBracket` → `tbName`, `tbRate`, `tbThreshold` (`src/Core/Tax.hs:22-26`); `Account` → `accId`, `accCode` (`src/Finance/Accounting.hs:26-27`); `LedgerEntry` → `leId`, `leDate`, `leDebit`; `Transaction` → `txId`, `txEntries`; `AccPlan` → `apId`, `apCode` (`src/Finance/AccPlan.hs:15`); `BillLine` → `blId`, `blBillId` (`src/Service/BillService.hs:52`); `Event` → `eventAggregateId`, `eventEventType` (`test/DAL/EventStoreSpec.hs`).
- Fully descriptive camelCase (dominant in newer infrastructure/system modules): `logTimestamp`, `logLevel` (`src/System/Logger.hs:17`); `failureThresholdCount`, `halfOpenMaxCalls` (`src/System/CircuitBreaker.hs:29`); `accountingEventId` (`src/Core/Services/Accounting.hs`); `postedBillId` (`src/Service/BillService.hs:57`).

**Strictness:** fields are frequently strict with `!`: `tbName :: !Text` (`src/Core/Tax.hs`), `QuerySuccess !a` (`src/DAL/Types.hs:118`). `StrictData` is used in `src/Core/Tax.hs` and a small number of hot-path modules.

**Types:** PascalCase. Newtypes wrap a single primitive with an `unX` accessor: `newtype Money = Money {unMoney :: Double}` (`src/Surypus/Types/Common.hs:103`), `newtype Decimal = Decimal Double` (`src/Surypus/CoreTypes.hs:14`), `newtype TaxRate = TaxRate { unTaxRate :: Decimal }` (`src/Finance/Tax.hs:26`).

**Constructors:** PascalCase. Constructor families share a prefix:
`QuerySuccess | QueryError | QueryResults` (`src/DAL/Types.hs:117`),
`CommandSuccess | CommandError` (`src/DAL/Types.hs:127`),
`CBSClosed | CBSOpen | CBSHalfOpen | CBSDisabled` (`src/System/CircuitBreaker.hs:23`),
`PostSuccess | PostFailed` (`src/Service/BillService.hs:62`).
`SCREAMING_SNAKE_CASE` constructors from the legacy schema (`PPOPT_SALES` in `AGENTS.md`) do not appear in `src/`; do not introduce them.

**Type variables:** lowercase `a`, `m`, `s`, `r` (`type RepositoryT m a` in `src/DAL/Repository.hs:23`).

## Code Style

**Formatting tool:** Fourmolu, enforced non-blocking in `.github/workflows/haskell-formatting.yml` (`fourmolu --mode check src/ test/ app/ tools/`). There is **no** `fourmolu.yaml`, `.fourmolu.yaml`, or `ormolu.yaml`, so Fourmolu defaults apply. `CONTRIBUTING.md` documents `fourmolu -i src/ test/` as the developer command.

**Indentation:** 2 spaces, no tabs (`AGENTS.md`, `CONTRIBUTING.md`). Known 4-space outliers to normalize when touched: `src/DAL/Repository.hs`, `src/DAL/Classifiers.hs`, `src/Surypus/API/CRM.hs`, `src/Surypus/API/Production.hs`, `src/Surypus/Types/Goods.hs`, `src/Surypus/Types/Stock.hs`, `src/Surypus/Types/Bill.hs`.

**Line length:** 100 characters maximum (documented standard; not machine-enforced).

**Export lists:** 172 of 382 modules declare an explicit export list; 210 export everything (`module Foo where`). New and reviewed modules should declare exports. Leading-comma style is the Fourmolu/Ormolu default and appears in `src/Core/Tax.hs:11-16`:

```haskell
module Core.Tax
  ( TaxBracket(..)
  , applyTax
  ) where
```

Trailing-comma style also exists (`src/Finance/Accounting.hs:9-17`, `src/Surypus/Error.hs:3-6`). Follow the surrounding file; do not reformat unrelated files.

**Record construction:** both record syntax and positional construction are used. Use record syntax for anything with more than ~3 fields, and update records with record update syntax (`person { pName = ... }` in `test/DAL/DBSpec.hs`).

**Pragmas and module docs:** module Haddock (`-- | ...`) is placed either before the pragmas (`test/Test.hs:1`) or after them, immediately before `module` (`src/Core/Tax.hs`). Multi-line module docs use the `{-| Module: ... @-}` block form (`src/Service/BillService.hs:4-11`).

**Section separators:** modules use dashed rules between logical sections:
`--------------------------------------------------------------------------------` (`src/Service/BillService.hs:34`) or the 76-column banner `-- ============================================================================` (tests, `test/QuickCheckInvariantsSpec.hs:17`). Comment rules are descriptive only; they carry no semantics.

## Import Organization

**Order (documented in `CONTRIBUTING.md`):** external libraries → qualified imports → local project imports, with a blank line between groups. In practice the ordering is loose; the reliable rule is: *external first, local (`DAL.*`, `Core.*`, `Surypus.*`) last, separated by a blank line.* See `test/Domain/InvariantsSpec.hs:16-30` and `test/Core/TaxSpec.hs:5-8`.

**Qualification style:** pre-qualified dominates — `import qualified Data.Text as T` (308 occurrences) versus post-qualified `import Data.Text qualified as T` (7, e.g. `src/Surypus/Validation.hs:28`, which enables `ImportQualifiedPost`). Prefer pre-qualified.

**Alias conventions:**
`T` = `Data.Text`, `Map`/`M` = `Data.Map(.Strict)`, `TE` = `Data.Text.Encoding`, `UUID` = `Data.UUID`, `BS`/`BC` = `Data.ByteString(.Char8)`, `LBS`/`BL` = lazy `Data.ByteString(.Lazy)`, `R` = `Database.Redis`, `P`/`DBS` = `Database.Persist.*`, `ES` = event store modules (`src/DAL/QueriesORM.hs`, `src/Surypus/API/Server.hs`).

**Explicit import lists:** preferred per `CODE_REVIEW_GUIDELINES.md` ("Uses explicit imports (no wildcards)"), but bare whole-module imports still exist in 126 places — most often `import DAL.Types` (8×), `import Database.Esqueleto.Experimental` (4×), `import Servant` (3×), and `import Finance.Accounting` (3×). When adding code, use an explicit list or a qualified alias; do not add new unqualified wildcard imports.

**Local re-export pattern:** modules re-export a sibling type module in their export list: `module DAL.QueriesORM ( ..., module DAL.Types ) where` (`src/DAL/QueriesORM.hs:40`).

**Test imports:** `Test.Hspec` first and unqualified, then `Test.QuickCheck` (whole or explicit list), then project modules (`test/Finance/AccountingSpec.hs:6-9`, `test/TranscendenceSpec.hs:4-20`).

## Error Handling

**Patterns:**
- `Maybe` for expected absence / failed smart-constructor validation: `mkTaxBracket`, `mkLedgerEntry`, `mkTransaction` return `Nothing` on invalid input (`src/Core/Tax.hs:30`, `src/Finance/Accounting.hs:50-73`).
- `Either` with a domain error type for validation that must explain the failure: `validatePersonInput :: Text -> Maybe Text -> Maybe Text -> Either ValidationError ()` (`src/Surypus/Validation.hs:67`), `validateTransaction :: Transaction -> Either Text Transaction` (`src/Finance/Accounting.hs`), `mkNonNeg :: Decimal -> Either Text NonNeg` (`src/Finance/AccPlan.hs:38`).
- `Either Text` is the most common error channel (134 signatures); `Either String` appears mainly in older stubs (`src/Production/JobSystem.hs`, `src/Surypus/JWT/Token.hs:108`) — prefer `Text` in new code.
- Result ADTs for DAL operations: `QueryResult a = QuerySuccess a | QueryError Text | QueryResults [a] Int` and `CommandResult a` (`src/DAL/Types.hs:117-130`). API handlers (`src/Surypus/API/Bills.hs`) pass these through rather than throwing.
- Typed application errors: `AppError`/`AppErrorType` (`src/Surypus/Error.hs`), `ServiceError` + `ServiceM = ReaderT Pool (ExceptT ServiceError IO)` (`src/Service/Service.hs:60-66`), `RepositoryError` + `type RepositoryT m a = ExceptT RepositoryError m a` (`src/DAL/Repository.hs:14-23`).
- Exceptions are reserved for infrastructure and resilience code, where they are caught rather than thrown: `Control.Exception.try` in `src/System/Retry.hs` and `src/System/CircuitBreaker.hs`.
- Avoid partial functions and `undefined`/`error`; HLint enables the `partial` group (`.hlint.yaml`) and the review checklist requires `Maybe`/`Either`. Only 3 occurrences of `undefined`/`error "` exist in `src/`.

**Prescriptive rule:** validate at boundaries with a smart constructor (`mkX` returning `Maybe`/`Either`), store the validated value, and propagate `Either`/`QueryResult` upward. Do not throw from pure domain code.

## LiquidHaskell Refinement Annotations

Refinement specs are a first-class convention for financial and inventory modules. The canonical shape (`src/Core/Tax.hs:4-8`, `src/Finance/Tax.hs:6-12`, `src/Core/Payroll/Calculation.hs:3-7`):

```haskell
{-@ LIQUID "--reflection" @-}
{-@ LIQUID "--ple"        @-}

{-@ type ValidTaxRate = {v:Double | v >= 0.0 && v <= 1.0} @-}
{-@ type NonNegDouble = {v:Double | v >= 0.0} @-}

{-@ applyTax :: rate:ValidTaxRate -> base:NonNegDouble -> {v:NonNegDouble | v <= base} @-}
-- | Apply tax rate to base amount
applyTax :: Double -> Double -> Double
```

Conventions:
- Type aliases are declared immediately after the `LIQUID` pragmas, before `module`.
- Annotations sit **directly above** the Haskell signature; the Haddock `-- |` comment follows the annotation.
- Refined newtypes are related through their accessor: `{-@ type TaxRateValid = {v:TaxRate | 0 <= unTaxRate v && unTaxRate v <= 100} @-}` (`src/Finance/Tax.hs:12`).
- Shared predicates/measures live in `src/Surypus/Refined.hs` (`NonNegDouble`, `PositiveDouble`, `Percentage`, `NonNegInt64`, `clampNonNeg`, `clampPercentage`).
- Invariants covered: VAT bounds (`src/Finance/Tax.hs`), double-entry balance (`src/Finance/Accounting.hs`), stock non-negativity (`src/Inventory/Stock.hs`), payroll non-negativity (`src/Core/Payroll/Calculation.hs`), commission rate (`src/DAL/Agent.hs`), plus `src/Core/Optimization.hs`, `src/Core/Inventory.hs`, `src/Commerce/Payment.hs`, `src/Commerce/CashSessionTemp.hs`, `src/Retail/CashSessionTemp.hs`, `src/Production/Types.hs`.
- Configuration and coverage narrative: `liquidhaskell.yaml`. CI: `.github/workflows/liquidhaskell-verify.yml` runs `liquid` when available and otherwise degrades to a warning and an annotation-coverage grep.
- When creating a validated value, pair the annotation with a smart constructor that actually enforces the predicate — the annotation documents the contract, the constructor enforces it.

## Haddock and doctest

**Haddock is required for public APIs** (`AGENTS.md`, `docs/ai/DOCUMENTATION_RULES.md`, `CODE_REVIEW_GUIDELINES.md`).

Observed form:
- Module header: `-- | Tax calculation module` or the block form `{-| Module: ... @-}`, always above `module`.
- Exported items: `-- |` one-line summary, blank `--` line, then detail (`src/Surypus/Validation.hs:62-66`).
- Record fields: trailing `-- ^` comments (`src/System/CircuitBreaker.hs:48-49`).
- Export-list sections: `-- * Functions` comments inside the list (`src/Surypus/Refined.hs:4`).
- Cross-references use Haddock quotes: `'validateINN'`, `@SURYPUS_TEST_DATABASE_URL@` (`src/Surypus/Validation.hs:65`, `test/DAL/EventStoreIntegration.hs:6`).
- Density: ~1,967 Haddock lines in `src/`; coverage is tracked in `docs/generated/inventory/coverage.json` (86.7% module coverage per `docs/ai/COVERAGE.md`).

**doctest is policy-only today.** `AGENTS.md` and `docs/ai/DOCUMENTATION_RULES.md` define documentation level L3 as executable doctest examples and require `doctest src/` to pass. In practice:
- Zero `>>>` examples exist in `src/`.
- `doctest` is not a cabal component and does not run in `.github/workflows/documentation.yml`.
- `docs/generated/inventory/modules.json` reports `"doctest_examples": 0` for modules.

If you add an example, write it in the documented L3 form and verify it manually or add a doctest component; do not claim verification that CI does not perform.

**Generated docs are never hand-edited:** `docs/generated/**` is machine-produced (`docs/ai/DOCUMENTATION_RULES.md`); regenerate with `tools/documentation/*`.

## JSON and Serialization

- Derive `Generic` and either derive or hand-write instances: `deriving (Show, Eq, Generic, ToJSON, FromJSON)` (`src/Finance/Bill.hs:27`) or `instance FromJSON (PersonEntity)` / `instance ToJSON (PersonEntity)` (`src/DAL/Types.hs:37-38`).
- For snake_case wire formats, use `genericToJSON`/`genericParseJSON` with `fieldLabelModifier = camelTo2 '_' . drop N` (72 uses): `src/Surypus/Types/Common.hs:96-101`. `drop N` strips the record prefix (`drop 2` for `qp*`, `drop 5` for `range*`).
- Explicit `object [...]` values are used for ad-hoc payloads and error responses (`src/System/Logger.hs:66-75`, `src/Surypus/API/GraphQL.hs`).
- Money/Decimal JSON is serialized as a plain number through a newtype instance (`src/Surypus/CoreTypes.hs:23-27`, `src/Surypus/Types/Common.hs:106-111`).

## Logging

- `monad-logger` is the DAL/database logging path (`Database.Persist.Postgresql` + `runNoLoggingT` in tests, `test/DAL/EventStoreIntegration.hs:11`).
- Katip is wired in `src/Surypus/API/Logger.hs`.
- A lightweight in-memory STM logger exists at `src/System/Logger.hs` (`LogLevel = Debug | Info | Warn | Error | Critical`, `newtype Logger = Logger (TVar [LogEntry])`, `ToJSON LogEntry`).
- Avoid `putStrLn` for diagnostics (51 occurrences remain in `src/`); use the module's logger or `runStdoutLoggingT` when a `MonadLogger` context is already in scope.

## Module Design

- One module per file; file path equals module path.
- Explicit export lists for new modules; re-export type modules deliberately (`module DAL.Types` in `src/DAL/QueriesORM.hs`).
- One aggregator exists: `src/Surypus.hs` re-exports `Surypus.CoreTypes`, `Surypus.JWT`, `Surypus.RBAC`, `DAL.Types`, `DAL.Database`. Do not add new aggregators; import the concrete module.
- Generated code is marked: `src/DAL/Types.hs` begins `-- Generated from dsl/schema.yaml` / `-- DO NOT EDIT MANUALLY`.
- Stub modules exist and are labeled `(stub)` in Haddock (`src/Core/Services/Accounting.hs`); do not treat stub behavior as the contract.

## Linting

`hlint src/ test/ app/ tools/` with `.hlint.yaml`. Enabled groups: `dollar`, `generalise`, `partial`, `future`, `extra`, `use-lens`, `use-th-quotes`, `generalise-for-conciseness`, `teaching`. Configured ignores are scoped to specific modules (e.g. `Avoid partial function` within `Core.Price`, `Core.Currency.Operations`). CI (`.github/workflows/haskell-hlint.yml`) uploads an HTML report and does not fail the build (`|| true`).

Weeder configuration (`weeder.toml`) sets roots `Main.main` and `^Paths_.*`, with `IsString`/`IsList` instances as instance roots.

## Comments and Documentation of Decisions

- Comments explain invariants and decisions, not syntax: `-- Invariant: result >= 0 and result <= base` (`src/Core/Tax.hs:42`), `-- StrictData + BangPatterns for performance` (`src/Core/Tax.hs:17`), `-- rate is in percentage points (Decimal 20 = 20%)` (`src/Finance/Tax.hs:46`).
- Test modules carry a `-- |` header explaining what the spec pins and why (`test/Service/WorkflowEngineSpec.hs:3-9`, `test/Domain/InvariantsSpec.hs:2-12`).
- TODOs are not tracked in code; work items belong in Beads (`bd`) per `AGENTS.md`.

## Commit and PR Conventions

- **Conventional Commits**: `<type>(<optional scope>): <description>` with types `feat|fix|docs|style|refactor|perf|test|build|ci|chore|revert` (`CONTRIBUTING.md`).
- PRs must update `CHANGELOG.md` and, for public API changes, Haddock + module graph + `mkdocs build --strict` (`docs/ai/DOCUMENTATION_RULES.md`).
- Task tracking is Beads (`bd ready`, `bd update <id> --claim`, `bd close <id>`); no markdown TODO lists (`AGENTS.md`, `.agents/skills/beads/SKILL.md`).

---

*Convention analysis: 2026-10-23*
