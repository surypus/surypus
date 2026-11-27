#!/usr/bin/env bash
# Verifies the Phase 1 server contract without a running PostgreSQL:
#  - missing DB_HOST fails fast
#  - /api/v1/health returns 503 when the DB port is closed
#  - /api/v1/health returns 200 when a TCP listener exists
#  - unknown routes return 404
set -euo pipefail

BIN=${1:-$(stack --no-nix path --local-install-root)/bin/surypus-server}
WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT

if env -u DB_HOST "$BIN" >"$WORK/fail.log" 2>&1; then
  echo "FAIL: server started without DB_HOST"
  exit 1
fi
grep -q "DB_HOST is required" "$WORK/fail.log"

port_db=55432
port_http=18081
DB_HOST=127.0.0.1 DB_PORT=$port_db PORT=$port_http "$BIN" >"$WORK/no-db.log" 2>&1 &
srv=$!
trap 'kill "$srv" 2>/dev/null || true; rm -rf "$WORK"' EXIT
sleep 2
code=$(curl -s -o "$WORK/no-db.json" -w '%{http_code}' "http://127.0.0.1:$port_http/api/v1/health")
grep -q '"status":"unavailable"' "$WORK/no-db.json"
[ "$code" = 503 ]
kill "$srv" 2>/dev/null || true
wait "$srv" 2>/dev/null || true

python3 - "$port_db" <<'PY' &
import socket, sys, time
s = socket.socket()
s.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
s.bind(('127.0.0.1', int(sys.argv[1])))
s.listen(5)
time.sleep(15)
PY
listener=$!
sleep 1
port_http=18082
DB_HOST=127.0.0.1 DB_PORT=$port_db PORT=$port_http "$BIN" >"$WORK/db.log" 2>&1 &
srv2=$!
sleep 2
code=$(curl -s -o "$WORK/db.json" -w '%{http_code}' "http://127.0.0.1:$port_http/api/v1/health")
grep -q '"status":"ok"' "$WORK/db.json"
[ "$code" = 200 ]
code=$(curl -s -o /dev/null -w '%{http_code}' "http://127.0.0.1:$port_http/api/v1/nope")
[ "$code" = 404 ]
kill "$srv2" "$listener" 2>/dev/null || true
wait "$srv2" 2>/dev/null || true
wait "$listener" 2>/dev/null || true
echo "SERVER_HEALTH_OK"
