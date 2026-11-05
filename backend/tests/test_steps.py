from orchestrator.steps import arxiv_id_of, clean_fulltext


class TestArxivId:
    def test_uses_the_field_when_there_is_one(self):
        assert arxiv_id_of({"arxiv_id": "1706.03762"}) == "1706.03762"

    def test_reads_it_from_the_cited_link(self):
        assert arxiv_id_of({"cited_url": "https://arxiv.org/abs/arXiv:1607.06450"}) == "1607.06450"
        assert arxiv_id_of({"cited_url": "https://arxiv.org/pdf/1607.06450v2.pdf"}) == "1607.06450"

    def test_other_links_have_no_id(self):
        assert arxiv_id_of({"cited_url": "https://example.test/1607.06450"}) is None
        assert arxiv_id_of({}) is None


class TestCleanFulltext:
    def test_drops_the_bibliography(self):
        text = "Body about attention.\nReferences\n[1] Someone. A paper. 2017."
        assert clean_fulltext(text).strip() == "Body about attention."

    def test_cuts_at_the_last_heading_only(self):
        text = "See the references\nReferences\nMore body.\nReferences\n[1] A paper."
        assert "More body." in clean_fulltext(text)
        assert "A paper" not in clean_fulltext(text)

    def test_removes_citation_marks(self):
        cleaned = clean_fulltext("Attention [1, 2] as Bahdanau et al. showed [3-5] works.")
        assert "et al" not in cleaned
        assert "[" not in cleaned
        assert "Attention" in cleaned

    def test_keeps_text_with_no_heading(self):
        assert clean_fulltext("Only a body.") == "Only a body."
