import time
from http.cookies import SimpleCookie

from fastapi import Response

from services.api.app.auth import make_token, verify_token, set_auth_cookie
from services.api.app.config import settings


def test_make_and_verify_token():
    now = int(time.time())
    token = make_token("alice")
    user, exp = verify_token(token)
    assert user == "alice"
    assert now + settings.token_ttl_sec - 1 <= exp <= now + settings.token_ttl_sec + 1


def test_verify_token_expired():
    token = make_token("bob", int(time.time()) - 1)
    assert verify_token(token) is None


def test_set_auth_cookie():
    resp = Response()
    token = "tok"
    set_auth_cookie(resp, token)
    cookie_header = resp.headers["set-cookie"]
    c = SimpleCookie()
    c.load(cookie_header)
    cookie = c[settings.auth_cookie]
    assert cookie.value == token
    assert cookie["path"] == settings.cookie_path
    assert cookie["samesite"] == settings.cookie_samesite
    assert cookie["max-age"] == str(settings.token_ttl_sec)
    if settings.cookie_domain:
        assert cookie["domain"] == settings.cookie_domain
    assert cookie["httponly"]
    if settings.cookie_secure:
        assert cookie["secure"]

