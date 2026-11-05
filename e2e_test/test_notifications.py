"""Native interaction: opening a push from the notification shade."""

from realtron import PAPER_TITLE, adb, signed_in


async def test_tc10_push_from_the_shade_opens_the_paper(agent, send_push):
    await agent.check(signed_in(), "selected_tab (string)")
    adb("shell", "input", "keyevent", "KEYCODE_HOME")
    send_push()

    data = await agent.check(
        "Pull down the Android notification shade. Wait up to 60 seconds for a Realtron "
        "notification titled 'Analysis done', and tap it.",
        "screen_title (string), paper_title (string)",
    )
    assert data["screen_title"] == "Paper Overview"
    assert PAPER_TITLE in data["paper_title"]
