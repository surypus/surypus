#!/usr/bin/env bash
# Authoritative, deterministic migration order for Surypus.
#
# Groups are applied in a fixed sequence; within a group files are ordered by
# numeric version, then by filename. This is the single file list used by both
# the migration runner and the CI verification script.
set -euo pipefail

ROOT=$(cd "$(dirname "$0")/.." && pwd)
cd "$ROOT"

emit() {
  local dir=$1 group=$2
  [ -d "$dir" ] || return 0
  for f in "$dir"/V*.sql; do
    [ -f "$f" ] || continue
    local base version
    base=$(basename "$f")
    version=$(printf '%s' "$base" | sed -En 's/^V([0-9]+)[^_]*__.*/\1/p')
    if [ -z "$version" ]; then
      echo "invalid migration name: $f" >&2
      exit 1
    fi
    printf '%s %s %s\n' "$group" "$version" "$f"
  done
}

# Deliberately excluded: sql/core (legacy RBAC schema variant, conflicts with
# sql/migrations/V001__core_schema.sql), sql/policy, sql/service, sql/archive,
# sql/test, sql/seeds and sql/procedures.sql (handled separately by
# ci-dry-run-mig.sh). See sql/MIGRATIONS.md.
{
  emit sql/migrations 0
  emit sql/event 1
  emit sql/projection 2
  emit sql/aggregate 3
} | LC_ALL=C sort -k2,2n -k1,1n -k3,3 | cut -d' ' -f3-
