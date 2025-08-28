import os, time, asyncio
from typing import Callable, Awaitable, Optional

# In-memory fallback limiter (per-minute window)
class InMemoryRateLimiter:
    def __init__(self, max_per_min: int, lock_sec: int):
        self.max = max_per_min
        self.lock = lock_sec
        self.bucket = {}  # key -> (reset_ts, count)

    async def __call__(self, key: str) -> bool:
        now = int(time.time())
        reset, cnt = self.bucket.get(key, (now + 60, 0))
        if now >= reset:
            reset, cnt = now + 60, 0
        cnt += 1
        if cnt > self.max:
            # lock by pushing reset into the future
            reset = max(reset, now + self.lock)
            self.bucket[key] = (reset, cnt)
            return False
        self.bucket[key] = (reset, cnt)
        return True

async def _redis_limiter(url: str, max_per_min: int, lock_sec: int) -> Callable[[str], Awaitable[bool]]:
    try:
        # prefer redis.asyncio if available
        from redis.asyncio import from_url as redis_from_url  # type: ignore
        r = redis_from_url(url, decode_responses=True)
        async def limiter(key: str) -> bool:
            # atomic INCR + EXPIRE within 60s window; lock on exceed
            pipe = r.pipeline()
            k = f"rl:{key}:{int(time.time()//60)}"
            await pipe.incr(k).expire(k, 120).execute()
            cnt = int(await r.get(k) or "0")
            if cnt > max_per_min:
                await r.setex(f"rl:lock:{key}", lock_sec, "1")
                return False
            if await r.get(f"rl:lock:{key}"):
                return False
            return True
        # smoke ping to ensure connection ok
        await r.ping()
        return limiter
    except Exception:
        return None  # fall back

async def get_limiter() -> Callable[[str], Awaitable[bool]]:
    max_per_min = int(os.getenv("BFL_AUTH_RL_MAX_PER_MIN", "10"))
    lock_sec    = int(os.getenv("BFL_AUTH_RL_LOCK_SEC", "60"))
    url = os.getenv("REDIS_URL", "").strip()
    if url:
        lim = await _redis_limiter(url, max_per_min, lock_sec)
        if lim: return lim
    # graceful fallback
    return InMemoryRateLimiter(max_per_min, lock_sec)


class RateLimiter:
    """Compatibility wrapper exposing connect/is_locked/incr/ping APIs."""
    def __init__(self):
        self._lim: Optional[Callable[[str], Awaitable[bool]]] = None

    async def connect(self) -> None:
        self._lim = await get_limiter()

    async def is_locked(self, key: str) -> bool:
        if not self._lim:
            await self.connect()
        assert self._lim is not None
        return not await self._lim(key)

    async def incr(self, key: str) -> None:
        if not self._lim:
            await self.connect()
        assert self._lim is not None
        await self._lim(key)

    async def ping(self) -> bool:
        try:
            await self.connect()
            return True
        except Exception:
            return False

rate_limiter = RateLimiter()
