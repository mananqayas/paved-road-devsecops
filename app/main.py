# main.py
from fastapi import FastAPI
from pydantic import BaseModel

app = FastAPI(title="paved-road-sample-api", version="0.1.0")
class HelloResponse(BaseModel):
    message: str
    env: str

@app.get("/healthz", tags=["ops"])
def healthz():
    return {"status": "ok"}

@app.get("/hello", response_model=HelloResponse, tags=["api"])
def hello(name: str = "world") -> HelloResponse:
    safe_name = "".join(c for c in name if c.isalnum() or c in ("-", "_"))[:64]
    return HelloResponse(message=f"hello, {safe_name}", env="dev")
