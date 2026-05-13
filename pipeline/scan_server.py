#!/usr/bin/env python3
"""Simple FastAPI wrapper around the scan bridge.

POST /scan accepts a multipart file field named `file` (image bytes) and returns
the same JSON payload produced by `scan_dipstick.run_scan`.

This server is intended for local/dev usage (mobile device or desktop calling
the local pipeline). It reuses the existing pipeline implementation and does
not spawn a separate process.
"""
from __future__ import annotations

import tempfile
from pathlib import Path
from typing import Any

from fastapi import FastAPI, File, UploadFile, HTTPException, Request
from fastapi.responses import JSONResponse, StreamingResponse
import uvicorn
import asyncio
import uuid
import json

try:
    from .scan_dipstick import run_scan
except ImportError:
    import sys

    workspace_root = Path(__file__).resolve().parent.parent
    if str(workspace_root) not in sys.path:
        sys.path.insert(0, str(workspace_root))
    from pipeline.scan_dipstick import run_scan


app = FastAPI(title="Uritect Scan Bridge")

# In-memory scan state. For production use a persistent store.
_SCANS: dict[str, dict] = {}


@app.get("/health")
def health() -> dict[str, str]:
    return {"status": "ok", "service": "scan_bridge"}


@app.post("/scan")
async def scan_endpoint(request: Request, file: UploadFile = File(...)) -> Any:
    suffix = Path(file.filename).suffix or ".jpg"
    prefer_header = request.headers.get("prefer", "") or ""
    respond_async = "respond-async" in prefer_header.lower()
    # Allow forcing async mode via query param for testing: ?force_async=1
    force_param = request.query_params.get("force_async")
    if force_param and force_param.lower() in {"1", "true", "yes"}:
        respond_async = True

    # Debug logging to help diagnose async selection
    print(f"[SCAN_SERVER] POST /scan - prefer_header={prefer_header!r}, force_param={force_param!r}, respond_async={respond_async}")
    all_headers = dict(request.headers)
    print(f"[SCAN_SERVER] All request headers: {all_headers}")

    try:
        with tempfile.NamedTemporaryFile(delete=False, suffix=suffix) as tmp:
            content = await file.read()
            tmp.write(content)
            tmp_path = Path(tmp.name)

        # If client asked for async processing, start background worker and return id
        if respond_async:
            scan_id = str(uuid.uuid4())
            _SCANS[scan_id] = {"status": "queued", "events": [], "result": None, "error": None}

            def _progress_cb(stage: str, pct: int):
                _SCANS[scan_id]["events"].append({"type": "progress", "stage": stage, "progress": pct})

            async def _worker():
                _SCANS[scan_id]["status"] = "running"
                try:
                    result = await asyncio.to_thread(run_scan, tmp_path, None, "legacy", _progress_cb)
                    _SCANS[scan_id]["result"] = result
                    _SCANS[scan_id]["status"] = "completed"
                    _SCANS[scan_id]["events"].append({"type": "result", "payload": result})
                except Exception as e:
                    _SCANS[scan_id]["status"] = "error"
                    _SCANS[scan_id]["error"] = str(e)
                    _SCANS[scan_id]["events"].append({"type": "error", "error": str(e)})
                finally:
                    try:
                        if tmp_path.exists():
                            tmp_path.unlink()
                    except Exception:
                        pass

            asyncio.create_task(_worker())
            return JSONResponse(status_code=202, content={"id": scan_id, "status": "accepted"})

        # Otherwise run synchronously and return the result
        try:
            payload = await asyncio.to_thread(run_scan, tmp_path)
            return JSONResponse(content=payload)
        finally:
            try:
                if tmp_path.exists():
                    tmp_path.unlink()
            except Exception:
                pass
    except Exception as exc:  # pragma: no cover - surface errors to caller
        raise HTTPException(status_code=500, detail=str(exc))


@app.get("/scan_events/{scan_id}")
async def scan_events(scan_id: str):
    if scan_id not in _SCANS:
        raise HTTPException(status_code=404, detail="Scan id not found")

    async def event_generator():
        idx = 0
        # Stream events as Server-Sent Events
        while True:
            events = _SCANS.get(scan_id, {}).get("events", [])
            while idx < len(events):
                ev = events[idx]
                idx += 1
                data = json.dumps(ev, default=str)
                yield f"data: {data}\n\n"

            status = _SCANS.get(scan_id, {}).get("status")
            if status in {"completed", "error"}:
                break
            await asyncio.sleep(0.2)

        # finish stream
        yield "event: done\n\n"

    return StreamingResponse(event_generator(), media_type="text/event-stream")


@app.post("/debug_trigger_async")
async def debug_trigger_async():
    """Debug helper: start an async scan on a known sample image and return scan id."""
    sample = Path(__file__).resolve().parent / "photos" / "005" / "005-Daylight.jpg"
    if not sample.exists():
        raise HTTPException(status_code=404, detail="Sample image not found on server")

    scan_id = str(uuid.uuid4())
    _SCANS[scan_id] = {"status": "queued", "events": [], "result": None, "error": None}

    def _progress_cb(stage: str, pct: int):
        _SCANS[scan_id]["events"].append({"type": "progress", "stage": stage, "progress": pct})

    async def _worker():
        _SCANS[scan_id]["status"] = "running"
        try:
            result = await asyncio.to_thread(run_scan, sample, None, "legacy", _progress_cb)
            _SCANS[scan_id]["result"] = result
            _SCANS[scan_id]["status"] = "completed"
            _SCANS[scan_id]["events"].append({"type": "result", "payload": result})
        except Exception as e:
            _SCANS[scan_id]["status"] = "error"
            _SCANS[scan_id]["error"] = str(e)
            _SCANS[scan_id]["events"].append({"type": "error", "error": str(e)})

    asyncio.create_task(_worker())
    return JSONResponse(status_code=202, content={"id": scan_id, "status": "accepted"})


if __name__ == "__main__":
    uvicorn.run(app, host="127.0.0.1", port=8000, log_level="info")
