#!/usr/bin/env bash
set -euo pipefail
# build локально если нужно
if [ -d "services/ui" ]; then
  pushd services/ui >/dev/null
  if [ -f pnpm-lock.yaml ] && command -v pnpm >/dev/null 2>&1; then
    pnpm install --frozen-lockfile
    pnpm build
  else
    npm ci || npm i
    npm run build
  fi
  popd >/dev/null
fi
# rsync dist и перезапуск только api
rsync -az --delete "$PWD/services/ui/dist/" bfl-onprem:/opt/bfl/services/ui/dist/
ssh bfl-onprem 'cd /opt/bfl && docker compose up -d --no-deps --build api'
