from fastapi import FastAPI
from fastapi.staticfiles import StaticFiles
from fastapi.responses import FileResponse, PlainTextResponse
from prometheus_client import Counter, generate_latest, CONTENT_TYPE_LATEST

app = FastAPI()

# Health
@app.get("/api/health")
def health():
    return {"ok": True}

# Prometheus metrics (минимум, с нужным префиксом)
BFL_NOOP = Counter("bfl_autopilot_noop_total", "Autopilot noop counter")
@app.get("/metrics")
def metrics():
    BFL_NOOP.inc()
    return PlainTextResponse(generate_latest(), media_type=CONTENT_TYPE_LATEST)

# PROD UI: статика + SPA-fallback
# ожидаем билд UI в services/ui/dist
app.mount("/autopilot/assets", StaticFiles(directory="services/ui/dist/assets"), name="autopilot_assets")

@app.get("/autopilot", include_in_schema=False)
@app.get("/autopilot/{path:path}", include_in_schema=False)
def autopilot_spa(path: str = ""):
    return FileResponse("services/ui/dist/index.html")
