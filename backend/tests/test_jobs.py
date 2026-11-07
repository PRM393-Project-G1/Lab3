import asyncio

from fakes import UID, FakeSteps, FakeStore
from orchestrator.jobs import GENERIC_ERROR, JobManager, Pipeline
from orchestrator.steps import StepError

ID = "1706.03762"


def run(store, steps):
    asyncio.run(Pipeline(store, steps).run(ID, UID, True))


class TestFinishedJob:
    def setup_method(self):
        self.store = FakeStore()
        self.steps = FakeSteps()
        run(self.store, self.steps)
        self.doc = self.store.analyses[ID]

    def test_ends_as_done_at_full_progress(self):
        assert self.doc["status"] == "done"
        assert self.doc["progress"] == {"stage": "topics", "percent": 100, "processedRefs": 2}
        assert self.doc["error"] is None

    def test_writes_the_summary_the_app_reads(self):
        assert self.doc["summary"]["totalRefs"] == 2
        assert self.doc["summary"]["error"] == 1
        assert self.doc["summary"]["verified"] == 1

    def test_keeps_the_arxiv_title_and_authors(self):
        assert self.doc["paperTitle"] == "Attention Is All You Need"
        assert self.doc["paperAuthors"] == ["A. Vaswani"]

    def test_saves_references_and_topics(self):
        assert [ref["id"] for ref in self.store.references] == ["ref-001", "ref-002"]
        assert self.store.references[0]["textSource"] == "abstract"
        assert [topic["term"] for topic in self.store.topics] == ["attention"]
        assert self.store.references[0]["topicIds"] == [self.store.topics[0]["id"]]

    def test_saves_what_saffron_adds_to_topics(self):
        topic = self.store.topics[0]
        assert (topic["importance"], topic["occurrences"]) == (0.8, 3)
        assert topic["authors"] == [{"name": "A. Vaswani", "score": 0.5}]
        assert self.doc["authorLinks"] == [{"a": "A. Vaswani", "b": "N. Shazeer", "similarity": 0.9}]

    def test_notifies_who_asked(self):
        assert self.store.notifications == [
            (UID, ID, "Analysis done", "Attention Is All You Need · 1 flagged")
        ]

    def test_progress_walks_through_the_stages_the_app_knows(self):
        stages = [f["progress"]["stage"] for f in self.store.history if "progress" in f]
        seen = list(dict.fromkeys(stages))
        assert seen == ["references", "verify", "fabrication", "fulltext", "topics"]

    def test_no_progress_write_lands_after_the_final_status(self):
        statuses = [f["status"] for f in self.store.history if "status" in f]
        assert statuses[-1] == "done"
        assert statuses.count("done") == 1

    def test_progress_never_goes_backwards(self):
        percents = [f["progress"]["percent"] for f in self.store.history if "progress" in f]
        assert percents == sorted(percents)


def test_total_refs_is_known_while_running():
    store, steps = FakeStore(), FakeSteps()
    run(store, steps)
    running = [f for f in store.history if f.get("status") == "processing" and "summary" in f]
    assert running and running[0]["summary"] == {"totalRefs": 2}


def test_a_step_error_shows_its_own_message():
    store, steps = FakeStore(), FakeSteps()
    steps.error, steps.error_at = StepError("Couldn't extract topics."), "topics"
    run(store, steps)
    assert store.analyses[ID]["status"] == "failed"
    assert store.analyses[ID]["error"] == "Couldn't extract topics."
    assert store.notifications == []


def test_an_unexpected_error_does_not_leak_details_to_the_phone():
    store, steps = FakeStore(), FakeSteps()
    steps.error, steps.error_at = RuntimeError("secret path C:/x"), "check"
    run(store, steps)
    assert store.analyses[ID]["status"] == "failed"
    assert store.analyses[ID]["error"] == GENERIC_ERROR


def test_a_paper_without_references_fails_clearly():
    store, steps = FakeStore(), FakeSteps()
    steps.references = []
    run(store, steps)
    assert store.analyses[ID]["error"] == "No references found in this paper."
    assert "topics" not in steps.calls


def test_a_failed_push_does_not_undo_the_results():
    store, steps = FakeStore(), FakeSteps()
    store.fail_notify = True
    run(store, steps)
    assert store.analyses[ID]["status"] == "done"


def test_a_failed_title_lookup_falls_back_to_refchecker():
    class NoMetadata(FakeSteps):
        async def paper_metadata(self, analysis_id):
            return {}

    store = FakeStore()
    run(store, NoMetadata())
    assert store.analyses[ID]["paperTitle"] == "From RefChecker"


def test_jobs_run_one_at_a_time():
    async def scenario():
        store, first = FakeStore(), FakeSteps()
        first.gate = asyncio.Event()
        manager = JobManager(Pipeline(store, first))
        manager.start("1111.11111", UID, True)
        manager.start("2222.22222", UID, True)
        await asyncio.sleep(0.05)
        assert "processing" in store.analyses["1111.11111"].get("status", "")
        assert "2222.22222" not in store.analyses
        first.gate.set()
        await manager.wait_all()
        assert store.analyses["2222.22222"]["status"] == "done"

    asyncio.run(scenario())


def test_cancelling_stops_the_job_before_results_are_written():
    async def scenario():
        store, steps = FakeStore(), FakeSteps()
        steps.gate = asyncio.Event()
        manager = JobManager(Pipeline(store, steps))
        manager.start(ID, UID, True)
        await asyncio.sleep(0.05)
        await manager.cancel(ID)
        assert not manager.is_running(ID)
        assert store.references == []
        assert store.notifications == []

    asyncio.run(scenario())
