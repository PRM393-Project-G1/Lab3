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
    # Never reach real Firebase Auth from a test.
    yield FirebaseNotificationStore(db, accounts=lambda: {})
    db.close()


def test_transaction_claim_has_exactly_one_owner(store):
    reference = store._request("emulator-claim-request-12345")
    reference.set({"status": "queued", "title": "Test"})
    with ThreadPoolExecutor(max_workers=2) as pool:
        claims = list(pool.map(lambda owner: store.claim(reference.id, owner), ["one", "two"]))
    assert sum(value is not None for value in claims) == 1
    assert reference.get().to_dict()["status"] == "processing"



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


def test_heartbeat_merges_fields_and_stamps_server_time(store):
    reference = store._db.collection("workerStatus").document("notifications")
    store.heartbeat("notifications", {"state": "running", "version": "test"})
    first = reference.get().to_dict()
    assert first["state"] == "running" and isinstance(first["lastSeen"], datetime)
    store.heartbeat("notifications", {"state": "stopped"})
    assert reference.get().to_dict() | {"lastSeen": None} == {"state": "stopped", "version": "test", "lastSeen": None}


def test_directory_lists_every_profile_with_auth_fields_but_never_tokens(store):
    from orchestrator.directory import Account
    db = store._db
    created = datetime(2026, 11, 1, tzinfo=timezone.utc)
    store._accounts = lambda: {"emulator-directory-user": Account("user@example.test", False, created, None)}
    user = db.collection("users").document("emulator-directory-user")
    user.set({"role": "user", "displayName": "User", "fcmTokens": ["private-token"]})
    store.sync_directory()
    projection = db.collection("adminUserDirectory").document(user.id)
    data = projection.get().to_dict()
    assert set(data) == {"displayName", "hasDevice", "role", "email", "disabled", "createdAt", "lastSignInAt", "updatedAt"}
    assert (data["hasDevice"], data["role"], data["email"], data["disabled"], data["createdAt"]) == (True, "user", "user@example.test", False, created)
    user.update({"displayName": 123, "fcmTokens": "malformed-token-list", "role": "admin"})
    store.sync_directory()
    data = projection.get().to_dict()
    assert (data["displayName"], data["hasDevice"], data["role"]) == ("Unnamed user", False, "admin")

    def unavailable():
        raise RuntimeError("Auth is down")

    store._accounts = unavailable
    store.sync_directory()
    assert projection.get().to_dict()["email"] == "user@example.test"
    user.delete()
    store.sync_directory()
    assert not projection.get().exists


def test_a_linked_paper_is_stored_in_the_inbox_item(store):
    from orchestrator.notification_worker import Announcement
    announcement = Announcement("Title", "Body", "admin", "selected", ("emulator-link-user",), "1706.03762")
    store.store_inbox("emulator-link-user", "emulator-link-request-12345", announcement)
    item = store._db.document("users/emulator-link-user/notifications/admin-emulator-link-request-12345").get().to_dict()
    assert item["analysisId"] == "1706.03762" and item["type"] == "admin_message"


def test_scheduled_requests_wait_until_due_and_cancelled_ones_never_run(store):
    now = datetime.now(timezone.utc)
    requests = store._db.collection("adminNotificationRequests")
    requests.document("emulator-scheduled-future-1").set({"status": "queued", "sendAt": now + timedelta(hours=1)})
    requests.document("emulator-scheduled-due-0001").set({"status": "queued", "sendAt": now - timedelta(minutes=1)})
    requests.document("emulator-scheduled-cancelled").set({"status": "cancelled", "sendAt": now - timedelta(minutes=1)})
    queued = store.queued_ids()
    assert "emulator-scheduled-due-0001" in queued
    assert "emulator-scheduled-future-1" not in queued and "emulator-scheduled-cancelled" not in queued
    assert store.claim("emulator-scheduled-future-1", "worker") is None
    assert store.claim("emulator-scheduled-cancelled", "worker") is None
    assert store.claim("emulator-scheduled-due-0001", "worker") is not None
