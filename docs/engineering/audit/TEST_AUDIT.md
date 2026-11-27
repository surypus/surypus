# Test audit — 2026-11-27

- Single Hspec entry point: `test/Test.hs` (aggregates all specs).
- `stack test`: **1234 examples, 0 failures, 3 pending** (GHC 9.6.5).
- 87 test modules after adding `AuthMiddlewareSpec` and
  `AuthMiddlewareDecisionSpec`.
- New coverage: pure authorization decisions (8 examples) and WAI status-code
  behaviour (8 examples), including regressions for fail-open routes, JWT-role
  fallback, public-path prefix matching, and store-call arguments.
- Property suites present: `QuickCheckInvariantsSpec`, `Domain.InvariantsSpec`,
  `Finance.*Spec`, `Core.TaxSpec` (100 cases per property in output).
- Integration suites exist for PostgreSQL event store and Redis streams
  (`DAL.EventStoreIntegration`, `Infrastructure.Redis.EventStreamSpec`), but
  they are only fully exercised with `SURYPUS_TEST_DATABASE_URL` and
  `SURYPUS_TEST_REDIS_URL`; those variables were not set for this run, which
  matches the 3 pending examples.
- CI: 78 workflow files (one `.disabled`). Presence of a workflow was not
  treated as evidence that it passes; CI state was not queried in this run.

Finding: the prior RBAC negative test checked a pure mapping result, not the
HTTP decision. A test can be green while the deployed behaviour is insecure.
All security properties now have a WAI-level assertion.
