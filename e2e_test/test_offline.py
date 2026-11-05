"""Error path: no network on the phone."""

from realtron import signed_in


async def test_tc08_no_network_shows_retry(agent, airplane_mode):
    data = await agent.check(
        f"{signed_in()} Type 2401.00001 into 'arXiv ID or link' and tap 'Analyze'. "
        "Wait up to 30 seconds for a message to appear.",
        "banner_title (string), retry_button_visible (boolean), "
        "still_on_analyze (boolean, the 'Analyze' screen is showing)",
    )
    assert data["banner_title"] == "Can't reach server"
    assert data["retry_button_visible"] is True
    assert data["still_on_analyze"] is True
