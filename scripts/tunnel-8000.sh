#!/usr/bin/env bash
set -euo pipefail
PID=/tmp/bfl_tunnel_8000.pid

if [[ "${1:-}" == "down" ]]; then
  [[ -f "$PID" ]] && kill "$(cat "$PID")" 2>/dev/null || true
  rm -f "$PID"
  echo "tunnel: down"
  exit 0
fi

[[ -f "$PID" ]] && kill "$(cat "$PID")" 2>/dev/null || true
rm -f "$PID"

TARGET="bfl-onprem"
if ! grep -q 'Host bfl-onprem' "${HOME}/.ssh/config" 2>/dev/null && ! ls "${HOME}/.ssh/conf.d/"*bfl-onprem* >/dev/null 2>&1; then
  if [[ -f /tmp/bfl_onprem_ip ]]; then
    TARGET="bfl@$(cat /tmp/bfl_onprem_ip)"
  fi
fi

ssh -fN -L 8000:127.0.0.1:8000 "$TARGET"
sleep 0.5
PID_SSH="$(lsof -tiTCP:8000 -sTCP:LISTEN | head -n1 || true)"
[[ -n "$PID_SSH" ]] || { echo "failed to start tunnel"; exit 1; }
echo "$PID_SSH" > "$PID"
echo "tunnel: up ($PID_SSH)"
