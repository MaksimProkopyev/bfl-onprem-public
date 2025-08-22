import os, httpx
from typing import Optional, List
from fastapi import APIRouter, HTTPException, Query

router = APIRouter(prefix="/api/admin/alerts", tags=["alerts"])

def _am_base() -> str:
    base = os.getenv("ALERTMANAGER_BASE_URL")
    if not base:
        raise HTTPException(status_code=503, detail="ALERTMANAGER_BASE_URL is not configured")
    return base.rstrip("/")

@router.get("")
def list_alerts(
    service: Optional[str] = Query(None),
    area: Optional[str] = Query(None),
    severity: Optional[str] = Query(None, description="comma-separated warning,critical"),
    active: bool = Query(True), silenced: bool = Query(False), inhibited: bool = Query(False),
    limit: Optional[int] = Query(200, ge=1, le=1000), q: Optional[str] = Query(None)
):
    base = _am_base()
    params: List[tuple[str, str]] = [
        ("active", str(active).lower()), ("silenced", str(silenced).lower()),
        ("inhibited", str(inhibited).lower()), ("limit", str(limit or 200))
    ]
    if service: params.append(("filter", f"service='{service}'"))
    if area: params.append(("filter", f"area='{area}'"))
    if severity:
        sev = "|".join([s.strip() for s in severity.split(",") if s.strip()])
        if sev: params.append(("filter", f"severity=~\"({sev})\""))
    try:
        with httpx.Client(timeout=10) as cli:
            r = cli.get(f"{base}/api/v2/alerts", params=params)
    except Exception as e:
        raise HTTPException(status_code=502, detail=f"Alertmanager unreachable: {e}")
    if r.status_code != 200:
        raise HTTPException(status_code=502, detail=f"Alertmanager error: {r.status_code}")
    alerts = r.json()
    if q:
        ql = q.lower()
        def ok(a: dict) -> bool:
            if ql in (a.get("labels", {}).get("alertname","").lower()): return True
            for k,v in (a.get("labels",{}) or {}).items():
                if ql in f"{k}={v}".lower(): return True
            return False
        alerts = [a for a in alerts if ok(a)]
    return {"alerts": alerts, "count": len(alerts)}
