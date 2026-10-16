-- Legacy event log (superseded).
--
-- This table used to be named @event_store@, which collided with the CQRS
-- event store created by V1000__event_store_schema.sql. Because both used
-- @CREATE TABLE IF NOT EXISTS@, whichever migration ran first won silently and
-- the other schema never materialised -- the event store was unusable either
-- way. The CQRS schema is the supported one, so the legacy log now lives under
-- its own name. V1006__event_store_reconcile.sql renames any pre-existing
-- legacy @event_store@ on upgraded databases.
CREATE TABLE IF NOT EXISTS legacy_event_store (
  id BIGSERIAL PRIMARY KEY,
  event_name TEXT NOT NULL,
  payload TEXT,
  created_at TIMESTAMP WITHOUT TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_legacy_event_store_created ON legacy_event_store (created_at DESC);

