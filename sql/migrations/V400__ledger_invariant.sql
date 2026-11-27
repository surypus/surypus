-- Phase 3 Ledger Canon: balanced entries and idempotent writes.
-- The trigger rejects single-sided journal rows before they are persisted.
-- The idempotency table guarantees that a repeated key cannot create a second
-- entry; the application-level single write path is App.Tx.runWrite.

CREATE TABLE IF NOT EXISTS ledger_idempotency (
  key TEXT PRIMARY KEY,
  entry_id BIGINT NOT NULL UNIQUE REFERENCES journal_entries(id),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE OR REPLACE FUNCTION enforce_balanced_journal_entry()
RETURNS TRIGGER AS $$
BEGIN
  IF COALESCE(NEW.debit, 0) <> COALESCE(NEW.credit, 0) THEN
    RAISE EXCEPTION 'journal entry must be balanced: debit % != credit %',
      NEW.debit, NEW.credit
      USING ERRCODE = 'check_violation';
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS journal_entries_balanced ON journal_entries;
CREATE TRIGGER journal_entries_balanced
  BEFORE INSERT OR UPDATE ON journal_entries
  FOR EACH ROW EXECUTE FUNCTION enforce_balanced_journal_entry();
