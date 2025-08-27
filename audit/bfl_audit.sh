#!/usr/bin/env zsh
set -euo pipefail
ok(){ print -P "%F{76}✅ $1%f"; }; bad(){ print -P "%F{196}❌ $1%f"; }
have(){ [ -e "$1" ] && ok "file: $1" || bad "file: $1"; }

print "• Files"
for f in \
  services/api/app/config.py \
  services/api/app/auth.py \
  services/api/app/metrics.py \
  services/api/app/ratelimit.py \
  services/api/app/main.py \
  services/api/app/middleware/auth_gate.py \
  services/api/app/middleware/sec_headers.py \
  services/api/app/middleware/__init__.py \
  services/api/Dockerfile \
  docker-compose.yml \
  docker-compose.override.yml \
  scripts/smoke.sh \
  .github/workflows/ci.yml \
  docs/LOGIN.md \
  docs/RUNBOOK.md \
  docs/SECURITY.md \
  services/api/tests \
  e2e \
; do have "$f"; done

print "\n• Greps"
# cookie setter — все флаги в одной строке
grep -Rns -E 'set_cookie\([^)]*secure=.*httponly=.*samesite=.*domain=.*path=.*\)' services/api/app/auth.py >/dev/null \
  && ok "cookie setter flags" || bad "cookie setter flags"

# ENV для cookie
grep -Rns -E 'BFL_AUTH_COOKIE|BFL_COOKIE_(SECURE|HTTPONLY|SAMESITE|DOMAIN|PATH)' services/api/app/config.py >/dev/null \
  && ok "BFL_AUTH_COOKIE env" || bad "BFL_AUTH_COOKIE env"

# CSRF double-submit: наличие cookies bfl_csrf + заголовка X-CSRF-Token где-либо в app
( grep -Rns -E 'bfl_csrf' services/api/app >/dev/null && grep -Rns -E 'X-CSRF-Token' services/api/app >/dev/null ) \
  && ok "CSRF double-submit" || bad "CSRF double-submit"

# Endpoints: допускаем " и '
grep -Rns -E '@app\.get\(\s*["'\'']/livez["'\'']\s*\)' services/api/app/main.py >/dev/null && ok "/livez" || bad "/livez"
grep -Rns -E '@app\.get\(\s*["'\'']/readyz["'\'']\s*\)' services/api/app/main.py >/dev/null && ok "/readyz" || bad "/readyz"
# /api/health может быть и router.get(...)
grep -Rns -E '(@app|router)\.get\(\s*["'\'']/api/health["'\'']\s*\)' services/api/app/main.py services/api/app/auth.py 2>/dev/null \
  && ok "/api/health" || bad "/api/health"

# Security headers
grep -Rns -E 'X-Content-Type-Options.*nosniff' services/api/app/middleware/sec_headers.py >/dev/null \
  && ok "Security headers: nosniff" || bad "Security headers: nosniff"
grep -Rns -E 'Referrer-Policy.*no-referrer' services/api/app/middleware/sec_headers.py >/dev/null \
  && ok "Security headers: no-referrer" || bad "Security headers: no-referrer"

# AuthGate: допускаем разные формулировки — JSONResponse + 401 и RedirectResponse + 303
grep -Rns -E 'JSONResponse\([^)]*status_code\s*=\s*401' services/api/app/middleware/auth_gate.py >/dev/null \
  && ok "AuthGate /api→401" || bad "AuthGate /api→401"
grep -Rns -E 'RedirectResponse\([^)]*status_code\s*=\s*303' services/api/app/middleware/auth_gate.py >/dev/null \
  && ok "AuthGate /autopilot→303" || bad "AuthGate /autopilot→303"

# Rate-limit: наличие get_limiter и redis.*async, плюс хук в /api/auth/login
( grep -Rns -E 'def\s+get_limiter' services/api/app/ratelimit.py >/dev/null && \
  grep -Rns -E 'redis(\.asyncio)?' services/api/app/ratelimit.py >/dev/null ) \
if ; then
if   ok "Rate limit (Redis)"; then
  ok "Rate limit (Redis)"
else
  bad "Rate limit (Redis)"
fi
else
  bad "Rate limit (Redis)"
fi
if ( grep -Rns -E "async def login" services/api/app/auth.py >/dev/null; then
if   ok "Rate limit hook in login"; then
  ok "Rate limit hook in login"
else
  bad "Rate limit hook in login"
fi
else
  bad "Rate limit hook in login"
fi
  && ok "Rate limit hook in login" || bad "Rate limit hook in login"

# Prometheus
grep -Rns -E 'bfl_autopilot_http_latency_seconds' services/api/app/metrics.py >/dev/null \
  && ok "Prometheus metrics" || bad "Prometheus metrics"

# Base64 автопаддинг
grep -Rns -E '_b64pad|=+\"?\\)?$' services/api/app/auth.py >/dev/null \
  && ok "Base64 autopadding" || bad "Base64 autopadding"

# Docker/compose
grep -Rns '^USER ' services/api/Dockerfile | grep -vq root && ok "Dockerfile non-root" || bad "Dockerfile USER"
! grep -Rns '8000:8000' docker-compose.yml >/dev/null && ok "compose base: no 8000:8000" || bad "compose base publishes 8000"
grep -Rns -E '127\.0\.0\.1:18000:8000' docker-compose.override.yml >/dev/null && ok "override: 127.0.0.1:18000:8000" || bad "override loopback"

print "\n✔ AUDIT: DONE"
