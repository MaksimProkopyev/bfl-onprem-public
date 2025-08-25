#!/usr/bin/env zsh
set -euo pipefail

# Паттерн существующего туннеля
PATTERN='ssh -N -L 127.0.0.1:8000:127.0.0.1:18000 bfl-onprem'

# Если туннель не запущен — стартуем.
if ! pgrep -f "$PATTERN" >/dev/null 2>&1; then
  # освободим локальный порт на всякий случай (идемпотентно)
  lsof -tiTCP:8000 -sTCP:LISTEN | xargs -r kill -9 || true

  # вариант 1 (предпочтительно): ssh сам уходит в фон
  if command -v ssh >/dev/null 2>&1; then
    ssh -f -o ExitOnForwardFailure=yes -N \
      -L 127.0.0.1:8000:127.0.0.1:18000 bfl-onprem
  else
    # запасной вариант с nohup, тоже без disown
    nohup ssh -o ExitOnForwardFailure=yes -N \
      -L 127.0.0.1:8000:127.0.0.1:18000 bfl-onprem \
      >>/tmp/bfl-tunnel.log 2>&1 &
  fi
  # короткая пауза для установления форварда
  sleep 0.5
fi

# верифицируем локальный листенер
if lsof -nP -iTCP:8000 -sTCP:LISTEN >/dev/null 2>&1; then
  echo "tunnel: 127.0.0.1:8000 → bfl-onprem:127.0.0.1:18000 OK"
else
  echo "⛔ tunnel failed to start" >&2
  exit 1
fi
