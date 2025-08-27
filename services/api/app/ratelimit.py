from __future__ import annotations
from typing import Optional
import os
from .config import settings
try:
    from redis import asyncio as redis
except Exception:
    redis = None

class RateLimiter:
    def __init__(self, url: Optional[str], max_per_min: int = 10, lock_sec: int = 60):
        self.url = url; self.max_per_min = max_per_min; self.lock_sec = lock_sec; self._r=None
    async def connect(self):
        if self.url and redis:
            self._r = redis.from_url(self.url)
        return self
    async def incr(self, key: str) -> bool:
        if not self._r: return False
        p = self._r.pipeline(); p.incr(key); p.expire(key, 60)
        count,_ = await p.execute()
        return int(count) > self.max_per_min
    async def lock(self, key: str):
        if not self._r: return
        await self._r.setex(f"lock:{key}", self.lock_sec, 1)
    async def is_locked(self, key: str) -> bool:
        if not self._r: return False
        return bool(await self._r.get(f"lock:{key}"))
    async def ping(self) -> bool:
        if not self._r: return False
        try: return bool(await self._r.ping())
        except Exception: return False

rate_limiter = RateLimiter(settings.REDIS_URL, int(os.getenv("BFL_AUTH_RL_MAX_PER_MIN", "10")), int(os.getenv("BFL_AUTH_RL_LOCK_SEC", "60")))
