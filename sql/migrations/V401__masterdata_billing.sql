-- Phase 4/5 canon: append-only stock movements, weighted-average cost and
-- a canonical trial-balance view. All DDL is idempotent and loads after the
-- existing V256 stock_movements definition.

ALTER TABLE stock_movements
  ADD COLUMN IF NOT EXISTS average_cost NUMERIC(18, 6);

CREATE OR REPLACE FUNCTION reject_mutation()
RETURNS TRIGGER AS $$
BEGIN
  RAISE EXCEPTION 'stock_movements is append-only; use a compensating movement'
    USING ERRCODE = 'check_violation';
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS stock_movements_append_only ON stock_movements;
CREATE TRIGGER stock_movements_append_only
  BEFORE UPDATE OR DELETE ON stock_movements
  FOR EACH ROW EXECUTE FUNCTION reject_mutation();

-- Canonical billing lines and payments linked to the existing bills table.
CREATE TABLE IF NOT EXISTS billing_canon_lines (
  id BIGSERIAL PRIMARY KEY,
  bill_id BIGINT NOT NULL REFERENCES bills(id),
  goods_id UUID,
  quantity NUMERIC(18, 6) NOT NULL CHECK (quantity >= 0),
  unit_price NUMERIC(18, 6) NOT NULL CHECK (unit_price >= 0),
  vat_rate NUMERIC(5, 2) NOT NULL DEFAULT 20 CHECK (vat_rate BETWEEN 0 AND 100),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS billing_canon_payments (
  id BIGSERIAL PRIMARY KEY,
  bill_id BIGINT NOT NULL REFERENCES bills(id),
  amount NUMERIC(18, 2) NOT NULL CHECK (amount >= 0),
  paid_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE OR REPLACE VIEW trial_balance_canon AS
  SELECT
    account_id::text AS account,
    SUM(COALESCE(debit, 0)) AS debit,
    SUM(COALESCE(credit, 0)) AS credit
  FROM journal_entries
  GROUP BY account_id;
