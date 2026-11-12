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
from datetime import datetime, timezone
from typing import Any, Protocol

from .contract import CANCELLED, DONE, FAILED, RUNNING

logger = logging.getLogger(__name__)

ACTIONS = "adminActions"
CANCEL_ANALYSIS = "cancelAnalysis"
RETRY_ANALYSIS = "retryAnalysis"
HIDE_ANALYSIS = "hideAnalysis"
UNHIDE_ANALYSIS = "unhideAnalysis"
DELETE_ANALYSIS = "deleteAnalysis"
ANALYSIS_ACTIONS = (CANCEL_ANALYSIS, RETRY_ANALYSIS, HIDE_ANALYSIS, UNHIDE_ANALYSIS, DELETE_ANALYSIS)
SET_ROLE = "setRole"
SET_DISABLED = "setDisabled"
USER_ACTIONS = (SET_ROLE, SET_DISABLED)
STOPPED_BY_ADMIN = "Stopped by an administrator."
VISIBLE = {"hidden": False, "hiddenReason": None, "hiddenBy": None, "hiddenAt": None}
GENERIC_FAILURE = "Something went wrong on the server. Check the result before trying again."
RESTARTED = "The backend restarted before finishing this action. Check the result before trying again."

_ACTION_ID = re.compile(r"^[A-Za-z0-9_-]{20,80}$")
_ANALYSIS_ID = re.compile(r"^\d{4}\.\d{4,5}$")


class ActionError(Exception):
    """A refusal written back for the admin to read."""


def _is_uid(value: Any) -> bool:
    return isinstance(value, str) and 1 <= len(value) <= 128 and "/" not in value


@dataclass(frozen=True)
class AdminAction:
    type: str
    target: str
    requested_by: str
    reason: str | None = None
    role: str | None = None
    disabled: bool | None = None

    @classmethod
    def parse(cls, data: dict[str, Any]) -> "AdminAction":
        kind, target, sender, reason = data.get("type"), data.get("target"), data.get("requestedBy"), data.get("reason")
        if kind not in ANALYSIS_ACTIONS + USER_ACTIONS:
            raise ActionError("This action is not supported by the backend.")
        if not _is_uid(sender):
            raise ActionError("Invalid requester.")
        if reason is not None and (not isinstance(reason, str) or len(reason) > 200):
            raise ActionError("The reason must be at most 200 characters.")
        reason = reason.strip() or None if isinstance(reason, str) else None
        if kind in ANALYSIS_ACTIONS:
            if not isinstance(target, str) or not _ANALYSIS_ID.match(target):
                raise ActionError("Invalid analysis ID.")
            return cls(kind, target, sender, reason)
        if not _is_uid(target):
            raise ActionError("Invalid user ID.")
        if target == sender:
            raise ActionError("Admins cannot change their own role or account.")
        role, disabled = data.get("role"), data.get("disabled")
        if kind == SET_ROLE and role not in ("admin", "user"):
            raise ActionError("The role must be admin or user.")
        if kind == SET_DISABLED and not isinstance(disabled, bool):
            raise ActionError("Choose whether to disable or enable the account.")
        return cls(kind, target, sender, reason, role if kind == SET_ROLE else None, disabled if kind == SET_DISABLED else None)


class ActionStore(Protocol):
    def queued_action_ids(self) -> list[str]: ...
    def claim_action(self, action_id: str, owner: str) -> dict[str, Any] | None: ...
    def finish_action(self, action_id: str, owner: str, fields: dict[str, Any]) -> None: ...
    def fail_unfinished_actions(self, message: str) -> int: ...
    def is_admin(self, uid: str) -> bool: ...
    def get_analysis(self, analysis_id: str) -> dict[str, Any] | None: ...
    def create_analysis(self, analysis_id: str, uid: str, ai_assisted: bool) -> None: ...
    def finish_analysis(self, analysis_id: str, fields: dict[str, Any]) -> None: ...
    def update_analysis(self, analysis_id: str, fields: dict[str, Any]) -> None: ...
    def delete_analysis(self, analysis_id: str) -> None: ...
    def get_user(self, uid: str) -> dict[str, Any] | None: ...
    def admin_count(self) -> int: ...
    def set_role(self, uid: str, role: str) -> None: ...
    def set_disabled(self, uid: str, disabled: bool) -> None: ...


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
            HIDE_ANALYSIS: self._hide_analysis,
            UNHIDE_ANALYSIS: self._unhide_analysis,
            DELETE_ANALYSIS: self._delete_analysis,
            SET_ROLE: self._set_role,
            SET_DISABLED: self._set_disabled,
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
        hidden = analysis.get("hidden") is True
        # Hidden results were judged wrong, so they may be produced again too.
        if analysis.get("status") not in (FAILED, CANCELLED) and not (hidden and analysis.get("status") == DONE):
            raise ActionError(f"Only failed, stopped or hidden analyses can be run again; this one is {analysis.get('status')}.")
        if self._jobs.is_running(action.target):
            raise ActionError("This analysis is already running.")
        # The original requester keeps ownership and receives the "done" notification.
        uid = analysis.get("requestedBy") if isinstance(analysis.get("requestedBy"), str) else action.requested_by
        ai_assisted = analysis.get("aiAssisted") if isinstance(analysis.get("aiAssisted"), bool) else True
        await asyncio.to_thread(self._store.create_analysis, action.target, uid, ai_assisted)
        if hidden:
            await asyncio.to_thread(self._store.update_analysis, action.target, VISIBLE)
        self._jobs.start(action.target, uid, ai_assisted)
        return "Analysis queued again with its original settings."

    async def _hide_analysis(self, action: AdminAction) -> str:
        analysis = await self._analysis(action)
        if analysis.get("status") != DONE:
            raise ActionError(f"Only completed analyses can be hidden; this one is {analysis.get('status')}.")
        if analysis.get("hidden") is True:
            raise ActionError("This analysis is already hidden.")
        await asyncio.to_thread(self._store.update_analysis, action.target, {
            "hidden": True, "hiddenReason": action.reason, "hiddenBy": action.requested_by,
            "hiddenAt": datetime.now(timezone.utc)})
        return "Results hidden. Users now see that an administrator removed them."

    async def _unhide_analysis(self, action: AdminAction) -> str:
        analysis = await self._analysis(action)
        if analysis.get("hidden") is not True:
            raise ActionError("This analysis is not hidden.")
        await asyncio.to_thread(self._store.update_analysis, action.target, VISIBLE)
        return "Results visible to users again."

    async def _delete_analysis(self, action: AdminAction) -> str:
        analysis = await self._analysis(action)
        if analysis.get("status") in RUNNING or self._jobs.is_running(action.target):
            raise ActionError("Stop this analysis before deleting it.")
        await asyncio.to_thread(self._store.delete_analysis, action.target)
        return "Analysis and its results deleted. Users can request the paper again."

    async def _user(self, action: AdminAction) -> dict[str, Any]:
        user = await asyncio.to_thread(self._store.get_user, action.target)
        if user is None:
            raise ActionError("This user has no Realtron profile.")
        return user

    async def _set_role(self, action: AdminAction) -> str:
        user = await self._user(action)
        current = "admin" if user.get("role") == "admin" else "user"
        if current == action.role:
            raise ActionError(f"This user is already {'an admin' if current == 'admin' else 'a regular user'}.")
        if action.role == "admin" and user.get("disabled") is True:
            raise ActionError("Enable this account before making it an admin.")
        if action.role == "user" and await asyncio.to_thread(self._store.admin_count) <= 1:
            raise ActionError("Realtron needs at least one admin.")
        await asyncio.to_thread(self._store.set_role, action.target, action.role)
        return "Admin access granted." if action.role == "admin" else "Admin access removed. The web workspace closes for them at once."

    async def _set_disabled(self, action: AdminAction) -> str:
        user = await self._user(action)
        if action.disabled and user.get("role") == "admin":
            raise ActionError("Remove admin access before disabling this account.")
        await asyncio.to_thread(self._store.set_disabled, action.target, bool(action.disabled))
        return ("Account disabled. The user is signed out within an hour and cannot sign in again."
                if action.disabled else "Account enabled. The user can sign in again.")

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
