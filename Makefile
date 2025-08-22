SHELL := /bin/bash
COMPOSE_FILE ?= docker-compose.infra.yml
API_MODULE   ?= services.api.main:app
API_PORT     ?= 8000
UI_DIR       ?= services/admin-ui
.PHONY: infra infra-down api worker ui smoke-noop smoke-k6
infra: ; docker compose -f $(COMPOSE_FILE) up -d
infra-down: ; docker compose -f $(COMPOSE_FILE) down
api: ; uvicorn $(API_MODULE) --host 127.0.0.1 --port $(API_PORT)
worker: ; python -m services.workers.autopilot_runner
ui: ; cd $(UI_DIR) && (pnpm i || npm i) && (pnpm dev --host 127.0.0.1 || npm run dev -- --host 127.0.0.1)
smoke-noop: ; curl -s -X POST http://localhost:$(API_PORT)/api/admin/autopilot/tasks -H 'Content-Type: application/json' -d '{"type":"noop","payload":{}}' | jq -r '.id' || true
smoke-k6: ; curl -s -X POST http://localhost:$(API_PORT)/api/admin/autopilot/tasks -H 'Content-Type: application/json' -d '{"type":"k6_smokes","payload":{"base_url":"http://localhost:$(API_PORT)"}}' | jq -r '.id' || true
