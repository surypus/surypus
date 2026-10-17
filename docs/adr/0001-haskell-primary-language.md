# ADR-001: Haskell as the Primary Language

**Status:** Accepted
**Date:** 2025-01-15

## Decision

We chose Haskell 2010 with GHC 9.6.5 as the primary implementation language.

## Rationale

- Strong static type system prevents entire classes of bugs (null pointer, type confusion)
- Effect system (IO, STM, ReaderT) makes side effects explicit
- LiquidHaskell enables formal verification of critical invariants
- Garbage collection simplifies concurrent programming
- Static binary compilation simplifies deployment

## Consequences

- All new development is in Haskell
- Existing C++ code is being ported incrementally
- Team must have Haskell proficiency (Agda, Coq, Idris also allowed)
- Build system uses Stack with resolver lts-22.21

---

## ADR-002: PostgreSQL for Persistence

**Status:** Accepted
**Date:** 2025-02-01

## Decision

Use PostgreSQL as the primary database with stored procedures for heavy computations.

## Rationale

- ACID compliance for financial data
- Stored procedures for tax and accounting computations
- Mature Haskell ecosystem (persistent, esqueleto, postgresql-simple)
- JSONB support for flexible document storage

## Consequences

- Heavy computations live in PostgreSQL (calc_vat, calc_bill_totals)
- Haskell validates input, SQL computes results
- Migrations use versioned SQL files (V000–V1005)
- 367 migration files in the current chain

---

## ADR-003: Event Sourcing for Audit

**Status:** Accepted
**Date:** 2025-03-01

## Decision

Adopt Event Store pattern for auditability and event-driven architecture.

## Rationale

- Immutable audit trail of all business events
- Enables CQRS for read/write separation
- Supports event-driven notifications
- Snapshots prevent full stream replay

## Consequences

- Events are immutable and append-only
- Event bus publishes to subscribers
- Snapshots taken after N events
- Event store is the source of truth for business state changes

---

## ADR-004: Documentation Factory Pipeline

**Status:** Accepted
**Date:** 2026-08-31

## Decision

Build an automated documentation pipeline: Cabal + Haddock + doctest + Hoogle + Mermaid + GitHub Actions + AI-agent.

## Rationale

- Surypus has hundreds of exposed-modules requiring automated API documentation
- Haddock generates API reference from annotated Haskell code
- doctest makes documentation examples executable
- Hoogle provides type-level search
- Mermaid generates architecture and module dependency diagrams
- AI assists documentation generation but is never the source of truth

## Consequences

- `docs/generated/` is auto-generated only
- `docs/architecture/`, `docs/guides/`, `docs/adr/` are human/AI-maintained
- CI validates documentation on every PR
- GitHub Pages publishes the documentation site
- ReadTheDocs provides the canonical documentation experience

## Principles

> **AI не является источником истины.**
> Источником истины являются GHC, Cabal, Haddock, исходный код и исполняемые тесты.
