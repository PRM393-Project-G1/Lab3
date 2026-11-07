import json
import logging

from orchestrator.steps import _optional_list, arxiv_id_of, canonical_authors, clean_fulltext, saffron_corpus


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


def authors_of(*references):
    return canonical_authors([{"authors": list(names)} for names in references])


class TestCanonicalAuthors:
    def test_one_spelling_per_person_across_the_paper(self):
        assert authors_of(["A. Vaswani", "N. Shazeer"], ["Ashish Vaswani"], ["Vaswani, Ashish"]) == [
            ["Ashish Vaswani", "N. Shazeer"],
            ["Ashish Vaswani"],
            ["Ashish Vaswani"],
        ]

    def test_drops_et_al_and_others(self):
        assert authors_of(["D. Bahdanau", "et al."], ["K. Cho et al.", "and others"]) == [
            ["D. Bahdanau"],
            ["K. Cho"],
        ]

    def test_a_bare_surname_joins_the_only_person_with_it(self):
        assert authors_of(["Hinton"], ["Geoffrey Hinton"]) == [["Geoffrey Hinton"], ["Geoffrey Hinton"]]

    def test_different_initials_stay_different_people(self):
        assert authors_of(["J. Smith", "K. Smith"], ["Smith"]) == [["J. Smith", "K. Smith"], ["Smith"]]

    def test_a_person_listed_twice_in_one_reference_counts_once(self):
        assert authors_of(["A. Vaswani", "Ashish Vaswani"]) == [["Ashish Vaswani"]]

    def test_a_reference_without_authors_has_none(self):
        assert canonical_authors([{}, {"authors": None}]) == [[], []]


class TestSaffronCorpus:
    def test_keeps_saffrons_fields_and_names_the_authors(self):
        document = {
            "id": "ref-001",
            "name": "Attention",
            "contents": "Attention. Body",
            "mime_type": "text/plain",
            "textSource": "fulltext",
            "authors": ["Ashish Vaswani"],
        }
        assert saffron_corpus([document]) == {
            "documents": [
                {
                    "id": "ref-001",
                    "name": "Attention",
                    "contents": "Attention. Body",
                    "mime_type": "text/plain",
                    "authors": [{"id": "Ashish Vaswani", "name": "Ashish Vaswani"}],
                }
            ]
        }


class TestOptionalList:
    def test_reads_a_list(self, tmp_path):
        path = tmp_path / "terms.json"
        path.write_text(json.dumps([{"term_string": "attention"}]), encoding="utf-8")
        assert _optional_list(path) == [{"term_string": "attention"}]

    def test_a_missing_broken_or_odd_file_is_empty(self, tmp_path, caplog):
        broken, odd = tmp_path / "broken.json", tmp_path / "odd.json"
        broken.write_text("{", encoding="utf-8")
        odd.write_text("{}", encoding="utf-8")
        with caplog.at_level(logging.WARNING):
            assert _optional_list(tmp_path / "missing.json") == []
            assert _optional_list(broken) == []
        assert _optional_list(odd) == []
        assert "broken.json" in caplog.text
