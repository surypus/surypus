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

# Prefer a user-local or venv mkdocs that carries the pymdownx extensions;
# the distro package often lacks them. Fall back to whatever is on PATH.
MKDOCS=""
for candidate in "$HOME/.local/bin/mkdocs" "$(command -v mkdocs || true)"; do
    [ -n "$candidate" ] && [ -x "$candidate" ] || continue
    if "$candidate" --version >/dev/null 2>&1; then
        MKDOCS="$candidate"
        break
    fi
done
if [ -z "$MKDOCS" ]; then
    echo "mkdocs not found; install it with: pip install mkdocs mkdocs-material pymdown-extensions"
    exit 1
fi
# The distro mkdocs frequently lacks the pymdownx extensions this config uses.
# If none of the candidates can import them, build a throwaway venv from the
# pinned docs requirements so the check is reproducible anywhere.
MKDOCS_PY="$(head -1 "$MKDOCS" 2>/dev/null | sed -e 's|^#![[:space:]]*||' -e 's|[[:space:]]*$||')"
if ! { [ -n "$MKDOCS_PY" ] && [ -x "$MKDOCS_PY" ] && "$MKDOCS_PY" -c "import pymdownx, markdown" >/dev/null 2>&1; }; then
    echo "no mkdocs with pymdownx found; building one from docs/requirements.txt"
    VENV_DIR="${DOCS_VENV:-$REPO_ROOT/.venv-docs}"
    if [ ! -x "$VENV_DIR/bin/mkdocs" ]; then
        python3 -m venv "$VENV_DIR"
        "$VENV_DIR/bin/pip" install --quiet --upgrade pip
        "$VENV_DIR/bin/pip" install --quiet -r docs/requirements.txt
    fi
    if "$VENV_DIR/bin/python" -c "import pymdownx" >/dev/null 2>&1; then
        MKDOCS="$VENV_DIR/bin/mkdocs"
    else
        echo "failed to provision a mkdocs with the required extensions"
        exit 1
    fi
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