#!/usr/bin/env bash
set -euo pipefail
RED=$'\033[31m'; GRN=$'\033[32m'; YLW=$'\033[33m'; NC=$'\033[0m'
ok(){ echo "${GRN}✔${NC} $*"; }
ko(){ echo "${RED}✘${NC} $*"; FAIL=1; }
info(){ echo "${YLW}•${NC} $*"; }
check(){ local msg="$1"; shift; bash -lc "$*" >/dev/null 2>&1 && ok "$msg" || ko "$msg"; }

FAIL=0
info "Files"
for f in \
  services/api/app/config.py \
  services/api/app/auth.py \
  services/api/app/middleware/auth_gate.py \
  services/api/app/middleware/sec_headers.py \
  services/api/app/metrics.py \
  services/api/app/ratelimit.py \
  services/api/app/main.py \
  services/api/Dockerfile \
  docker-compose.yml docker-compose.override.yml \
  scripts/smoke.sh \
  .github/workflows/ci.yml \
  docs/LOGIN.md docs/RUNBOOK.md docs/SECURITY.md \
  services/api/tests
do check "exists: $f" "test -e $f"; done

echo
info "Greps"
check "cookie setter flags" "grep -R 'set_cookie' -n services/api/app/auth.py | grep -E 'secure=.*httponly=.*samesite'"
check "BFL_AUTH_COOKIE env" "grep -R 'BFL_AUTH_COOKIE' -n services/api/app"
check "CSRF double-submit" "grep -R 'X-CSRF-Token' -n services/api/app"
check "AuthGate /api→401" "grep -R 'Unauthorized' -n services/api/app/middleware/auth_gate.py"
check "AuthGate /autopilot→303" "grep -R '/autopilot/login' -n services/api/app/middleware/auth_gate.py"
check "Rate limit (Redis)" "grep -R 'redis' -n services/api/app/ratelimit.py"
check "/livez,/readyz,/api/health" "grep -R '@app.get(\"/livez\")' -n services/api/app/main.py && grep -R '@app.get(\"/readyz\")' -n services/api/app/main.py && grep -R '@app.get(\"/api/health\")' -n services/api/app/main.py"
check "Security headers" "grep -R 'X-Content-Type-Options' -n services/api/app/middleware/sec_headers.py"
check "Prometheus metrics" "grep -R 'bfl_autopilot_' -n services/api/app"
check "Base64 autopadding" "grep -R 'urlsafe_b64decode' -n services/api/app/auth.py && grep -R '=-len' -n services/api/app/auth.py || true"
check "Dockerfile non-root" "grep -R '^USER ' -n services/api/Dockerfile"
check "compose base: no 8000:8000" "! grep -R '8000:8000' -n docker-compose.yml"
check "override: 127.0.0.1:18000:8000" "grep -R '127.0.0.1:18000:8000' -n docker-compose.override.yml"
check "CI workflow present" "test -f .github/workflows/ci.yml"

echo
if [ "$FAIL" -eq 0 ]; then ok "AUDIT: PASS"; else ko "AUDIT: FAIL"; fi
exit "$FAIL"
