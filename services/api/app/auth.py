import base64, hashlib, hmac, time
from fastapi import Response
from .config import settings

SEP = b":"

def _b64u_enc(b: bytes) -> str:
    return base64.urlsafe_b64encode(b).decode().rstrip("=")

def _b64u_dec(s: str) -> bytes:
    s = s + "=" * (-len(s) % 4)
    return base64.urlsafe_b64decode(s)

def make_token(username: str, exp: int | None = None) -> str:
    if exp is None:
        exp = int(time.time()) + settings.BFL_AUTH_TTL_SEC
    msg = f"{username}:{exp}".encode()
    sig = hmac.new(settings.BFL_SECRET.encode(), msg, hashlib.sha256).digest()
    return _b64u_enc(msg + b"." + sig)

def verify_token(token: str) -> str | None:
    try:
        raw = _b64u_dec(token)
        msg, sig = raw.rsplit(b".", 1)
        exp = int(msg.split(SEP, 1)[1].decode())
        if exp < int(time.time()):
            return None
        expected = hmac.new(settings.BFL_SECRET.encode(), msg, hashlib.sha256).digest()
        if not hmac.compare_digest(expected, sig):
            return None
        return msg.split(SEP, 1)[0].decode()
    except Exception:
        return None

def set_auth_cookie(resp: Response, token: str):
    resp.set_cookie(key=settings.BFL_AUTH_COOKIE, value=token, secure=settings.BFL_COOKIE_SECURE, httponly=settings.BFL_COOKIE_HTTPONLY, samesite=settings.BFL_COOKIE_SAMESITE, domain=settings.BFL_COOKIE_DOMAIN, path=settings.BFL_COOKIE_PATH, max_age=settings.BFL_AUTH_TTL_SEC)
