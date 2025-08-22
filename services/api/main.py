from fastapi import FastAPI
from prometheus_client import make_asgi_app

from services.api.routes import health
from services.api.routes import autopilot as autopilot_routes
from services.api.routes import alerts as alerts_routes

app = FastAPI(title="BFL on-prem API")
app.include_router(health.router)
app.include_router(autopilot_routes.router)
app.include_router(alerts_routes.router)
app.mount("/metrics", make_asgi_app())
