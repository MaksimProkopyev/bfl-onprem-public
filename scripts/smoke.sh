#!/usr/bin/env zsh
set -euo pipefail
# гарантируем туннель
"$(dirname "$0")/tunnel.sh" >/dev/null

# 1) health
curl -fsS 127.0.0.1:8000/api/health | grep -q '{"ok":true}' && echo "health OK"

# 2) metrics (префикс)
curl -fsS 127.0.0.1:8000/metrics | grep -m1 '^bfl_autopilot_' >/dev/null && echo "metrics OK"

# 3) /autopilot: HEAD=302, HTML, asset=200
curl -fsSI 127.0.0.1:8000/autopilot | grep -q '^HTTP/1.1 302' && echo "head redirect OK"
curl -fsS  127.0.0.1:8000/autopilot/ | grep -qi '<!doctype html>' && echo "html OK"
a="$(curl -fsS 127.0.0.1:8000/autopilot/ | grep -oE '/autopilot/assets/[^"'"'"' >]+\.js' | head -n1 || true)"
[ -n "$a" ] && curl -fsSI "http://127.0.0.1:8000$a" | grep -q '^HTTP/1.1 200' && echo "asset OK" || (echo "⛔ asset missing"; exit 1)

echo "SMOKE: ALL GREEN"
