import asyncio
import time

import pytest
from fastapi.testclient import TestClient

from fakes import TOKEN, UID, FakeActionStore, FakeJobs, FakeSteps, verify_token
from orchestrator.admin_actions import RESTARTED, STOPPED_BY_ADMIN, AdminActionWorker
from orchestrator.main import create_app

ID = "1706.03762"
ACTION = "admin-action-request-0001"


def process(store, jobs, action_id=ACTION):
    asyncio.run(AdminActionWorker(store, jobs).process(action_id))
    return store.actions[action_id]


def test_cancel_stops_the_job_and_tells_the_requester_why():
    store, jobs = FakeActionStore(), FakeJobs()
    store.analyses[ID] = {"status": "processing", "requestedBy": UID}
    jobs.running.add(ID)
    store.queue(ACTION, type="cancelAnalysis", target=ID)
    result = process(store, jobs)
    assert result["status"] == "completed" and result["error"] is None
    assert jobs.cancelled == [ID]
    assert store.analyses[ID] == {"status": "cancelled", "requestedBy": UID, "error": STOPPED_BY_ADMIN}


def test_cancel_refuses_a_finished_analysis_without_touching_it():
    store, jobs = FakeActionStore(), FakeJobs()
    store.analyses[ID] = {"status": "done"}
    store.queue(ACTION, type="cancelAnalysis", target=ID)
    result = process(store, jobs)
    assert result["status"] == "failed" and "this one is done" in result["error"]
    assert store.analyses[ID] == {"status": "done"} and not jobs.cancelled


def test_retry_keeps_the_original_requester_and_settings():
    store, jobs = FakeActionStore(), FakeJobs()
    store.analyses[ID] = {"status": "failed", "requestedBy": UID, "aiAssisted": False, "error": "Topic extraction took too long."}
    store.queue(ACTION, type="retryAnalysis", target=ID)
    assert process(store, jobs)["status"] == "completed"
    assert store.created == [(ID, UID, False)] and jobs.started == [(ID, UID, False)]
    assert store.analyses[ID]["status"] == "queued"


@pytest.mark.parametrize("status", ["queued", "processing", "done"])
def test_retry_refuses_anything_but_failed_or_stopped(status):
    store, jobs = FakeActionStore(), FakeJobs()
    store.analyses[ID] = {"status": status}
    store.queue(ACTION, type="retryAnalysis", target=ID)
    assert process(store, jobs)["status"] == "failed"
    assert not jobs.started


def test_a_revoked_admin_cannot_act_and_bad_input_is_refused():
    store, jobs = FakeActionStore(), FakeJobs()
    store.analyses[ID] = {"status": "processing"}
    store.roles["admin-1"] = "user"
    store.queue(ACTION, type="cancelAnalysis", target=ID)
    assert process(store, jobs)["error"] == "The requester no longer has admin access."
    store.roles["admin-1"] = "admin"
    for number, fields in enumerate([{"type": "dropDatabase", "target": ID}, {"type": "cancelAnalysis", "target": "../users"},
                                     {"type": "cancelAnalysis", "target": ID, "reason": "x" * 201}]):
        action_id = f"admin-action-invalid-{number:04d}"
        store.queue(action_id, **fields)
        assert process(store, jobs, action_id)["status"] == "failed"
    assert store.analyses[ID]["status"] == "processing" and not jobs.cancelled


def test_a_missing_analysis_and_a_second_claim_are_handled():
    store, jobs = FakeActionStore(), FakeJobs()
    store.queue(ACTION, type="retryAnalysis", target=ID)
    assert process(store, jobs)["error"] == "This analysis no longer exists."
    store.actions[ACTION]["error"] = "kept"
    process(store, jobs)  # Already finished: no second run.
    assert store.actions[ACTION]["error"] == "kept"


def test_unfinished_actions_fail_when_the_backend_restarts():
    store, jobs = FakeActionStore(), FakeJobs()
    store.queue(ACTION, type="cancelAnalysis", target=ID)
    store.actions[ACTION].update(status="processing", workerId="old")

    async def scenario():
        stop = asyncio.Event()
        stop.set()
        await AdminActionWorker(store, jobs).run(stop)

    asyncio.run(scenario())
    assert (store.actions[ACTION]["status"], store.actions[ACTION]["error"]) == ("failed", RESTARTED)


def test_the_api_process_cancels_its_own_running_job():
    store, steps = FakeActionStore(), FakeSteps()
    steps.gate = asyncio.Event()  # Holds the job mid-run.
    with TestClient(create_app(store, verify_token, steps, actions=store, action_poll_seconds=0.02)) as client:
        assert client.post("/api/analyses", json={"arxivId": ID}, headers={"Authorization": f"Bearer {TOKEN}"}).status_code == 202
        store.queue(ACTION, type="cancelAnalysis", target=ID)
        deadline = time.monotonic() + 5
        while store.actions[ACTION]["status"] != "completed" and time.monotonic() < deadline:
            time.sleep(0.02)
        assert store.actions[ACTION]["status"] == "completed"
        assert store.analyses[ID]["status"] == "cancelled"


def test_hide_marks_completed_results_and_unhide_restores_them():
    store, jobs = FakeActionStore(), FakeJobs()
    store.analyses[ID] = {"status": "done", "summary": {"totalRefs": 3}}
    store.queue(ACTION, type="hideAnalysis", target=ID, reason="Wrong references parsed")
    assert process(store, jobs)["status"] == "completed"
    hidden = store.analyses[ID]
    assert hidden["hidden"] is True and hidden["hiddenReason"] == "Wrong references parsed" and hidden["hiddenBy"] == "admin-1"
    store.queue("admin-action-hide-again-01", type="hideAnalysis", target=ID)
    assert process(store, jobs, "admin-action-hide-again-01")["error"] == "This analysis is already hidden."
    store.queue("admin-action-unhide-0001", type="unhideAnalysis", target=ID)
    assert process(store, jobs, "admin-action-unhide-0001")["status"] == "completed"
    assert store.analyses[ID]["hidden"] is False and store.analyses[ID]["hiddenReason"] is None


@pytest.mark.parametrize("status", ["queued", "failed"])
def test_only_completed_results_can_be_hidden(status):
    store, jobs = FakeActionStore(), FakeJobs()
    store.analyses[ID] = {"status": status}
    store.queue(ACTION, type="hideAnalysis", target=ID)
    assert process(store, jobs)["status"] == "failed"
    assert "hidden" not in store.analyses[ID]


def test_a_hidden_result_can_be_rerun_and_becomes_visible():
    store, jobs = FakeActionStore(), FakeJobs()
    store.analyses[ID] = {"status": "done", "hidden": True, "requestedBy": UID, "aiAssisted": True}
    store.queue(ACTION, type="retryAnalysis", target=ID)
    assert process(store, jobs)["status"] == "completed"
    assert store.analyses[ID]["hidden"] is False and store.analyses[ID]["status"] == "queued"
    assert jobs.started == [(ID, UID, True)]


def test_delete_removes_finished_analyses_but_never_running_ones():
    store, jobs = FakeActionStore(), FakeJobs()
    store.analyses[ID] = {"status": "processing"}
    store.queue(ACTION, type="deleteAnalysis", target=ID)
    assert process(store, jobs)["error"] == "Stop this analysis before deleting it."
    store.analyses[ID] = {"status": "failed"}
    store.queue("admin-action-delete-0002", type="deleteAnalysis", target=ID)
    assert process(store, jobs, "admin-action-delete-0002")["status"] == "completed"
    assert ID not in store.analyses and store.deleted == [ID]
