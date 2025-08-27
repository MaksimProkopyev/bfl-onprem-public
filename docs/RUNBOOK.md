# RUNBOOK
- `/livez` — всегда 200.
- `/readyz` — 200 при доступном Redis, иначе 503.
- `/api/health` — {status, version, build_sha, redis}
- Сеть: base compose без публикации; override `127.0.0.1:18000:8000`.
