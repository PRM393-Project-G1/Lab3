"""What every test shares: test data, starting points and the agent wrapper."""

from __future__ import annotations

import json
import os
import re
import subprocess
import time
import urllib.request
from pathlib import Path
from typing import Any

import pytest

PACKAGE = "vn.fpt.prm393.realtron"
PAPER_ID = "1706.03762"
PAPER_TITLE = "Attention Is All You Need"
REMOTE_CONFIG = json.loads(
    (Path(__file__).parent.parent / "firebase" / "remote-config-defaults.json").read_text()
)
STATUS_LABELS = {"Hallucinated", "Error", "Warning", "Unverified", "Verified"}


def need(name: str) -> str:
    """Reads a setting. Credentials and URLs stay out of the repository."""
    value = os.environ.get(name)
    if not value:
        pytest.skip(f"{name} is not set")
    return value


def signed_out() -> str:
    return (
        "Open the Realtron app. If the bottom tabs are visible, tap 'Profile', "
        "then tap 'Sign out'. Wait until 'Continue with Google' is showing."
    )


def connect_if_asked() -> str:
    return (
        f"If 'Connect server' appears, type {need('E2E_SERVER_URL')} into 'Server URL', "
        "tap 'Test', wait for the text starting with 'Connected', then tap 'Continue'. "
    )


def signed_in() -> str:
    return (
        "Open the Realtron app. If 'Continue with Google' is showing, tap it and "
        f"choose the account {need('E2E_TEST_ACCOUNT')}. {connect_if_asked()}"
        "If Android asks for notification permission, tap 'Allow'. "
        "Tap the 'Analyze' tab and wait until it is showing."
    )


def open_paper() -> str:
    return (
        f"{signed_in()} Type {PAPER_ID} into 'arXiv ID or link', tap 'Analyze', "
        "and wait until the screen title is 'Paper Overview'."
    )


def parse_output(output: Any) -> dict[str, Any]:
    """Reads the JSON object the agent was asked to finish with."""
    if isinstance(output, dict):
        return output
    match = re.search(r"\{.*\}", str(output), re.DOTALL)
    assert match, f"The agent reported no JSON object: {output!r}"
    return json.loads(match.group(0))


def final_report(task_id: str) -> str | None:
    """The agent's closing report for a finished task.

    The Flash profile leaves the task's `output` empty: its answer is the
    `explanation` of the last `report_task_status` step of the session.
    """
    base = os.environ.get("ARTEMIS_BASE_URL", "http://127.0.0.1:8000").rstrip("/")
    with urllib.request.urlopen(f"{base}/api/sessions/{task_id}/steps", timeout=30) as response:
        steps = json.load(response)
    for step in reversed(steps):
        action = step.get("action_taken") or {}
        if action.get("action") == "report_task_status":
            return (action.get("args") or {}).get("explanation")
    return None


class Agent:
    """Sends one instruction and returns the values the agent reports."""

    def __init__(self, client: Any, node: pytest.Item) -> None:
        self._client = client
        self._node = node

    async def check(
        self,
        instruction: str,
        fields: str,
        *,
        timeout: float = 600,
    ) -> dict[str, Any]:
        goal = (
            f"{instruction}\n\nFinish with one JSON object and nothing else. "
            f"Its keys: {fields}. Report exactly what is on screen, and use null "
            "for anything you cannot see."
        )
        started = time.monotonic()
        result = await self._client.run(
            goal,
            expected_output=f"A JSON object with these keys: {fields}",
            timeout=timeout,
        )
        output = result.output
        if output is None and result.succeeded:
            output = final_report(result.trace_id)
        self._node.user_properties += [
            ("trace_id", result.trace_id),
            ("agent_seconds", round(time.monotonic() - started, 1)),
            ("output", output),
        ]
        assert result.succeeded, result.error or result.status
        return parse_output(output)


def adb(*args: str, timeout: float = 60) -> str:
    serial = os.environ.get("ARTEMIS_DEVICE_SERIAL")
    command = ["adb", *(["-s", serial] if serial else []), *args]
    done = subprocess.run(command, capture_output=True, text=True, timeout=timeout, check=True)
    return done.stdout
