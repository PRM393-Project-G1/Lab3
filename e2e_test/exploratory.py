"""One unscripted session in the Pro profile. Writes evidence/e2e/exploratory.md."""

from __future__ import annotations

import asyncio
import os
from pathlib import Path

from artemis_client import ArtemisClient

REPORT = Path(__file__).parent.parent / "evidence" / "e2e" / "exploratory.md"
GOAL = """Explore the Realtron Android app for about 20 minutes, as a new user would.
It is already signed in. Try every tab, the paper 1706.03762, its topics and references,
History, Notifications, Profile, the Back button, leaving a flow halfway, and
wrong input. List each problem you find: what you did, what happened, what you expected,
and the screen. Report only problems you actually saw."""


async def main() -> None:
    client = ArtemisClient(
        os.environ.get("ARTEMIS_BASE_URL"),
        token=os.environ.get("ARTEMIS_TOKEN"),
        device_serial=os.environ.get("ARTEMIS_DEVICE_SERIAL"),
    )
    result = await client.run(GOAL, profile="pro", timeout=2400)
    REPORT.parent.mkdir(parents=True, exist_ok=True)
    REPORT.write_text(
        f"# Exploratory session\n\n- Trace: `{result.trace_id}`\n- Status: {result.status}\n"
        f"- Error: {result.error}\n\n## Agent report\n\n{result.output}\n",
        encoding="utf-8",
    )
    print(f"{result.status}, trace {result.trace_id}, report in {REPORT}")


if __name__ == "__main__":
    asyncio.run(main())
