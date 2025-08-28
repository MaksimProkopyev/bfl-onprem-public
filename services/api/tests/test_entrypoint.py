from uvicorn.importer import import_from_string
from fastapi import FastAPI


def test_app_importable():
    app = import_from_string("services.api.app.main:app")
    assert isinstance(app, FastAPI)
