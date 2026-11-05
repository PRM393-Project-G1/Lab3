"""Analyzes papers ahead of a demo, so the app finds real results straight away.

Run from `backend/`: `.venv/Scripts/python -m orchestrator.seed 1706.03762 1409.0473`
Papers already done are skipped. Add `--force` to run them again.
"""

from __future__ import annotations

import argparse
import asyncio
import logging
from typing import Any

from dotenv import load_dotenv

from .config import BACKEND_DIR, Settings
from .jobs import Pipeline
from .steps import Steps
from .store import FirebaseStore

REQUESTED_BY = "seed"


class _NoPush:
    """Writes like the real store, but nobody is waiting for a notification."""

    def __init__(self, store: FirebaseStore) -> None:
        self._store = store

    def __getattr__(self, name: str) -> Any:
        return getattr(self._store, name)

    def notify_done(self, uid: str, analysis_id: str, title: str, body: str) -> None:
        pass


async def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("papers", nargs="+")
    parser.add_argument("--force", action="store_true")
    parser.add_argument("--no-ai", action="store_true", help="Skip the LLM checks")
    args = parser.parse_args()

    logging.basicConfig(level=logging.WARNING)
    load_dotenv(BACKEND_DIR / ".env")
    store = FirebaseStore()
    pipeline = Pipeline(_NoPush(store), Steps(Settings.from_env()))
    failed = 0
    for paper in args.papers:
        existing = store.get_analysis(paper) or {}
        if existing.get("status") == "done" and not args.force:
            print(f"{paper}: already done")
            continue
        store.create_analysis(paper, REQUESTED_BY, not args.no_ai)
        await pipeline.run(paper, REQUESTED_BY, not args.no_ai)
        result = store.get_analysis(paper) or {}
        print(f"{paper}: {result.get('status')} {result.get('error') or result.get('summary')}")
        failed += result.get("status") != "done"
    return 1 if failed else 0


if __name__ == "__main__":
    raise SystemExit(asyncio.run(main()))
