from copy import deepcopy
import asyncio

import pytest

from orchestrator.notification_worker import Announcement, NotificationWorker, PushResult

REQUEST_ID = "a-valid-announcement-request-1234"


class FakeNotificationStore:
    def __init__(self):
        self.users = {"admin": {"role": "admin"}, "a": {"role": "user", "fcmTokens": ["t1", "t1"]},
                      "b": {"role": "user", "fcmTokens": []}}
        self.requests = {REQUEST_ID: {"title": "Update", "body": "A useful message", "audience": "all",
                                    "recipientUids": [], "requestedBy": "admin", "status": "queued"}}
        self.inbox = {}
        self.pushes = []
        self.result = PushResult(accepted=1)
        self.inbox_failures = set()
        self.crash_push = False
        self.revoke_after_first = False
        self.synced = 0
        self.heartbeats = []
        self.read_refreshes = 0

    def sync_directory(self): self.synced += 1
    def heartbeat(self, name, fields): self.heartbeats.append((name, fields["state"]))
    def refresh_read_counts(self): self.read_refreshes += 1
    def interrupt_stale(self): pass
    def queued_ids(self): return [key for key, value in self.requests.items() if value["status"] == "queued"]
    def claim(self, request_id, owner):
        value = self.requests.get(request_id)
        if not value or value["status"] != "queued": return None
        original = deepcopy(value)
        value.update(status="processing", workerId=owner)
        return original
    def is_admin(self, uid): return self.users.get(uid, {}).get("role") == "admin"
    def user_ids(self): return [uid for uid, user in self.users.items() if user.get("role", "user") == "user"]
    def recipient(self, uid): return self.users.get(uid)
    def still_owned(self, request_id, owner):
        value = self.requests[request_id]
        return value["status"] == "processing" and value["workerId"] == owner
    def store_inbox(self, uid, request_id, announcement):
        if uid in self.inbox_failures: raise RuntimeError("offline")
        self.inbox.setdefault((uid, request_id), announcement)
    def send_push(self, uid, tokens, request_id, announcement):
        self.pushes.append((uid, tokens, request_id))
        if self.revoke_after_first: self.users["admin"]["role"] = "user"
        if self.crash_push: raise RuntimeError("lost acknowledgement")
        return self.result
    def update(self, request_id, owner, fields):
        if self.still_owned(request_id, owner): self.requests[request_id].update(fields)


def test_broadcast_excludes_admin_and_stores_inbox_even_without_device():
    store = FakeNotificationStore()
    NotificationWorker(store).tick()
    result = store.requests[REQUEST_ID]
    assert result["status"] == "completed"
    assert result["counts"] == {"recipients": 2, "inboxStored": 2, "pushAccepted": 1, "pushFailed": 0,
                                 "pushUnknown": 0, "withoutDevice": 1, "skipped": 0, "inboxFailed": 0}
    assert list(store.inbox) == [("a", REQUEST_ID), ("b", REQUEST_ID)]
    assert store.pushes == [("a", ["t1"], REQUEST_ID)]


def test_selected_targets_are_revalidated_not_expanded_to_all_users():
    store = FakeNotificationStore()
    store.requests[REQUEST_ID].update(audience="selected", recipientUids=["b", "admin", "deleted"])
    NotificationWorker(store).process(REQUEST_ID)
    assert list(store.inbox) == [("b", REQUEST_ID)]
    assert store.pushes == []
    assert store.requests[REQUEST_ID]["counts"]["skipped"] == 2
    assert store.requests[REQUEST_ID]["status"] == "partial"


def test_retry_or_second_worker_does_not_send_a_claimed_request_again():
    store = FakeNotificationStore()
    NotificationWorker(store).process(REQUEST_ID)
    NotificationWorker(store).process(REQUEST_ID)
    assert len(store.pushes) == 1


def test_sender_revoked_before_processing_is_rejected():
    store = FakeNotificationStore()
    store.users["admin"]["role"] = "user"
    NotificationWorker(store).process(REQUEST_ID)
    assert store.inbox == {}
    assert store.pushes == []
    assert store.requests[REQUEST_ID]["status"] == "failed"


def test_revocation_during_broadcast_stops_remaining_users():
    store = FakeNotificationStore()
    store.revoke_after_first = True
    NotificationWorker(store).process(REQUEST_ID)
    assert list(store.inbox) == [("a", REQUEST_ID)]
    assert store.requests[REQUEST_ID]["status"] == "partial"


def test_uncertain_push_is_reported_and_never_automatically_replayed():
    store = FakeNotificationStore()
    store.result = PushResult(unknown=1)
    worker = NotificationWorker(store)
    worker.process(REQUEST_ID)
    worker.tick()
    assert store.requests[REQUEST_ID]["status"] == "partial"
    assert store.requests[REQUEST_ID]["counts"]["pushUnknown"] == 1
    assert len(store.pushes) == 1


def test_crash_after_inbox_does_not_replay_the_push():
    store = FakeNotificationStore()
    store.crash_push = True
    worker = NotificationWorker(store)
    worker.process(REQUEST_ID)
    worker.tick()
    assert store.requests[REQUEST_ID]["status"] == "interrupted"
    assert store.requests[REQUEST_ID]["counts"]["inboxStored"] == 1
    assert len(store.pushes) == 1


def test_inbox_failure_isolated_and_never_pushes_an_unstored_message():
    store = FakeNotificationStore()
    store.inbox_failures.add("a")
    NotificationWorker(store).process(REQUEST_ID)
    assert store.pushes == []
    assert list(store.inbox) == [("b", REQUEST_ID)]
    assert store.requests[REQUEST_ID]["counts"]["inboxFailed"] == 1


@pytest.mark.parametrize("patch", [
    {"title": " "}, {"body": "a" * 501}, {"audience": "other"},
    {"audience": "selected", "recipientUids": []}, {"recipientUids": ["a"]},
    {"audience": "selected", "recipientUids": ["a", "a"]},
    {"audience": "selected", "recipientUids": ["../users/admin"]},
    {"audience": "selected", "recipientUids": [123]},
])
def test_malformed_request_fails_without_external_side_effects(patch):
    store = FakeNotificationStore()
    store.requests[REQUEST_ID].update(patch)
    NotificationWorker(store).process(REQUEST_ID)
    assert store.requests[REQUEST_ID]["status"] == "failed"
    assert not store.inbox and not store.pushes


def test_standalone_loop_stops_without_leaving_a_pending_task():
    async def scenario():
        store = FakeNotificationStore()
        worker = NotificationWorker(store, poll_seconds=0.01)
        stop = asyncio.Event()
        task = asyncio.create_task(worker.run(stop))
        for _ in range(100):
            if store.requests[REQUEST_ID]["status"] == "completed": break
            await asyncio.sleep(0.01)
        stop.set()
        await asyncio.wait_for(task, timeout=1)
        assert store.synced == 1
        assert store.heartbeats == [("notifications", "running"), ("notifications", "stopped")]
    asyncio.run(scenario())


def test_a_linked_paper_travels_with_the_message_and_bad_links_fail_safely():
    store = FakeNotificationStore()
    store.requests[REQUEST_ID]["analysisId"] = "1706.03762"
    NotificationWorker(store).tick()
    assert store.requests[REQUEST_ID]["status"] == "completed"
    assert {announcement.analysis_id for announcement in store.inbox.values()} == {"1706.03762"}
    for value in ("../users", 1706.03762, ""):
        store = FakeNotificationStore()
        store.requests[REQUEST_ID]["analysisId"] = value
        NotificationWorker(store).tick()
        assert store.requests[REQUEST_ID]["status"] == "failed" and not store.inbox


def test_read_counts_refresh_on_their_own_schedule_and_never_block_sending():
    store = FakeNotificationStore()
    worker = NotificationWorker(store)
    worker.tick()
    worker.tick()
    assert store.read_refreshes == 1

    def broken():
        raise RuntimeError("index still building")

    store = FakeNotificationStore()
    store.refresh_read_counts = broken
    NotificationWorker(store).tick()
    assert store.requests[REQUEST_ID]["status"] == "completed"
