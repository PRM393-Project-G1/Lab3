import asyncio

from fastapi.testclient import TestClient

from fakes import FakeSteps, FakeStore, verify_token
from orchestrator import __version__
from orchestrator.heartbeat import Heartbeat
from orchestrator.main import create_app


def test_beats_until_stopped_then_reports_a_clean_stop():
    writes = []

    async def scenario():
        stop = asyncio.Event()
        task = asyncio.create_task(Heartbeat("worker", lambda name, fields: writes.append((name, fields)),
                                             interval=0.01, extra=lambda: {"runningJobs": 2}).run(stop))
        while len(writes) < 2:
            await asyncio.sleep(0.005)
        stop.set()
        await asyncio.wait_for(task, timeout=1)

    asyncio.run(scenario())
    name, first = writes[0]
    assert name == "worker"
    assert first["state"] == "running" and first["version"] == __version__ and first["runningJobs"] == 2
    assert first["startedAt"] == writes[1][1]["startedAt"]
    assert writes[-1] == ("worker", {"state": "stopped"})


def test_a_failing_write_never_stops_the_process():
    calls = []

    def write(name, fields):
        calls.append(fields["state"])
        raise RuntimeError("Firestore is down")

    async def scenario():
        stop = asyncio.Event()
        task = asyncio.create_task(Heartbeat("worker", write, interval=0.01).run(stop))
        while len(calls) < 2:
            await asyncio.sleep(0.005)
        stop.set()
        await asyncio.wait_for(task, timeout=1)

    asyncio.run(scenario())
    assert calls[-1] == "stopped"


def test_the_api_reports_itself_alive_and_stopped():
    store = FakeStore()
    with TestClient(create_app(store, verify_token, FakeSteps())) as client:
        assert client.get("/api/health").status_code == 200
    names = {name for name, _ in store.heartbeats}
    assert names == {"backend"}
    assert store.heartbeats[0][1]["runningJobs"] == 0
    assert store.heartbeats[-1] == ("backend", {"state": "stopped"})
