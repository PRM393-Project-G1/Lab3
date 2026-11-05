"""Flow A: analyzing a paper, with its alternate and error paths."""

import re

import pytest

from realtron import PAPER_ID, PAPER_TITLE, need, open_paper, signed_in

STEPS = ["References", "Verify", "Fabrication check", "Full text", "Topics"]


async def test_tc03_finished_paper_opens_right_away(agent, logged):
    data = await agent.check(
        open_paper(),
        "screen_title (string), paper_title (string), "
        "references_count (integer, the number in the 'References (N)' button), "
        "topics_summary (string, the line like '9 topics · 2 weak')",
    )
    assert data["screen_title"] == "Paper Overview"
    assert PAPER_TITLE in data["paper_title"]
    assert data["references_count"] > 0
    assert re.fullmatch(r"\d+ topics · \d+ weak", data["topics_summary"])
    assert logged("search")


async def test_tc04_invalid_id_shows_an_error(agent):
    data = await agent.check(
        f"{signed_in()} Type abc123 into 'arXiv ID or link'. Do not tap anything else.",
        "error_text (string, under the field), analyze_button_enabled (boolean)",
    )
    assert data["error_text"] == "Not a valid arXiv ID"
    assert data["analyze_button_enabled"] is False


async def test_tc05_link_shared_from_chrome_fills_the_field(agent):
    data = await agent.check(
        f"Open Chrome and go to https://arxiv.org/abs/{PAPER_ID}. Open the Chrome menu, "
        "tap 'Share', and choose 'Realtron' in the Android share sheet. "
        "If Realtron asks you to sign in or connect, stop and report null for every key.",
        "screen_title (string), field_value (string, the text in 'arXiv ID or link'), "
        "analyze_button_enabled (boolean)",
    )
    assert data["screen_title"] == "Analyze"
    assert PAPER_ID in data["field_value"]
    assert data["analyze_button_enabled"] is True


async def test_tc14_unreachable_server_explains_what_to_check(agent):
    data = await agent.check(
        f"{signed_in()} Tap the 'Profile' tab, then tap 'Change' next to 'Server'. "
        "Replace the text in 'Server URL' with http://100.1.2.3:8000 and tap 'Test'. "
        "Wait up to 30 seconds for the result.",
        "error_title (string), hints (list of the short hint texts), "
        "save_button_enabled (boolean)",
    )
    assert data["error_title"] in {"Can't reach server", "Timed out"}
    if data["error_title"] == "Can't reach server":
        assert data["hints"] == ["Tailscale on?", "Backend running?", "Using http://?"]
    assert data["save_button_enabled"] is False


async def test_tc15_stopping_an_analysis_asks_first(agent):
    paper = need("E2E_STOPPABLE_ARXIV_ID")
    data = await agent.check(
        f"{signed_in()} Type {paper} into 'arXiv ID or link' and tap 'Analyze'. "
        "When 'Analyzing…' is showing, note the step names, then tap 'Stop'. "
        "Note the dialog title and message, tap 'Stop' in the dialog, "
        "and wait until the screen changes.",
        "steps (list of the step names, top to bottom), dialog_title (string), "
        "dialog_message (string), analyzing_screen_still_showing (boolean)",
    )
    assert data["steps"] == STEPS
    assert data["dialog_title"] == "Stop analysis?"
    assert data["dialog_message"] == "Progress will be lost."
    assert data["analyzing_screen_still_showing"] is False


async def test_tc16_new_paper_runs_to_results(agent, request):
    """Each run needs a paper the backend has not analyzed yet."""
    papers = need("E2E_NEW_ARXIV_IDS").split(",")
    spec = getattr(request.node, "callspec", None)
    run = spec.params.get("__pytest_repeat_step_number", 0) if spec else 0
    if run >= len(papers):
        pytest.skip(f"E2E_NEW_ARXIV_IDS has no paper for run {run + 1}")
    data = await agent.check(
        f"{signed_in()} Type {papers[run]} into 'arXiv ID or link' and tap 'Analyze'. "
        "Stay on 'Analyzing…' until 'View results' appears, which can take 20 minutes. "
        "Tap 'View results'.",
        "screen_title (string), references_count (integer, the number in the "
        "'References (N)' button)",
        timeout=1800,
    )
    assert data["screen_title"] == "Paper Overview"
    assert data["references_count"] > 0
