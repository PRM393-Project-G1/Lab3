"""Firebase adapter for admin announcements; never exposes device tokens to web."""

from __future__ import annotations

from datetime import datetime, timedelta, timezone
from typing import Any

import firebase_admin
from firebase_admin import firestore, messaging
from google.api_core.exceptions import AlreadyExists
from google.cloud.firestore_v1.base_query import FieldFilter

from .heartbeat import WORKER_STATUS
from .notification_worker import ADMIN_MESSAGE, DIRECTORY, REQUESTS, Announcement, PushResult


class FirebaseNotificationStore:
    def __init__(self, db: Any = None) -> None:
        if db is None:
            if not firebase_admin._apps:
                firebase_admin.initialize_app()
            db = firestore.client()
        self._db = db

    def sync_directory(self) -> None:
        directory = self._db.collection(DIRECTORY)
        existing = {snapshot.id: snapshot.to_dict() for snapshot in directory.stream()}
        eligible = set()
        for snapshot in self._db.collection("users").stream():
            user = snapshot.to_dict() or {}
            if user.get("role", "user") != "user":
                continue
            eligible.add(snapshot.id)
            name, tokens = user.get("displayName"), user.get("fcmTokens")
            fields = {
                "displayName": name if isinstance(name, str) and name.strip() else "Unnamed user",
                "hasDevice": isinstance(tokens, list) and any(isinstance(token, str) and token for token in tokens),
            }
            if any((existing.get(snapshot.id) or {}).get(key) != value for key, value in fields.items()):
                directory.document(snapshot.id).set({**fields, "updatedAt": firestore.SERVER_TIMESTAMP})
        for uid in existing.keys() - eligible:
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
            reference.create({"title": announcement.title, "body": announcement.body, "type": ADMIN_MESSAGE,
                "requestId": request_id, "createdAt": firestore.SERVER_TIMESTAMP, "read": False})
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
                    data={"type": ADMIN_MESSAGE, "notificationId": f"admin-{request_id}"},
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
