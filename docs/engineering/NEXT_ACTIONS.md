# Next actions (ordered)

1. **S-10 (P1)** — Verify the real permission query against a migrated
   PostgreSQL schema. A local server is reachable via peer auth; a dedicated
   role is needed for the Haskell process. Add `SURYPUS_TEST_DATABASE_URL`
   integration coverage for allow/deny and admin role.
3. **S-03 (P1)** — `DAL.Queue.processJob` still returns success-shaped stubs.
   Replace with real handlers or remove the module from exported surfaces.
4. **S-04 (P1)** — `System.Secrets` stores plaintext; implement encryption at
   rest or rename the module to state its real behaviour.
5. **S-05 (P2)** — `EventProcessor.generateEventId` returns a constant; use
   `Data.UUID.V4` (import already present but commented out).
6. **Migrations** — reconcile competing `V001`/`V002` files across
   `sql/migrations`, `sql/core`, `sql/event`, `sql/aggregate`; define one
   deterministic order and validate against PostgreSQL.
7. **Docs** — regenerate `STATE.md`/`ROADMAP.md` from measured facts once the
   tenant-context fix and DB integration are done. Keep superseded notices.
