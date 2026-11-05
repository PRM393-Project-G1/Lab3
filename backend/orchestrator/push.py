"""Sends the real `Analysis done` push for a finished paper, without analyzing it again.

For testing the app in the foreground, in the background and closed.
Run from `backend/`: `.venv/Scripts/python -m orchestrator.push 1706.03762`
"""

from __future__ import annotations

import argparse
import sys

from dotenv import load_dotenv

from . import merge
from .config import BACKEND_DIR
from .store import FirebaseStore


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("paper")
    args = parser.parse_args()

    load_dotenv(BACKEND_DIR / ".env")
    store = FirebaseStore()
    analysis = store.get_analysis(args.paper) or {}
    if analysis.get("status") != "done":
        print(f"{args.paper} has no finished analysis.", file=sys.stderr)
        return 1

    users = store.users_with_tokens()
    title = analysis.get("paperTitle") or f"arXiv:{args.paper}"
    for uid in users:
        store.notify_done(uid, args.paper, "Analysis done", merge.done_message(title, analysis["summary"]))
    print(f"Sent to {len(users)} user(s).")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
