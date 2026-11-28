-- V017__inventory_movements.sql
-- Canonical inventory movement ledger for bill posting.
--
-- The legacy bill_lines table uses UUID bill ids while bills.id is BIGINT, so
-- it cannot be joined for posting. bill_posting_lines is the line source for
-- the posting flow; reconciling the legacy table is a separate decision.
CREATE TABLE IF NOT EXISTS bill_posting_lines (
    id BIGSERIAL PRIMARY KEY,
    bill_id BIGINT NOT NULL,
    goods_id BIGINT NOT NULL,
    quantity NUMERIC(18, 4) NOT NULL CHECK (quantity > 0),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_bill_posting_lines_bill
    ON bill_posting_lines (bill_id);

CREATE TABLE IF NOT EXISTS inventory_movements (
    id BIGSERIAL PRIMARY KEY,
    bill_id BIGINT NOT NULL,
    goods_id BIGINT NOT NULL,
    movement_type TEXT NOT NULL CHECK (movement_type IN ('receipt', 'issue')),
    quantity NUMERIC(18, 4) NOT NULL CHECK (quantity > 0),
    tenant_id BIGINT NOT NULL DEFAULT 0,
    occurred_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE (bill_id, goods_id, movement_type)
);

CREATE INDEX IF NOT EXISTS idx_inventory_movements_bill
    ON inventory_movements (bill_id);
