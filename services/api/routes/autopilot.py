from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel
from typing import Dict, Any
from services.common.autopilot import Task, QueueBackend, list_types, get_log

router = APIRouter(prefix="/api/admin/autopilot", tags=["autopilot"])

class CreateTaskIn(BaseModel):
    type: str
    payload: Dict[str, Any] = {}

class CreateTaskOut(BaseModel):
    id: str

def _require_perm(_: str = "autopilot.run"):
    return True

@router.get("/types")
def types(_: bool = Depends(_require_perm)):
    return list_types()

@router.post("/tasks", response_model=CreateTaskOut)
def create_task(body: CreateTaskIn, _: bool = Depends(_require_perm)):
    if body.type not in list_types():
        raise HTTPException(status_code=400, detail=f"Unknown type: {body.type}")
    q = QueueBackend()
    task = Task(type=body.type, payload=body.payload).ensure()
    q.enqueue(task)
    return {"id": task.id}

@router.get("/logs/{task_id}")
def task_logs(task_id: str, _: bool = Depends(_require_perm)):
    log = get_log(task_id)
    if not log:
        raise HTTPException(status_code=404, detail="Not found")
    return log

@router.get("/status")
def status(_: bool = Depends(_require_perm)):
    return {"ok": True}
