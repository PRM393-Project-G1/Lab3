"""Firebase adapter for admin announcements; never exposes device tokens to web."""

from __future__ import annotations

import logging
from collections.abc import Callable
from datetime import datetime, timedelta, timezone
from typing import Any

import firebase_admin
from firebase_admin import auth, firestore, messaging
from google.api_core.exceptions import AlreadyExists
from google.cloud.firestore_v1.base_query import FieldFilter

from .directory import Account, changed, directory_fields
from .heartbeat import WORKER_STATUS
from .notification_worker import ADMIN_MESSAGE, DIRECTORY, REQUESTS, Announcement, PushResult

logger = logging.getLogger(__name__)


def list_accounts() -> dict[str, Account]:
    return {record.uid: Account.from_record(record) for record in auth.list_users().iterate_all()}


class FirebaseNotificationStore:
    def __init__(self, db: Any = None, accounts: Callable[[], dict[str, Account]] | None = None) -> None:
        if db is None:
            if not firebase_admin._apps:
                firebase_admin.initialize_app()
            db = firestore.client()
        self._db = db
        self._accounts = accounts or list_accounts

    def sync_directory(self) -> None:
        directory = self._db.collection(DIRECTORY)
        existing = {snapshot.id: snapshot.to_dict() for snapshot in directory.stream()}
        try:
            accounts: dict[str, Account] | None = self._accounts()
        except Exception:
            # Keep the last known Auth fields rather than blank them.
            logger.warning("Could not list Firebase Auth users for the admin directory", exc_info=True)
            accounts = None
        listed = set()
        for snapshot in self._db.collection("users").stream():
            listed.add(snapshot.id)
            previous = existing.get(snapshot.id)
            fields = directory_fields(snapshot.to_dict() or {}, (accounts or {}).get(snapshot.id), previous)
            if changed(previous, fields):
                directory.document(snapshot.id).set({**fields, "updatedAt": firestore.SERVER_TIMESTAMP})
        for uid in existing.keys() - listed:
            directory.document(uid).delete()

    def _request(self, request_id: str):
        return self._db.collection(REQUESTS).document(request_id)

    def queued_ids(self) -> list[str]:
        return [item.id for item in self._db.collection(REQUESTS).where(filter=FieldFilter("status", "==", "queued")).limit(10).stream()]

    def claim(self, request_id: str, owner: str) -> dict[str, Any] | None:
        reference = self._request(request_id)

        @firestore.transactional
        def claim(transaction):
            data = reference.get(transaction=transaction).to_dict() or {}
            if data.get("status") != "queued":
                return None
            transaction.update(reference, {"status": "processing", "workerId": owner,
                "startedAt": firestore.SERVER_TIMESTAMP, "updatedAt": firestore.SERVER_TIMESTAMP})
            return data

        return claim(self._db.transaction())

    def interrupt_stale(self) -> None:
        cutoff = datetime.now(timezone.utc) - timedelta(minutes=10)
        for snapshot in self._db.collection(REQUESTS).where(filter=FieldFilter("status", "==", "processing")).stream():
            @firestore.transactional
            def interrupt(transaction):
                data = snapshot.reference.get(transaction=transaction).to_dict() or {}
                updated = data.get("updatedAt") or data.get("startedAt")
                if data.get("status") == "processing" and isinstance(updated, datetime) and updated < cutoff:
                    transaction.update(snapshot.reference, {"status": "interrupted", "finishedAt": firestore.SERVER_TIMESTAMP,
                        "error": "Worker stopped before completion. No automatic resend; review before creating another request."})
            interrupt(self._db.transaction())

    def is_admin(self, uid: str) -> bool:
        return (self._db.collection("users").document(uid).get().to_dict() or {}).get("role") == "admin"

    def user_ids(self) -> list[str]:
        return [item.id for item in self._db.collection("users").stream() if (item.to_dict() or {}).get("role", "user") == "user"]

    def recipient(self, uid: str) -> dict[str, Any] | None:
        return self._db.collection("users").document(uid).get().to_dict()

    def still_owned(self, request_id: str, owner: str) -> bool:
        data = self._request(request_id).get().to_dict() or {}
        return data.get("status") == "processing" and data.get("workerId") == owner

    def store_inbox(self, uid: str, request_id: str, announcement: Announcement) -> None:
        reference = self._db.collection("users").document(uid).collection("notifications").document(f"admin-{request_id}")
        try:
            item = {"title": announcement.title, "body": announcement.body, "type": ADMIN_MESSAGE,
                "requestId": request_id, "createdAt": firestore.SERVER_TIMESTAMP, "read": False}
            if announcement.analysis_id:
                item["analysisId"] = announcement.analysis_id
            reference.create(item)
        except AlreadyExists:
            # Do not reset a user's read state if an inbox record already exists.
            pass

    def send_push(self, uid: str, tokens: list[str], request_id: str, announcement: Announcement) -> PushResult:
        accepted = failed = unknown = 0
        gone = []
        for offset in range(0, len(tokens), 500):
            batch = tokens[offset:offset + 500]
            try:
                response = messaging.send_each_for_multicast(messaging.MulticastMessage(
                    tokens=batch, notification=messaging.Notification(title=announcement.title, body=announcement.body),
                    data={"type": ADMIN_MESSAGE, "notificationId": f"admin-{request_id}",
                          **({"analysisId": announcement.analysis_id} if announcement.analysis_id else {})},
                    android=messaging.AndroidConfig(priority="high", notification=messaging.AndroidNotification(tag=f"admin-{request_id}")),
                ))
            except Exception:
                unknown += len(batch)
                continue
            accepted += response.success_count
            failed += response.failure_count
            gone.extend(token for token, result in zip(batch, response.responses)
                if isinstance(result.exception, (messaging.UnregisteredError, messaging.SenderIdMismatchError)))
        if gone:
            try:
                self._db.collection("users").document(uid).update({"fcmTokens": firestore.ArrayRemove(gone)})
            except Exception:
                pass  # Token cleanup must not obscure an already accepted push.
        return PushResult(accepted, failed, unknown)

    def update(self, request_id: str, owner: str, fields: dict[str, Any]) -> None:
        reference = self._request(request_id)

        @firestore.transactional
        def update(transaction):
            data = reference.get(transaction=transaction).to_dict() or {}
            if data.get("status") != "processing" or data.get("workerId") != owner:
                return
            values = {**fields, "updatedAt": firestore.SERVER_TIMESTAMP}
            if fields.get("status") in ("completed", "partial", "failed", "interrupted"):
                values["finishedAt"] = firestore.SERVER_TIMESTAMP
            transaction.update(reference, values)

        update(self._db.transaction())

    def heartbeat(self, name: str, fields: dict[str, Any]) -> None:
        self._db.collection(WORKER_STATUS).document(name).set({**fields, "lastSeen": firestore.SERVER_TIMESTAMP}, merge=True)
