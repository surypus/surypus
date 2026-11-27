#!/usr/bin/env bash
# Deterministic verification gate for Surypus phases 2 and 8.
# Fails on any build/test error or if a LiquidHaskell invariant marker is lost.
set -euo pipefail

cd "$(dirname "$0")/.."

stack --no-nix build --fast
stack --no-nix test

for f in src/Finance/Accounting.hs src/Core/Tax.hs src/Inventory/Stock.hs; do
  grep -q '{-@' "$f" || {
    echo "VERIFICATION_GATE_FAILED: missing LiquidHaskell annotations in $f" >&2
    exit 1
  }
done

echo "VERIFICATION_GATE_OK"
