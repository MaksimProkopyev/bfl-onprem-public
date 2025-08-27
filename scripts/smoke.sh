#!/usr/bin/env bash
set -euo pipefail
BASE="${BASE:-http://127.0.0.1:18000}"

req() { curl -fsS "$@"; }

echo "[1] /livez";       req "$BASE/livez" | grep -q '"ok": true'
echo "[2] /metrics";     req "$BASE/metrics" | grep -q 'bfl_autopilot_http_latency_seconds_bucket'
echo "[3] /readyz";      code=$(curl -s -o /dev/null -w '%{http_code}' "$BASE/readyz"); [[ "$code" =~ 200|503 ]]
echo "[4] /api/health";  req "$BASE/api/health" | grep -q '"status": "ok"'

echo "[5] UI login page (public)"
html="$(curl -fsS "$BASE/autopilot/login" | head -n1)"
echo "$html" | grep -qi "<html" || { echo "ui login FAIL"; exit 2; }

echo "[6] CSRF + login"
h=$(mktemp); c=$(mktemp)
curl -s -D "$h" -c "$c" "$BASE/autopilot/login" >/dev/null
csrf=$(grep -E '\sbfl_csrf\s' "$c" | awk '{print $7}')
[ -n "$csrf" ] || { echo "no csrf"; exit 3; }
code=$(curl -s -o /dev/null -w '%{http_code}' -b "$c" -c "$c" -H "X-CSRF-Token: $csrf" \
  -F 'username=demo' -F 'password=demo' "$BASE/api/auth/login")
[ "$code" = "200" ] || { echo "login failed"; exit 4; }

echo "[7] /api/auth/me (401->200)"
code=$(curl -s -o /dev/null -w '%{http_code}' "$BASE/api/auth/me"); [ "$code" = "401" ]
code=$(curl -s -o /dev/null -w '%{http_code}' -b "$c" "$BASE/api/auth/me"); [ "$code" = "200" ]

echo "SMOKE: ALL GREEN"
