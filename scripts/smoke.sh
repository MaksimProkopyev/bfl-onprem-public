#!/usr/bin/env zsh
set -euo pipefail
HOST="127.0.0.1:8000"
pass(){ print -P "%F{2}$1%f"; }
fail(){ print -P "%F{1}⛔ $1%f"; exit 1; }

# 0) туннель
DIR="${0:a:h}"; "$DIR/tunnel.sh" >/dev/null 2>&1 || true

# 1) health
curl -fsS "http://$HOST/api/health" | grep -q '{"ok":true}' && pass "health OK" || fail "health FAIL"

# 2) metrics
curl -fsS "http://$HOST/metrics" | grep -q '^bfl_autopilot_' && pass "metrics OK" || fail "metrics FAIL"

# 3) login
JAR="/tmp/bfl.cookies"; rm -f "$JAR"
USER="${BFL_USER:-admin}"; PASS="${BFL_PASS:-admin}"
curl -fsS -c "$JAR" -d "username=$USER&password=$PASS" -X POST "http://$HOST/api/auth/login" >/dev/null || fail "login FAIL"

# 4) UI HTML (проверяем doctype без учёта регистра либо content-type)
HTML="$(curl -fsS -b "$JAR" "http://$HOST/autopilot/")" || fail "ui html FAIL"
if print -r -- "$HTML" | grep -qi '<!doctype html'; then pass "ui html OK"; else
  HDRS="$(curl -fsSI -b "$JAR" "http://$HOST/autopilot/")"
  echo "$HDRS" | grep -iq '^content-type: *text/html' && pass "ui html OK" || fail "ui html FAIL"
fi

# 5) asset
ASSET="$(print -r -- "$HTML" | sed -n 's#.*src="/autopilot/assets/\([^"]\+\.js\)".*#\1#p' | head -n1)"
[ -n "$ASSET" ] || fail "asset not found in html"
curl -fsSI "http://$HOST/autopilot/assets/$ASSET" | head -n1 | grep -q "200" && pass "asset OK" || fail "asset missing"

pass "SMOKE: ALL GREEN"
