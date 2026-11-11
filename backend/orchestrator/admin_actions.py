"""Admin actions: the web queues them in Firestore, the API process carries them out.

The web never calls this server. It creates `adminActions/{id}` with status
`queued` (Firestore Rules check the shape and the admin role), and this worker
claims each one, checks the requester is still an admin, acts with the Admin SDK
and records the outcome. The documents double as the admin audit log.
"""

from __future__ import annotations

import asyncio
import logging
import re
import uuid
from collections.abc import Awaitable, Callable
from dataclasses import dataclass
from typing import Any, Protocol

from .contract import CANCELLED, FAILED, RUNNING

logger = logging.getLogger(__name__)

ACTIONS = "adminActions"
CANCEL_ANALYSIS = "cancelAnalysis"
RETRY_ANALYSIS = "retryAnalysis"
ANALYSIS_ACTIONS = (CANCEL_ANALYSIS, RETRY_ANALYSIS)
STOPPED_BY_ADMIN = "Stopped by an administrator."
GENERIC_FAILURE = "Something went wrong on the server. Check the result before trying again."
RESTARTED = "The backend restarted before finishing this action. Check the result before trying again."

_ACTION_ID = re.compile(r"^[A-Za-z0-9_-]{20,80}$")
_ANALYSIS_ID = re.compile(r"^\d{4}\.\d{4,5}$")


class ActionError(Exception):
    """A refusal written back for the admin to read."""


@dataclass(frozen=True)
class AdminAction:
    type: str
    target: str
    requested_by: str
    reason: str | None = None

    @classmethod
    def parse(cls, data: dict[str, Any]) -> "AdminAction":
        kind, target, sender, reason = data.get("type"), data.get("target"), data.get("requestedBy"), data.get("reason")
        if kind not in ANALYSIS_ACTIONS:
            raise ActionError("This action is not supported by the backend.")
        if not isinstance(sender, str) or not 1 <= len(sender) <= 128 or "/" in sender:
            raise ActionError("Invalid requester.")
        if not isinstance(target, str) or not _ANALYSIS_ID.match(target):
            raise ActionError("Invalid analysis ID.")
        if reason is not None and (not isinstance(reason, str) or len(reason) > 200):
            raise ActionError("The reason must be at most 200 characters.")
        return cls(kind, target, sender, reason.strip() or None if isinstance(reason, str) else None)


class ActionStore(Protocol):
    def queued_action_ids(self) -> list[str]: ...
    def claim_action(self, action_id: str, owner: str) -> dict[str, Any] | None: ...
    def finish_action(self, action_id: str, owner: str, fields: dict[str, Any]) -> None: ...
    def fail_unfinished_actions(self, message: str) -> int: ...
    def is_admin(self, uid: str) -> bool: ...
    def get_analysis(self, analysis_id: str) -> dict[str, Any] | None: ...
    def create_analysis(self, analysis_id: str, uid: str, ai_assisted: bool) -> None: ...
    def finish_analysis(self, analysis_id: str, fields: dict[str, Any]) -> None: ...


class Jobs(Protocol):
    def is_running(self, analysis_id: str) -> bool: ...
    def start(self, analysis_id: str, uid: str, ai_assisted: bool) -> None: ...
    async def cancel(self, analysis_id: str) -> None: ...


class AdminActionWorker:
    def __init__(self, store: ActionStore, jobs: Jobs, poll_seconds: float = 10) -> None:
        self._store = store
        self._jobs = jobs
        self._owner = str(uuid.uuid4())
        self._poll_seconds = poll_seconds
        self._handlers: dict[str, Callable[[AdminAction], Awaitable[str]]] = {
            CANCEL_ANALYSIS: self._cancel_analysis,
            RETRY_ANALYSIS: self._retry_analysis,
        }

    async def tick(self) -> None:
        for action_id in await asyncio.to_thread(self._store.queued_action_ids):
            await self.process(action_id)

    async def process(self, action_id: str) -> None:
        if not _ACTION_ID.match(action_id):
            return
        data = await asyncio.to_thread(self._store.claim_action, action_id, self._owner)
        if data is None:
            return
        try:
            action = AdminAction.parse(data)
            if not await asyncio.to_thread(self._store.is_admin, action.requested_by):
                raise ActionError("The requester no longer has admin access.")
            outcome = {"status": "completed", "result": await self._handlers[action.type](action), "error": None}
        except ActionError as error:
            outcome = {"status": "failed", "error": str(error)}
        except Exception:
            logger.exception("Admin action %s failed", action_id)
            outcome = {"status": "failed", "error": GENERIC_FAILURE}
        await asyncio.to_thread(self._store.finish_action, action_id, self._owner, outcome)

    async def _analysis(self, action: AdminAction) -> dict[str, Any]:
        analysis = await asyncio.to_thread(self._store.get_analysis, action.target)
        if analysis is None:
            raise ActionError("This analysis no longer exists.")
        return analysis

    async def _cancel_analysis(self, action: AdminAction) -> str:
        analysis = await self._analysis(action)
        if analysis.get("status") not in RUNNING:
            raise ActionError(f"Only queued or processing analyses can be stopped; this one is {analysis.get('status')}.")
        await self._jobs.cancel(action.target)
        await asyncio.to_thread(self._store.finish_analysis, action.target, {"status": CANCELLED, "error": STOPPED_BY_ADMIN})
        return "Analysis stopped. The requester sees it as stopped by an administrator."

    async def _retry_analysis(self, action: AdminAction) -> str:
        analysis = await self._analysis(action)
        if analysis.get("status") not in (FAILED, CANCELLED):
            raise ActionError(f"Only failed or stopped analyses can be run again; this one is {analysis.get('status')}.")
        if self._jobs.is_running(action.target):
            raise ActionError("This analysis is already running.")
        # The original requester keeps ownership and receives the "done" notification.
        uid = analysis.get("requestedBy") if isinstance(analysis.get("requestedBy"), str) else action.requested_by
        ai_assisted = analysis.get("aiAssisted") if isinstance(analysis.get("aiAssisted"), bool) else True
        await asyncio.to_thread(self._store.create_analysis, action.target, uid, ai_assisted)
        self._jobs.start(action.target, uid, ai_assisted)
        return "Analysis queued again with its original settings."

    async def run(self, stop: asyncio.Event) -> None:
        try:
            failed = await asyncio.to_thread(self._store.fail_unfinished_actions, RESTARTED)
            if failed:
                logger.warning("Marked %d unfinished admin actions as failed", failed)
        except Exception:
            logger.exception("Could not check for unfinished admin actions")
        while not stop.is_set():
            try:
                await self.tick()
            except Exception:
                logger.exception("Admin action worker could not complete its poll")
            try:
                await asyncio.wait_for(stop.wait(), timeout=self._poll_seconds)
            except TimeoutError:
                pass
