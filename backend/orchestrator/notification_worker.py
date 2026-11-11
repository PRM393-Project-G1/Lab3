"""Admin announcement queue. No automatic replay after an uncertain push attempt."""

from __future__ import annotations

import asyncio
import logging
import re
import time
import uuid
from dataclasses import asdict, dataclass
from typing import Any, Protocol

logger = logging.getLogger(__name__)
ADMIN_MESSAGE = "admin_message"
REQUESTS = "adminNotificationRequests"
DIRECTORY = "adminUserDirectory"


@dataclass(frozen=True)
class Announcement:
    title: str
    body: str
    requested_by: str
    audience: str
    recipient_uids: tuple[str, ...]

    @classmethod
    def parse(cls, data: dict[str, Any]) -> "Announcement":
        title, body, sender = data.get("title"), data.get("body"), data.get("requestedBy")
        if not isinstance(title, str) or not 1 <= len(title.strip()) <= 80:
            raise ValueError("Title must contain 1–80 characters.")
        if not isinstance(body, str) or not 1 <= len(body.strip()) <= 500:
            raise ValueError("Message must contain 1–500 characters.")
        if len((title + body).encode("utf-8")) > 3000:
            raise ValueError("Message is too large for push notifications.")
        if not isinstance(sender, str) or not 1 <= len(sender) <= 128 or "/" in sender:
            raise ValueError("Invalid sender.")
        audience, uids = data.get("audience"), data.get("recipientUids")
        if audience not in ("all", "selected") or not isinstance(uids, list):
            raise ValueError("Invalid audience.")
        if any(not isinstance(uid, str) or not 1 <= len(uid) <= 128 or "/" in uid for uid in uids):
            raise ValueError("Invalid recipient.")
        if len(set(uids)) != len(uids) or len(uids) > 100:
            raise ValueError("Select at most 100 distinct recipients.")
        if (audience == "all" and uids) or (audience == "selected" and not uids):
            raise ValueError("The recipient list does not match the audience.")
        return cls(title.strip(), body.strip(), sender, audience, tuple(uids))


@dataclass
class DeliveryCounts:
    recipients: int = 0
    inboxStored: int = 0
    pushAccepted: int = 0
    pushFailed: int = 0
    pushUnknown: int = 0
    withoutDevice: int = 0
    skipped: int = 0
    inboxFailed: int = 0


@dataclass(frozen=True)
class PushResult:
    accepted: int = 0
    failed: int = 0
    unknown: int = 0


class NotificationStore(Protocol):
    def sync_directory(self) -> None: ...
    def interrupt_stale(self) -> None: ...
    def queued_ids(self) -> list[str]: ...
    def claim(self, request_id: str, owner: str) -> dict[str, Any] | None: ...
    def is_admin(self, uid: str) -> bool: ...
    def user_ids(self) -> list[str]: ...
    def recipient(self, uid: str) -> dict[str, Any] | None: ...
    def still_owned(self, request_id: str, owner: str) -> bool: ...
    def store_inbox(self, uid: str, request_id: str, announcement: Announcement) -> None: ...
    def send_push(self, uid: str, tokens: list[str], request_id: str, announcement: Announcement) -> PushResult: ...
    def update(self, request_id: str, owner: str, fields: dict[str, Any]) -> None: ...


class NotificationWorker:
    def __init__(self, store: NotificationStore, poll_seconds: float = 10) -> None:
        self._store = store
        self._owner = str(uuid.uuid4())
        self._poll_seconds = poll_seconds
        self._last_sync = float("-inf")

    def tick(self) -> None:
        if time.monotonic() - self._last_sync >= 60:
            self._store.sync_directory()
            self._store.interrupt_stale()
            self._last_sync = time.monotonic()
        for request_id in self._store.queued_ids():
            self.process(request_id)

    def process(self, request_id: str) -> None:
        if not re.fullmatch(r"[A-Za-z0-9_-]{20,80}", request_id):
            return
        data = self._store.claim(request_id, self._owner)
        if data is None:
            return
        counts = DeliveryCounts()
        try:
            announcement = Announcement.parse(data)
            if not self._store.is_admin(announcement.requested_by):
                raise ValueError("The sender no longer has admin access.")
            uids = self._store.user_ids() if announcement.audience == "all" else list(announcement.recipient_uids)
            counts.recipients = len(uids)
            if not uids:
                raise ValueError("No eligible users were found.")
            self._store.update(request_id, self._owner, {"counts": asdict(counts)})
            for uid in uids:
                if not self._store.still_owned(request_id, self._owner):
                    return
                # Revocation during a broadcast also stops subsequent recipients.
                if not self._store.is_admin(announcement.requested_by):
                    raise ValueError("Admin access was revoked while processing this request.")
                user = self._store.recipient(uid)
                if user is None or user.get("role", "user") != "user":
                    counts.skipped += 1
                else:
                    try:
                        self._store.store_inbox(uid, request_id, announcement)
                    except Exception:
                        counts.inboxFailed += 1
                        logger.warning("Could not store an announcement inbox item")
                    else:
                        counts.inboxStored += 1
                        raw_tokens = user.get("fcmTokens")
                        tokens = sorted({token for token in raw_tokens if isinstance(token, str) and token}) if isinstance(raw_tokens, list) else []
                        if not tokens:
                            counts.withoutDevice += 1
                        else:
                            result = self._store.send_push(uid, tokens, request_id, announcement)
                            counts.pushAccepted += result.accepted
                            counts.pushFailed += result.failed
                            counts.pushUnknown += result.unknown
                self._store.update(request_id, self._owner, {"counts": asdict(counts)})
            partial = counts.skipped or counts.inboxFailed or counts.pushFailed or counts.pushUnknown
            self._store.update(request_id, self._owner, {
                "status": "partial" if partial else "completed", "counts": asdict(counts),
                "error": "Some recipients or push attempts need review." if partial else None,
            })
        except ValueError as error:
            self._store.update(request_id, self._owner, {
                "status": "partial" if counts.inboxStored else "failed", "error": str(error), "counts": asdict(counts),
            })
        except Exception:
            # A network failure may follow FCM acceptance. Never replay blindly.
            logger.exception("Announcement processing was interrupted")
            self._store.update(request_id, self._owner, {
                "status": "interrupted", "error": "Processing was interrupted. Push outcome may be uncertain; no automatic resend.",
                "counts": asdict(counts),
            })

    async def run(self, stop: asyncio.Event) -> None:
        while not stop.is_set():
            try:
                await asyncio.to_thread(self.tick)
            except Exception:
                logger.exception("Announcement worker could not complete its poll")
            try:
                await asyncio.wait_for(stop.wait(), timeout=self._poll_seconds)
            except TimeoutError:
                pass


def main() -> None:
    import os
    from dotenv import load_dotenv
    from .config import BACKEND_DIR
    from .notification_store import FirebaseNotificationStore

    load_dotenv(BACKEND_DIR / ".env")
    if not os.path.isfile(os.environ.get("GOOGLE_APPLICATION_CREDENTIALS", "")):
        raise SystemExit("Set GOOGLE_APPLICATION_CREDENTIALS to the Firebase service account file.")
    logging.basicConfig(level=logging.INFO)
    worker = NotificationWorker(FirebaseNotificationStore())
    try:
        asyncio.run(worker.run(asyncio.Event()))
    except KeyboardInterrupt:
        pass


if __name__ == "__main__":
    main()
