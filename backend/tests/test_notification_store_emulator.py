"""Optional adapter integration checks. Refuse live credentials; only a local emulator."""
import os
from concurrent.futures import ThreadPoolExecutor
from datetime import datetime, timedelta, timezone
from types import SimpleNamespace

import pytest

pytestmark = pytest.mark.skipif(not os.environ.get("FIRESTORE_EMULATOR_HOST"), reason="Requires local Firestore emulator")


@pytest.fixture
def store():
    from google.auth.credentials import AnonymousCredentials
    from google.cloud.firestore import Client
    from orchestrator.notification_store import FirebaseNotificationStore
    address = os.environ["FIRESTORE_EMULATOR_HOST"]
    assert address.startswith(("127.0.0.1:", "localhost:")), "This test is local-only"
    db = Client(project="demo-realtron-admin", credentials=AnonymousCredentials())
    yield FirebaseNotificationStore(db)
    db.close()


def test_transaction_claim_has_exactly_one_owner(store):
    reference = store._request("emulator-claim-request-12345")
    reference.set({"status": "queued", "title": "Test"})
    with ThreadPoolExecutor(max_workers=2) as pool:
        claims = list(pool.map(lambda owner: store.claim(reference.id, owner), ["one", "two"]))
    assert sum(value is not None for value in claims) == 1
    assert reference.get().to_dict()["status"] == "processing"


def test_directory_projection_never_exposes_device_tokens_and_removes_admins(store):
    db = store._db
    user = db.collection("users").document("emulator-directory-user")
    user.set({"role": "user", "displayName": "User", "fcmTokens": ["private-token"]})
    store.sync_directory()
    projection = db.collection("adminUserDirectory").document(user.id)
    assert set(projection.get().to_dict()) == {"displayName", "hasDevice", "updatedAt"}
    assert projection.get().to_dict()["hasDevice"] is True
    user.update({"displayName": 123, "fcmTokens": "malformed-token-list"})
    store.sync_directory()
    assert projection.get().to_dict()["displayName"] == "Unnamed user"
    assert projection.get().to_dict()["hasDevice"] is False
    user.update({"role": "admin"})
    store.sync_directory()
    assert not projection.get().exists


def test_inbox_create_is_idempotent_and_does_not_reset_read(store):
    from orchestrator.notification_worker import Announcement
    announcement = Announcement("Title", "Body", "admin", "selected", ("emulator-inbox-user",))
    store.store_inbox("emulator-inbox-user", "emulator-inbox-request-1234", announcement)
    reference = store._db.document("users/emulator-inbox-user/notifications/admin-emulator-inbox-request-1234")
    reference.update({"read": True})
    store.store_inbox("emulator-inbox-user", "emulator-inbox-request-1234", announcement)
    assert reference.get().to_dict()["read"] is True
    assert reference.get().to_dict()["type"] == "admin_message"


def test_stale_processing_is_interrupted_without_overwriting_an_active_owner(store):
    stale = store._request("emulator-stale-request-1234")
    active = store._request("emulator-active-request-1234")
    stale.set({"status": "processing", "workerId": "old", "updatedAt": datetime.now(timezone.utc) - timedelta(minutes=11)})
    active.set({"status": "processing", "workerId": "new", "updatedAt": datetime.now(timezone.utc)})
    store.interrupt_stale()
    assert stale.get().to_dict()["status"] == "interrupted"
    assert active.get().to_dict()["status"] == "processing"
    store.update(stale.id, "old", {"status": "completed"})
    assert stale.get().to_dict()["status"] == "interrupted"


def test_push_chunks_are_bounded_and_invalid_tokens_are_removed(store, monkeypatch):
    from firebase_admin import messaging
    from orchestrator.notification_worker import Announcement
    batches = []
    tokens = [f"fixture-token-{i}" for i in range(501)]
    store._db.document("users/emulator-push-user").set({"role": "user", "fcmTokens": tokens})
    def fake_send(message):
        batches.append(message)
        return SimpleNamespace(success_count=len(message.tokens) - 1, failure_count=1,
            responses=[SimpleNamespace(exception=messaging.UnregisteredError("gone"))] +
                      [SimpleNamespace(exception=None) for _ in message.tokens[1:]])
    monkeypatch.setattr(messaging, "send_each_for_multicast", fake_send)
    result = store.send_push("emulator-push-user", tokens, "emulator-push-request-1234", Announcement("Title", "Body", "admin", "all", ()))
    assert [len(batch.tokens) for batch in batches] == [500, 1]
    assert result.accepted == 499 and result.failed == 2
    assert batches[0].data["type"] == "admin_message"
    remaining = store._db.document("users/emulator-push-user").get().to_dict()["fcmTokens"]
    assert tokens[0] not in remaining and tokens[500] not in remaining
