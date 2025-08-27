from urllib.parse import urlencode
from starlette.middleware.base import BaseHTTPMiddleware
from starlette.responses import JSONResponse, RedirectResponse
from starlette.requests import Request
from ..auth import verify_token
from ..config import settings

class AuthGateMiddleware(BaseHTTPMiddleware):
    async def dispatch(self, request: Request, call_next):
        path = request.url.path
        public = {"/livez", "/readyz", "/metrics", "/api/health", "/api/auth/login"}
        if path in public or any(path.startswith(p + "/") for p in public):
            return await call_next(request)

        token = request.cookies.get(settings.BFL_AUTH_COOKIE)
        user = verify_token(token) if token else None

        if path.startswith("/api/") and not user:
            return JSONResponse({"detail": "Unauthorized"}, status_code=401)
        if path.startswith("/autopilot/") and not user:
            q = urlencode({"next": path})
            return RedirectResponse(url=f"/autopilot/login?{q}", status_code=303)

        request.state.user = user
        return await call_next(request)
