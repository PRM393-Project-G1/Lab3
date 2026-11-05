"""Fixtures for the Realtron ARTEMIS suite, and the run log behind the results table."""

from __future__ import annotations

import json
import os
import re
import subprocess
from collections.abc import Callable, Iterator
from datetime import datetime, timezone
from pathlib import Path

import pytest
from artemis_client import ArtemisClient

from realtron import PACKAGE, Agent, adb

RESULTS = Path(__file__).parent.parent / "evidence" / "e2e" / "results.jsonl"


@pytest.fixture(scope="session", autouse=True)
def analytics_debug_mode() -> None:
    """Makes Analytics log each event to Logcat right away."""
    adb("shell", "setprop", "debug.firebase.analytics.app", PACKAGE)
    adb("shell", "setprop", "log.tag.FA", "VERBOSE")
    adb("shell", "setprop", "log.tag.FA-SVC", "VERBOSE")


@pytest.fixture(autouse=True)
def cold_start() -> None:
    """Every test starts from a closed app, so none depends on another's order."""
    adb("shell", "am", "force-stop", PACKAGE)


@pytest.fixture
def agent(request: pytest.FixtureRequest) -> Agent:
    client = ArtemisClient(
        os.environ.get("ARTEMIS_BASE_URL"),
        token=os.environ.get("ARTEMIS_TOKEN"),
        device_serial=os.environ.get("ARTEMIS_DEVICE_SERIAL"),
        default_profile="flash",
    )
    return Agent(client, request.node)


@pytest.fixture
def logged() -> Callable[[str], bool]:
    """Clears Logcat, then answers whether an Analytics event has been logged."""
    adb("logcat", "-c")

    def check(event: str) -> bool:
        log = adb("logcat", "-d", "-s", "FA", "FA-SVC")
        return re.search(rf"name={re.escape(event)}\b", log) is not None

    return check


@pytest.fixture
def airplane_mode() -> Iterator[None]:
    adb("shell", "cmd", "connectivity", "airplane-mode", "enable")
    try:
        yield
    finally:
        adb("shell", "cmd", "connectivity", "airplane-mode", "disable")


@pytest.fixture
def send_push() -> Callable[[], None]:
    """Asks the backend side to send a real push, through a team-provided command."""
    command = os.environ.get("E2E_PUSH_COMMAND")
    if not command:
        pytest.skip("E2E_PUSH_COMMAND is not set")

    def send() -> None:
        subprocess.run(command, shell=True, check=True, timeout=120)

    return send


@pytest.hookimpl(hookwrapper=True)
def pytest_runtest_makereport(item: pytest.Item, call: pytest.CallInfo) -> Iterator[None]:
    outcome = yield
    report = outcome.get_result()
    # A skip is decided while preparing the test, or by need() inside it.
    if report.when == "call" or (report.when == "setup" and report.skipped):
        _record(item, report)


def _record(item: pytest.Item, report: pytest.TestReport) -> None:
    match = re.search(r"test_tc(\d+)", item.name)
    props = dict(report.user_properties)
    entry = {
        "at": datetime.now(timezone.utc).isoformat(timespec="seconds"),
        "test": f"TC-{match.group(1)}" if match else item.name,
        "node": item.nodeid,
        "outcome": report.outcome,
        "seconds": round(report.duration, 1),
        "trace_id": props.get("trace_id"),
        "output": props.get("output"),
        "reason": str(report.longrepr)[-500:] if report.failed or report.skipped else None,
    }
    RESULTS.parent.mkdir(parents=True, exist_ok=True)
    with RESULTS.open("a", encoding="utf-8") as log:
        log.write(json.dumps(entry, ensure_ascii=False, default=str) + "\n")
