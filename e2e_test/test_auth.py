"""Sign-in, cancelled sign-in and sign-out."""

from realtron import connect_if_asked, need, signed_in, signed_out


async def test_tc01_google_sign_in(agent):
    data = await agent.check(
        f"{signed_out()} Tap 'Continue with Google'. In the Android account picker, "
        f"choose {need('E2E_TEST_ACCOUNT')}. {connect_if_asked()}"
        "If Android asks for notification permission, tap 'Allow'. "
        "Wait until the bottom tabs are showing.",
        "selected_tab (string), tabs (list of tab labels, left to right)",
    )
    assert data["selected_tab"] == "Analyze"
    assert data["tabs"] == ["Analyze", "History", "Profile"]


async def test_tc02_cancelled_sign_in_shows_a_message(agent):
    data = await agent.check(
        f"{signed_out()} Tap 'Continue with Google'. When the Android account picker "
        "opens, press the Back button to cancel it.",
        "message (string, the text explaining what happened), "
        "sign_in_button_visible (boolean)",
    )
    assert data["message"] == "Sign-in cancelled"
    assert data["sign_in_button_visible"] is True


async def test_tc13_sign_out_returns_to_sign_in(agent, logged):
    data = await agent.check(
        f"{signed_in()} Tap the 'Profile' tab, then tap 'Sign out'. "
        "Wait until the screen changes.",
        "sign_in_button_visible (boolean), bottom_tabs_visible (boolean)",
    )
    assert data["sign_in_button_visible"] is True
    assert data["bottom_tabs_visible"] is False
    assert logged("logout")
