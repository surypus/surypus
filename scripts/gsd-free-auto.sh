#!/usr/bin/env bash
# gsd-free-auto.sh — unattended `gsd auto` on a Cursor free plan.
#
# Cursor's free plan accepts only the `auto` model: every named model is
# rejected with "Named models unavailable Free plans can only use Auto".
# That means this wrapper needs no API keys at all — it makes sure the
# cursor-agent provider is selected and hands control to GSD.
#
# No secrets are read here; the AutonomousSecretsStore stays empty and unused.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$REPO_ROOT"

SETTINGS="$HOME/.gsd/agent/settings.json"

if [ ! -f "$SETTINGS" ]; then
    echo "missing $SETTINGS" >&2
    exit 1
fi

PROVIDER="$(python3 - "$SETTINGS" <<'PY'
import json, sys
try:
    s = json.load(open(sys.argv[1]))
    print(f"{s.get('defaultProvider','')}/{s.get('defaultModel','')}")
except Exception:
    print("unknown/unknown")
PY
)"

echo "gsd provider: ${PROVIDER}" >&2

case "$PROVIDER" in
    cursor-agent/*)
        ;;
    *)
        echo "provider is not cursor-agent; refusing to run unattended" >&2
        exit 1
        ;;
esac

exec gsd auto --mode auto