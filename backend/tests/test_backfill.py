from orchestrator.backfill import backfill


class FakeBackfillStore:
    def __init__(self):
        self.analyses = {
            "1706.03762": {"status": "done"},
            "1409.0473": {"status": "done", "topicSummary": []},
        }
        self.topics = {"1706.03762": [{"term": "attention", "depth": 0, "counts": {"error": 2, "verified": 1}}], "1409.0473": []}
        self.reads = []

    def completed_analyses(self):
        return list(self.analyses.items())

    def topics_of(self, analysis_id):
        self.reads.append(analysis_id)
        return self.topics[analysis_id]

    def update_analysis(self, analysis_id, fields):
        self.analyses[analysis_id].update(fields)


def test_fills_only_missing_summaries_unless_forced():
    store = FakeBackfillStore()
    assert backfill(store) == 1
    assert store.reads == ["1706.03762"]
    assert store.analyses["1706.03762"]["topicSummary"] == [{"term": "attention", "depth": 0, "total": 3, "flagged": 2}]
    assert backfill(store, force=True) == 2
