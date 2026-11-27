-- BOOT-04: tenant scoping for the core accounting tables.
-- Idempotent so it can be replayed by scripts/migrate.sh and the CI chain.
ALTER TABLE bills    ADD COLUMN IF NOT EXISTS tenant_id BIGINT;
ALTER TABLE payments ADD COLUMN IF NOT EXISTS tenant_id BIGINT;
ALTER TABLE accounts ADD COLUMN IF NOT EXISTS tenant_id BIGINT;

CREATE INDEX IF NOT EXISTS idx_bills_tenant_id    ON bills (tenant_id);
CREATE INDEX IF NOT EXISTS idx_payments_tenant_id ON payments (tenant_id);
CREATE INDEX IF NOT EXISTS idx_accounts_tenant_id ON accounts (tenant_id);
