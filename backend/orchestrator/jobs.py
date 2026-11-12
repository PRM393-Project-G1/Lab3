"""One analysis from start to finish, and the queue that runs them."""

from __future__ import annotations

import asyncio
import logging
import time
from concurrent.futures import ThreadPoolExecutor
from typing import Any

from . import merge
from .contract import DONE, DONE_TITLE, FAILED, PROCESSING
from .ports import AnalysisSteps, ProgressStore
from .steps import StepError

logger = logging.getLogger(__name__)

GENERIC_ERROR = "Something went wrong on the server."
PROGRESS_INTERVAL_SECONDS = 2.0
# Where each stage starts on the progress bar. The keys are the app's `progress.stage`.
STAGE_PERCENT = {"references": 0, "verify": 10, "fabrication": 60, "fulltext": 70, "topics": 85}


class _Progress:
    """Writes progress in order, on its own thread, callable from any thread.

    Skips writes under 2 seconds apart unless the stage changes, because the Spark
    plan allows 20,000 Firestore writes a day. Call `flush` before writing a final
    status, or a late update would set it back to `processing`.
    """

    def __init__(self, store: ProgressStore, analysis_id: str) -> None:
        self._store = store
        self._id = analysis_id
        self._writer = ThreadPoolExecutor(max_workers=1)
        self._stage = ""
        self._last_write = 0.0
        self.total_refs = 0
        self.processed = 0

    def report(self, stage: str, fraction: float = 0.0, **fields: Any) -> None:
        self._writer.submit(self._write, stage, fraction, fields)

    def _write(self, stage: str, fraction: float, fields: dict[str, Any]) -> None:
        now = time.monotonic()
        if stage == self._stage and not fields and now - self._last_write < PROGRESS_INTERVAL_SECONDS:
            return
        self._stage, self._last_write = stage, now
        stages = list(STAGE_PERCENT)
        following = stages.index(stage) + 1
        end = STAGE_PERCENT[stages[following]] if following < len(stages) else 100
        start = STAGE_PERCENT[stage]
        update = {
            "status": PROCESSING,
            "progress": {
                "stage": stage,
                "percent": int(start + (end - start) * fraction),
                "processedRefs": self.processed,
            },
            **fields,
        }
        if self.total_refs:
            update["summary"] = {"totalRefs": self.total_refs}
        try:
            self._store.update_analysis(self._id, update)
        except Exception:  # A lost progress update must not stop the analysis.
            logger.exception("Couldn't write progress for %s", self._id)

    async def flush(self) -> None:
        await asyncio.wrap_future(self._writer.submit(lambda: None))

    def close(self) -> None:
        self._writer.shutdown(wait=False)


class Pipeline:
    def __init__(self, store: ProgressStore, steps: AnalysisSteps) -> None:
        self._store = store
        self._steps = steps

    async def run(self, analysis_id: str, uid: str, ai_assisted: bool) -> None:
        progress = _Progress(self._store, analysis_id)
        failure: str | None = None
        try:
            await self._analyze(analysis_id, uid, ai_assisted, progress)
        except StepError as error:
            logger.warning("Analysis %s failed: %s", analysis_id, error)
            failure = str(error)
        except Exception:
            logger.exception("Analysis %s failed", analysis_id)
            failure = GENERIC_ERROR
        finally:
            await progress.flush()
            progress.close()
        if failure:
            await asyncio.to_thread(
                self._store.finish_analysis, analysis_id, {"status": FAILED, "error": failure}
            )

    async def _analyze(
        self,
        analysis_id: str,
        uid: str,
        ai_assisted: bool,
        progress: _Progress,
    ) -> None:
        store, steps = self._store, self._steps

        progress.report("references")
        metadata = await steps.paper_metadata(analysis_id)
        if metadata:
            progress.report("references", **metadata)

        def on_event(event: dict[str, Any]) -> None:
            kind = event.get("event")
            if kind == "title_updated" and not metadata and event.get("paper_title"):
                progress.report("references", paperTitle=event["paper_title"])
            elif kind == "references_extracted":
                progress.total_refs = int(event.get("total_refs") or 0)
                progress.report("verify")
            elif kind == "progress" and event.get("total"):
                progress.total_refs = int(event["total"])
                progress.processed = int(event.get("current") or 0)
                progress.report("verify", progress.processed / progress.total_refs)
            elif kind == "phase":
                progress.report("fabrication")

        result = await steps.check_references(analysis_id, ai_assisted, on_event)
        raw_references = result.get("references") or []
        if not raw_references:
            raise StepError("No references found in this paper.")
        progress.total_refs = progress.processed = len(raw_references)
        references = [merge.reference_doc(raw, i) for i, raw in enumerate(raw_references, 1)]

        progress.report("fulltext")
        documents = await steps.collect_texts(
            raw_references,
            lambda done: progress.report("fulltext", done / len(raw_references)),
        )
        for reference, document in zip(references, documents):
            reference["textSource"] = document["textSource"]
            reference["title"] = document["name"]

        progress.report("topics")
        saffron = await steps.extract_topics(analysis_id, documents)
        topics = merge.build_topics(
            references,
            saffron.doc_terms,
            saffron.taxonomy,
            terms=saffron.terms,
            term_sim=saffron.term_sim,
            author_terms=saffron.author_terms,
        )
        await asyncio.to_thread(store.replace_results, analysis_id, references, topics)

        summary = merge.summarize(references)
        title = metadata.get("paperTitle") or result.get("paper_title") or f"arXiv:{analysis_id}"
        await progress.flush()
        await asyncio.to_thread(
            store.finish_analysis,
            analysis_id,
            {
                "status": DONE,
                "paperTitle": title,
                "summary": summary,
                "authorLinks": merge.author_links(saffron.author_sim),
                "topicSummary": merge.topic_summary(topics),
                "error": None,
                "progress": {"stage": "topics", "percent": 100, "processedRefs": len(references)},
            },
        )
        try:
            await asyncio.to_thread(
                store.notify_done, uid, analysis_id, DONE_TITLE, merge.done_message(title, summary)
            )
        except Exception:  # The results are saved; a missed push does not undo them.
            logger.exception("Couldn't notify %s about %s", uid, analysis_id)


class JobManager:
    """Runs one analysis at a time: each one is heavy on memory and on rate limits."""

    def __init__(self, pipeline: Pipeline, parallel: int = 1) -> None:
        self._pipeline = pipeline
        self._slots = asyncio.Semaphore(parallel)
        self._tasks: dict[str, asyncio.Task[None]] = {}

    @property
    def running(self) -> int:
        return len(self._tasks)

    def is_running(self, analysis_id: str) -> bool:
        return analysis_id in self._tasks

    def start(self, analysis_id: str, uid: str, ai_assisted: bool) -> None:
        async def work() -> None:
            async with self._slots:
                await self._pipeline.run(analysis_id, uid, ai_assisted)

        task = asyncio.create_task(work())
        self._tasks[analysis_id] = task
        task.add_done_callback(lambda _: self._tasks.pop(analysis_id, None))

    async def cancel(self, analysis_id: str) -> None:
        task = self._tasks.get(analysis_id)
        if task is not None:
            task.cancel()
            await asyncio.gather(task, return_exceptions=True)

    async def cancel_all(self) -> None:
        for analysis_id in list(self._tasks):
            await self.cancel(analysis_id)

    async def wait_all(self) -> None:
        await asyncio.gather(*self._tasks.values(), return_exceptions=True)
