from __future__ import annotations
import json, os, queue, threading, time, uuid, subprocess
from dataclasses import dataclass, asdict
from typing import Any, Callable, Dict, Optional
try:
    import redis  # type: ignore
except Exception:
    redis = None  # type: ignore
from prometheus_client import Counter, Histogram, Gauge

AUTOPILOT_STARTED = Counter("bfl_autopilot_started_total","Number of autopilot task runs started",["type"])
AUTOPILOT_SUCCEEDED = Counter("bfl_autopilot_succeeded_total","Number of autopilot task runs succeeded",["type"])
AUTOPILOT_FAILED = Counter("bfl_autopilot_failed_total","Number of autopilot task runs failed",["type","reason"])
AUTOPILOT_DURATION = Histogram("bfl_autopilot_duration_seconds","Autopilot task run duration",["type"], buckets=(0.05,0.1,0.25,0.5,1,2,5,10,30,60))
AUTOPILOT_INFLIGHT = Gauge("bfl_autopilot_inflight","Currently running autopilot tasks",["type"])
AUTOPILOT_QUEUE_DEPTH = Gauge("bfl_autopilot_queue_depth","Depth of autopilot queue",[])

@dataclass
class Task:
    type: str
    payload: Dict[str, Any]
    id: str = ""
    created_ts: float = 0.0
    attempts: int = 0
    max_attempts: int = 3
    def ensure(self) -> "Task":
        if not self.id: self.id = str(uuid.uuid4())
        if not self.created_ts: self.created_ts = time.time()
        return self

Handler = Callable[[Task], Dict[str, Any]]

class Registry:
    def __init__(self): self._handlers: Dict[str, Handler] = {}
    def register(self, type_: str):
        def deco(fn: Handler): self._handlers[type_] = fn; return fn
        return deco
    def get(self, type_: str) -> Handler:
        if type_ not in self._handlers: raise KeyError(f"No handler for task type '{type_}'")
        return self._handlers[type_]
    def types(self) -> Dict[str, str]:
        return {k: getattr(v,"__doc__","") for k,v in self._handlers.items()}

REGISTRY = Registry()

class QueueBackend:
    def __init__(self):
        url = os.getenv("REDIS_URL")
        self.key = os.getenv("AUTOPILOT_QUEUE_KEY","bfl:autopilot:q")
        self._local_q: Optional[queue.Queue[str]] = None
        self._redis = None
        if url and redis is not None:
            self._redis = redis.from_url(url, decode_responses=True)
        else:
            self._local_q = queue.Queue()
    def enqueue(self, task: Task) -> str:
        data = json.dumps(asdict(task.ensure()))
        if self._redis:
            self._redis.rpush(self.key, data)
            AUTOPILOT_QUEUE_DEPTH.set(self._redis.llen(self.key))
        else:
            assert self._local_q is not None
            self._local_q.put(data)
            AUTOPILOT_QUEUE_DEPTH.set(self._local_q.qsize())
        return task.id
    def blocking_pop(self, timeout: int = 1) -> Optional[Task]:
        raw: Optional[str] = None
        if self._redis:
            res = self._redis.blpop(self.key, timeout=timeout)
            if res is not None: _, raw = res
            AUTOPILOT_QUEUE_DEPTH.set(self._redis.llen(self.key))
        else:
            try:
                assert self._local_q is not None
                raw = self._local_q.get(timeout=timeout)
                AUTOPILOT_QUEUE_DEPTH.set(self._local_q.qsize())
            except queue.Empty:
                return None
        if not raw: return None
        return Task(**json.loads(raw))

@REGISTRY.register("noop")
def _noop(task: Task) -> Dict[str, Any]:
    """No-op task for testing."""
    time.sleep(task.payload.get("sleep", 0.01))
    return {"ok": True}

@REGISTRY.register("k6_smokes")
def _k6_smokes(task: Task) -> Dict[str, Any]:
    """Run k6 smoke suite if configured; otherwise dry-run."""
    cmd = os.getenv("K6_RUN_CMD")
    env = {"BASE_URL": task.payload.get("base_url","http://localhost:8000"), "TOKEN": task.payload.get("token","")}
    if not cmd:
        time.sleep(0.02)
        return {"dry_run": True, "env": env}
    started = time.time()
    proc = subprocess.run(cmd, shell=True, env={**os.environ, **env}, capture_output=True)
    if proc.returncode != 0:
        raise RuntimeError(f"k6 failed rc={proc.returncode}: {proc.stderr[:256]!r}")
    return {"rc": proc.returncode, "t": time.time()-started, "stdout": proc.stdout[-256:].decode("utf-8", "ignore")}

class Runner:
    def __init__(self, q: QueueBackend): self.q = q; self._stop = threading.Event()
    def stop(self): self._stop.set()
    def run_forever(self, idle_sleep: float = 0.2):
        while not self._stop.is_set():
            task = self.q.blocking_pop(timeout=1)
            if not task: time.sleep(idle_sleep); continue
            self._execute(task)
    def _execute(self, task: Task) -> None:
        h = REGISTRY.get(task.type)
        AUTOPILOT_INFLIGHT.labels(task.type).inc()
        AUTOPILOT_STARTED.labels(task.type).inc()
        try:
            with AUTOPILOT_DURATION.labels(task.type).time():
                result = h(task)
            AUTOPILOT_SUCCEEDED.labels(task.type).inc()
            _emit_log(task,"success",result)
        except Exception as e:
            AUTOPILOT_FAILED.labels(task.type, type(e).__name__).inc()
            _emit_log(task,"error",{"error": str(e)})
        finally:
            AUTOPILOT_INFLIGHT.labels(task.type).dec()

_LOGS: Dict[str, Dict[str, Any]] = {}
def _emit_log(task: Task, status: str, data: Dict[str, Any]):
    _LOGS[task.id] = {"id": task.id, "type": task.type, "status": status, "data": data, "ts": time.time(), "payload": task.payload}
def get_log(task_id: str) -> Optional[Dict[str, Any]]: return _LOGS.get(task_id)
def list_types() -> Dict[str, str]: return REGISTRY.types()
