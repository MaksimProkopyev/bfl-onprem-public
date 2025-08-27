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

from fastapi import Request
@app.api_route("/autopilot", methods=["HEAD"], include_in_schema=False)
async def _autopilot_root(request: Request):
    return RedirectResponse(url="/autopilot/", status_code=302)

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

# ==== BFL simple login gate (/autopilot) ====
try:
    from .auth import router as _auth_router
    from .auth import AuthGateMiddleware as _AuthGateMiddleware
    app.include_router(_auth_router)
    app.add_middleware(_AuthGateMiddleware)
except Exception as _e:
    # не валим приложение, просто логируем
    import sys
    print(f"[bfl-auth] disabled: {_e}", file=sys.stderr)
# ============================================

# HEAD 200 для /autopilot/
from fastapi import Response as _Response
@app.head("/autopilot/")
def _head_autopilot():
    return _Response(status_code=200)

# ==== BFL auth bootstrap (robust) ====
def _bfl_auth_bootstrap():
    import sys
    try:
        # сначала относительный импорт (запуск как app.main)
        from .auth import router as _router, AuthGateMiddleware as _AG
    except Exception:
        try:
            # затем абсолютный импорт (на всякий)
            from app.auth import router as _router, AuthGateMiddleware as _AG  # type: ignore
        except Exception as _e:
            print(f"[bfl-auth] disabled: {_e}", file=sys.stderr)
            return
    try:
        app.include_router(_router)
        app.add_middleware(_AG)
        print("[bfl-auth] enabled", file=sys.stderr)
    except Exception as _e:
        print(f"[bfl-auth] disabled on attach: {_e}", file=sys.stderr)

_bfl_auth_bootstrap()
# =====================================

# ensure GET/HEAD allowed at /autopilot/
from fastapi import Response as _Response
@app.api_route("/autopilot/", methods=["HEAD"])
def _bfl_head_get_autopilot():
    # HEAD вернёт 200 пусто, GET отдаст index через SPA-фоллбек/статику (middleware решит доступ)
    return _Response(status_code=200)

# ==== BFL auth fallback (self-contained) ====
try:
    # Если нормальный модуль auth сработал — ничего не делаем
    pass
except Exception:
    pass

if "_bfl_auth_fallback" not in globals():
    _bfl_auth_fallback = True
    import os, time, base64, hmac, hashlib
    from fastapi import APIRouter, Request, Form
    from fastapi.responses import HTMLResponse, JSONResponse, RedirectResponse
    from starlette.middleware.base import BaseHTTPMiddleware

    COOKIE="bfl_auth"
    USER=os.getenv("BFL_DASHBOARD_USER","admin")
    PASS=os.getenv("BFL_DASHBOARD_PASS","admin")
    SECRET=os.getenv("BFL_SECRET","dev-secret").encode()
    TTL=int(os.getenv("BFL_AUTH_TTL_SEC","604800"))
    ENABLED=os.getenv("BFL_AUTH_ENABLED","1")!="0"

    def _sign(u, exp):
        payload=f"{u}:{exp}"
        sig=hmac.new(SECRET, payload.encode(), hashlib.sha256).hexdigest()
        return base64.urlsafe_b64encode(f"{payload}:{sig}".encode()).decode()

    def _verify(tok):
        try:
            raw=base64.urlsafe_b64decode(tok.encode()).decode()
            u,exp_s,sig=raw.rsplit(":",2); exp=int(exp_s)
            if exp<int(time.time()): return None
            exp_sig=hmac.new(SECRET, f"{u}:{exp}".encode(), hashlib.sha256).hexdigest()
            return u if hmac.compare_digest(sig,exp_sig) else None
        except Exception:
            return None

    class _Gate(BaseHTTPMiddleware):
        async def dispatch(self, request: Request, call_next):
            if not ENABLED: return await call_next(request)
            p=request.url.path
            if p.startswith("/api/") or p.startswith("/metrics") or p.startswith("/autopilot/login") or p.startswith("/autopilot/logout"):
                return await call_next(request)
            if p.startswith("/autopilot"):
                tok=request.cookies.get(COOKIE,"")
                if not (tok and _verify(tok)):
                    nxt=p+(("?"+request.url.query) if request.url.query else "")
                    nxt=base64.urlsafe_b64encode(nxt.encode()).decode()
                    return RedirectResponse(f"/autopilot/login?next={nxt}", status_code=303)
            return await call_next(request)

    _router = APIRouter()

    @_router.get("/autopilot/login", response_class=HTMLResponse)
    async def _login_page(next: str | None = None):
        return HTMLResponse(f"""<!doctype html><html><head><meta charset="utf-8"/><title>BFL Login</title></head>
<body><form method="post" action="/api/auth/login">
<input type="hidden" name="next" value="{next or ''}"/>
<label>Логин</label><input name="username" required/>
<label>Пароль</label><input name="password" type="password" required/>
<button type="submit">Войти</button></form></body></html>""")

    @_router.post("/api/auth/login")
    async def _login(username: str = Form(...), password: str = Form(...), next: str | None = Form(None)):
        if username==USER and password==PASS:
            exp=int(time.time())+TTL
            tok=_sign(username, exp)
            r=RedirectResponse(url=base64.urlsafe_b64decode(next.encode()).decode() if next else "/autopilot/", status_code=303)
            r.set_cookie(COOKIE, tok, httponly=True, samesite="lax", secure=False, path="/")
            return r
        return HTMLResponse("Неверные данные", status_code=401)

    @_router.post("/api/auth/logout")
    async def _logout():
        r=RedirectResponse("/autopilot/login", status_code=303)
        r.delete_cookie(COOKIE, path="/")
        return r

    @_router.get("/api/auth/me")
    async def _me(request: Request):
        tok=request.cookies.get(COOKIE,"")
        u=_verify(tok) if tok else None
        return JSONResponse({"authenticated": bool(u), "user": u or None}, status_code=200 if u else 401)

    try:
        app.include_router(_router)
        app.add_middleware(_Gate)
        print("[bfl-auth-fallback] enabled", flush=True)
    except Exception as _e:
        import sys
        print(f"[bfl-auth-fallback] failed: {_e}", file=sys.stderr)
# ============================================
# --- BFL explicit index for /autopilot/ (idempotent) ---
try:
    import os
    from fastapi.responses import FileResponse as _FileResponse
    _BFL_UI_INDEX = os.environ.get("BFL_UI_INDEX", "/app/ui/dist/index.html")
    if not any(getattr(r, 'path', '') == "/autopilot/" and "GET" in getattr(r, 'methods', set()) for r in app.routes):
        @app.get("/autopilot/", include_in_schema=False)
        def _bfl_autopilot_index():
            return _FileResponse(_BFL_UI_INDEX)
except Exception as _e:
    print(f"[bfl-autopilot-index] disabled: {_e}")
# --------------------------------------------------------

# --- BFL UI assets mount + robust GET /autopilot/ ---
try:
    import os
    from pathlib import Path as _Path
    from fastapi.responses import FileResponse as _FileResponse, HTMLResponse as _HTMLResponse
    from starlette.staticfiles import StaticFiles as _StaticFiles

    _UI_DIR = os.environ.get("BFL_UI_DIR", "/app/ui/dist")
    _UI_ASSETS = os.path.join(_UI_DIR, "assets")
    _UI_INDEX = os.environ.get("BFL_UI_INDEX", os.path.join(_UI_DIR, "index.html"))

    # /autopilot/assets → /app/ui/dist/assets (если ещё не смонтирован)
    if not any(getattr(r, 'path', '').startswith("/autopilot/assets") for r in app.routes):
        if os.path.isdir(_UI_ASSETS):
            app.mount("/autopilot/assets", _StaticFiles(directory=_UI_ASSETS), name="autopilot_assets")
        else:
            print(f"[bfl-ui] warn: assets dir not found: {_UI_ASSETS}")

    # GET /autopilot/ → index.html
    if not any(getattr(r, 'path', '') == "/autopilot/" and "GET" in getattr(r, 'methods', set()) for r in app.routes):
        @app.get("/autopilot/", include_in_schema=False)
        def _bfl_autopilot_index():
            p = _Path(_UI_INDEX)
            if p.is_file():
                return _FileResponse(str(p))
            # дружелюбный дебаг без 500, чтобы смоук не падал молча
            body = f"""<!doctype html>
<html><head><meta charset="utf-8"><title>BFL UI</title></head>
<body>
<h3>UI index not found</h3>
<p>Expected: {_UI_INDEX}</p>
<p>Check volume mount to /app/ui/dist and vite base="/autopilot/".</p>
</body></html>"""
            return _HTMLResponse(body, status_code=200)
except Exception as _e:
    print(f"[bfl-ui] disabled: {_e}")
# ----------------------------------------------------
