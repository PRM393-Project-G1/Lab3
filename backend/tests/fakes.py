"""Stand-ins for Firebase and for the slow steps."""

from __future__ import annotations

import asyncio
from typing import Any

from orchestrator.steps import SaffronOutput

UID = "user-1"
TOKEN = "good-token"


def verify_token(token: str) -> str:
    if token != TOKEN:
        raise ValueError("Invalid token")
    return UID


class FakeStore:
    def __init__(self) -> None:
        self.analyses: dict[str, dict[str, Any]] = {}
        self.history: list[dict[str, Any]] = []
        self.references: list[dict[str, Any]] = []
        self.topics: list[dict[str, Any]] = []
        self.notifications: list[tuple[str, str, str, str]] = []
        self.interrupted_checks = 0
        self.fail_notify = False

    def get_analysis(self, analysis_id: str) -> dict[str, Any] | None:
        return self.analyses.get(analysis_id)

    def create_analysis(self, analysis_id: str, uid: str, ai_assisted: bool) -> None:
        self.analyses[analysis_id] = {"requestedBy": uid, "aiAssisted": ai_assisted, "status": "queued"}

    def update_analysis(self, analysis_id: str, fields: dict[str, Any]) -> None:
        self.analyses.setdefault(analysis_id, {}).update(fields)
        self.history.append(dict(fields))

    def finish_analysis(self, analysis_id: str, fields: dict[str, Any]) -> None:
        self.update_analysis(analysis_id, fields)

    def fail_interrupted(self) -> int:
        self.interrupted_checks += 1
        return 0

    def replace_results(self, analysis_id: str, references: Any, topics: Any) -> None:
        self.references, self.topics = list(references), list(topics)

    def notify_done(self, uid: str, analysis_id: str, title: str, body: str) -> None:
        if self.fail_notify:
            raise RuntimeError("FCM is down")
        self.notifications.append((uid, analysis_id, title, body))


class FakeSteps:
    def __init__(self) -> None:
        self.references: list[dict[str, Any]] = [
            {"title": "Good", "status": "verified"},
            {"title": "Bad", "status": "error", "errors": [{"error_type": "year", "error_details": "Wrong"}]},
        ]
        self.error: Exception | None = None
        self.error_at = ""
        self.gate: asyncio.Event | None = None
        self.calls: list[str] = []
        self.ai_flags: list[bool] = []

    def _maybe_fail(self, step: str) -> None:
        self.calls.append(step)
        if self.error and self.error_at == step:
            raise self.error

    async def paper_metadata(self, analysis_id: str) -> dict[str, Any]:
        self._maybe_fail("metadata")
        return {"paperTitle": "Attention Is All You Need", "paperAuthors": ["A. Vaswani"]}

    async def check_references(self, analysis_id: str, ai_assisted: bool, on_event: Any) -> dict[str, Any]:
        self._maybe_fail("check")
        self.ai_flags.append(ai_assisted)
        on_event({"event": "references_extracted", "total_refs": len(self.references)})
        on_event({"event": "progress", "current": 1, "total": len(self.references)})
        on_event({"event": "phase", "message": "Running hallucination detection..."})
        if self.gate:
            await self.gate.wait()
        return {"paper_title": "From RefChecker", "references": self.references}

    async def collect_texts(self, references: list[dict[str, Any]], on_progress: Any) -> list[dict[str, str]]:
        self._maybe_fail("texts")
        on_progress(len(references))
        return [
            {"id": f"ref-{i:03d}", "name": ref["title"], "contents": ref["title"], "textSource": "abstract"}
            for i, ref in enumerate(references, 1)
        ]

    async def extract_topics(self, analysis_id: str, documents: list[dict[str, Any]]) -> SaffronOutput:
        self._maybe_fail("topics")
        return SaffronOutput(
            doc_terms=[{"document_id": "ref-001", "term_string": "attention"}],
            taxonomy={"root": "HEAD_TERM", "children": [{"root": "attention", "score": 0.9, "children": []}]},
            terms=[{"term_string": "attention", "score": 0.8, "occurrences": 3}],
            author_terms=[{"authorId": "A. Vaswani", "termId": "attention", "score": 0.5}],
            author_sim=[{"author1_id": "A. Vaswani", "author2_id": "N. Shazeer", "similarity": 0.9}],
        )
