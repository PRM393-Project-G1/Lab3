"""The three commands the app sends. Progress and results go through Firestore."""

from __future__ import annotations

import asyncio
import logging
import os
import re
from collections.abc import AsyncIterator, Callable
from contextlib import asynccontextmanager
from typing import Any

from fastapi import Depends, FastAPI, Header, HTTPException
from pydantic import BaseModel

from . import __version__
from .config import Settings
from .jobs import JobManager, Pipeline
from .steps import Steps
from .uploads import CloudinarySigner

logger = logging.getLogger(__name__)

# Same rule as the app's parseArxivId: the ID becomes a Firestore document ID.
_ARXIV_ID = re.compile(r"^\d{4}\.\d{4,5}$")
# No slash, so the name cannot leave the user's folder.
_REPORT_FILE = re.compile(r"^[A-Za-z0-9_.-]{1,100}\.pdf$")
_RUNNING = ("queued", "processing")


class StartRequest(BaseModel):
    arxivId: str
    aiAssisted: bool = True


class UploadRequest(BaseModel):
    fileName: str


def create_app(
    store: Any,
    verify_token: Callable[[str], str],
    steps: Any,
    signer: CloudinarySigner | None = None,
) -> FastAPI:
    manager_holder: dict[str, JobManager] = {}

    @asynccontextmanager
    async def lifespan(_: FastAPI) -> AsyncIterator[None]:
        manager_holder["manager"] = JobManager(Pipeline(store, steps))
        interrupted = await asyncio.to_thread(store.fail_interrupted)
        if interrupted:
            logger.warning("Marked %d interrupted analyses as failed", interrupted)
        yield
        # What was running is marked as interrupted on the next start.
        await manager_holder["manager"].cancel_all()

    app = FastAPI(title="Realtron", version=__version__, lifespan=lifespan)

    def current_user(authorization: str | None = Header(default=None)) -> str:
        scheme, _, token = (authorization or "").partition(" ")
        if scheme.lower() != "bearer" or not token:
            raise HTTPException(401, "Sign in first")
        try:
            return verify_token(token)
        except ValueError as error:
            raise HTTPException(401, "Sign in first") from error

    @app.get("/api/health")
    def health() -> dict[str, str]:
        return {"status": "ok", "version": __version__}

    @app.post("/api/analyses", status_code=202)
    async def start_analysis(request: StartRequest, uid: str = Depends(current_user)) -> dict[str, str]:
        analysis_id = request.arxivId
        if not _ARXIV_ID.match(analysis_id):
            raise HTTPException(422, "Not a valid arXiv ID")
        manager = manager_holder["manager"]
        existing = await asyncio.to_thread(store.get_analysis, analysis_id)
        status = (existing or {}).get("status")
        if status == "done" or manager.is_running(analysis_id):
            return {"analysisId": analysis_id, "status": status or "queued"}
        await asyncio.to_thread(store.create_analysis, analysis_id, uid, request.aiAssisted)
        manager.start(analysis_id, uid, request.aiAssisted)
        return {"analysisId": analysis_id, "status": "queued"}

    @app.post("/api/analyses/{analysis_id}/cancel")
    async def cancel_analysis(analysis_id: str, uid: str = Depends(current_user)) -> dict[str, str]:
        existing = await asyncio.to_thread(store.get_analysis, analysis_id)
        if existing is None:
            raise HTTPException(404, "No such analysis")
        if existing.get("requestedBy") != uid:
            raise HTTPException(403, "Only who started it can stop it")
        if existing.get("status") not in _RUNNING:
            return {"analysisId": analysis_id, "status": existing["status"]}
        await manager_holder["manager"].cancel(analysis_id)
        await asyncio.to_thread(store.finish_analysis, analysis_id, {"status": "cancelled"})
        return {"analysisId": analysis_id, "status": "cancelled"}

    @app.post("/api/uploads/signature")
    def sign_upload(request: UploadRequest, uid: str = Depends(current_user)) -> dict:
        if signer is None:
            raise HTTPException(503, "Uploads aren't set up on the server.")
        if not _REPORT_FILE.match(request.fileName):
            raise HTTPException(422, "Not a report file name")
        return signer.sign(uid, request.fileName)

    return app


def build_app() -> FastAPI:
    """For uvicorn: `uvicorn --factory orchestrator.main:build_app`."""
    from .store import FirebaseStore, verify_token

    logging.basicConfig(level=logging.INFO)
    key = os.environ.get("GOOGLE_APPLICATION_CREDENTIALS")
    if not key or not os.path.isfile(key):
        raise SystemExit("Set GOOGLE_APPLICATION_CREDENTIALS in .env to the service account key file.")
    signer = CloudinarySigner.from_env()
    if signer is None:
        logger.warning("No CLOUDINARY_* settings: report uploads are off")
    return create_app(FirebaseStore(), verify_token, Steps(Settings.from_env()), signer)
