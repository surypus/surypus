#!/usr/bin/env bash
# generate-inventory.sh — generate documentation inventory from Surypus src/
# Calls generate-inventory.py with all arguments passed through.
exec python3 "$(dirname "$0")/generate-inventory.py" "$@"
