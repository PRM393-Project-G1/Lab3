"""Optional adapter checks for the analysis store. Refuse live credentials; only a local emulator."""
import os
from concurrent.futures import ThreadPoolExecutor
from datetime import datetime

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
