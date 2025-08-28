import base64, hmac, hashlib, time, secrets
from typing import Optional, Tuple
from fastapi import APIRouter, Response, Request, HTTPException
from .config import settings
from .metrics import login_requests, auth_invalid_token
from .ratelimit import get_limiter

router = APIRouter()

def _b64pad(s: str) -> str:
    return s + "=" * (-len(s) % 4)

def sign_token(username: str, exp: int) -> str:
    msg = f"{username}:{exp}".encode()
    sig = hmac.new(settings.auth_secret.encode(), msg, hashlib.sha256).digest()
    return base64.urlsafe_b64encode(msg + b"." + sig).decode().rstrip("=")

def make_token(username: str, exp: Optional[int] = None) -> str:
    """Create signed auth token for *username* with optional expiry."""
    if exp is None:
        exp = int(time.time()) + settings.token_ttl_sec
    return sign_token(username, exp)

def verify_token(token: str) -> Optional[Tuple[str,int]]:
    try:
        raw = base64.urlsafe_b64decode(_b64pad(token))
        msg, sig = raw.rsplit(b".", 1)
        if not hmac.compare_digest(
            hmac.new(settings.auth_secret.encode(), msg, hashlib.sha256).digest(), sig
        ):
            return None
        username, exp_s = msg.decode().split(":",1)
        exp = int(exp_s)
        if time.time() > exp:
            auth_invalid_token.inc()
            return None
        return username, exp
    except Exception:
        auth_invalid_token.inc()
        return None

def set_auth_cookie(resp: Response, token: str):
    # однострочно — под grep-аудит
    resp.set_cookie(key=settings.auth_cookie, value=token, secure=settings.cookie_secure, httponly=settings.cookie_httponly, samesite=settings.cookie_samesite, domain=settings.cookie_domain, path=settings.cookie_path, max_age=settings.token_ttl_sec)

def set_csrf_cookie(resp: Response):
    token = secrets.token_urlsafe(32)
    resp.set_cookie(
        key=settings.csrf_cookie, value=token,
        secure=settings.cookie_secure, httponly=False,
        samesite=settings.cookie_samesite, domain=settings.cookie_domain,
        path="/autopilot/login"
    )
    return token

@router.get("/autopilot/login")
async def login_page(resp: Response):
    set_csrf_cookie(resp)
    return Response(
        content="""<html><body><h1>Login</h1>
<form method="POST" action="/api/auth/login">
<input name="username"/><input name="password" type="password"/>
<input type="hidden" name="next" value="/autopilot/"/>
<button type="submit">Login</button></form></body></html>""",
        media_type="text/html"
    )

@router.post("/api/auth/login")
async def login(request: Request, resp: Response):
    # rate-limit (per ip+username) — Redis или in-memory fallback
    limiter = await get_limiter()
    ip = getattr(request.client, "host", "0.0.0.0")
    form = await request.form()
    username = str(form.get("username","")).strip()
    rl_key = f"{ip}:{username or '-'}"
    if not await limiter(rl_key):
        login_requests.labels(result="rate_limited", code="429").inc()
        raise HTTPException(status_code=429, detail="rate limited")

    # CSRF double-submit
    csrf_cookie = request.cookies.get(settings.csrf_cookie)
    csrf_header = request.headers.get("X-CSRF-Token")
    if not csrf_cookie or not csrf_header or csrf_cookie != csrf_header:
        login_requests.labels(result="csrf_fail", code="400").inc()
        raise HTTPException(status_code=400, detail="csrf")

    password = str(form.get("password","")).strip()
    if not username or not password:
        login_requests.labels(result="bad_creds", code="401").inc()
        raise HTTPException(status_code=401, detail="bad credentials")

    exp = int(time.time()) + settings.token_ttl_sec
    token = sign_token(username, exp)
    set_auth_cookie(resp, token)
    login_requests.labels(result="ok", code="200").inc()
    return {"ok": True, "next": form.get("next") or "/autopilot/"}

@router.get("/api/auth/me")
async def me(request: Request):
    token = request.cookies.get(settings.auth_cookie)
    if not token:
        raise HTTPException(status_code=401, detail="unauthorized")
    info = verify_token(token)
    if not info:
        raise HTTPException(status_code=401, detail="invalid")
    return {"user": info[0], "exp": info[1]}

@router.post("/api/auth/logout")
async def logout(resp: Response):
    resp.delete_cookie(key=settings.auth_cookie, path=settings.cookie_path, domain=settings.cookie_domain)
    return {"ok": True}
