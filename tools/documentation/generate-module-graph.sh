#!/usr/bin/env bash
# generate-module-graph.sh
# Generate Mermaid module dependency graph from Surypus src/
#
# Usage:
#   ./tools/documentation/generate-module-graph.sh > docs/generated/graphs/modules.mmd
#
# Parses module declarations and import statements in src/ to produce
# a flowchart TD graph. The output is deterministic and source-derived.
set -euo pipefail

SRC_DIR="${1:-src}"
OUTPUT="${2:-docs/generated/graphs/modules.mmd}"

mkdir -p "$(dirname "$OUTPUT")"

# Collect all .hs files
mapfile -t FILES < <(find "$SRC_DIR" -name '*.hs' -type f | sort)

cat > "$OUTPUT" <<'HEADER'
---
flowchart TD
    title "Surypus Module Dependency Graph (generated from src/)"
    ---
HEADER

# Build edges: for each file, extract module name and import targets
declare -A MODFILE
EDGES=()

for f in "${FILES[@]}"; do
    # Extract module declaration: module Foo.Bar where ...
    MOD=$(grep -oE '^module\s+[A-Z][A-Za-z0-9.]*' "$f" 2>/dev/null | sed 's/^module\s\+//' | head -1 || true)
    if [ -z "$MOD" ]; then continue; fi
    MODFILE["$MOD"]="$f"
    # Extract imports
    while IFS= read -r line; do
        IMP=$(echo "$line" | grep -oE '^import\s+[A-Z][A-Za-z0-9.<>()]*' | sed 's/^import\s\+//' | head -1 || true)
        if [ -n "$IMP" ]; then
            EDGES+=("$MOD|$IMP")
        fi
    done < <(grep -E '^import\s+[A-Z]' "$f" 2>/dev/null || true)
done

# Deduplicate and write edges
printf '%s\n' "${EDGES[@]}" 2>/dev/null | sort -u | while IFS='|' read -r from to; do
    # Sanitize: only allow module-like chars
    from_s=$(echo "$from" | tr -cd 'A-Za-z0-9.')
    to_s=$(echo "$to" | tr -cd 'A-Za-z0-9.')
    if [ -n "$from_s" ] && [ -n "$to_s" ]; then
        echo "    ${from_s} --> ${to_s}"
    fi
done >> "$OUTPUT"

cat >> "$OUTPUT" <<'FOOTER'

    subgraph "Core"
        end
    subgraph "Surypus"
        end
    subgraph "Finance"
        end
    subgraph "Inventory"
        end
    subgraph "CRM"
        end
    subgraph "API"
        end
    subgraph "DAL"
        end
    subgraph "Infrastructure"
        end
    subgraph "Security"
        end
FOOTER

echo "Generated $OUTPUT with $(wc -l < "$OUTPUT") lines"
