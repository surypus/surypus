#!/usr/bin/env bash
# CI-level tenant RLS isolation check (Phase 6 Auth & RBAC).
#
# Usage: TEST_PG_CONN=postgres://user@localhost/db bash scripts/check-tenant-rls.sh
#
# Creates an isolated schema with two tenants and one row per tenant in each
# scoped table, applies the real V402 migration to that schema, then reads every
# table as a non-owner role with app.tenant_id set to each tenant in turn.
# Owners and superusers bypass RLS, so the unprivileged probe role is essential:
# checking as the CI postgres user would pass even with no policies at all.
set -euo pipefail

ROOT=$(cd "$(dirname "$0")/.." && pwd)
cd "$ROOT"

: "${TEST_PG_CONN:?TEST_PG_CONN is required (e.g. postgres://user@localhost/db)}"
command -v psql >/dev/null 2>&1 || { echo "psql is required" >&2; exit 2; }

MIGRATION=sql/migrations/V402__tenant_rls.sql
[ -r "$MIGRATION" ] || { echo "missing $MIGRATION" >&2; exit 2; }

conn="$TEST_PG_CONN"
SCHEMA="tenant_rls_check_$$"
ROLE="surypus_rls_probe_$$"

cleanup() {
  psql "$conn" -q -v ON_ERROR_STOP=0 <<SQL >/dev/null 2>&1 || true
DROP SCHEMA IF EXISTS "$SCHEMA" CASCADE;
DROP ROLE IF EXISTS "$ROLE";
SQL
}
trap cleanup EXIT

echo "Tenant RLS isolation check: schema=$SCHEMA probe_role=$ROLE"

psql "$conn" -v ON_ERROR_STOP=1 -q <<SQL
DROP SCHEMA IF EXISTS "$SCHEMA" CASCADE;
CREATE SCHEMA "$SCHEMA";

DO \$\$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = '$ROLE') THEN
    CREATE ROLE "$ROLE" NOLOGIN NOSUPERUSER NOBYPASSRLS;
  END IF;
END
\$\$;
ALTER ROLE "$ROLE" NOSUPERUSER NOBYPASSRLS;
GRANT USAGE ON SCHEMA "$SCHEMA" TO "$ROLE";

-- Stand-ins for the production tenant-scoped tables. BIGINT ids match the
-- value DAL.Database puts into app.tenant_id.
CREATE TABLE "$SCHEMA".tenants (
  tenant_id BIGINT PRIMARY KEY,
  name TEXT NOT NULL
);
CREATE TABLE "$SCHEMA".bills (id BIGINT PRIMARY KEY, tenant_id BIGINT NOT NULL, number TEXT);
CREATE TABLE "$SCHEMA".payments (id BIGINT PRIMARY KEY, tenant_id BIGINT NOT NULL, amount NUMERIC(18,2));
CREATE TABLE "$SCHEMA".accounts (id BIGINT PRIMARY KEY, tenant_id BIGINT NOT NULL, code TEXT);
CREATE TABLE "$SCHEMA".event_store (id BIGINT PRIMARY KEY, tenant_id BIGINT NOT NULL, event_type TEXT);

GRANT SELECT, INSERT ON ALL TABLES IN SCHEMA "$SCHEMA" TO "$ROLE";

INSERT INTO "$SCHEMA".tenants (tenant_id, name) VALUES (1, 'Tenant One'), (2, 'Tenant Two');

-- Seed as owner (owners bypass RLS): exactly one row per tenant per table.
INSERT INTO "$SCHEMA".bills       VALUES (1, 1, 'BILL-T1'), (2, 2, 'BILL-T2');
INSERT INTO "$SCHEMA".payments    VALUES (1, 1, 10.00), (2, 2, 20.00);
INSERT INTO "$SCHEMA".accounts    VALUES (1, 1, 'ACC-T1'), (2, 2, 'ACC-T2');
INSERT INTO "$SCHEMA".event_store VALUES (1, 1, 'Created'), (2, 2, 'Created');
SQL

# Apply the actual migration. search_path makes current_schema() resolve to the
# probe schema, so the migration's final call targets these tables (and the
# applier can be re-run after event_store exists in the real chain).
PGOPTIONS="-c search_path=${SCHEMA},public" \
  psql "$conn" -v ON_ERROR_STOP=1 -q -f "$MIGRATION"

echo "RLS state (name relrowsecurity policies):"
rls_state=$(psql "$conn" -At -v ON_ERROR_STOP=1 <<SQL
SELECT format('%s relrowsecurity=%s policies=%s', c.relname, c.relrowsecurity,
       (SELECT count(*) FROM pg_policies p
        WHERE p.schemaname = '$SCHEMA' AND p.tablename = c.relname))
FROM pg_class c
JOIN pg_namespace n ON n.oid = c.relnamespace
WHERE n.nspname = '$SCHEMA'
  AND c.relname IN ('bills','payments','accounts','event_store')
ORDER BY c.relname;
SQL
)
echo "$rls_state"
[ "$(printf '%s\n' "$rls_state" | grep -c 'relrowsecurity=t policies=1')" -eq 4 ] || {
  echo "FAIL: RLS not enabled with exactly one policy on all four tables" >&2
  exit 1
}

# All reads/writes below happen as a non-owner, non-superuser role.
psql "$conn" -v ON_ERROR_STOP=1 -q <<SQL
SET ROLE "$ROLE";

DO \$\$
DECLARE
  v_tenant BIGINT;
  v_count BIGINT;
  v_tables TEXT[] := ARRAY['bills','payments','accounts','event_store'];
  v_table TEXT;
BEGIN
  FOREACH v_tenant IN ARRAY ARRAY[1::BIGINT, 2::BIGINT] LOOP
    PERFORM set_config('app.tenant_id', v_tenant::TEXT, TRUE);
    FOREACH v_table IN ARRAY v_tables LOOP
      EXECUTE format('SELECT count(*) FROM %I.%I', '$SCHEMA', v_table) INTO v_count;
      IF v_count <> 1 THEN
        RAISE EXCEPTION 'RLS leak: tenant % sees % rows in % (expected 1)', v_tenant, v_count, v_table;
      END IF;
      EXECUTE format('SELECT count(*) FROM %I.%I WHERE tenant_id <> %s', '$SCHEMA', v_table, v_tenant)
        INTO v_count;
      IF v_count <> 0 THEN
        RAISE EXCEPTION 'RLS leak: tenant % sees % foreign rows in %', v_tenant, v_count, v_table;
      END IF;
      RAISE NOTICE 'PASS tenant=% table=% own_rows=1 foreign_rows=0', v_tenant, v_table;
    END LOOP;
  END LOOP;

  -- No tenant context (missing/empty GUC) must be default-deny.
  PERFORM set_config('app.tenant_id', '', TRUE);
  FOREACH v_table IN ARRAY v_tables LOOP
    EXECUTE format('SELECT count(*) FROM %I.%I', '$SCHEMA', v_table) INTO v_count;
    IF v_count <> 0 THEN
      RAISE EXCEPTION 'RLS leak: empty tenant context sees % rows in %', v_count, v_table;
    END IF;
  END LOOP;
  RAISE NOTICE 'PASS empty tenant context sees 0 rows in all four tables';

  -- WITH CHECK must also block cross-tenant writes.
  PERFORM set_config('app.tenant_id', '1', TRUE);
  BEGIN
    EXECUTE format('INSERT INTO %I.bills (id, tenant_id, number) VALUES (99, 2, ''CROSS-TENANT'')', '$SCHEMA');
    RAISE EXCEPTION 'RLS leak: cross-tenant INSERT was allowed';
  EXCEPTION WHEN insufficient_privilege THEN
    NULL;
  END;
  RAISE NOTICE 'PASS cross-tenant INSERT blocked by WITH CHECK';
END
\$\$;
RESET ROLE;
SQL

echo "TENANT_RLS_ISOLATION_OK"
