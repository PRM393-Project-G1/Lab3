"""Flow C: reopening a checked paper from History."""

from realtron import PAPER_TITLE, open_paper


async def test_tc17_history_search_and_reopen(agent):
    data = await agent.check(
        f"{open_paper()} Tap the 'History' tab. Type zzzz-no-match into 'Search' and "
        "note the message. Clear the search. Tap the card for "
        f"'{PAPER_TITLE}' and wait for the next screen.",
        "no_match_message (string), opened_screen_title (string), paper_title (string)",
    )
    assert data["no_match_message"] == "No results"
    assert data["opened_screen_title"] == "Paper Overview"
    assert PAPER_TITLE in data["paper_title"]
