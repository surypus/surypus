# Engineering baseline — Surypus (fresh inspection, 2026-11-27)

Source of truth: clean worktree of `origin/main` at `078ead3` on branch
`autonomous/audit-2026-11-27`. No pre-existing dirty file was touched.

## Measured facts

| Item | Value | How measured |
|---|---|---|
| Library modules in `src/` | 387 (386 before this task's new module) | `find src -name '*.hs' \| wc -l` |
| Exposed modules in `Surypus.cabal` | 385 after change (384 before) | grep of stanzas |
| Test modules in `test/` | 87 (85 before) | `find test -name '*.hs' \| wc -l` |
| Test examples | **1234, 0 failures, 3 pending** | `stack test` |
| CI workflow files | 78 (1 disabled) | `ls .github/workflows/` |
| Toolchain | Stack 3.7.1 / GHC 9.6.5 / resolver lts-22.21 | `stack path --compiler-exe` |
| SQL migration files | 40+ across `sql/migrations`, `sql/core`, `sql/event`, `sql/aggregate`, `sql/archive` | `find sql -type f` |
| DSL schema | `dsl/schema.yaml`, 3724 bytes | `ls -la dsl/` |

System GHC 9.10.3 is **not** usable for verification: its package db has
missing files for `hspec` (`ghc-pkg check`-class failure). All verification in
this baseline used Stack's GHC 9.6.5 and cached snapshot packages.

## State reconciliation

- `STATE.md` (last updated 2026-06-12) and `ROADMAP.md` declare `v1.0`,
  "8 of 8 phases COMPLETE", "production-ready". The current `README.md` says
  "prototype", "not production-ready", "one green vertical slice". These are
  contradictory; the older documents are marked **superseded** in place and
  are not deleted.
- The local `main` clone at `/home/dominicusin/surypus` (`cc23bd7`) is
  36 commits ahead / 29 behind `origin/main`. It has 4 uncommitted files.
  Those changes were left untouched; all work here is against `origin/main`.
- Four other local clones exist on feature branches (`feat/api-real-dal`,
  `feat/masterdata-billing`, `feat/tenant-rls`). No attempt was made to merge
  them; their relationship to `origin/main` is **UNVERIFIED**.

## Critical structural finding

The `surypus-server` executable (`app/Main.hs`) is a health-probe stub: it
answers `GET /api/v1/health`, `GET /api/v1`, and 404 for everything else.
`Surypus.API.Server.apiServer` — the Servant application with RBAC, tenant
middleware, rate limiting, WebSocket and 386 library modules — is **not
referenced by any executable**. The production HTTP surface is therefore not
the one described in the documentation. Status: **VERIFIED** (grep of all
`app/` and `src/` call sites).

## Stubs with false success

`DAL.Queue.processJob` and every `process*` helper return a success-shaped
JSON object without doing work; `Infrastructure.EmailSender.sendEmail` returns
`"Email sent successfully (simulated)"`;
`Integration.API.EventProcessor.generateEventId` returns a constant;
`System.Secrets.storeSecret` keeps plaintext;
`Surypus.DB.Pool` pool statistics and `Science.ML.DemandForecasting.trainModel`
are placeholders. `undefined` does not occur in `src/`; `error "` occurs twice.
