import time

import pytest
from fakes import TOKEN, UID, FakeSteps, FakeStore, verify_token
from fastapi.testclient import TestClient
from orchestrator.main import create_app

ID = "1706.03762"
AUTH = {"Authorization": f"Bearer {TOKEN}"}


@pytest.fixture
def store():
    return FakeStore()


@pytest.fixture
def steps():
    return FakeSteps()


@pytest.fixture
def client(store, steps):
    with TestClient(create_app(store, verify_token, steps)) as test_client:
        yield test_client


def wait_for(store, status):
    for _ in range(200):
        if store.analyses.get(ID, {}).get("status") == status:
            return
        time.sleep(0.01)
    raise AssertionError(f"Never reached {status}: {store.analyses.get(ID)}")


def test_health_matches_what_the_connect_screen_checks(client):
    response = client.get("/api/health")
    assert response.status_code == 200
    assert response.json()["status"] == "ok"
    assert response.json()["version"]


def test_startup_clears_jobs_left_by_a_restart(client, store):
    assert store.interrupted_checks == 1


@pytest.mark.parametrize(
    "headers",
    [{}, {"Authorization": "Bearer wrong"}, {"Authorization": TOKEN}, {"Authorization": "Bearer "}],
)
def test_commands_need_a_valid_firebase_token(client, headers):
    start = client.post("/api/analyses", json={"arxivId": ID}, headers=headers)
    cancel = client.post(f"/api/analyses/{ID}/cancel", json={}, headers=headers)
    assert start.status_code == 401
    assert cancel.status_code == 401


def test_starting_creates_the_document_and_runs_the_job(client, store):
    response = client.post("/api/analyses", json={"arxivId": ID, "aiAssisted": False}, headers=AUTH)

    assert response.status_code == 202
    assert response.json() == {"analysisId": ID, "status": "queued"}
    wait_for(store, "done")
    assert store.analyses[ID]["requestedBy"] == UID
    assert store.analyses[ID]["aiAssisted"] is False


def test_the_ai_switch_reaches_the_checker(client, store, steps):
    client.post("/api/analyses", json={"arxivId": ID, "aiAssisted": False}, headers=AUTH)
    wait_for(store, "done")
    assert steps.ai_flags == [False]


def test_a_finished_paper_is_not_analyzed_again(client, store, steps):
    store.analyses[ID] = {"status": "done", "requestedBy": "someone"}

    response = client.post("/api/analyses", json={"arxivId": ID}, headers=AUTH)

    assert response.json() == {"analysisId": ID, "status": "done"}
    assert steps.calls == []


def test_a_failed_paper_can_be_tried_again(client, store, steps):
    store.analyses[ID] = {"status": "failed", "error": "Earlier", "requestedBy": UID}

    client.post("/api/analyses", json={"arxivId": ID}, headers=AUTH)

    wait_for(store, "done")


@pytest.mark.parametrize("bad", ["abc123", "hep-th/9901001", "../../users/x", "1706.03762v5"])
def test_an_invalid_id_is_rejected(client, store, bad):
    response = client.post("/api/analyses", json={"arxivId": bad}, headers=AUTH)
    assert response.status_code == 422
    assert store.analyses == {}


def test_cancel_stops_a_running_job(client, store, steps):
    import asyncio

    steps.gate = asyncio.Event()
    client.post("/api/analyses", json={"arxivId": ID}, headers=AUTH)
    time.sleep(0.05)

    response = client.post(f"/api/analyses/{ID}/cancel", json={}, headers=AUTH)

    assert response.status_code == 200
    assert response.json()["status"] == "cancelled"
    assert store.analyses[ID]["status"] == "cancelled"
    assert store.references == []


def test_cancel_clears_a_job_this_server_no_longer_has(client, store):
    store.analyses[ID] = {"status": "processing", "requestedBy": UID}
    response = client.post(f"/api/analyses/{ID}/cancel", json={}, headers=AUTH)
    assert response.json()["status"] == "cancelled"


def test_cancel_leaves_a_finished_paper_alone(client, store):
    store.analyses[ID] = {"status": "done", "requestedBy": UID}
    response = client.post(f"/api/analyses/{ID}/cancel", json={}, headers=AUTH)
    assert response.status_code == 200
    assert store.analyses[ID]["status"] == "done"


def test_only_who_started_it_can_stop_it(client, store):
    store.analyses[ID] = {"status": "processing", "requestedBy": "someone-else"}
    response = client.post(f"/api/analyses/{ID}/cancel", json={}, headers=AUTH)
    assert response.status_code == 403
    assert store.analyses[ID]["status"] == "processing"


def test_cancelling_an_unknown_paper_is_not_found(client):
    response = client.post(f"/api/analyses/{ID}/cancel", json={}, headers=AUTH)
    assert response.status_code == 404
