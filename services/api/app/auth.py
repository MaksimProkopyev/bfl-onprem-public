import base64, hashlib, hmac, os, time
from fastapi import APIRouter, Request, Response, Form
from fastapi.responses import HTMLResponse, JSONResponse, RedirectResponse
from starlette.middleware.base import BaseHTTPMiddleware

COOKIE = "bfl_auth"
USER = os.getenv("BFL_DASHBOARD_USER", "admin")
PASS = os.getenv("BFL_DASHBOARD_PASS", "admin")
SECRET = os.getenv("BFL_SECRET", "dev-secret-change-me").encode()
ENABLED = os.getenv("BFL_AUTH_ENABLED", "1") != "0"
TTL = int(os.getenv("BFL_AUTH_TTL_SEC", "604800"))  # 7d

def _sign(username: str, exp: int) -> str:
    payload = f"{username}:{exp}"
    sig = hmac.new(SECRET, payload.encode(), hashlib.sha256).hexdigest()
    return base64.urlsafe_b64encode(f"{payload}:{sig}".encode()).decode()

def _verify(token: str) -> str | None:
    try:
        raw = base64.urlsafe_b64decode(token.encode()).decode()
        username, exp_s, sig = raw.rsplit(":", 2)
        exp = int(exp_s)
        if exp < int(time.time()):
            return None
        expected = hmac.new(SECRET, f"{username}:{exp}".encode(), hashlib.sha256).hexdigest()
        return username if hmac.compare_digest(sig, expected) else None
    except Exception:
        return None

def _is_exempt(path: str) -> bool:
    # не трогаем API/metrics, страницу логина и логаута
    if path.startswith("/api/") or path.startswith("/metrics"):
        return True
    if path.startswith("/autopilot/login") or path.startswith("/autopilot/logout"):
        return True
    return False

class AuthGateMiddleware(BaseHTTPMiddleware):
    async def dispatch(self, request: Request, call_next):
        if not ENABLED:
            return await call_next(request)
        p = request.url.path
        if p.startswith("/autopilot") and not _is_exempt(p):
            token = request.cookies.get(COOKIE, "")
            user = _verify(token) if token else None
            if not user:
                nxt = request.url.path
                if request.url.query:
                    nxt += f"?{request.url.query}"
                return RedirectResponse(url=f"/autopilot/login?next={next_url(nxt)}", status_code=303)
        return await call_next(request)

def next_url(u: str) -> str:
    return base64.urlsafe_b64encode(u.encode()).decode()

def from_next(u: str | None) -> str:
    if not u:
        return "/autopilot/"
    try:
        return base64.urlsafe_b64decode(u.encode()).decode()
    except Exception:
        return "/autopilot/"

router = APIRouter()

@router.get("/autopilot/login", response_class=HTMLResponse)
async def login_page(request: Request, next: str | None = None):
    return HTMLResponse(
        f"""<!doctype html><html><head><meta charset="utf-8"/>
<title>BFL Login</title>
<meta name="viewport" content="width=device-width,initial-scale=1"/>
<style>body{{font-family:-apple-system,system-ui,Segoe UI,Roboto,Arial;margin:0;background:#0f172a;color:#e2e8f0;display:grid;place-items:center;height:100vh}}
.card{{background:#111827;padding:24px;border-radius:16px;box-shadow:0 10px 25px rgba(0,0,0,.35);max-width:360px;width:100%}}
h1{{margin:0 0 12px 0;font-size:20px}}label{{display:block;margin:8px 0 4px;color:#94a3b8}}
input{{width:100%;padding:10px;border-radius:10px;border:1px solid #334155;background:#0b1220;color:#e2e8f0}}
button{{margin-top:12px;width:100%;padding:10px;border:0;border-radius:10px;background:#22c55e;color:#0b1220;font-weight:600;cursor:pointer}}
.small{{margin-top:8px;color:#94a3b8;font-size:12px;text-align:center}}</style></head>
<body><div class="card">
<h1>Вход в кабинет</h1>
<form method="post" action="/api/auth/login">
  <input type="hidden" name="next" value="{next or ''}"/>
  <label>Логин</label><input name="username" autocomplete="username" required/>
  <label>Пароль</label><input name="password" type="password" autocomplete="current-password" required/>
  <button type="submit">Войти</button>
  <div class="small">Доступ выдан локально. Трафик только через SSH-туннель.</div>
</form>
</div></body></html>"""
    )

@router.post("/api/auth/login")
async def login(username: str = Form(...), password: str = Form(...), next: str | None = Form(None)):
    if USER and PASS and username == USER and password == PASS:
        exp = int(time.time()) + TTL
        tok = _sign(username, exp)
        resp = RedirectResponse(url=from_next(next), status_code=303)
        resp.set_cookie(COOKIE, tok, httponly=True, samesite="lax", secure=False, path="/")
        return resp
    return HTMLResponse("<h3>Неверные учетные данные</h3><a href='/autopilot/login'>Назад</a>", status_code=401)

@router.post("/api/auth/logout")
async def logout():
    resp = RedirectResponse(url="/autopilot/login", status_code=303)
    resp.delete_cookie(COOKIE, path="/")
    return resp

@router.get("/api/auth/me")
async def me(request: Request):
    token = request.cookies.get(COOKIE, "")
    user = _verify(token) if token else None
    if not user:
        return JSONResponse({"authenticated": False}, status_code=401)
    return {"authenticated": True, "user": user}
