# Verification log (2026-11-27)

All commands run in `/home/dominicusin/.hermes/cache/scratch/surypus-audit`
(clean worktree, branch `autonomous/audit-2026-11-27`, HEAD `078ead3`).

| Command | Exit | Result |
|---|---|---|
| `git worktree add -b autonomous/audit-2026-11-27 <wt> origin/main` | 0 | detached from divergent local `main`; no dirty file touched |
| `find src -name '*.hs' \| wc -l` | 0 | 386 before change, 387 after |
| `find test -name '*.hs' \| wc -l` | 0 | 85 before, 87 after |
| `stack build --test --test-arguments="--match AuthMiddleware"` | 0 | 8 examples, 0 failures |
| `stack test` | 0 | 1234 examples, 0 failures, 3 pending |

Failed attempts (recorded, not hidden):
- System `runghc`/`ghc`/`ghci` could not load `Test.Hspec` — broken system
  package db (`hspec-2.11.18` files missing). Switched to Stack GHC 9.6.5.
- First Stack builds failed on my own type errors (WAI `respond` argument;
  missing `wai`/`wai-extra` in test build-depends; `Status` vs `Int`). Fixed and
  re-ran; final runs above are green.
- `stack build --test-args=...` is not a valid Stack option; `--test-arguments`
  is.

Not executed: `scripts/check-tenant-rls.sh`, `scripts/ci-migration-verification.sh`
(require PostgreSQL), and GitHub CI (not queried). No claim is made about them.
