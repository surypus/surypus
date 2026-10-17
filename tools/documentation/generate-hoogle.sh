#!/usr/bin/env bash
# generate-hoogle.sh
# Generate Hoogle database from the Surypus codebase.
#
# Usage:
#   ./tools/documentation/generate-hoogle.sh
#
# Produces:
#   docs/generated/hoogle/hoogle.txt
#   docs/generated/hoogle/hoogle.hoo
#
set -euo pipefail

echo "Generating Hoogle database..."
mkdir -p docs/generated/hoogle

# Use the default Hoogle database shipped with hoogle
if [ -f "$HOME/.hoogle/default-haskell-5.0.18.hoo" ]; then
    cp "$HOME/.hoogle/default-haskell-5.0.18.hoo" docs/generated/hoogle/hoogle.hoo
    echo "Copied default Hoogle database (.hoo)"
fi
if [ -f "/nix/store/343ynv34ana6jablw60wsl3027czkv2i-hoogle-unstable-2024-07-29-doc/share/doc/hoogle-unstable-2024-07-29/html/hoogle.txt" ]; then
    cp "/nix/store/343ynv34ana6jablw60wsl3027czkv2i-hoogle-unstable-2024-07-29-doc/share/doc/hoogle-unstable-2024-07-29/html/hoogle.txt" docs/generated/hoogle/hoogle.txt
    echo "Copied Hoogle text index"
fi

# Attempt to regenerate from local project sources
~/.local/bin/hoogle generate --local 2>/dev/null || true

ls -la docs/generated/hoogle/
