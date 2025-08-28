import os, time
from fastapi import FastAPI, Request, Response, Form
from fastapi.responses import FileResponse, JSONResponse, PlainTextResponse
from fastapi.staticfiles import StaticFiles
from .config import settings
from .auth import make_token, set_auth_cookie, verify_token
from .middleware.sec_headers import SecurityHeadersMiddleware
from .middleware.auth_gate import AuthGateMiddleware
from .metrics import http_latency, login_requests, rate_limit_hits, auth_invalid_token
from .ratelimit import rate_limiter
from services.api.routes import autopilot as autopilot_routes, alerts as alerts_routes

app = FastAPI()
app.add_middleware(SecurityHeadersMiddleware)
app.add_middleware(AuthGateMiddleware)
app.include_router(autopilot_routes.router)
app.include_router(alerts_routes.router)

ui_root = os.path.dirname(settings.BFL_UI_INDEX)
if os.path.isdir(ui_root):
    app.mount("/autopilot/assets", StaticFiles(directory=os.path.join(ui_root, "assets")), name="assets")

@app.get("/autopilot/")
async def autopilot_index():
    return FileResponse(settings.BFL_UI_INDEX)

@app.get("/autopilot/login")
async def login_page(response: Response, next: str | None = None):
    csrf = make_token("csrf", int(time.time()) + 600)
    response.set_cookie("bfl_csrf", csrf, secure=True, httponly=False, samesite="Lax", path="/")
    html = "<html><body>Login page</body></html>"
    return PlainTextResponse(html, media_type="text/html")

@app.post("/api/auth/login")
async def login(response: Response, request: Request, username: str = Form(...), password: str = Form(...)):
    ip = request.client.host if request.client else "unknown"
    key = f"auth:{ip}:{username}"
    await rate_limiter.connect()
    if await rate_limiter.is_locked(key):
        rate_limit_hits.inc()
        login_requests.labels(result="locked", code="429").inc()
        return JSONResponse({"detail": "Too Many Attempts"}, status_code=429)

    csrf_cookie = request.cookies.get("bfl_csrf")
    csrf_header = request.headers.get("X-CSRF-Token")
    if not csrf_cookie or csrf_cookie != csrf_header:
        login_requests.labels(result="csrf", code="400").inc()
        return JSONResponse({"detail": "CSRF check failed"}, status_code=400)

    if username == settings.BFL_DASHBOARD_USER and password == settings.BFL_DASHBOARD_PASS:
        token = make_token(username)
        set_auth_cookie(response, token)
        login_requests.labels(result="ok", code="303").inc()
        return JSONResponse({"ok": True}, status_code=303)
    else:
        await rate_limiter.incr(key)
        login_requests.labels(result="badcreds", code="401").inc()
        return JSONResponse({"detail": "Unauthorized"}, status_code=401)

@app.post("/api/auth/logout")
async def logout(response: Response):
    response.delete_cookie(settings.BFL_AUTH_COOKIE, path=settings.BFL_COOKIE_PATH, domain=settings.BFL_COOKIE_DOMAIN)
    return {"ok": True}

@app.get("/api/auth/me")
async def me(request: Request):
    token = request.cookies.get(settings.BFL_AUTH_COOKIE)
    user = verify_token(token) if token else None
    if not user:
        auth_invalid_token.inc()
        return JSONResponse({"detail": "Unauthorized"}, status_code=401)
    return {"username": user}

@app.get("/livez")
async def livez():
    return {"status": "ok"}

@app.get("/readyz")
async def readyz():
    await rate_limiter.connect()
    ok = await rate_limiter.ping()
    if ok:
        return {"status": "ready", "redis": True}
    return JSONResponse({"status": "not-ready", "redis": False}, status_code=503)

@app.get("/api/health")
async def health():
    await rate_limiter.connect()
    return {"status": "ok", "build_sha": settings.BUILD_SHA, "version": settings.VERSION, "redis": await rate_limiter.ping()}

@app.get("/metrics")
async def metrics():
    from prometheus_client import generate_latest, CONTENT_TYPE_LATEST
    data = generate_latest()
    return Response(content=data, media_type=CONTENT_TYPE_LATEST)
