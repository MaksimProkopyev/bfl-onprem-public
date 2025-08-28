import os
from pydantic import Field
from pydantic_settings import BaseSettings

class Settings(BaseSettings):
    BFL_AUTH_ENABLED: bool = bool(int(os.getenv("BFL_AUTH_ENABLED", "1")))
    BFL_SECRET: str = Field(..., env="BFL_SECRET")
    BFL_AUTH_TTL_SEC: int = int(os.getenv("BFL_AUTH_TTL_SEC", str(7*24*3600)))
    BFL_AUTH_COOKIE: str = os.getenv("BFL_AUTH_COOKIE", "bfl_auth")
    BFL_COOKIE_SECURE: bool = bool(int(os.getenv("BFL_COOKIE_SECURE", "1")))
    BFL_COOKIE_HTTPONLY: bool = bool(int(os.getenv("BFL_COOKIE_HTTPONLY", "1")))
    BFL_COOKIE_SAMESITE: str = os.getenv("BFL_COOKIE_SAMESITE", "Lax")
    BFL_COOKIE_DOMAIN: str | None = os.getenv("BFL_COOKIE_DOMAIN") or None
    BFL_COOKIE_PATH: str = os.getenv("BFL_COOKIE_PATH", "/")
    BFL_DASHBOARD_USER: str = Field(..., env="BFL_DASHBOARD_USER")
    BFL_DASHBOARD_PASS: str = Field(..., env="BFL_DASHBOARD_PASS")
    REDIS_URL: str | None = os.getenv("REDIS_URL") or None
    BFL_UI_INDEX: str = os.getenv("BFL_UI_INDEX", "/app/ui/dist/index.html")
    VERSION: str = os.getenv("BFL_VERSION", "0.2.0")
    BUILD_SHA: str = os.getenv("BFL_BUILD_SHA", "dev")

settings = Settings()

if (
    settings.BFL_SECRET == "change-me"
    or settings.BFL_DASHBOARD_USER == "admin"
    or settings.BFL_DASHBOARD_PASS == "admin"
):
    raise SystemExit(
        "Weak default credentials detected. Set BFL_SECRET, "
        "BFL_DASHBOARD_USER and BFL_DASHBOARD_PASS to strong values."
    )
