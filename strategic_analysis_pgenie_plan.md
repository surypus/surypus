# Surypus ERP — DSL-First ORM Strategy Using pGenie-Inspired Pattern

> **Source:** `~/src/Surypus` (clone of https://github.com/dominicusin/Surypus, pinned at `main`)
> **ORM reference:** pGenie — https://pgenie.io/docs/ (type-safe PostgreSQL client code generator; sqlc alternative that validates every query against a live PostgreSQL instance and tracks schema drift with committed signature files)
> **Goal:** The entire ERP is generated from a single versioned DSL. Changing the DSL auto-regenerates the ORM, SQL migrations, Datalog/logic layer, GET/POST API, and QML UI.

---

## 1. Current State of Surypus ORM Stack (what we have)

### 1.1 The two coexisting database layers

Surypus currently runs **two overlapping ORM stacks** that are not fully reconciled — this is the central architectural debt the DSL unification must resolve.

| Layer | Module | Technology | Status |
|---|---|---|---|
| **Persistent + Esqueleto (SQL generation)** | `DAL.Schema` (482 lines), `DAL.QueriesORM` (553 lines), `DAL.MutationsORM` (636 lines), `DAL.ClassifiersORM` (766 lines), `DAL.Migration` | `persistent` 2.18 + `esqueleto` 3.6 + TemplateHaskell (`mkPersist` / `mkMigrate "migrateAll"`) | **Live in cabal exposed-modules**; powers ~90% of runtime queries |
| **Hasql-based SQL** | `DAL.Queries` (thin wrapper → `DAL.QueriesORM`), `DAL.DB` (322-line in-memory stub), `DAL.Hasql.Database` | `Hasql` / `Database.Persist.Postgresql.ConnectionPool` | `DAL.DB` is a stub; `DAL.Hasql.Database` still imported by `Surypus.API.Server:14` as `ConnectionPool` |
| **Connection pool** | `DAL.ORMPool`, `DAL.Pool` | `createPostgresqlPool` hardcoded `host=localhost port=5432 dbname=surypus user=postgres password=postgres` | Single pool; no env-var config; blocks containerisation |
| **Procedures** | `DAL.Procedures` (92 lines) | PostgreSQL stored-procedure wrappers (`calcVAT`, `calcVATInclusive`, etc.) | Business logic lives in DB; Haskell side is thin |

### 1.2 The schema definition (the current "DSL")

The canonical schema lives in `src/DAL/Schema.hs` as a **Haskell quasi-quoted Persistent block** (`persistLowerCase|`), defining ~30 entity types (`PersonEntity`, `GoodsEntity`, `LocationEntity`, `BillEntity`, `BillLineEntity`, `StockEntity`, `LotEntity`, `EmployeeEntity`, `SalaryEntity`, `TaxEntity`, `CurrencyEntity`, `UnitEntity`, `OrderHeadEntity`, `OrderLineEntity`, `PaymentEntity`, `UserEntity`, `TenantEntity`, `RoleEntity`, `PermissionEntity`, `OksmEntity`, …) plus `sql=table` aliases.

`src/Surypus/DB/Schema.hs` re-exports `DAL.Schema` and adds `AuditEntry` and other entities via a second `share [mkPersist sqlSettings, mkMigrate "migrateCore"]` block.

**Key problem:** the schema is defined **in Haskell**, meaning the schema-to-SQL derivation happens at GHC compile time via Template Haskell, not as a standalone, language-agnostic artifact. pGenie's approach is the opposite: schema is defined in **YAML** (or SQL DDL), validated against a live Postgres, and **code is generated into the language**. This is the direction Surypus should move.

### 1.3 SQL migration files (already a rich asset)

The `sql/migrations/` directory contains **300+ migration files** (V000 through V500, plus V100–V450 series and V256–V258 domain-organization finalisation). There are also `sql/archive/`, `sql/aggregate/`, `sql/event/`, `sql/core/` subdirectories. This is already a substantial migration history — the challenge is that it is **not version-locked to a schema definition** and contains many "consolidated" placeholder files (`V103__consolidated.sql`, `V222__consolidated.sql`, …).

### 1.4 Frontend / QML

`frontend/qml/` contains `Main.qml`, `AppState.qml`, `LoginPanel.qml`, `RestClient.qml`, `WsClient.qml`, and `components/` (Card, DateField, KanbanColumn, LocationCard, …). These are hand-written QML and currently call `RestClient` directly — there is no code generation.

### 1.5 API layer

`API_DOCUMENTATION.md` lists ~50+ Scotty REST endpoints (`GET /api/v1/accounting/ledgers`, `POST /api/v1/accounting/transactions`, `GET /api/v1/inventory/goods`, etc.). Many still return hardcoded stubs per `strategic_analysis.md` and `STRATEGY.md`.

---

## 2. pGenie Model — What We Are Adopting

pGenie's core idea (from https://pgenie.io/docs/):

1. **Schema-first YAML** — the canonical schema is expressed in a declarative DSL (YAML), not in application code.
2. **Live validation** — every query is validated against a running PostgreSQL instance; schema drift is detected via **committed signature files**.
3. **Signature files** — a snapshot of the live schema's types (`*.sig`). On each run, pGenie compares the live signature to the committed one and reports drift.
4. **Code generation** — from the YAML + signatures, pGenie generates type-safe client code (Java/Haskell/Rust), SQL migrations, and query wrappers.
5. **Freeze file** — pins exact versions of generated code so the pipeline is reproducible.
6. **SQL migration integration** — pluggable into Flyway, Liquibase, Sqitch.

### 2.1 Direct mapping to Surypus primitives

| pGenie concept | Surypus equivalent | Target |
|---|---|---|
| `schema.yaml` (DDL-first) | `sql/migrations/V001__core_schema.sql` + `src/DAL/Schema.hs` (Persistent TH) | **Single source of truth**: pick ONE. Recommended: `sql/schema.yaml` (YAML) + generated `.sql` + generated `Schema.hs` |
| Signature files (`*.sig`) | `sql/docs/ARCHITECTURE.md` (manual) | Auto-generated `surypus.sig` committed to repo; diff in CI flags schema drift |
| Freeze file | None | `surypus.freeze` — pins every generated artifact's hash |
| Code generation | `mkPersist sqlSettings` TH at compile time | Standalone `surypus-codegen` binary that emits `Schema.hs`, `QueriesORM.hs`, `MutationsORM.hs`, `ClassifiersORM.hs`, `DAL/Types.hs`, SQL migrations |
| Migration tool integration | Custom `DAL.Migration` (Persistent `runMigration`) | `surypus-codegen migrate` → produces `V{N}__*.sql` into `sql/migrations/` |
| Live PG validation | None (only at `stack test` time against local PG) | CI job: `surypus-codegen validate --database-url=$DATABASE_URL` |

---

## 3. Strategic Plan — DSL-First Generation Pipeline

### 3.1 The single DSL: `dsl/schema.yaml`

Define a **Surypus-specific YAML schema dialect** that captures every Surypus domain concept. This is the **one true source of truth**. Everything below is generated from it.

**Proposed schema.yaml shape (draft):**

```yaml
# dsl/schema.yaml — Surypus ERP canonical schema
version: "1.0"

domain: SurypusERP
database: postgres

entities:
  - name: Bill
    sql: bill
    fields:
      - name: billId
        type: Int64
        primaryKey: true
      - name: code
        type: Text
        nullable: true
      - name: billType
        type: Int
      - name: docStatus
        type: Int
      - name: total
        type: Double
        refinement: NonNeg  # LiquidHaskell predicate
      - name: taxAmount
        type: Double
        refinement: NonNeg
      - name: personId
        type: Int64
        nullable: true
      - name: locationId
        type: Int64
        nullable: true
    theorems:
      - theorem_bill_total: "Total = Σ lines"
      - theorem_amounts_nonnegative: "all amounts ≥ 0"
    ddl: |
      CREATE TABLE bill (
        bill_id BIGINT PRIMARY KEY,
        code TEXT,
        bill_type INT NOT NULL,
        doc_status INT NOT NULL,
        total DOUBLE PRECISION NOT NULL CHECK (total >= 0),
        tax_amount DOUBLE PRECISION NOT NULL CHECK (tax_amount >= 0),
        person_id BIGINT REFERENCES person,
        location_id BIGINT REFERENCES location
      );

  - name: Goods
    sql: goods
    fields: [ ... ]

# Enums / classified classifiers (OKEI, OKVED2, TNVED, etc.)
classifiers:
  - name: OKEI
    table: okei
    code: Text
    fields: [name, unit_id, ...]

# Stored procedures
procedures:
  - name: calcVAT
    returns: Double
    args: [{amount: Double}, {rate: Double}]
    sql: "CREATE OR REPLACE FUNCTION calc_vat(amount DOUBLE PRECISION, rate DOUBLE PRECISION) RETURNS DOUBLE PRECISION AS $$ SELECT amount * rate / 100.0 $$ LANGUAGE SQL;"
    theorems: [theorem_vat_inclusion, theorem_vat_nonnegative]

# Datalog / logic rules (for the logic-layer / event-sourcing projections)
datalog:
  - name: stock_balance_invariant
    rule: |
      stock_balance(Goods, Location, Rest) :-
        Initial(Goods, Location, Init),
        Receipt(Goods, Location, Rec),
        Issue(Goods, Location, Iss),
        Rest = Init + Rec - Iss.
    theorem: theorem_stock_balance
```

**Why YAML (not Haskell TH) as the single source:**
- It is language-agnostic — readable by non-Haskell tooling (CI, pGenie-style generators, documentation).
- It diff-able in Git — every schema change is a clear, reviewable commit.
- It can drive **all downstream generators** (SQL migration, Haskell code, QML, OpenAPI spec, Datalog rules) from the same file.
- The existing 300+ SQL migration files can be **re-derived** from the YAML + theorems in a one-time migration pass.

### 3.2 Versioning strategy

| Artifact | Versioning mechanism | Location |
|---|---|---|
| `dsl/schema.yaml` | **Semantic version** + Git tags (`v0.1.0` … `v51.0.0`) | `dsl/schema.yaml` at HEAD; tagged releases |
| Generated SQL migrations | `V{N}__{description}.sql` with monotonic integer N | `sql/migrations/` |
| Generated Haskell entities | `src/DAL/Schema.hs`, `DAL/Types.hs` | Regenerated on each `codegen` run |
| Generated ORM queries | `src/DAL/QueriesORM.hs`, `MutationsORM.hs`, `ClassifiersORM.hs` | Regenerated |
| Generated QML | `frontend/qml/generated/` | Regenerated |
| Generated API spec | `openapi/` + `API_DOCUMENTATION.md` | Regenerated |
| Signature file | `surypus.sig` (SHA-256 of the schema YAML) | Committed |
| Freeze file | `surypus.freeze` (hash of every generated artifact) | Committed |

**Key rule:** every commit that changes `dsl/schema.yaml` must also change the generated artifacts. A CI check (`surypus-codegen --check`) verifies that the committed generated files match what `codegen` would produce from the current `schema.yaml`. If they don't match, the CI fails and the PR must be updated to regenerate.

### 3.3 The `surypus-codegen` pipeline

A standalone binary (or Nix derivation) that reads `dsl/schema.yaml` and emits the full ERP:

```
dsl/schema.yaml
   │
   ├─→ sql/migrations/V{N}__*.sql          # SQL DDL + migration ordering
   ├─→ src/DAL/Schema.hs                   # Persistent mkPersist block
   ├─→ src/DAL/Types.hs                    # Haskell domain types (with LiquidHaskell refinements)
   ├─→ src/DAL/QueriesORM.hs               # SELECT queries (Esqueleto)
   ├─→ src/DAL/MutationsORM.hs             # INSERT/UPDATE/DELETE
   ├─→ src/DAL/ClassifiersORM.hs           # Classifier lookups
   ├─→ src/DAL/Procedures.hs               # Stored-procedure wrappers
   ├─→ src/DAL/Procedures.sql              # CREATE OR REPLACE FUNCTION DDL
   ├─→ src/Core/Services/*.hs              # Service-layer stubs wired to DAL
   ├─→ src/Surypus.API.Server.hs           # Scotty route wiring (GET/POST endpoints)
   ├─→ openapi/spec.yaml                   # OpenAPI 3.0 spec
   ├─→ API_DOCUMENTATION.md                # Rendered docs
   ├─→ frontend/qml/generated/*.qml        # QML forms/list views per entity
   ├─→ frontend/qml/generated/Models.qml   # Typed QML model wrappers
   ├─→ datalog/rules.dl                    # Souffle/Datalog/Logiced rules
   ├─→ tests/DAL/SchemaSpec.hs             # Generated property tests
   ├─ surypus.sig                          # Live schema signature
   └─ surypus.freeze                       # Artifact freeze
```

**Each generator is a small, testable Haskell module.** The binary orchestrates them.

### 3.4 SQL migration generation (replacing the current 300+ manual files)

**Current problem:** `sql/migrations/` has 300+ files, many "consolidated" placeholders, with no clean derivation from a single schema definition.

**Target:** a single `surypus-codegen migrate` command that:
1. Reads `dsl/schema.yaml`.
2. Computes the diff against the previous `surypus.sig`.
3. Emits a single migration file `V{N}__surypus_schema.yaml` (or a set of ordered files) covering only the changed tables/columns/indexes.
4. Validates every generated SQL statement against a live PostgreSQL instance (the pGenie "live validation" model).
5. Updates `surypus.sig`.

**One-time cleanup:** run `surypus-codegen full-schema` today to regenerate the entire `sql/migrations/` directory from the current `dsl/schema.yaml`. This produces a clean, deduplicated migration set. The 300+ legacy files are then archived (`sql/migrations/archive/`) and replaced by the generated ones.

### 3.5 Datalog / logic layer generation

Surypus already has event-sourcing concepts (`DAL.EventStore`, `Infrastructure.EventStore.*`). The DSL's `datalog:` section should drive a **Soufflé/Datalog** (or Logiced) rules file that:
- Derives read-model projections from the event stream.
- Enforces invariants (`stock_balance`, `double_entry`, `vat_inclusion`) as logic programs.
- Is regenerated when the DSL changes.

**Flow:**
```
dsl/schema.yaml  ──→ surypus-codegen ──→ datalog/rules.dl  ──→ Soufflé compiled program
                                                                ──→ materialized views in PostgreSQL
                                                                ──→ Haskell read-model projections
```

### 3.6 GET/POST API generation

The DSL's entity definitions drive:
- **OpenAPI 3.0 spec** (`GET /api/v1/{entity}`, `POST /api/v1/{entity}`, etc.).
- **Scotty route handlers** (`src/Surypus.API.Server.hs`).
- **QML REST client bindings** (`frontend/qml/generated/RestClient*.qml`).

Every `entity` in `schema.yaml` automatically gets:
- `GET /api/v1/{entity.plural}` (list, with search/filter)
- `GET /api/v1/{entity.plural}/{id}` (detail)
- `POST /api/v1/{entity.plural}` (create)
- `PUT /api/v1/{entity.plural}/{id}` (update)
- `DELETE /api/v1/{entity.plural}/{id}` (delete)
- Refinement-type validation in the handler (maps LiquidHaskell predicates to runtime checks)

### 3.7 QML generation

Every entity in `dsl/schema.yaml` gets a generated QML form and a list view:
- `frontend/qml/generated/{Entity}Form.qml` — typed input form with validation.
- `frontend/qml/generated/{Entity}List.qml` — table/list view with search.
- `frontend/qml/generated/Models.qml` — typed QML model wrappers (`ListModel` + `DelegateModel`) that call the generated REST endpoints.

QML generation reads the entity fields + refinements and emits:
- `TextField` for `Text`
- `SpinBox`/`DoubleField` for `Double` with `NonNeg` validation
- `ComboBox` for classifier/enums
- `DateField` for `Day`
- Validation logic derived from LiquidHaskell predicates

### 3.8 LiquidHaskell integration

The DSL's `theorems:` section (e.g. `theorem_vat_inclusion`, `theorem_double_entry`) is compiled into:
- **Refinement types** in `src/DAL/Types.hs` (e.g. `{-@ type NonNeg = {v:Double | v >= 0} @-}`).
- **Smart constructors** that prove invariants at construction time.
- **Property tests** (QuickCheck) derived from the theorems.

When `schema.yaml` changes, the refinement types and theorems are regenerated — keeping the formal verification in sync with the schema.

---

## 4. Implementation Roadmap (phased)

### Phase A — Foundation (1–2 weeks)
1. **Extract current schema to YAML.** Write a parser that reads `src/DAL/Schema.hs` (the Persistent TH block) and emits `dsl/schema.yaml`. This is a one-time migration; after this, `schema.yaml` is canonical.
2. **Create `surypus-codegen` skeleton.** A Nix derivation + Haskell package that reads `dsl/schema.yaml` and (for now) just echoes the entities — proving the pipeline compiles.
3. **Set up signature file.** Generate `surypus.sig` from the current schema; commit it.
4. **CI check.** Add `surypus-codegen --check` to the GitHub Actions workflow: fail if committed generated files differ from `codegen` output.

### Phase B — Migration generation (2–3 weeks)
5. **Write the SQL migration generator.** From `schema.yaml` + previous `surypus.sig`, emit `V{N}__*.sql`.
6. **One-time migration pass.** Run `surypus-codegen full-schema` to regenerate `sql/migrations/` from the current schema. Archive the 300+ legacy files.
7. **Live validation.** Wire `surypus-codegen migrate` to spin up a test PostgreSQL container (via `docker-compose`) and validate every generated SQL statement against it.

### Phase C — ORM + DAL generation (2 weeks)
8. **Haskell code generators.** Emit `Schema.hs`, `Types.hs`, `QueriesORM.hs`, `MutationsORM.hs`, `ClassifiersORM.hs`, `Procedures.hs` from `schema.yaml`.
9. **Wire into cabal.** Switch `Surypus.cabal` exposed-modules to use the generated modules (or generate into `src/generated/` and include it).
10. **Remove `DAL.DB` stub and `DAL.Hasql.Database`.** All code now uses the generated ORM via `DAL.ORMPool`.

### Phase D — API + QML generation (2–3 weeks)
11. **OpenAPI + Scotty route generator.** Emit `src/Surypus.API.Server.hs` and `openapi/spec.yaml`.
12. **QML generator.** Emit `frontend/qml/generated/*.qml`.
13. **Update `frontend/qml/Main.qml`** to `import "generated"` and wire the generated models.

### Phase E — Datalog + formal verification (2 weeks)
14. **Datalog rules generator.** Emit `datalog/rules.dl` from the `theorems:` section.
15. **Soufflé compilation.** Add a CI job that compiles `datalog/rules.dl` with Soufflé and checks for violations.
16. **LiquidHaskell refinement sync.** Regenerate `{-@ … @-}` annotations in `Types.hs` from `schema.yaml`.

### Phase F — Freeze + release hygiene (1 week)
17. **`surypus.freeze`** generation and CI enforcement.
18. **Bump `Surypus.cabal`** to a version reflecting the new codegen pipeline.
19. **Tag `v52.0.0`** (or next milestone) with the full pipeline.

---

## 5. Verification gates (each phase)

| Gate | Command | Must pass |
|---|---|---|
| Schema YAML parses | `surypus-codegen validate dsl/schema.yaml` | exit 0 |
| Signature matches | `surypus-codegen sig --check` | exit 0 |
| Migrations valid against PG | `surypus-codegen migrate --validate` | exit 0 (live PG) |
| Haskell compiles | `stack build Surypus` | exit 0 |
| Generated ORM type-checks | `stack ghc -- -fno-code src/DAL/QueriesORM.hs` | exit 0 |
| Generated QML parses | `qml --list-imports frontend/qml/generated/*.qml` | exit 0 |
| OpenAPI spec is valid | `swagger-cli validate openapi/spec.yaml` | exit 0 |
| Datalog compiles | `souffle datalog/rules.dl` | exit 0 |
| LiquidHaskell checks | `liquid src/DAL/Types.hs` | exit 0 |
| All tests green | `stack test` | exit 0 |

---

## 6. Risk register

| Risk | Severity | Mitigation |
|---|---|---|
| One-time migration from 300+ legacy SQL files to generated set loses a migration | HIGH | Archive old files; keep them in `sql/migrations/archive/`; verify `stack test` + `pg_dump` comparison before deleting |
| Generated Haskell code is too large / cabal compilation times out | MEDIUM | Generated modules go into `src/generated/` with `ghc-options: -fno-code` in dev; CI uses `stack build --file-watch` |
| QML generation produces verbose/unreadable code | MEDIUM | Generated files are in `frontend/qml/generated/`; hand-written code stays in `frontend/qml/` and imports generated modules |
| pGenie is a moving target; its CLI/format changes | LOW | We are adopting the **pattern** (YAML schema → signature → codegen → live validation), not pGenie's CLI; our `surypus-codegen` is self-contained |
| DSL changes cascade through all generators and cause PR churn | MEDIUM | Use `surypus.freeze` + CI check; only regenerate when schema.yaml actually changes |
| LiquidHaskell refinement type generation is fragile | MEDIUM | Keep refinement predicates simple; generate a `liquidhaskell.yaml` per entity; CI runs `liquid` and reports |

---

## 7. Immediate next actions (this week)

- [ ] **Confirm `dsl/schema.yaml` is the right canonical form.** Review the current `src/DAL/Schema.hs` entities against `sql/migrations/V001__core_schema.sql` to ensure nothing is lost in extraction.
- [ ] **Prototype the YAML→Persistent TH extraction.** Write a script that reads `src/DAL/Schema.hs` and emits a minimal `dsl/schema.yaml` for the first 10 entities.
- [ ] **Create the `surypus-codegen` Nix derivation skeleton** in `tools/surypus-codegen/`.
- [ ] **Open an issue** for the one-time migration of `sql/migrations/`.

---

## 8. References

- Surypus repo (local clone): `~/src/Surypus`
- pGenie docs: https://pgenie.io/docs/ (How It Works, Installation, Writing Migrations, Writing Queries, Signature Files, Freeze File, Using pGenie in CI/CD)
- Surypus STRATEGY.md: `~/src/Surypus/STRATEGY.md`
- Surypus PLANNING.md: `~/src/Surypus/PLANNING.md`
- Surypus ARCHITECTURE.md: `~/src/Surypus/ARCHITECTURE.md`
- Surypus strategic_analysis.md: `~/src/Surypus/strategic_analysis.md`
- Surypus API_DOCUMENTATION.md: `~/src/Surypus/API_DOCUMENTATION.md`
- Surypus AGENTS.md: `~/src/Surypus/AGENTS.md`
- Surypus Schema.hs: `~/src/Surypus/src/DAL/Schema.hs` (482 lines, Persistent TH)
- Surypus QueriesORM.hs: `~/src/Surypus/src/DAL/QueriesORM.hs` (553 lines, Esqueleto)
- Surypus sql/migrations/: `~/src/Surypus/sql/migrations/` (300+ files)
- Surypus QML frontend: `~/src/Surypus/frontend/qml/`

---

*Generated: 2026-08-29. Based on `main` branch of `dominicusin/Surypus` (cloned 2026-08-29) and pGenie docs (https://pgenie.io/docs/).*

---

## 9. Canonical Strategic Goals (SMART, priority-ordered)

These goals supersede the earlier descriptive principles. They are the acceptance
criteria for the next development epoch. The DSL transpiler (this plan) is **Goal 3**,
not the whole program.

### Goal 1 — Close the critical business loop (Critical Path Closure)
Take **bill posting** end-to-end to a fully working, tested state:
create → refinement-predicate validation → domain event → projection into
accounting registers → audit trail. This is the only flow that demonstrates the
value proposition ("formally verified accounting"), so it outranks any new domain.
- **Success:** an integration test where an invalid (by business rule) bill is
  rejected at the type/refinement level, and a valid one traverses the entire
  event-sourced pipeline and lands in the financial registers.

### Goal 2 — Close the security perimeter (Security Perimeter Closure)
Wire **RBAC middleware into every route without exception** and stabilise
**refresh-token rotation**. A multi-tenant system with partially protected routes
is worse than no multi-tenancy.
- **Success:** a route audit showing 100% of endpoints have an explicit RBAC
  policy (including explicit `public`), plus property tests proving no
  cross-tenant privilege escalation.

### Goal 3 — Promote the DSL transpiler to a CI artifact
Move the transpiler from "designed" to "wired into the dev loop":
`surypus-codegen generate/diff/status` must actually run in CI, detect breaking
changes, and block merge on schema/SQL/API inconsistency.
- **Success:** at least one real domain module (e.g. the **Invoice aggregate**)
  for which the DSL is the *only* source of schema edits, and all artifacts
  (SQL, Servant API, QML) are auto-generated and verified via `SchemaDiff` in
  the pipeline.

### Goal 4 — Replace AI patch automation with a systematic test harness
Patches A–C (via OpenCode) gave incremental progress, but AI-assisted generation
needs compensating QA or hidden drift accumulates between generated code and the
claimed formal guarantees. **QuickCheck property tests must be an acceptance
gate for every patch**, not a deferred task.
- **Success:** property-based tests for `PayrollService` and `InventoryService`
  exist *before* their production use, not after.

### Goal 5 — Close the observability loop
The circuit breaker must be **integrated into all external I/O boundaries**
(DB, worker, EventBridge) with metrics that actually show degradation. The basic
metrics endpoint (done in patches A–C) is only step one.
- **Success:** an injected external-dependency failure (e.g. DB down) in staging
  demonstrates the circuit breaker tripping without cascading system failure.

### Goal 6 — Activate the web frontend as an architecture-verification channel
Frontend activation is a tool, not a goal: it forces validation of whether the
QML generation and Servant API are fit for a real client, not just a theoretical schema.
- **Success:** the frontend drives at least one complete business scenario
  (e.g. create + view a bill).

---

## 10. Prioritized Work List (Critical / High / Medium / Low)

### Critical (blocks production readiness)
- Implement Job handlers on top of the existing worker dispatcher (patches A–C gave only a skeleton).
- End-to-end bill posting flow (create → refinement validation → event → register projections → audit).
- Wire RBAC middleware into all remaining routes (not just the "important" ones).
- Stabilise refresh-token rotation (eliminate the known reliability defect).
- Replace remaining hardcoded stubs in API handlers with real logic — starting with the critical path (finance, auth).

### High
- `PayrollService` — full implementation with event-sourced accrual model.
- `InventoryService` — full implementation, including reservation and stock movement.
- QuickCheck property tests for: Invoice aggregate refinement predicates, RBAC policies (no cross-tenant escalation), event-sourcing invariants (replay determinism).
- Integrate CircuitBreaker into all external I/O boundaries (DB, outbound HTTP, worker).
- Activate the web frontend for at least one full business scenario (create + view a bill).
- Promote `surypus-codegen` from standalone CLI to a mandatory CI gate blocking breaking changes.

### Medium
- Extend the DSL transpiler to a second domain aggregate (after Invoice) — likely InventoryItem or Employee — to prove the transpiler architecture is generalizable, not special-cased.
- Observability: structured logging correlated by event-sourcing correlation ID across all domains.
- Formalize the legacy migration strategy — a gradual cutover plan needs separate data-compatibility work if that remains a target.
- Document refinement predicates *as part of the DSL schema* (not only in code) for non-technical stakeholder auditability.

### Low (deferred until Critical/High close — expanding scope now widens the design/implementation gap)
- Broaden ERP domain coverage (production/MRP, advanced CRM, analytics/reporting).
- QML codegen for forms beyond the MVP scenario.

---

## 11. Progress log

- **2026-08-29 A**: Cloned `dominicusin/Surypus` → `~/src/Surypus`. Researched pGenie.
  Wrote this plan.
- **2026-08-29 B**: Extracted 54 entities from `src/DAL/Schema.hs` into `dsl/schema.yaml`
  (single canonical source). Created `tools/surypus-codegen/` with `Main.hs` (build/check/
  schema subcommands) and a standalone `surypus-codegen.cabal` / `.project`.
  Resolved the Nix GHC-9.10.3 build environment (glibc `crti.o` + `libgcc_s` linker
  path via `LIBRARY_PATH`/`NIX_LDFLAGS`); build of the transpiler is in progress.
