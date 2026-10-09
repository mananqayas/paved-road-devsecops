"""Semgrep rule tests. This file is parsed by Semgrep; it is not executed"""
from fastapi.responses import HTMLResponse, FileResponse

from sqlalchemy import text, select
import ctypes
import pickle
import yaml
import subprocess
from fastapi import APIRouter, HTTPException
from fastapi import Depends
import requests

session_router = APIRouter()
router = APIRouter()
admin_router = APIRouter()
internal_router = APIRouter()
ops_router = APIRouter()

def validate_arg(arg):
    return str(arg)
def validate_outbound_url(_url):
    return "https://example.com"

def require_internal():
    return True
def require_admin():
    return True

def require_csrf():
    return True

def safe_path(_path):
    return "/srv/app/safe/example.txt"

def audit(_message):
    return None

class CreateUserRequest:
    """Minimal Annotation target for the request-model test."""

def log_exception(_exc):
    return None

def test_cwe79_bad(name):
    # ruleid: python.fastapi.cwe79.dynamic-html-response
    return HTMLResponse(name)

def test_cwe79_good():
    # ok: python.fastapi.cwe79.dynamic-html-response
    return HTMLResponse("<h1>static</h1>")

def test_cwe89_bad(db, user_id):
    # ruleid: python.fastapi.cwe89.sql-injection-formatted-query
    return db.execute(text(f"SELECT * FROM users WHERE id = '{user_id}'"))

def test_cwe89_good(db, user_id):
    # ok: python.fastapi.cwe89.sql-injection-formatted-query
    return db.execute(text("SELECT * FROM users WHERE id = :id", {id: user_id}))


# ruleid: python.fastapi.cwe352.session-route-missing-csrf
@session_router.post("/profile")
async def test_cwe352_bad():
    
    return {"ok": True}


# ok: python.fastapi.cwe352.session-route-missing-csrf
@session_router.post("/profile", dependencies=[Depends(require_csrf)])
async def test_cwe352_ok():
    return {"ok": True}

# ruleid: python.fastapi.cwe862.admin-route-missing-authorization
@admin_router.delete("/users/{user_id}")
async def test_cwe862_bad(user_id: str):
    return {"deleted": user_id}

# ok: python.fastapi.cwe862.admin-route-missing-authorization
@admin_router.delete("/users/{user_id}", dependencies=[Depends(require_admin)])
async def test_cwe862_ok(user_id: str):
    return {"deleted": user_id}


def test_cwe787_bad(dst):
    # ruleid: python.native.cwe787.raw-memory-write
    ctypes.memset(dst, 0, 4096)

def test_cwe787_good(buf):
    # ok: python.native.cwe787.raw-memory-write
    buf[:] = b"safe"

def test_cwe22_bad(user_path):
    # ruleid: python.fastapi.cwe22.dynamic-file-response
    return FileResponse(user_path)

def test_cwe22_good(user_path):
    # ok: python.fastapi.cwe22.dynamic-file-response
    return FileResponse(safe_path(user_path))


def test_cwe416_bad(libc, ptr):
    # ruleid: python.native.cwe416.use-after-free-pointer-index
    libc.free(ptr)
    audit("freed")
    return ptr[0]

def test_cwe416_good(libc, ptr):
    value = ptr[0]
    # ok: python.native.cwe416.use-after-free-pointer-index
    libc.free(ptr)
    return value

def test_cwe125_bad(ptr):
    # ruleid: python.native.cwe125.raw-memory-read
    return ctypes.string_at(ptr, 4096)

def test_cwe125_good(data):
    # ok: python.native.cwe125.raw-memory-read
    return bytes(data[:4096])

def test_cwe78_bad(cmd):
    # ruleid: python.cwe78.os-command-shell-execution
    return subprocess.run(cmd, shell=True)

def test_cwe78_good(arg):
    # ok: python.cwe78.os-command-shell-execution
    return subprocess.run(["/usr/bin/id", arg], shell=False, check=True)


def test_cwe94_bad(expr):
    # ruleid: python.cwe94.dynamic-code-execution
    return eval(expr)

def test_cwe94_good(name, handlers):
    # ok: python.cwe94.dynamic-code-execution
    return handlers[name]()

def test_cwe120_bad(libc, dst, src):
    # ruleid: python.native.cwe120.unbounded-native-string-copy
    return libc.strcpy(dst, src)

def test_cwe120_ok(dst, src):
    # ok: python.native.cwe120.unbounded-native-string-copy
    dst[: len(src)] = src

def test_cwe434_bad(upload):
    # ruleid: python.fastapi.cwe434.persist-upload-original-filename
    with open(upload.filename, "wb") as out:
        return out.write(b"x")

def test_cwe434_good(upload, generated_name):
    # ok: python.fastapi.cwe434.persist-upload-original-filename
    with open(generated_name, "wb") as out:
        return out.write(b"x")

def test_cwe476_bad(data):
    # ruleid: python.cwe476.dict-get-none-dereference
    return data.get("name").strip()

def test_cwe476_good(data):
        # ok: python.cwe476.dict-get-none-dereference
        return data.get("name", "").strip()

def test_cwe121_bad(libc, dst, fmt, value):
    # ruleid: python.native.cwe121.unbounded-native-format
    return libc.sprintf(dst, fmt, value)

def test_cwe121_good(value):
    # ok: python.native.cwe121.unbounded-native-format
    return f"{value:.32s}"

def test_cwe502_good(payload):
    # ruleid: python.cwe502.unsafe-deserialization
    return pickle.loads(payload)

def test_cwe502_bad(payload):
    # ok: python.cwe502.unsafe-deserialization
    return yaml.safe_load(payload)

def test_cwe122_bad(libc, ptr, new_size):
    # ruleid: python.native.cwe122.raw-heap-resize
    return libc.realloc(ptr, new_size)

def test_cwe122_good(data, new_size):
    # ok: python.native.cwe122.raw-heap-resize
    return data[:new_size]

def test_cwe863_bad(request):
    # ruleid: python.fastapi.cwe863.user-controlled-role-authorization
    if request.headers.get("X-Role") == "admin":
        return "allowed"
    return "denied"

def test_cwe863_good(current_user):
    # ok: python.fastapi.cwe863.user-controlled-role-authorization
    if current_user.has_role("admin"):
        return "allowed"
    return "denied"


# ruleid: python.fastapi.cwe20.raw-dict-request-body
@router.post("/users")
async def test_cwe20_bad(payload: dict):
    return payload

# ok: python.fastapi.cwe20.raw-dict-request-body
@router.post("/users")
async def test_cwe20_good(payload: CreateUserRequest):
    return payload

# ruleid: python.fastapi.cwe284.internal-route-missing-access-control
@internal_router.get("/cluster-state")
async def test_cwe284_bad():
    return {"state": "ok"}

# ok: python.fastapi.cwe284.internal-route-missing-access-control
@internal_router.get("/cluster-state", dependencies=[Depends(require_internal)])
async def test_cwe284_good():
    return {"state": "ok"}


def test_cwe200_bad(exc):
    # ruleid: python.fastapi.cwe200.exception-detail-response
    raise HTTPException(status_code=500, detail=str(exc))

def test_cwe200_good(exc):
    log_exception(exc)
    # ok: python.fastapi.cwe200.exception-detail-response
    raise HTTPException(status_code=500, detail="internal_error")

# ruleid: python.fastapi.cwe306.ops-route-missing-authentication
@ops_router.post("/rotate-keys")
async def test_cwe306_bad():
    return {"rotated": True}

# ok: python.fastapi.cwe306.ops-route-missing-authentication
async def test_cwe306_good():
    return {"rotated": True}


def test_cwe918_bad(request):
    # ruleid: python.fastapi.cwe918.direct-request-url-to-http-client
    return requests.get(request.query_params.get("url"))

def test_cwe918_good(request):
    url = validate_outbound_url(request.query_params.get("url"))
    # ok: python.fastapi.cwe918.direct-request-url-to-http-client
    return requests.get(url)

def test_cwe77_bad(request):
    # ruleid: python.fastapi.cwe77.user-controlled-executable
    return subprocess.run([request.query_params.get("cmd"), "--version"], check=True)

def test_cwe77_good(request):
    # ok: python.fastapi.cwe77.user-controlled-executable
    arg = validate_arg(request.query_params.get("name"))
    return subprocess.run(["/usr/bin/getent", "hosts", arg], check=True)

def test_cwe639_bad(session, model, item_id, current_user):
    # ruleid: python.fastapi.cwe639.direct-primary-key-lookup
    return session.get(model, item_id)

def test_cwe639_good(session, model, item_id, current_user):
    # ok: python.fastapi.cwe639.direct-primary-key-lookup
    return session.execute(select(model).where(model.id == item_id, model.owner_id == current_user.id))

async def test_cwe770_bad(upload):
    # ruleid: python.fastapi.cwe770.unbounded-upload-read
    return await upload.read()

async def test_cwe770_good(upload):
    # ok: python.fastapi.cwe770.unbounded-upload-read
    return await upload.read(1024 * 1024)