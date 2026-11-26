#!/usr/bin/env bash
# CI migration verification: actually load the migration chain against Postgres.
#
# Historically this script only checked that migration files were non-empty, so
# real SQL errors (missing sequences, reserved-word columns, wrong FK targets,
# partitioned-table PK rules, function-parameter ordering) slipped into CI. Now
# it performs a true ordered load when a Postgres connection is available.
set -uo pipefail

echo "Migration verification: loading the full chain against Postgres (if available)"

# Collect every migration file and sort by version prefix (V<num>__).
mapfile -t FILES < <(cat <(ls sql/migrations/V*.sql 2>/dev/null) \
                          <(ls sql/event/V*.sql 2>/dev/null) \
                          <(ls sql/projection/V*.sql 2>/dev/null) \
                          <(ls sql/aggregate/V*.sql 2>/dev/null) \
                          | sort -t_ -k1 -n)

if [ -z "${TEST_PG_CONN:-}" ]; then
  if command -v psql >/dev/null 2>&1 && [ -n "${PGHOST:-}" ]; then
    TEST_PG_CONN="postgres://${PGUSER:-postgres}:${PGPASSWORD:-}@${PGHOST}:${PGPORT:-5432}/${PGDATABASE:-postgres}"
  fi
fi

if [ -z "${TEST_PG_CONN:-}" ]; then
  echo "WARN: no Postgres connection available (set TEST_PG_CONN or PGHOST)."
  echo "WARN: skipping real migration load — CI MUST provide a Postgres service to catch SQL errors."
  # Still fail the build if any migration file is empty (the old cheap check).
  errors=0
  for f in "${FILES[@]}"; do
    [ -s "$f" ] || { echo "ERR: $f is empty"; errors=$((errors+1)); }
  done
  [ "$errors" -eq 0 ] && echo "Non-empty check passed (DB load SKIPPED)." || exit 1
  exit 0
fi

conn="$TEST_PG_CONN"
tmp_sql=$(mktemp)
trap 'rm -f "$tmp_sql"' EXIT
{
  echo "BEGIN;"
  for f in "${FILES[@]}"; do
    echo "-- === $f ==="
    cat "$f"
    echo ";"
  done
  echo "ROLLBACK;"
} > "$tmp_sql"

echo "Loading ${#FILES[@]} migration files into a transaction (rolled back)..."
if psql "$conn" -v ON_ERROR_STOP=1 -f "$tmp_sql" >/tmp/ci_mig_load.log 2>&1; then
  echo "Migration chain loads cleanly (ALL_MIGRATIONS_LOAD_OK)."
  exit 0
else
  echo "Migration load FAILED. Full psql log (first 80 lines):"
  sed -n '1,80p' /tmp/ci_mig_load.log
  exit 1
fi
