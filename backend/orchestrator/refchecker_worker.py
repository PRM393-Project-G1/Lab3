"""Runs RefChecker for one paper, in its own process, so a job can be stopped at once.

Progress goes to stdout as lines starting with EVENT_PREFIX. The result goes to a file.
"""

from __future__ import annotations

import argparse
import asyncio
import json
import os
import sys

EVENT_PREFIX = "@@EVENT "
_EVENTS = {"title_updated", "references_extracted", "progress", "phase"}


async def _run(args: argparse.Namespace, events) -> dict:
    from backend.refchecker_wrapper import ProgressRefChecker

    from .bbl_repair import repair_year_first

    class Checker(ProgressRefChecker):
        async def _extract_references_from_bibtex(self, bibtex_content: str) -> tuple:
            references, method = await super()._extract_references_from_bibtex(bibtex_content)
            return repair_year_first(references or [], bibtex_content), method

    async def on_progress(event_type: str, data: dict) -> None:
        if event_type in _EVENTS:
            summary = {key: value for key, value in data.items() if key != "references"}
            events.write(f"{EVENT_PREFIX}{json.dumps({'event': event_type, **summary}, default=str)}\n")
            events.flush()

    checker = Checker(
        llm_provider=args.llm_provider,
        llm_model=args.llm_model,
        use_llm=bool(args.llm_provider),
        progress_callback=on_progress,
        semantic_scholar_api_key=os.environ.get("SEMANTIC_SCHOLAR_API_KEY"),
        # In the job's folder: RefChecker's shared cache would restore misread references.
        cache_dir=os.path.join(os.getcwd(), "cache"),
        hallucination_provider=args.llm_provider if args.hallucinations else None,
        hallucination_model=args.llm_model if args.hallucinations else None,
        detection_mode="references",
    )
    try:
        return await checker.check_paper(args.paper, "url")
    finally:
        checker.close()


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--paper", required=True)
    parser.add_argument("--result", required=True)
    parser.add_argument("--llm-provider")
    parser.add_argument("--llm-model")
    parser.add_argument("--hallucinations", action="store_true")
    args = parser.parse_args()

    # RefChecker prints as it works. Only our own lines may reach the job's stdout.
    events, sys.stdout = sys.stdout, sys.stderr
    result = asyncio.run(_run(args, events))
    with open(args.result, "w", encoding="utf-8") as file:
        json.dump(result, file, ensure_ascii=False, default=str)
    return 0


if __name__ == "__main__":
    sys.exit(main())
