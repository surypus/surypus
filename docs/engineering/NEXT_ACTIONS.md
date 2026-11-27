# Next actions (ordered)

1. **S-10 (P1, partially verified)** — The exact permission SQL was executed
   against the live `surypus` schema via peer auth: viewer/read allowed,
   viewer/delete denied, unknown user denied (transaction rolled back).
   Still missing: the same check through the Haskell pool. Needs a local DB
   role for the app process (or `SURYPUS_TEST_DATABASE_URL`), then an
   integration spec using `checkUserAppPermissionRepo` directly.
2. **S-03 (P1)** — `DAL.Queue.processJob` still returns success-shaped stubs.
   Replace with real handlers or remove the module from exported surfaces.
3. **S-04 (P1)** — `System.Secrets` stores plaintext; implement encryption at
   rest or rename the module to state its real behaviour.
4. **S-05 (P2)** — `EventProcessor.generateEventId` returns a constant; use
   `Data.UUID.V4` (import already present but commented out).
5. **Migrations** — reconcile competing `V001`/`V002` files across
   `sql/migrations`, `sql/core`, `sql/event`, `sql/aggregate`; define one
   deterministic order and validate against PostgreSQL.
6. **Docs** — regenerate `STATE.md`/`ROADMAP.md` from measured facts once the
   tenant-context fix and DB integration are done. Keep superseded notices.
