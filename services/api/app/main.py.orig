from fastapi import FastAPI
from fastapi.responses import JSONResponse, FileResponse, Response
from fastapi.staticfiles import StaticFiles
from prometheus_client import CollectorRegistry, CONTENT_TYPE_LATEST, generate_latest, Counter
import os

app = FastAPI()

# Metrics
REG = CollectorRegistry()
health_ctr = Counter("bfl_autopilot_health_checks_total", "Health checks", registry=REG)

# UI root relative to this file: services/api/app/main.py -> ../ui/dist
UI_ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "../ui/dist"))
ASSETS_DIR = os.path.join(UI_ROOT, "assets")
if os.path.isdir(ASSETS_DIR):
    app.mount("/autopilot/assets", StaticFiles(directory=ASSETS_DIR), name="autopilot_assets")

@app.get("/api/health")
def health():
    health_ctr.inc()
    return {"ok": True}

@app.get("/metrics")
def metrics():
    data = generate_latest(REG)
    return Response(content=data, media_type=CONTENT_TYPE_LATEST)

# SPA fallback
@app.get("/autopilot")
@app.get("/autopilot/{path:path}")
def spa(path: str = ""):
    index_path = os.path.join(UI_ROOT, "index.html")
    if os.path.isfile(index_path):
        return FileResponse(index_path)
    return JSONResponse({"detail": "UI build not found"}, status_code=404)
