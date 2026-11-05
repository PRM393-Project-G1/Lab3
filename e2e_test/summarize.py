"""Turns evidence/e2e/results.jsonl into the results table for docs/test-plan.md."""

from __future__ import annotations

import json
from collections import defaultdict
from pathlib import Path

RESULTS = Path(__file__).parent.parent / "evidence" / "e2e" / "results.jsonl"


def table(lines: list[str]) -> str:
    runs: dict[str, list[dict]] = defaultdict(list)
    for line in lines:
        entry = json.loads(line)
        runs[entry["test"]].append(entry)

    rows = [
        "| Test | Runs | Passed | Skipped | Failed | Pass rate | Avg seconds | Trace IDs |",
        "|---|---|---|---|---|---|---|---|",
    ]
    for test in sorted(runs):
        entries = runs[test]
        count = {o: sum(e["outcome"] == o for e in entries) for o in ("passed", "skipped", "failed")}
        ran = count["passed"] + count["failed"]
        rate = f"{count['passed']}/{ran}" if ran else "—"
        timed = [e["seconds"] for e in entries if e["outcome"] != "skipped"]
        average = f"{sum(timed) / len(timed):.1f}" if timed else "—"
        traces = ", ".join(e["trace_id"] for e in entries if e.get("trace_id")) or "—"
        rows.append(
            f"| {test} | {len(entries)} | {count['passed']} | {count['skipped']} "
            f"| {count['failed']} | {rate} | {average} | {traces} |"
        )
    return "\n".join(rows)


if __name__ == "__main__":
    print(table(RESULTS.read_text(encoding="utf-8").splitlines()))
