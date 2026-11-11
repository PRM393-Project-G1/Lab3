"""Everything the backend writes to Firebase."""

from __future__ import annotations

import logging
from collections.abc import Iterable
from typing import Any

import firebase_admin
from firebase_admin import auth, exceptions, firestore, messaging

from .contract import DONE, DONE_TYPE, FAILED, QUEUED, RUNNING
from .admin_actions import ACTIONS
from .heartbeat import WORKER_STATUS

logger = logging.getLogger(__name__)

BATCH_SIZE = 500
RESTARTED = "The server restarted. Try again."
_TOKEN_GONE = (messaging.UnregisteredError, messaging.SenderIdMismatchError)


def verify_token(token: str) -> str:
    """Returns the user's ID. Raises ValueError for any token that is not valid."""
    try:
        return auth.verify_id_token(token)["uid"]
    except (ValueError, exceptions.FirebaseError) as error:
        raise ValueError("Invalid token") from error


class FirebaseStore:
    """Uses the service account named by GOOGLE_APPLICATION_CREDENTIALS."""

    def __init__(self, db: Any = None) -> None:
        if db is None:
            if not firebase_admin._apps:
                firebase_admin.initialize_app()
            db = firestore.client()
        self._db = db

    def _analysis(self, analysis_id: str):
        return self._db.collection("analyses").document(analysis_id)

    def get_analysis(self, analysis_id: str) -> dict[str, Any] | None:
        snapshot = self._analysis(analysis_id).get()
        return snapshot.to_dict() if snapshot.exists else None

    def create_analysis(self, analysis_id: str, uid: str, ai_assisted: bool) -> None:
        self._analysis(analysis_id).set(
            {
                "requestedBy": uid,
                "aiAssisted": ai_assisted,
                "createdAt": firestore.SERVER_TIMESTAMP,
                "status": QUEUED,
                "progress": {"stage": "references", "percent": 0, "processedRefs": 0},
                "error": None,
                "updatedAt": firestore.SERVER_TIMESTAMP,
            },
            merge=True,
        )

    def update_analysis(self, analysis_id: str, fields: dict[str, Any]) -> None:
        # `updatedAt` lets the admin web tell a slow job from a stalled one.
        self._analysis(analysis_id).set({**fields, "updatedAt": firestore.SERVER_TIMESTAMP}, merge=True)

    def heartbeat(self, name: str, fields: dict[str, Any]) -> None:
        self._db.collection(WORKER_STATUS).document(name).set({**fields, "lastSeen": firestore.SERVER_TIMESTAMP}, merge=True)

    def is_admin(self, uid: str) -> bool:
        return (self._db.collection("users").document(uid).get().to_dict() or {}).get("role") == "admin"

    def _action(self, action_id: str):
        return self._db.collection(ACTIONS).document(action_id)

    def queued_action_ids(self) -> list[str]:
        query = self._db.collection(ACTIONS).where(filter=firestore.FieldFilter("status", "==", "queued")).limit(20)
        return [snapshot.id for snapshot in query.stream()]

    def claim_action(self, action_id: str, owner: str) -> dict[str, Any] | None:
        reference = self._action(action_id)

        @firestore.transactional
        def claim(transaction):
            data = reference.get(transaction=transaction).to_dict() or {}
            if data.get("status") != "queued":
                return None
            transaction.update(reference, {"status": "processing", "workerId": owner, "startedAt": firestore.SERVER_TIMESTAMP})
            return data

        return claim(self._db.transaction())

    def finish_action(self, action_id: str, owner: str, fields: dict[str, Any]) -> None:
        reference = self._action(action_id)

        @firestore.transactional
        def finish(transaction):
            data = reference.get(transaction=transaction).to_dict() or {}
            if data.get("status") == "processing" and data.get("workerId") == owner:
                transaction.update(reference, {**fields, "finishedAt": firestore.SERVER_TIMESTAMP})

        finish(self._db.transaction())

    def fail_unfinished_actions(self, message: str) -> int:
        query = self._db.collection(ACTIONS).where(filter=firestore.FieldFilter("status", "==", "processing"))
        count = 0
        for snapshot in query.stream():
            snapshot.reference.update({"status": "failed", "error": message, "finishedAt": firestore.SERVER_TIMESTAMP})
            count += 1
        return count

    def completed_analyses(self) -> Iterable[tuple[str, dict[str, Any]]]:
        query = self._db.collection("analyses").where(filter=firestore.FieldFilter("status", "==", DONE))
        for snapshot in query.stream():
            yield snapshot.id, snapshot.to_dict() or {}

    def topics_of(self, analysis_id: str) -> list[dict[str, Any]]:
        return [snapshot.to_dict() or {} for snapshot in self._analysis(analysis_id).collection("topics").stream()]

    def finish_analysis(self, analysis_id: str, fields: dict[str, Any]) -> None:
        self.update_analysis(analysis_id, {**fields, "finishedAt": firestore.SERVER_TIMESTAMP})

    def delete_analysis(self, analysis_id: str) -> None:
        """Deletes the results before the analysis, so after a partial failure the analysis
        is still listed and deleting it again finishes the job."""
        parent = self._analysis(analysis_id)
        for name in ("references", "topics"):
            snapshots = list(parent.collection(name).stream())
            for offset in range(0, len(snapshots), BATCH_SIZE):
                batch = self._db.batch()
                for snapshot in snapshots[offset:offset + BATCH_SIZE]:
                    batch.delete(snapshot.reference)
                batch.commit()
        parent.delete()

    def fail_interrupted(self) -> int:
        """After a restart nothing is running, so the app must not keep waiting."""
        query = self._db.collection("analyses").where(
            filter=firestore.FieldFilter("status", "in", list(RUNNING))
        )
        count = 0
        for snapshot in query.stream():
            snapshot.reference.set({"status": FAILED, "error": RESTARTED}, merge=True)
            count += 1
        return count

    def replace_results(
        self,
        analysis_id: str,
        references: Iterable[dict[str, Any]],
        topics: Iterable[dict[str, Any]],
    ) -> None:
        """Replaces whatever an earlier run left, so old topics cannot linger."""
        parent = self._analysis(analysis_id)
        batch = self._db.batch()
        pending = 0

        def commit_if_full() -> None:
            nonlocal batch, pending
            pending += 1
            if pending >= BATCH_SIZE:
                batch.commit()
                batch, pending = self._db.batch(), 0

        for name in ("references", "topics"):
            for snapshot in parent.collection(name).stream():
                batch.delete(snapshot.reference)
                commit_if_full()
        for name, docs in (("references", references), ("topics", topics)):
            for doc in docs:
                fields = {key: value for key, value in doc.items() if key != "id"}
                batch.set(parent.collection(name).document(doc["id"]), fields)
                commit_if_full()
        if pending:
            batch.commit()

    def users_with_tokens(self) -> list[str]:
        return [
            snapshot.id
            for snapshot in self._db.collection("users").stream()
            if (snapshot.to_dict() or {}).get("fcmTokens")
        ]

    def notify_done(self, uid: str, analysis_id: str, title: str, body: str) -> None:
        """Adds the inbox item and sends the push. A push is never worth failing a job."""
        user = self._db.collection("users").document(uid)
        user.collection("notifications").add(
            {
                "title": title,
                "body": body,
                "type": DONE_TYPE,
                "analysisId": analysis_id,
                "createdAt": firestore.SERVER_TIMESTAMP,
                "read": False,
            }
        )
        snapshot = user.get()
        tokens = (snapshot.to_dict() or {}).get("fcmTokens") or [] if snapshot.exists else []
        if not tokens:
            return
        response = messaging.send_each_for_multicast(
            messaging.MulticastMessage(
                tokens=tokens,
                notification=messaging.Notification(title=title, body=body),
                data={"analysisId": analysis_id},
                android=messaging.AndroidConfig(priority="high"),
            )
        )
        gone = [
            token
            for token, result in zip(tokens, response.responses)
            if not result.success and isinstance(result.exception, _TOKEN_GONE)
        ]
        if gone:
            user.update({"fcmTokens": firestore.ArrayRemove(gone)})
        logger.info("Push for %s: %d sent, %d removed", analysis_id, response.success_count, len(gone))
