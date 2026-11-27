-- Phase 6 (Auth & RBAC): tenant row-level security for the core scoped tables.
--
-- DAL.Database.runDbWithTenant sets a transaction-local GUC via
--   SELECT set_config('app.tenant_id', ?, TRUE)
-- before every scoped query. The policies below read that same GUC. A missing
-- or empty setting matches no row (default deny).
--
-- Idempotent / replay-safe:
--   * the applier only touches tables that exist right now, so the ordered
--     migration chain loads cleanly even though event_store is created in
--     sql/event/V001 and reconciled much later in V1006;
--   * re-apply after a table is created (scripts/check-tenant-rls.sh does this)
--     to extend the same policy to it;
--   * policies are dropped before recreation; tenant_id is added only if absent.
--
-- tenant_id is compared as text because bills/payments/accounts use BIGINT
-- while the CQRS event_store uses UUID.

CREATE SCHEMA IF NOT EXISTS app;

CREATE OR REPLACE FUNCTION app.apply_tenant_rls(p_schema TEXT DEFAULT current_schema())
RETURNS VOID AS $$
DECLARE
  v_table TEXT;
  v_qualified TEXT;
BEGIN
  FOREACH v_table IN ARRAY ARRAY['bills', 'payments', 'accounts', 'event_store'] LOOP
    v_qualified := format('%I.%I', p_schema, v_table);

    -- Cross-directory ordering: a table may not exist at this version yet.
    IF to_regclass(v_qualified) IS NULL THEN
      CONTINUE;
    END IF;

    EXECUTE format(
      'ALTER TABLE %s ADD COLUMN IF NOT EXISTS tenant_id BIGINT DEFAULT 0', v_qualified);
    EXECUTE format('ALTER TABLE %s ENABLE ROW LEVEL SECURITY', v_qualified);

    -- V016 installs a helper-based policy with the same name on some tables.
    EXECUTE format('DROP POLICY IF EXISTS tenant_isolation ON %s', v_qualified);
    EXECUTE format('DROP POLICY IF EXISTS tenant_rls_isolation ON %s', v_qualified);

    EXECUTE format(
      'CREATE POLICY tenant_isolation ON %s FOR ALL '
      'USING (tenant_id::text = NULLIF(current_setting(''app.tenant_id'', true), '''')) '
      'WITH CHECK (tenant_id::text = NULLIF(current_setting(''app.tenant_id'', true), ''''))',
      v_qualified);
  END LOOP;
END;
$$ LANGUAGE PLPGSQL;

-- Applies to whatever exists in the current schema at this point in the chain.
SELECT app.apply_tenant_rls();
