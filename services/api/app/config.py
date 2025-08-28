import os
try:
    from pydantic_settings import BaseSettings  # type: ignore
except Exception:  # pragma: no cover - fallback for older pydantic
    from pydantic import BaseSettings

class Settings(BaseSettings):
    BFL_AUTH_ENABLED: bool = bool(int(os.getenv("BFL_AUTH_ENABLED", "1")))
    BFL_SECRET: str = os.getenv("BFL_SECRET", "change-me")
    BFL_AUTH_TTL_SEC: int = int(os.getenv("BFL_AUTH_TTL_SEC", str(7*24*3600)))
    BFL_AUTH_COOKIE: str = os.getenv("BFL_AUTH_COOKIE", "bfl_auth")
    BFL_CSRF_COOKIE: str = os.getenv("BFL_CSRF_COOKIE", "bfl_csrf")
    BFL_COOKIE_SECURE: bool = bool(int(os.getenv("BFL_COOKIE_SECURE", "1")))
    BFL_COOKIE_HTTPONLY: bool = bool(int(os.getenv("BFL_COOKIE_HTTPONLY", "1")))
    BFL_COOKIE_SAMESITE: str = os.getenv("BFL_COOKIE_SAMESITE", "Lax")
    BFL_COOKIE_DOMAIN: str | None = os.getenv("BFL_COOKIE_DOMAIN") or None
    BFL_COOKIE_PATH: str = os.getenv("BFL_COOKIE_PATH", "/")
    BFL_DASHBOARD_USER: str = os.getenv("BFL_DASHBOARD_USER", "admin")
    BFL_DASHBOARD_PASS: str = os.getenv("BFL_DASHBOARD_PASS", "admin")
    REDIS_URL: str | None = os.getenv("REDIS_URL") or None
    BFL_UI_INDEX: str = os.getenv("BFL_UI_INDEX", "/app/ui/dist/index.html")
    VERSION: str = os.getenv("BFL_VERSION", "0.2.0")
    BUILD_SHA: str = os.getenv("BFL_BUILD_SHA", "dev")

    # aliases matching names used throughout the codebase
    @property
    def auth_secret(self) -> str:  # pragma: no cover - simple alias
        return self.BFL_SECRET

    @property
    def token_ttl_sec(self) -> int:  # pragma: no cover - simple alias
        return self.BFL_AUTH_TTL_SEC

    @property
    def auth_cookie(self) -> str:  # pragma: no cover - simple alias
        return self.BFL_AUTH_COOKIE

    @property
    def csrf_cookie(self) -> str:  # pragma: no cover - simple alias
        return self.BFL_CSRF_COOKIE

    @property
    def cookie_secure(self) -> bool:  # pragma: no cover - simple alias
        return self.BFL_COOKIE_SECURE

    @property
    def cookie_httponly(self) -> bool:  # pragma: no cover - simple alias
        return self.BFL_COOKIE_HTTPONLY

    @property
    def cookie_samesite(self) -> str:  # pragma: no cover - simple alias
        return self.BFL_COOKIE_SAMESITE

    @property
    def cookie_domain(self) -> str | None:  # pragma: no cover - simple alias
        return self.BFL_COOKIE_DOMAIN

    @property
    def cookie_path(self) -> str:  # pragma: no cover - simple alias
        return self.BFL_COOKIE_PATH

settings = Settings()
