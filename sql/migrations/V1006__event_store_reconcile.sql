-- Reconcile databases where the legacy event log (V014) claimed the
-- @event_store@ name before the CQRS schema (V1000) could be created.
--
-- On a fresh database this is a no-op: V014 now creates @legacy_event_store@
-- and V1000 owns @event_store@. On an upgraded database the legacy table still
-- sits under the @event_store@ name, so V1000's @CREATE TABLE IF NOT EXISTS@
-- was silently skipped and the CQRS columns never existed. Rename it out of the
-- way so the real event store can be created.
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'event_store' AND column_name = 'event_name'
  ) AND NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'event_store' AND column_name = 'aggregate_id'
  ) THEN
    IF NOT EXISTS (
      SELECT 1 FROM information_schema.tables WHERE table_name = 'legacy_event_store'
    ) THEN
      ALTER TABLE event_store RENAME TO legacy_event_store;
    END IF;
  END IF;
END $$;
