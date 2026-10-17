#!/usr/bin/env bash
# check-docs.sh
# Validate the Surypus documentation pipeline.
#
# Checks:
#   1. MkDocs site builds without warnings (--strict)
#   2. Module graph generates without errors
#   3. Documentation inventory is valid JSON
#   4. Coverage report is present
#   5. No generated file is manually modified (git check)
#
# Usage:
#   ./tools/documentation/check-docs.sh
set -uo pipefail

ERRORS=0
REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$REPO_ROOT"

# mkdocs is usually on PATH (pip install --user or a venv); fall back to the
# common user-local location rather than a hardcoded machine path.
MKDOCS="$(command -v mkdocs || true)"
if [ -z "$MKDOCS" ] && [ -x "$HOME/.local/bin/mkdocs" ]; then
    MKDOCS="$HOME/.local/bin/mkdocs"
fi
if [ -z "$MKDOCS" ]; then
    echo "mkdocs not found; install it with: pip install mkdocs mkdocs-material"
    exit 1
fi

echo "=== Surypus Documentation Validation ==="
echo
echo "mkdocs: $MKDOCS"
echo

echo "[1/5] MkDocs build (--strict)..."
if "$MKDOCS" build --strict > /tmp/mkdocs-check.log 2>&1; then
    echo "✓ MkDocs build passed"
else
    echo "✗ MkDocs build failed"
    tail -20 /tmp/mkdocs-check.log
    ERRORS=$((ERRORS+1))
fi
echo

echo "[2/5] Module graph..."
if bash ./tools/documentation/generate-module-graph.sh src docs/generated/graphs/modules.mmd >/dev/null 2>&1; then
    LINES=$(wc -l < docs/generated/graphs/modules.mmd)
    echo "✓ Module graph generated ($LINES lines)"
else
    echo "✗ Module graph generation failed"
    ERRORS=$((ERRORS+1))
fi
echo

echo "[3/5] Documentation inventory..."
if python3 tools/documentation/generate-inventory.py >/dev/null 2>&1 \
   && python3 -c "import json; json.load(open('docs/generated/inventory/modules.json'))" 2>/dev/null; then
    echo "✓ Documentation inventory is valid JSON"
else
    echo "✗ Inventory generation failed or produced invalid JSON"
    ERRORS=$((ERRORS+1))
fi
echo

echo "[4/5] Coverage report..."
if [ -f docs/generated/inventory/coverage.json ]; then
    python3 -c "
import json
c = json.load(open('docs/generated/inventory/coverage.json'))
cov = c['coverage']
print(f\"✓ Coverage: {cov['percentage']}% ({cov['documented']}/{cov['modules']} modules)\")
"
else
    echo "✗ coverage.json not found"
    ERRORS=$((ERRORS+1))
fi
echo

echo "[5/5] Generated files not manually modified..."
if git diff --name-only -- docs/generated/ | grep -q .; then
    echo "✗ Generated files have uncommitted modifications:"
    git diff --name-only -- docs/generated/
    ERRORS=$((ERRORS+1))
else
    echo "✓ Generated files are clean (no manual modifications)"
fi
echo

echo "=== Result: $ERRORS error(s) ==="
if [ "$ERRORS" -gt 0 ]; then
    exit 1
fi