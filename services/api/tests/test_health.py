import asyncio
from services.api.app.main import livez


def test_livez():
    r = asyncio.run(livez())
    assert r == {"status": "ok"}
