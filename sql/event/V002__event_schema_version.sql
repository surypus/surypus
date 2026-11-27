-- BOOT-04: event store schema version marker.
-- Allows consumers to reject events written with an incompatible schema.
ALTER TABLE event_store
  ADD COLUMN IF NOT EXISTS event_schema_version INT NOT NULL DEFAULT 1;

CREATE INDEX IF NOT EXISTS idx_event_store_schema_version
  ON event_store (event_schema_version);
