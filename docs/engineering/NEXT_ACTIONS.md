# Next actions (ordered)

1. **S-02 (P0)** — Replace the health-probe-only `app/Main.hs` with the real
   `Surypus.API.Server.apiServer`, wired to DB config, RBAC permission store,
   metrics and public paths. Acceptance: a running server serves a documented
   route (e.g. `GET /api/v1/persons`) with real DB-backed data and an
   integration test proves 401/403/200 behaviour. Requires a PostgreSQL
   instance for full verification.
2. **S-03 (P1)** — Replace `DAL.Queue.processJob` placeholder handlers with
   real handlers, or delete the module from exported surfaces if the Redis
   Streams worker is the canonical queue. Do not leave success-shaped stubs.
3. **S-04 (P1)** — Implement encryption at rest in `System.Secrets` or rename
   the module to reflect in-memory plaintext; add tests.
4. **S-05 (P2)** — `EventProcessor.generateEventId` must generate unique IDs
   (`Data.UUID.V4` is already imported but commented out).
5. **Migration corpus** — reconcile the competing `V001`/`V002` files under
   `sql/migrations`, `sql/core`, `sql/event`, `sql/aggregate`; define one
   deterministic order and validate against a real PostgreSQL service.
6. **Documentation** — regenerate `STATE.md`/`ROADMAP.md` from measured
   repository facts once S-02 is done; keep superseded notices in place.
