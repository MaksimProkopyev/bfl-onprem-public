import os, time
from fastapi import FastAPI, Request, Response, Form
from fastapi.responses import FileResponse, JSONResponse, PlainTextResponse
from fastapi.staticfiles import StaticFiles
from .config import settings
from .auth import make_token, set_auth_cookie, verify_token
from .middleware.sec_headers import SecurityHeadersMiddleware
from .middleware.auth_gate import AuthGateMiddleware
from .metrics import login_requests, rate_limit_hits, auth_invalid_token
from .ratelimit import get_limiter

app = FastAPI()
app.add_middleware(SecurityHeadersMiddleware)
app.add_middleware(AuthGateMiddleware)

ui_root = os.path.dirname(settings.BFL_UI_INDEX)
if os.path.isdir(ui_root):
    app.mount("/autopilot/assets", StaticFiles(directory=os.path.join(ui_root, "assets")), name="assets")

@app.get("/autopilot/")
async def autopilot_index():
    return FileResponse(settings.BFL_UI_INDEX)

@app.get("/autopilot/login")
async def login_page(response: Response, next: str | None = None):
    csrf = make_token("csrf", int(time.time()) + 600)
    response.set_cookie(
        settings.csrf_cookie,
        csrf,
        secure=settings.cookie_secure,
        httponly=False,
        samesite=settings.cookie_samesite,
        domain=settings.cookie_domain,
        path=settings.cookie_path,
    )
    html = "<html><body>Login page</body></html>"
    return PlainTextResponse(html, media_type="text/html")

@app.post("/api/auth/login")
async def login(response: Response, request: Request, username: str = Form(...), password: str = Form(...)):
    ip = request.client.host if request.client else "unknown"
    key = f"auth:{ip}:{username}"
    limiter = await get_limiter()
    if not await limiter(key):
        rate_limit_hits.inc()
        login_requests.labels(result="locked", code="429").inc()
        return JSONResponse({"detail": "Too Many Attempts"}, status_code=429)

    csrf_cookie = request.cookies.get(settings.csrf_cookie)
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
        login_requests.labels(result="badcreds", code="401").inc()
        return JSONResponse({"detail": "Unauthorized"}, status_code=401)

@app.post("/api/auth/logout")
async def logout(response: Response):
    response.delete_cookie(settings.auth_cookie, path=settings.cookie_path, domain=settings.cookie_domain)
    return {"ok": True}

@app.get("/api/auth/me")
async def me(request: Request):
    token = request.cookies.get(settings.auth_cookie)
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
    return {"status": "ready", "redis": False}

@app.get("/api/health")
async def health():
    return {
        "status": "ok",
        "build_sha": settings.BUILD_SHA,
        "version": settings.VERSION,
        "redis": False,
    }

@app.get("/metrics")
async def metrics():
    from prometheus_client import generate_latest, CONTENT_TYPE_LATEST
    data = generate_latest()
    return Response(content=data, media_type=CONTENT_TYPE_LATEST)
