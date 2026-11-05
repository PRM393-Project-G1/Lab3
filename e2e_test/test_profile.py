"""Top-level tabs and the Remote Config values shown on Profile."""

from realtron import REMOTE_CONFIG, signed_in


async def test_tc11_remote_config_values_are_shown(agent):
    data = await agent.check(
        f"{signed_in()} Tap the 'Profile' tab. Scroll to the 'Remote Config' section "
        "and read each key and its value.",
        ", ".join(f"{key} (string)" for key in REMOTE_CONFIG),
    )
    for key, value in REMOTE_CONFIG.items():
        expected = str(value).lower() if isinstance(value, bool) else str(value)
        assert data[key] == expected, key


async def test_tc12_each_tab_opens(agent):
    data = await agent.check(
        f"{signed_in()} Tap 'History' and note the screen title. Tap 'Profile' and note "
        "the screen title. Tap 'Analyze' and note the screen title.",
        "history_title (string), profile_title (string), analyze_title (string)",
    )
    assert data["history_title"] == "History"
    assert data["profile_title"] == "Profile"
    assert data["analyze_title"] == "Analyze"
