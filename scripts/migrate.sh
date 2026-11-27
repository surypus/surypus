#!/usr/bin/env bash
# Canonical migration runner (BOOT-03).
#
# Preflight: numeric V<version> names, no duplicate version/file pairs, safe
# paths. Application: pg_try_advisory_lock, per-file transaction, checksum
# ledger in surypus_schema_migrations. Re-running is a no-op; a changed file is
# a hard failure.
set -euo pipefail

ROOT=$(cd "$(dirname "$0")/.." && pwd)
cd "$ROOT"

CONN=${TEST_PG_CONN:-${DATABASE_URL:-}}
CHECK_ONLY=0
while [ $# -gt 0 ]; do
  case "$1" in
    --conn) CONN=$2; shift 2 ;;
    --check-only) CHECK_ONLY=1; shift ;;
    *) echo "unknown argument: $1" >&2; exit 2 ;;
  esac
done

mapfile -t FILES < <(
  cat <(ls sql/migrations/V*.sql 2>/dev/null || true) \
      <(ls sql/event/V*.sql 2>/dev/null || true) \
      <(ls sql/projection/V*.sql 2>/dev/null || true) \
      <(ls sql/aggregate/V*.sql 2>/dev/null || true) \
  | while read -r f; do
      base=$(basename "$f")
      version=$(printf '%s' "$base" | sed -En 's/^V([0-9]+)[^_]*__.*/\1/p')
      if [ -z "$version" ]; then
        echo "invalid migration name: $f" >&2
        exit 1
      fi
      case "$f" in
        sql/migrations/*) g=0 ;; sql/event/*) g=1 ;; sql/projection/*) g=2 ;; sql/aggregate/*) g=3 ;; *) g=4 ;;
      esac
      printf '%s %s %s\n' "$g" "$version" "$f"
    done \
  | sort -k2,2n -k1,1n -k3,3 \
  | cut -d' ' -f3-
)

[ "${#FILES[@]}" -gt 0 ] || { echo "no migration files found" >&2; exit 1; }

declare -A SEEN=()
for f in "${FILES[@]}"; do
  case "$f" in ../*|/*|*'..'*) echo "unsafe migration path: $f" >&2; exit 1 ;; esac
  [ -r "$f" ] || { echo "unreadable migration: $f" >&2; exit 1; }
  key=$(basename "$f")
  if [ -n "${SEEN[$key]:-}" ]; then
    echo "duplicate migration filename: $key (${SEEN[$key]} and $f)" >&2
    exit 1
  fi
  SEEN[$key]=$f
done

echo "MIGRATION_PREFLIGHT_OK: ${#FILES[@]} files"
if [ "$CHECK_ONLY" -eq 1 ]; then
  exit 0
fi

if [ -z "$CONN" ]; then
  echo "DATABASE_URL, TEST_PG_CONN or --conn is required" >&2
  exit 2
fi

psql "$CONN" -v ON_ERROR_STOP=1 -q -c \
  "CREATE TABLE IF NOT EXISTS surypus_schema_migrations (
     version TEXT NOT NULL,
     filename TEXT PRIMARY KEY,
     checksum TEXT NOT NULL,
     applied_at TIMESTAMPTZ NOT NULL DEFAULT now()
   )"

lock=$(psql "$CONN" -At -v ON_ERROR_STOP=1 -c "SELECT pg_try_advisory_lock(123456789)")
[ "$lock" = "t" ] || { echo "another migration runner holds the advisory lock" >&2; exit 3; }
trap 'psql "$CONN" -q -c "SELECT pg_advisory_unlock(123456789)" >/dev/null 2>&1 || true' EXIT

applied=0
for f in "${FILES[@]}"; do
  base=$(basename "$f")
  version=$(printf '%s' "$base" | sed -En 's/^V([0-9]+)[^_]*__.*/\1/p')
  sum=$(sha256sum "$f" | cut -d' ' -f1)
  prev=$(psql "$CONN" -At -v ON_ERROR_STOP=1 -c \
    "SELECT checksum FROM surypus_schema_migrations WHERE filename = '$base'")
  if [ -n "$prev" ]; then
    [ "$prev" = "$sum" ] || { echo "checksum mismatch for $base" >&2; exit 4; }
    continue
  fi
  psql "$CONN" -v ON_ERROR_STOP=1 -1 -q -f "$f"
  psql "$CONN" -v ON_ERROR_STOP=1 -q -c \
    "INSERT INTO surypus_schema_migrations (version, filename, checksum) VALUES ('$version', '$base', '$sum')"
  applied=$((applied + 1))
done

echo "MIGRATION_RUN_OK: applied=$applied total=${#FILES[@]}"
