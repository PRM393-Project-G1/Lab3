"""Adds `topicSummary` to analyses that finished before the field existed.

Run from `backend/`: `.venv/Scripts/python -m orchestrator.backfill`
Each completed analysis without a summary costs one read of its `topics`.
Add `--force` to rebuild every summary.
"""

from __future__ import annotations

import argparse
from collections.abc import Iterable
from typing import Any, Protocol

from . import merge


class BackfillStore(Protocol):
    def completed_analyses(self) -> Iterable[tuple[str, dict[str, Any]]]: ...
    def topics_of(self, analysis_id: str) -> list[dict[str, Any]]: ...
    def update_analysis(self, analysis_id: str, fields: dict[str, Any]) -> None: ...


def backfill(store: BackfillStore, force: bool = False) -> int:
    """Returns how many analyses were updated."""
    updated = 0
    for analysis_id, data in store.completed_analyses():
        if not force and isinstance(data.get("topicSummary"), list):
            continue
        store.update_analysis(analysis_id, {"topicSummary": merge.topic_summary(store.topics_of(analysis_id))})
        updated += 1
    return updated


def main() -> int:
    from dotenv import load_dotenv

    from .config import BACKEND_DIR
    from .store import FirebaseStore

    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--force", action="store_true", help="rebuild summaries that already exist")
    args = parser.parse_args()
    load_dotenv(BACKEND_DIR / ".env")
    print(f"Updated {backfill(FirebaseStore(), args.force)} analyses.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
