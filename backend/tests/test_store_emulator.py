"""Optional adapter checks for the analysis store. Refuse live credentials; only a local emulator."""
import os
from concurrent.futures import ThreadPoolExecutor
from datetime import datetime
from types import SimpleNamespace

import pytest

pytestmark = pytest.mark.skipif(not os.environ.get("FIRESTORE_EMULATOR_HOST"), reason="Requires local Firestore emulator")


@pytest.fixture
def store():
    from google.auth.credentials import AnonymousCredentials
    from google.cloud.firestore import Client
    from orchestrator.store import FirebaseStore
    address = os.environ["FIRESTORE_EMULATOR_HOST"]
    assert address.startswith(("127.0.0.1:", "localhost:")), "This test is local-only"
    db = Client(project="demo-realtron-admin", credentials=AnonymousCredentials())
    yield FirebaseStore(db)
    db.close()


def test_an_action_has_one_owner_and_only_it_records_the_outcome(store):
    reference = store._action("emulator-action-claim-0001")
    reference.set({"status": "queued", "type": "cancelAnalysis", "target": "1706.03762", "requestedBy": "admin"})
    assert "emulator-action-claim-0001" in store.queued_action_ids()
    with ThreadPoolExecutor(max_workers=2) as pool:
        claims = list(pool.map(lambda owner: store.claim_action(reference.id, owner), ["one", "two"]))
    assert sum(claim is not None for claim in claims) == 1
    owner = "one" if claims[0] is not None else "two"
    store.finish_action(reference.id, "intruder", {"status": "completed"})
    assert reference.get().to_dict()["status"] == "processing"
    store.finish_action(reference.id, owner, {"status": "completed", "result": "ok"})
    data = reference.get().to_dict()
    assert data["status"] == "completed" and isinstance(data["finishedAt"], datetime)


def test_unfinished_actions_are_failed_and_updates_stamp_the_analysis(store):
    reference = store._action("emulator-action-stale-0001")
    reference.set({"status": "processing", "workerId": "gone"})
    assert store.fail_unfinished_actions("restarted") >= 1
    assert reference.get().to_dict()["error"] == "restarted"
    store.update_analysis("1706.03762", {"status": "processing"})
    assert isinstance(store.get_analysis("1706.03762")["updatedAt"], datetime)


def test_delete_removes_the_analysis_and_all_its_results(store):
    store.update_analysis("2101.00002", {"status": "done"})
    parent = store._analysis("2101.00002")
    for index in range(3):
        parent.collection("references").document(f"ref-{index}").set({"status": "verified"})
    parent.collection("topics").document("t-a").set({"term": "A"})
    store.delete_analysis("2101.00002")
    assert store.get_analysis("2101.00002") is None
    assert not list(parent.collection("references").stream()) and not list(parent.collection("topics").stream())


class FakeAuth:
    """Stands in for firebase_admin.auth so the test never reaches real accounts."""

    def __init__(self):
        self.disabled, self.revoked = {}, []

    def get_user(self, uid):
        return SimpleNamespace(uid=uid, email=f"{uid}@example.test", disabled=self.disabled.get(uid, False),
                               user_metadata=SimpleNamespace(creation_timestamp=1767225600000, last_sign_in_timestamp=None))

    def update_user(self, uid, disabled):
        self.disabled[uid] = disabled

    def revoke_refresh_tokens(self, uid):
        self.revoked.append(uid)


def test_role_and_account_changes_update_the_profile_auth_and_directory(store):
    from orchestrator.store import FirebaseStore
    fake = FakeAuth()
    users = FirebaseStore(store._db, auth_api=fake)
    profile = store._db.collection("users").document("emulator-managed-user")
    profile.set({"role": "user", "displayName": "Managed", "fcmTokens": ["private-token"]})
    before = users.admin_count()
    users.set_role(profile.id, "admin")
    assert profile.get().to_dict()["role"] == "admin" and users.admin_count() == before + 1
    entry = store._db.collection("adminUserDirectory").document(profile.id).get().to_dict()
    assert entry["role"] == "admin" and entry["email"] == "emulator-managed-user@example.test" and "fcmTokens" not in entry
    users.set_role(profile.id, "user")
    users.set_disabled(profile.id, True)
    assert fake.revoked == [profile.id] and users.get_user(profile.id)["disabled"] is True
    assert store._db.collection("adminUserDirectory").document(profile.id).get().to_dict()["disabled"] is True
    assert users.get_user("emulator-missing-user") is None
