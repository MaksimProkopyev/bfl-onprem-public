#!/usr/bin/env zsh
set -euo pipefail
PATTERN='ssh -N -L 127.0.0.1:9090:127.0.0.1:19090 -L 127.0.0.1:3000:127.0.0.1:13000 bfl-onprem'
pgrep -f "$PATTERN" >/dev/null 2>&1 || ssh -f -o ExitOnForwardFailure=yes -N \
  -L 127.0.0.1:9090:127.0.0.1:19090 \
  -L 127.0.0.1:3000:127.0.0.1:13000 \
  bfl-onprem
echo "monitoring tunnels: 9090→19090, 3000→13000 OK"
