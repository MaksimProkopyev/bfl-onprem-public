from fastapi.testclient import TestClient
from services.api.app.main import app

def test_livez():
    c = TestClient(app)
    r = c.get("/livez")
    assert r.status_code == 200
