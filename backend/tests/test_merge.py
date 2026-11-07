from orchestrator import merge


def raw(status="verified", **fields):
    return {"title": "A paper", "status": status, **fields}


def refs(*statuses):
    return [merge.reference_doc(raw(status), i) for i, status in enumerate(statuses, 1)]


def node(term, *children, score=0.5):
    return {"root": term, "score": score, "linkScore": "NaN", "children": list(children)}


def links(**terms):
    return [
        {"document_id": ref_id, "term_string": term.replace("_", " ")}
        for term, ref_ids in terms.items()
        for ref_id in ref_ids
    ]


class TestStatus:
    def test_every_refchecker_status_maps_to_an_app_status(self):
        expected = {
            "verified": "verified",
            "error": "error",
            "warning": "warning",
            "unverified": "unverified",
            "suggestion": "verified",
            "hallucination": "hallucinated",
            "something-new": "unverified",
        }
        for status, mapped in expected.items():
            assert merge.map_status({"status": status}) == mapped

    def test_a_likely_fabricated_verdict_outranks_the_status(self):
        assessment = {"verdict": "LIKELY"}
        assert merge.map_status({"status": "error", "hallucination_assessment": assessment}) == "hallucinated"

    def test_an_unlikely_verdict_changes_nothing(self):
        assessment = {"verdict": "UNLIKELY"}
        assert merge.map_status({"status": "error", "hallucination_assessment": assessment}) == "error"


class TestReferenceDoc:
    def test_uses_the_field_names_the_app_reads(self):
        doc = merge.reference_doc(
            raw(
                "error",
                title="Attention",
                authors=["A. Vaswani"],
                year="2017",
                venue="NeurIPS",
                authoritative_urls=[{"type": "arxiv", "url": "https://arxiv.org/abs/1706.03762"}],
                errors=[{"error_type": "year", "error_details": "Wrong year", "cited_value": 2016, "actual_value": 2017}],
                warnings=[{"error_type": "venue", "error_details": "Venue differs"}],
            ),
            7,
        )
        assert doc["id"] == "ref-007"
        assert doc["index"] == 7
        assert doc["year"] == 2017
        assert doc["url"] == "https://arxiv.org/abs/1706.03762"
        assert doc["issues"] == [
            {"type": "year", "message": "Wrong year", "cited": "2016", "actual": "2017"},
            {"type": "venue", "message": "Venue differs", "cited": "NeurIPS"},
        ]

    def test_a_missing_cited_value_is_read_from_the_reference(self):
        doc = merge.reference_doc(
            raw(
                "error",
                authors=["A. Vaswani", "N. Shazeer"],
                errors=[
                    {
                        "error_type": "author",
                        "error_details": "Author count mismatch:\n   cited: two",
                        "actual_value": "Ashish Vaswani",
                    }
                ],
            ),
            1,
        )
        assert doc["issues"] == [
            {
                "type": "author",
                "message": "Author count mismatch: cited: two",
                "cited": "A. Vaswani, N. Shazeer",
                "actual": "Ashish Vaswani",
            }
        ]

    def test_an_empty_venue_is_stored_as_none(self):
        assert merge.reference_doc(raw(venue=""), 1)["venue"] is None

    def test_a_year_that_is_not_a_number_is_left_out(self):
        assert merge.reference_doc(raw(year="n.d."), 1)["year"] is None

    def test_falls_back_to_the_cited_url(self):
        assert merge.reference_doc(raw(cited_url="https://x.test"), 1)["url"] == "https://x.test"

    def test_a_fabricated_reference_carries_its_explanation(self):
        doc = merge.reference_doc(
            raw(
                "unverified",
                hallucination_assessment={
                    "verdict": "LIKELY",
                    "explanation": "No such paper",
                    "found_title": "A close title",
                    "link": "https://x.test/close",
                },
            ),
            1,
        )
        assert doc["hallucination"] == {
            "explanation": "No such paper",
            "closestMatchTitle": "A close title",
            "closestMatchUrl": "https://x.test/close",
        }

    def test_other_references_have_no_hallucination_block(self):
        assert "hallucination" not in merge.reference_doc(raw("error"), 1)


def test_summary_counts_each_status():
    assert merge.summarize(refs("verified", "error", "error", "hallucination")) == {
        "totalRefs": 4,
        "hallucinated": 1,
        "error": 2,
        "warning": 0,
        "unverified": 0,
        "verified": 1,
    }


class TestTopics:
    def test_flattens_the_taxonomy_below_the_head_term(self):
        references = refs("verified", "error")
        taxonomy = node("HEAD_TERM", node("deep learning", node("attention")))

        topics = merge.build_topics(
            references, links(deep_learning=["ref-001"], attention=["ref-002"]), taxonomy
        )

        parent, child = topics
        assert (parent["term"], parent["parentId"], parent["depth"]) == ("deep learning", None, 0)
        assert (child["term"], child["parentId"], child["depth"]) == ("attention", parent["id"], 1)
        assert parent["refIds"] == ["ref-001"]
        assert child["refIds"] == ["ref-002"]

    def test_counts_cover_the_subtree_once_per_reference(self):
        references = refs("verified", "error")
        taxonomy = node("HEAD_TERM", node("parent", node("left"), node("right")))

        parent, *_ = merge.build_topics(
            references,
            links(left=["ref-001", "ref-002"], right=["ref-002"]),
            taxonomy,
        )

        assert parent["counts"]["verified"] == 1
        assert parent["counts"]["error"] == 1

    def test_references_learn_their_topics(self):
        references = refs("verified")
        topics = merge.build_topics(references, links(attention=["ref-001"]), node("HEAD_TERM", node("attention")))
        assert references[0]["topicIds"] == [topics[0]["id"]]

    def test_a_reference_without_a_term_stays_unclassified(self):
        references = refs("verified", "error")
        merge.build_topics(references, links(attention=["ref-001"]), node("HEAD_TERM", node("attention")))
        assert references[1]["topicIds"] == []

    def test_branches_without_references_are_dropped(self):
        references = refs("verified")
        taxonomy = node("HEAD_TERM", node("empty", node("empty child")), node("kept"))
        topics = merge.build_topics(references, links(kept=["ref-001"]), taxonomy)
        assert [topic["term"] for topic in topics] == ["kept"]

    def test_an_empty_child_is_dropped_but_its_parent_stays(self):
        references = refs("verified")
        taxonomy = node("HEAD_TERM", node("kept", node("empty")))
        topics = merge.build_topics(references, links(kept=["ref-001"]), taxonomy)
        assert [topic["term"] for topic in topics] == ["kept"]

    def test_a_parent_with_only_child_references_stays(self):
        references = refs("verified")
        taxonomy = node("HEAD_TERM", node("parent", node("child")))
        topics = merge.build_topics(references, links(child=["ref-001"]), taxonomy)
        assert [topic["term"] for topic in topics] == ["parent", "child"]

    def test_similar_terms_get_different_ids(self):
        references = refs("verified")
        taxonomy = node("HEAD_TERM", node("neural-net"), node("neural net"))
        topics = merge.build_topics(
            references,
            [
                {"document_id": "ref-001", "term_string": "neural-net"},
                {"document_id": "ref-001", "term_string": "neural net"},
            ],
            taxonomy,
        )
        assert len({topic["id"] for topic in topics}) == 2

    def test_a_score_of_nan_is_stored_as_zero(self):
        references = refs("verified")
        topics = merge.build_topics(
            references, links(a=["ref-001"]), node("HEAD_TERM", node("a", score=float("nan")))
        )
        assert topics[0]["score"] == 0.0

    def test_a_reference_joins_only_its_strongest_terms(self):
        references = refs("verified")
        terms = [f"term {i}" for i in range(merge.MAX_TOPICS_PER_REFERENCE + 2)]
        doc_terms = [
            {"document_id": "ref-001", "term_string": term, "tfidf": float(i), "occurrences": 1}
            for i, term in enumerate(terms)
        ]
        taxonomy = node("HEAD_TERM", *[node(term) for term in terms])

        topics = merge.build_topics(references, doc_terms, taxonomy)

        assert {topic["term"] for topic in topics} == set(terms[2:])

    def test_links_to_unknown_documents_are_ignored(self):
        references = refs("verified")
        topics = merge.build_topics(
            references, links(a=["ref-001", "ref-999"]), node("HEAD_TERM", node("a"))
        )
        assert topics[0]["refIds"] == ["ref-001"]


class TestTermDetails:
    def topics(self, **saffron):
        references = refs("verified", "error")
        taxonomy = node("HEAD_TERM", node("attention"), node("Machine Translation"), node("empty"))
        return merge.build_topics(
            references,
            links(attention=["ref-001"], machine_translation=["ref-002"]),
            taxonomy,
            **saffron,
        )

    def by_term(self, topics):
        return {topic["term"]: topic for topic in topics}

    def test_without_the_extra_files_every_topic_still_has_the_fields(self):
        for topic in self.topics():
            assert (topic["importance"], topic["occurrences"]) == (0.0, 0)
            assert (topic["related"], topic["authors"]) == ([], [])

    def test_importance_and_occurrences_match_by_term_ignoring_case(self):
        topics = self.by_term(
            self.topics(terms=[{"term_string": "machine translation", "score": 0.7, "occurrences": 4}])
        )
        assert topics["Machine Translation"]["importance"] == 0.7
        assert topics["Machine Translation"]["occurrences"] == 4
        assert topics["attention"]["importance"] == 0.0

    def test_related_topics_go_both_ways_strongest_first(self):
        topics = self.by_term(
            self.topics(
                term_sim=[
                    {"term1_id": "attention", "term2_id": "machine translation", "similarity": 0.4},
                    {"term1_id": "attention", "term2_id": "empty", "similarity": 0.9},
                    {"term1_id": "attention", "term2_id": "attention", "similarity": 1.0},
                ]
            )
        )
        translation = topics["Machine Translation"]
        assert topics["attention"]["related"] == [
            {"topicId": translation["id"], "term": "Machine Translation", "similarity": 0.4}
        ]
        assert translation["related"][0]["term"] == "attention"

    def test_related_topics_are_capped(self):
        terms = [f"t{i}" for i in range(merge.MAX_RELATED_TOPICS + 3)]
        topics = merge.build_topics(
            refs(*["verified"] * len(terms)),
            [{"document_id": f"ref-{i:03d}", "term_string": term} for i, term in enumerate(terms, 1)],
            node("HEAD_TERM", *[node(term) for term in terms]),
            term_sim=[
                {"term1_id": "t0", "term2_id": term, "similarity": i / 10}
                for i, term in enumerate(terms[1:], 1)
            ],
        )
        related = topics[0]["related"]
        assert len(related) == merge.MAX_RELATED_TOPICS
        assert related[0]["term"] == terms[-1]

    def test_authors_are_the_highest_scoring_per_topic(self):
        topics = self.by_term(
            self.topics(
                author_terms=[
                    {"authorId": "Ashish Vaswani", "termId": "attention", "score": 0.2},
                    {"authorId": "Noam Shazeer", "termId": "attention", "score": 0.6},
                    {"authorId": "Ashish Vaswani", "termId": "attention", "score": 0.3},
                    {"authorId": "", "termId": "attention", "score": 0.9},
                ]
            )
        )
        assert topics["attention"]["authors"] == [
            {"name": "Noam Shazeer", "score": 0.6},
            {"name": "Ashish Vaswani", "score": 0.3},
        ]
        assert topics["Machine Translation"]["authors"] == []


class TestAuthorLinks:
    def test_each_pair_once_strongest_first(self):
        links_ = merge.author_links(
            [
                {"author1_id": "B", "author2_id": "A", "similarity": 0.5},
                {"author1_id": "A", "author2_id": "B", "similarity": 0.7},
                {"author1_id": "A", "author2_id": "C", "similarity": 0.9},
            ]
        )
        assert links_ == [
            {"a": "A", "b": "C", "similarity": 0.9},
            {"a": "A", "b": "B", "similarity": 0.7},
        ]

    def test_skips_self_pairs_blank_names_and_nan(self):
        assert merge.author_links(
            [
                {"author1_id": "A", "author2_id": "A", "similarity": 1.0},
                {"author1_id": "", "author2_id": "B", "similarity": 0.5},
                {"author1_id": "A", "author2_id": "B", "similarity": "NaN"},
            ]
        ) == []

    def test_keeps_only_the_strongest_pairs(self):
        pairs = [
            {"author1_id": f"A{i:02d}", "author2_id": "Z", "similarity": i / 100}
            for i in range(1, merge.MAX_AUTHOR_LINKS + 6)
        ]
        links_ = merge.author_links(pairs)
        assert len(links_) == merge.MAX_AUTHOR_LINKS
        assert links_[0]["similarity"] == (merge.MAX_AUTHOR_LINKS + 5) / 100
