"""Flow B: finding weak topics, down to one reference."""

from realtron import REMOTE_CONFIG, STATUS_LABELS, open_paper


async def test_tc06_weak_filter_keeps_only_weak_topics(agent, logged):
    data = await agent.check(
        f"{open_paper()} Tap 'Explore'. On 'Topics', tap the 'Weak' chip.",
        "row_count (integer, topic rows showing), weak_row_count (integer, rows marked "
        "'Weak'), empty_message (string), footer (string, the line starting with 'Weak:')",
    )
    if data["empty_message"] is not None:
        assert data["empty_message"] == "No weak topics"
        return
    assert data["row_count"] > 0
    assert data["weak_row_count"] == data["row_count"]
    percent = round(REMOTE_CONFIG["weak_topic_threshold"] * 100)
    assert data["footer"] == f"Weak: ≥ {percent}% refs have issues"
    assert logged("filter_weak_topics")


async def test_tc07_topic_leads_to_a_reference(agent, logged):
    data = await agent.check(
        f"{open_paper()} Tap 'Explore'. Tap the first topic row. Note the topic name, "
        "then tap the first reference in its list. If a 'Likely fabricated' dialog opens, "
        "note its title and close it.",
        "topic_name (string), reference_status (string, the status label at the top), "
        "has_cited_and_actual (boolean, a table with 'Cited' and 'Actual' is showing), "
        "dialog_title (string)",
    )
    assert data["topic_name"]
    assert data["reference_status"] in STATUS_LABELS
    if data["reference_status"] == "Hallucinated":
        assert data["dialog_title"] == "Likely fabricated"
    assert data["has_cited_and_actual"] is True
    assert logged("view_topic")
    assert logged("view_reference")


async def test_tc18_reference_list_matches_the_overview(agent):
    data = await agent.check(
        f"{open_paper()} Note the number in the 'References (N)' button, then tap it. "
        "Scroll to the end of the list and count the references.",
        "overview_count (integer), screen_title (string), listed_count (integer)",
    )
    assert data["screen_title"] == "References"
    assert data["listed_count"] == data["overview_count"]
