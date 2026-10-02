import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from fastapi.testclient import TestClient

from app.main import app

client: TestClient = TestClient(app)

def test_healthz():
    r = client.get("/healthz")
    assert r.status_code == 200
    assert r.json()["status"] == "ok"

def test_hello_default():
    r = client.get("hello")
    assert r.status_code == 200
    assert r.json()["message"] == "hello, world"

def test_hello_santizers_input():
    r = client.get("/hello", params={"name": "bob<script>"})
    assert r.status_code == 200
    assert "<" not in r.json()["message"]