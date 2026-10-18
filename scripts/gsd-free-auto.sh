#!/usr/bin/env bash
# gsd-free-auto.sh — unattended `gsd` runs on the ChatGPT-account Codex backend.
#
# GSD has no bundled `openai-codex` provider, and its `custom-openai` provider
# cannot set a `base_url`. So the path here is:
#
#   GSD (provider "codex", api openai-completions)
#     -> codex-openai-proxy.py  (127.0.0.1:8787/v1, OpenAI-shaped)
#       -> chatgpt.com/backend-api/codex/responses
#         (credential: ~/.codex/auth.json, ChatGPT OAuth — refreshed on demand)
#
# No API key is needed and no secret is written outside ~/.codex/auth.json.
#
# Usage:  ./scripts/gsd-free-auto.sh headless quick "<task>"
#         ./scripts/gsd-free-auto.sh headless auto
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$REPO_ROOT"

PROXY_HOST="${CODEX_PROXY_HOST:-127.0.0.1}"
PROXY_PORT="${CODEX_PROXY_PORT:-8787}"
SETTINGS="$HOME/.gsd/agent/settings.json"
PROXY_SCRIPT="$REPO_ROOT/scripts/codex-openai-proxy.py"

if [ ! -f "$SETTINGS" ]; then
    echo "missing $SETTINGS" >&2
    exit 1
fi
if [ ! -f "$PROXY_SCRIPT" ]; then
    echo "missing $PROXY_SCRIPT" >&2
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

if [ "$PROVIDER" != "codex/gpt-6-luna" ]; then
    echo "expected codex/gpt-6-luna, refusing to run unattended" >&2
    exit 1
fi

# Start the proxy when it is not already listening.
if ! curl -sf --max-time 4 "http://${PROXY_HOST}:${PROXY_PORT}/healthz" >/dev/null 2>&1; then
    echo "starting codex-openai-proxy on ${PROXY_HOST}:${PROXY_PORT}" >&2
    mkdir -p "$HOME/.cache"
    CODEX_PROXY_HOST="$PROXY_HOST" CODEX_PROXY_PORT="$PROXY_PORT" \
        setsid python3 "$PROXY_SCRIPT" >>"$HOME/.cache/codex-openai-proxy.log" 2>&1 &
    for _ in $(seq 1 20); do
        if curl -sf --max-time 4 "http://${PROXY_HOST}:${PROXY_PORT}/healthz" >/dev/null 2>&1; then
            break
        fi
        sleep 0.5
    done
fi

if ! curl -sf --max-time 4 "http://${PROXY_HOST}:${PROXY_PORT}/healthz" >/dev/null 2>&1; then
    echo "codex-openai-proxy did not come up; see ~/.cache/codex-openai-proxy.log" >&2
    exit 1
fi

exec gsd "$@"
