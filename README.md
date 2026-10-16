# Surypus ERP/CRM

**Haskell ERP prototype with formal verification in selected areas**

[![License: MPL-2.0](https://img.shields.io/badge/License-MPL%202.0-blue.svg)](https://opensource.org/licenses/MPL-2.0)
[![Haskell](https://img.shields.io/badge/Language-Haskell-5e5086?logo=haskell)](https://www.haskell.org/)
[![GHC](https://img.shields.io/badge/GHC-9.6.5-5e5086)](https://www.haskell.org/ghc/)
[![Stack](https://img.shields.io/badge/Stack-3.x-5e5086)](https://docs.haskellstack.org/)
[![CI](https://github.com/surypus/surypus/workflows/CI/badge.svg)](https://github.com/surypus/surypus/actions/workflows/ci.yml)

---

## Overview

Surypus is an experimental Haskell ERP/CRM prototype. It focuses on a narrow
verifiable core: tax calculations, double-entry accounting, JWT auth with
refresh rotation, RBAC, and bill posting.

This repository is not production-ready. The current goal is one green
vertical slice, not broad feature coverage.

## Current status

- **Prototype stage** — the library and executables build; the API surface is
  exercised by tests, not deployed.
- **CI: green** — 27 workflows pass on `main` (build + tests, CodeQL, HLint,
  Fourmolu, Hadolint, secret scanning, coverage, supply-chain checks, docs).
- **382 library modules** in `src/`: 381 exposed in `exposed-modules` of
  `Surypus.cabal`, plus one internal helper (`Service.Workflow`).
- **792 test examples, 0 failures** across 54 test modules (a few pending
  without infrastructure); **798 examples, 0 failures, 0 pending** when run with
  `SURYPUS_TEST_DATABASE_URL` and `SURYPUS_TEST_REDIS_URL`, which also exercises
  the real PostgreSQL event-store round-trip and the Redis Streams fan-out.
- Stack resolver: `lts-22.21` (GHC **9.6.5**); local development uses GHC
  9.10.3.

## Getting started

```bash
stack build
stack test
stack run
```

Or with Cabal:

```bash
cabal build all --enable-tests
cabal test
```

## Repository layout

```
src/     library modules (382), organised by domain (Finance, Commerce, HR, ...)
app/     executables (surypus-server, ...)
test/    Hspec test suite (test/Test.hs is the aggregator entry point)
tools/   build and documentation helpers
docs/    MkDocs documentation sources
dsl/     schema.yaml — source of the generated DAL.Types entity types
```

## Documentation

- [CONTRIBUTING.md](CONTRIBUTING.md)
- [SECURITY.md](SECURITY.md)
- [ARCHITECTURE.md](ARCHITECTURE.md)
- [API_DOCUMENTATION.md](API_DOCUMENTATION.md)
- [TASKS.md](TASKS.md) — task ledger
- [TODO.md](TODO.md) — consolidated task list
- [CODE_OF_CONDUCT.md](CODE_OF_CONDUCT.md)
- [GOVERNANCE.md](GOVERNANCE.md)
