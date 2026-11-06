"""What the pipeline and the API need from the outside world.

Firebase and the external tools sit behind these protocols, so the core never
imports firebase_admin and the tests swap in the fakes of `tests/fakes.py`.
Each consumer asks only for what it uses.
"""

from __future__ import annotations

from collections.abc import Callable, Mapping
from typing import Any, Protocol


class ProgressStore(Protocol):
    """What one running job writes."""

    def update_analysis(self, analysis_id: str, fields: dict[str, Any]) -> None: ...
    def finish_analysis(self, analysis_id: str, fields: dict[str, Any]) -> None: ...
    def replace_results(self, analysis_id: str, references: Any, topics: Any) -> None: ...
    def notify_done(self, uid: str, analysis_id: str, title: str, body: str) -> None: ...


class AnalysisStore(ProgressStore, Protocol):
    """Everything the API reads and writes."""

    def get_analysis(self, analysis_id: str) -> dict[str, Any] | None: ...
    def create_analysis(self, analysis_id: str, uid: str, ai_assisted: bool) -> None: ...
    def fail_interrupted(self) -> int: ...


class AnalysisSteps(Protocol):
    """The slow parts of a job, each talking to something outside this process."""

    async def paper_metadata(self, analysis_id: str) -> dict[str, Any]: ...

    async def check_references(
        self,
        analysis_id: str,
        ai_assisted: bool,
        on_event: Callable[[dict[str, Any]], None],
    ) -> dict[str, Any]: ...

    async def collect_texts(
        self,
        references: list[Mapping[str, Any]],
        on_progress: Callable[[int], None],
    ) -> list[dict[str, str]]: ...

    async def extract_topics(
        self,
        analysis_id: str,
        documents: list[dict[str, str]],
    ) -> tuple[list[dict[str, Any]], dict[str, Any]]: ...
