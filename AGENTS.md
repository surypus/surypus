# AGENTS.md - Surypus Development Guide

## Project Overview

This repository contains:
- **Surypus/** - Haskell reimplementation with formal verification (target for new development)

Primary development focus is on the Haskell codebase (Surypus).

### Language Constraint
**Haskell** — основной язык проекта, допускается  **Agda**, **Coq**, **Idris**, **Souffle**, **Datalog**, **Prolog**, в крайнем случае  **OCaml**,  возможно **Clojure**. Никаких других языков без явного согласования.

---

## Build Commands

### Surypus (Haskell)

```bash
# Build the project
stack build

# Run all tests
stack test

# Run a single test (by test name)
stack test --test-arguments "--match 'VAT'"

# Run a single test file
stack test --test-arguments "test/Test.hs"

# Watch mode (rebuild on changes)
stack build --file-watch

# REPL for interactive development
stack repl

# Typecheck without building
stack ghc -- -fno-code

# Run hlint (if installed)
hlint src/
```

```

---

## Running Tests

Tests use **Hspec** for unit tests and **QuickCheck** for property-based testing.

### Single Test Examples

```bash
# Run tests matching a pattern
stack test --match "VAT"

# Run specific spec
stack test --test-arguments "-m \"НДС 20%\""

# Run with verbose output
stack test --verbose

# Run QuickCheck properties
stack test --test-arguments "--quickcheck"
```

### Test Structure

Tests are in `Surypus/test/Test.hs`:
- `spec_vat_calculation` - VAT calculation tests
- `spec_accounting` - Double-entry bookkeeping tests
- `spec_inventory` - Stock/warehouse tests
- QuickCheck properties: `prop_vat_nonnegative`, `prop_price_with_vat_ge`

---

## Code Style Guidelines

### Language Standard
- **Haskell**: Use Haskell2010 (`default-language: Haskell2010` in .cabal)
- Enable warnings: `-Wall` (already set in stack.yaml for locals)

### Imports

```haskell
-- Group imports in this order:
import qualified Data.Text as T  -- External libraries
import qualified Data.Map as M
import Data.Text (Text)           -- Specific exports
import Data.Int (Int64)

-- Local imports
import Core.Tax
import DAL.Types
```

### Naming Conventions

| Element | Convention | Example |
|---------|------------|---------|
| Modules | PascalCase | `Core.Tax`, `DAL.Queries` |
| Types | PascalCase | `TaxRate`, `LedgerEntry` |
| Type aliases | PascalCase | `type Money = Decimal` |
| Functions | camelCase | `calcVAT`, `validateTaxRate` |
| Record fields | camelCase | `trId`, `trName`, `leDate` |
| Constructors | PascalCase | `PPOPT_SALES`, `Asset` |
| Type variables | camelCase | `a`, `m`, `f` |

### Record Syntax

```haskell
-- Use record syntax for data with multiple fields
data TaxRate = TaxRate
  { trId    :: Int64
  , trName  :: Text
  , trRate  :: Double
  , trFlags :: Int
  } deriving (Show, Eq)

-- Access fields directly (no lenses needed initially)
getRate :: TaxRate -> Double
getRate t = trRate t
```

### Type Definitions

```haskell
-- Use newtype for single-field wrappers with constraints
newtype Money = Money { unMoney :: Decimal }
  deriving (Eq, Num)

-- Use data for sum types with multiple constructors
data BillType 
  = PPOPT_GOODSRECEIPT
  | PPOPT_SALES
  | PPOPT_TRANSFER
  deriving (Eq, Show)

-- Use type aliases for domain concepts
type DocDate = Day
type GoodsID = Int
type BillID = Int
```

### Error Handling

```haskell
-- Use Either for recoverable errors
validateTaxRate :: TaxRate -> Either String TaxRate
validateTaxRate tr
  | trRate tr < 0 = Left "Tax rate cannot be negative"
  | trRate tr > 100 = Left "Tax rate cannot exceed 100%"
  | otherwise = Right tr

-- Use Maybe for optional values
findGoods :: GoodsID -> Maybe Goods

-- Pattern matching in do-blocks
case validateTaxRate rate of
  Left err -> logError err >> return Nothing
  Right r  -> processRate r
```

### Documentation

```haskell
-- Module header (required)
-- | Tax calculation module
module Core.Tax (calcVAT, calcTaxInclusive) where

-- Function docs (for public API)
-- | Calculate VAT amount from price and rate
-- | Returns: VAT amount >= 0 and <= price
calcVAT :: Double -> Double -> Double
calcVAT amount rate = amount * (rate / 100.0)
```

### Formatting

- **Indentation**: 2 spaces (no tabs)
- **Line length**: 100 characters max
- **Trailing whitespace**: Remove
- **Blank lines**: Single blank line between top-level definitions

### Refinement Types (LiquidHaskell)

For formal verification, use LiquidHaskell predicates:

```haskell
{-@ type NonNeg = {v:Double | v >= 0} @-}

{-@ calcVAT :: Double -> NonNeg -> NonNeg @-}
calcVAT :: Double -> Double -> Double
calcVAT amount rate = amount * (rate / 100.0)
```

### PostgreSQL Integration

Heavy computations should live in PostgreSQL:
- Use stored procedures for: `calc_vat()`, `calc_bill_totals()`, `get_lot_bounds()`
- Validate in Haskell, compute in SQL
- Use `persistent` + `esqueleto` for type-safe database queries

---

## File Organization

```
Surypus/
├── src/
│   ├── Core/           -- Domain modules (Tax, Goods, Accounting, etc.)
│   ├── DAL/            -- Database access layer
│   ├── Surypus/        -- Core utilities (Types, Z3, I18n)
│   ├── APIServer.hs    -- REST API (Scotty)
│   └── Reports.hs     -- Report generation
├── test/
│   ├── Test.hs        -- Main test suite
│   ├── Domain/        -- Domain-specific tests
│   ├── DB/            -- Integration tests
│   └── API/           -- API tests
└── stack.yaml
```

---

## Key Dependencies

- **base** >=4.12 && <5
- **text** - Text handling
- **time** - Date/time
- **uuid** - Unique identifiers
- **containers** - Data structures
- **hspec** - Testing framework
- **QuickCheck** - Property-based testing

---

## Development Workflow

1. Make changes in `src/`
2. Run `stack build` to check compilation
3. Run `stack test` to verify tests pass
4. Run `stack test --match "pattern"` for targeted testing
5. Use `stack repl` for interactive debugging

---

## Common Issues to Avoid

### Imports
- **NEVER** import `Double` from `GHC.Float` - it's already in Prelude
- Use `qualified Data.Text as T` (not `Data.Text as Data.Text`)
- Remove unused imports (causes warnings)

### Type Safety
- Use `Text` instead of `String` for user data
- Use `Int64` for database IDs
- Avoid `undefined` - use proper error handling

### Testing
- Always use `Text.pack` for string literals in tests: `T.pack "text"`
- Match record field order exactly when constructing values
- Import test dependencies in cabal file for both library and test-suite

---

## Architecture Principles

### Layer Separation
1. **Core/** - Domain logic (Tax, Accounting, Warehouse)
2. **DAL/** - Database access (Queries, Mutations, Types)
3. **Surypus/** - Utilities (Types, Z3, I18n)

### Key Invariants (to verify in code)
- VAT: result >= 0 and <= price
- Accounting: Σ Debit = Σ Credit
- Stock: Rest = Initial + Receipt - Issue

### Refinement Types (LiquidHaskell)
Use LiquidHaskell to prove critical properties:
```haskell
{-@ type NonNeg = {v:Double | v >= 0} @-}
{-@ calcVAT :: Double -> NonNeg -> NonNeg @-}
```

---

## Service Layer

### Pattern
Service functions orchestrate business logic between API handlers and DAL:

```haskell
-- Signature: context -> input -> IO (Either Error Output)
createBill :: AuthContext -> CreateBillInput -> IO (Either ServiceError Bill)
createBill ctx input = do
  -- 1. Validate input
  case validateBillInput input of
    Left err -> return (Left (ValidationError err))
    Right valid -> do
      -- 2. Check permissions
      case hasPermission ctx "bill:create" of
        False -> return (Left Forbidden)
        True -> do
          -- 3. Call DAL
          result <- DAL.Bill.create valid
          -- 4. Process result
          case result of
            Left dbErr -> return (Left (DBError dbErr))
            Right bill -> return (Right bill)
```

### Error Types
```haskell
data ServiceError
  = ValidationError Text
  | NotFound Text
  | Forbidden
  | Conflict Text
  | DBError DBError
  | InternalError Text
```

### Service Module Structure
- `Core.Services.Tax` - Tax calculations
- `Core.Services.Goods` - Goods management
- `Core.Services.Person` - Person/Employee operations
- `Core.Services.Accounting` - Double-entry operations
- `Core.Services.Inventory` - Stock operations

---

## Database Migrations

### Order of Application
Apply migrations in numeric order:

| Migration | Description |
|-----------|-------------|
| V001 | Initial schema (companies, persons, etc.) |
| V002 | Goods and inventory tables |
| V003 | Bills and orders |
| V004 | Accounting tables |
| V005 | Payroll tables |
| V006 | Jobs and reports |
| V007 | Auth and sessions |
| V008 | Audit logging |
| V009 | RBAC tables |
| V010 | Production enhancements |

### Migration Files Location
```
config/migrations/
├── V001__initial_schema.sql
├── V002__goods.sql
├── V003__bills.sql
├── V004__accounting.sql
├── V005__payroll.sql
├── V006__jobs.sql
├── V007__auth.sql
├── V008__audit.sql
├── V009__rbac_store.sql
└── V010__production.sql
```

### Running Migrations
```bash
# Apply all pending migrations
psql -h localhost -U surypus -d surypus -f config/migrations/init_db.sh

# Apply single migration
psql -h localhost -U surypus -d surypus -f config/migrations/V009__rbac_store.sql
```

---

## Job Types

### Overview
Background jobs are stored in `jobs` table with type and payload.

### Job Types

| Type | Description | Payload Fields |
|------|-------------|----------------|
| `report_generate` | Generate PDF report | `reportType`, `params`, `format` |
| `data_export` | Export data to CSV/Excel | `entity`, `filters`, `format` |
| `data_import` | Import data from CSV | `entity`, `filePath`, `mapping` |
| `notification_send` | Send email/push notification | `type`, `recipients`, `template`, `data` |
| `cleanup_old_data` | Archive/delete old records | `entity`, `olderThanDays`, `dryRun` |
| `sync_external` | Sync with external API | `service`, `direction`, `batchSize` |

### Job Payload Example (JSON)
```json
{
  "jobType": "report_generate",
  "payload": {
    "reportType": "invoice",
    "params": {
      "billId": 12345,
      "template": "invoice.yaml"
    },
    "format": "pdf"
  }
}
```

### Job Status Flow
`pending` → `processing` → `completed` | `failed`

### Querying Jobs
```sql
SELECT id, job_type, status, created_at, started_at, completed_at
FROM jobs
WHERE status IN ('pending', 'processing')
ORDER BY created_at ASC;
```

---

## PostgreSQL Integration

<!-- BEGIN BEADS INTEGRATION v:1 profile:full hash:d4f96305 -->
## Issue Tracking with bd (beads)

**IMPORTANT**: This project uses **bd (beads)** for ALL issue tracking. Do NOT use markdown TODOs, task lists, or other tracking methods.

### Why bd?

- Dependency-aware: Track blockers and relationships between issues
- Git-friendly: Dolt-powered version control with native sync
- Agent-optimized: JSON output, ready work detection, discovered-from links
- Prevents duplicate tracking systems and confusion

### Quick Start

**Check for ready work:**

```bash
bd ready --json
```

**Create new issues:**

```bash
bd create "Issue title" --description="Detailed context" -t bug|feature|task -p 0-4 --json
bd create "Issue title" --description="What this issue is about" -p 1 --deps discovered-from:bd-123 --json
```

**Claim and update:**

```bash
bd update <id> --claim --json
bd update bd-42 --priority 1 --json
```

**Complete work:**

```bash
bd close bd-42 --reason "Completed" --json
```

### Issue Types

- `bug` - Something broken
- `feature` - New functionality
- `task` - Work item (tests, docs, refactoring)
- `epic` - Large feature with subtasks
- `chore` - Maintenance (dependencies, tooling)

### Priorities

- `0` - Critical (security, data loss, broken builds)
- `1` - High (major features, important bugs)
- `2` - Medium (default, nice-to-have)
- `3` - Low (polish, optimization)
- `4` - Backlog (future ideas)

### Workflow for AI Agents

1. **Check ready work**: `bd ready` shows unblocked issues
2. **Claim your task atomically**: `bd update <id> --claim`
3. **Work on it**: Implement, test, document
4. **Discover new work?** Create linked issue:
   - `bd create "Found bug" --description="Details about what was found" -p 1 --deps discovered-from:<parent-id>`
5. **Complete**: `bd close <id> --reason "Done"`

### Auto-Sync

bd automatically syncs via Dolt:

- Each write auto-commits to Dolt history
- Use `bd dolt push`/`bd dolt pull` for remote sync
- No manual export/import needed!

### Important Rules

- ✅ Use bd for ALL task tracking
- ✅ Always use `--json` flag for programmatic use
- ✅ Link discovered work with `discovered-from` dependencies
- ✅ Check `bd ready` before asking "what should I work on?"
- ❌ Do NOT create markdown TODO lists
- ❌ Do NOT use external issue trackers
- ❌ Do NOT duplicate tracking systems

For more details, see README.md and docs/QUICKSTART.md.

## Landing the Plane (Session Completion)

**When ending a work session**, you MUST complete ALL steps below. Work is NOT complete until `git push` succeeds.

**MANDATORY WORKFLOW:**

1. **File issues for remaining work** - Create issues for anything that needs follow-up
2. **Run quality gates** (if code changed) - Tests, linters, builds
3. **Update issue status** - Close finished work, update in-progress items
4. **PUSH TO REMOTE** - This is MANDATORY:
   ```bash
   git pull --rebase
   bd dolt push
   git push
   git status  # MUST show "up to date with origin"
   ```
5. **Clean up** - Clear stashes, prune remote branches
6. **Verify** - All changes committed AND pushed
7. **Hand off** - Provide context for next session

**CRITICAL RULES:**
- Work is NOT complete until `git push` succeeds
- NEVER stop before pushing - that leaves work stranded locally
- NEVER say "ready to push when you are" - YOU must push
- If push fails, resolve and retry until it succeeds

<!-- END BEADS INTEGRATION -->


## Documentation Protocol (Haddock + doctest + Hoogle + Mermaid)

When modifying public Haskell APIs or adding new modules:

1. **Haddock**: Add Haddock comments to every exported function, type, class, and module.
   ```haskell
   -- | Calculate VAT amount from price and rate.
   --
   -- >>> calcVAT 100 0.2
   -- 20.0
   calcVAT :: Double -> Double -> Double
   ```

2. **doctest**: Add executable examples in Haddock comments. They are verified by `doctest`.
   ```bash
   # Run doctest on the project
   doctest src/
   # Or via the cabal project
   cabal build surypus-doctest --flag=doctest
   ```

3. **Hoogle**: After adding new exports, regenerate the Hoogle database.
   ```bash
   hoogle generate --local
   ```

4. **Mermaid**: After adding/removing modules, regenerate the module dependency graph.
   ```bash
   ./tools/documentation/generate-module-graph.sh src docs/generated/graphs/modules.mmd
   ```

5. **MkDocs**: Rebuild the documentation site locally to check for warnings.
   ```bash
   mkdocs build --strict
   ```

6. **Documentation Inventory**: Update `docs/generated/inventory/modules.json` when the
   module graph changes materially.

### Rules
- Never manually edit files in `docs/generated/` — they are machine-generated.
- Never invent API semantics. Haddock is the source of truth for the public API.
- Doctest examples must actually compile and run.
- Architecture diagrams must reflect the real module dependencies.
- AI-generated prose must be verified against Haddock, doctest, and the source code.

### Documentation Levels
- **L0**: No documentation (internal helpers)
- **L1**: Module header + exports list
- **L2**: Function/type/class documentation with signatures
- **L3**: Executable doctest examples
- **L4**: Architecture diagram (Mermaid) + module dependency graph
- **L5**: Domain guides (in `docs/guides/`)

### Pull Request Rule
If a public API changes (new/removed/changed exported function, type, or class):
- Documentation review is mandatory.
- Update Haddock, doctest examples, and module graph.
- Verify `mkdocs build --strict` passes.

## Secrets Policy

Never commit API keys, tokens, passwords, or credentials to the repository.
ReadTheDocs API keys must remain secret. If discovered, treat as leaked:
1. Rotate the key immediately on ReadTheDocs.
2. Remove it from any config or environment file.
3. Document the rotation in docs/ai/CHANGELOG.md.

<!-- GSD Configuration — managed by gsd-core installer -->
# Instructions for GSD

- Use the gsd-core skill when the user asks for GSD or uses a `gsd-*` command.
- Treat `/gsd-...` or `gsd-...` as command invocations and load the matching file from `.github/skills/gsd-*`.
- When a command says to spawn a subagent, prefer a matching custom agent from `.github/agents`.
- Do not apply GSD workflows unless the user explicitly asks for them.
- After completing any `gsd-*` command (or any deliverable it triggers: feature, bug fix, tests, docs, etc.), ALWAYS: (1) offer the user the next step by prompting via `ask_user`; repeat this feedback loop until the user explicitly indicates they are done.
<!-- /GSD Configuration -->
