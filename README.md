# BFL on-prem (bootstrap)
- API: FastAPI + /metrics + Autopilot (noop/k6_smokes)
- Admin-UI: Vite React (страница Autopilot)
- Infra: Prometheus/Grafana/Tempo/Alertmanager/Redis

## Быстрый запуск
docker compose -f docker-compose.infra.yml up -d
python3 -m venv .venv && source .venv/bin/activate && pip install -r requirements.txt
uvicorn services.api.main:app --host 127.0.0.1 --port 8000
# отдельным окном:
python -m services.workers.autopilot_runner
# фронт:
cd services/admin-ui && (pnpm i || npm i) && (pnpm dev --host 127.0.0.1 || npm run dev -- --host 127.0.0.1)

## Проверка
- API metrics: http://127.0.0.1:8000/metrics
- Grafana:     http://127.0.0.1:3000
- Prometheus:  http://127.0.0.1:9090
- Alertmanager:http://127.0.0.1:9093
- Admin-UI:    http://127.0.0.1:5173

## Автопилот (через API)
curl -X POST http://localhost:8000/api/admin/autopilot/tasks -H 'Content-Type: application/json' -d '{"type":"noop","payload":{}}'
