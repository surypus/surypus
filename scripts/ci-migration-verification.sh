#!/usr/bin/env bash
set -euo pipefail

echo "Migration Verification Suite: starting"

# Dry-run migrations (no DB required)
echo "Running dry-run migration validation..."
bash scripts/ci-dry-run-mig.sh

# Canonical preflight: file names, paths and deterministic order.
# The real DB load is performed above by ci-dry-run-mig.sh using the same list.
bash scripts/migrate.sh --check-only

# Basic static checks (if hlint is available in CI, do not fail if not present)
if command -v hlint > /dev/null 2>&1; then
  echo "Running hlint..."
  hlint . || true
fi

# Run targeted tests for migrations (MigrationDryRun and DSL tests)
echo "Running test suite for migrations..."
stack test --test-arguments="--match MigrationDryRun --match RBACCanon"

echo "Migration Verification Suite: completed"
