from fastapi import FastAPI
from fastapi.staticfiles import StaticFiles
from fastapi.responses import FileResponse, PlainTextResponse

app = FastAPI()

@app.get("/api/health")
def health():
    return {"ok": True}

@app.get("/metrics", response_class=PlainTextResponse)
def metrics():
    return "bfl_autopilot_up 1\n"

# PROD UI: статика + SPA fallback
app.mount("/autopilot/assets", StaticFiles(directory="services/ui/dist/assets"), name="autopilot_assets")

@app.get("/autopilot", include_in_schema=False)
@app.get("/autopilot/{path:path}", include_in_schema=False)
def autopilot_spa(path: str = ""):
    return FileResponse("services/ui/dist/index.html")
