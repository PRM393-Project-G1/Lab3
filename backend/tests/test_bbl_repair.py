from orchestrator.bbl_repair import repair_year_first

BBL = r"""\begin{thebibliography}{}

\bibitem[\protect\citename{Cho \bgroup et al.\egroup }2014]{cho14}
Kyunghyun Cho, Bart van Merrienboer, and Yoshua Bengio.
\newblock 2014.
\newblock Learning phrase representations using {RNN} encoder-decoder for
  statistical machine translation.
\newblock In {\em EMNLP}.

\bibitem[Fraser and Marcu2007]{fraser07}
Alexander Fraser and Daniel Marcu.
\newblock 2007.
\newblock Measuring word alignment quality.
\newblock {\em Computational Linguistics}, 33(3).

\bibitem{normal}
Someone Else.
\newblock A normal title.
\newblock In {\em ICML}, 2019.

\end{thebibliography}
"""


def misread(key):
    return {"bibitem_key": key, "title": "", "journal": "The title by mistake"}


def test_moves_the_title_and_venue_to_their_fields():
    cho = repair_year_first([misread("cho14")], BBL)[0]
    assert cho["title"] == "Learning phrase representations using RNN encoder-decoder for statistical machine translation"
    assert cho["journal"] == "EMNLP"
    assert cho["venue"] == "EMNLP"


def test_a_venue_without_in_keeps_its_details():
    fraser = repair_year_first([misread("fraser07")], BBL)[0]
    assert fraser["title"] == "Measuring word alignment quality"
    assert fraser["venue"].startswith("Computational Linguistics")


def test_a_reference_with_a_title_is_left_alone():
    reference = {"bibitem_key": "cho14", "title": "Already read", "journal": "ICLR"}
    assert repair_year_first([reference], BBL) == [{"bibitem_key": "cho14", "title": "Already read", "journal": "ICLR"}]


def test_other_styles_are_left_alone():
    reference = misread("normal")
    repair_year_first([reference], BBL)
    assert reference["title"] == ""


def test_an_unknown_key_is_left_alone():
    reference = misread("missing")
    repair_year_first([reference], BBL)
    assert reference["title"] == ""


def test_a_reference_without_a_key_is_left_alone_when_the_order_is_unknown():
    assert repair_year_first([{"title": ""}], BBL) == [{"title": ""}]


def test_references_without_keys_are_matched_by_position():
    references = [{"title": ""}, {"title": ""}, {"title": ""}]
    repair_year_first(references, BBL)
    assert references[0]["venue"] == "EMNLP"
    assert references[1]["title"] == "Measuring word alignment quality"
    assert references[2]["title"] == ""
