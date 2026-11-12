"""Turns RefChecker and Saffron output into the documents the app reads.

Field names here are the contract in `docs/architecture.md`, sections 7 and 8.
"""

from __future__ import annotations

import math
import re
from collections.abc import Iterable, Mapping
from typing import Any

STATUSES = ("hallucinated", "error", "warning", "unverified", "verified")
HEAD_TERM = "HEAD_TERM"
# Full texts mention most terms, so every topic would hold almost every reference.
MAX_TOPICS_PER_REFERENCE = 5
# Enough to read on a phone; the rest of Saffron's pairs are weak links.
MAX_RELATED_TOPICS = 5
MAX_TOPIC_AUTHORS = 5
MAX_AUTHOR_LINKS = 20


def map_status(raw: Mapping[str, Any]) -> str:
    """The app has five statuses. A suggestion is not a problem with the reference."""
    assessment = raw.get("hallucination_assessment") or {}
    status = raw.get("status")
    if status == "hallucination" or assessment.get("verdict") == "LIKELY":
        return "hallucinated"
    if status in ("error", "warning", "verified", "unverified"):
        return status
    return "verified" if status == "suggestion" else "unverified"


def _cited(entry: Mapping[str, Any], raw: Mapping[str, Any]) -> str | None:
    """RefChecker often names only the correct value, so read the cited one from the row."""
    if entry.get("cited_value") not in (None, ""):
        return str(entry["cited_value"])
    kind = entry.get("error_type")
    if kind == "author" and raw.get("authors"):
        return ", ".join(str(author) for author in raw["authors"])
    if kind in ("title", "year", "venue") and raw.get(kind):
        return str(raw[kind])
    return None


def _issue(entry: Mapping[str, Any], raw: Mapping[str, Any]) -> dict[str, Any]:
    issue: dict[str, Any] = {
        "type": entry.get("error_type") or "other",
        "message": " ".join((entry.get("error_details") or "").split()),
    }
    cited = _cited(entry, raw)
    if cited is not None:
        issue["cited"] = cited
    if entry.get("actual_value") is not None:
        issue["actual"] = str(entry["actual_value"])
    return issue


def _year(value: Any) -> int | None:
    try:
        return int(value)
    except (TypeError, ValueError):
        return None


def _url(raw: Mapping[str, Any]) -> str | None:
    for link in raw.get("authoritative_urls") or []:
        if link.get("url"):
            return link["url"]
    return raw.get("cited_url")


def reference_doc(raw: Mapping[str, Any], index: int) -> dict[str, Any]:
    """One document of `analyses/{id}/references`, without its topics yet."""
    assessment = raw.get("hallucination_assessment") or {}
    status = map_status(raw)
    doc: dict[str, Any] = {
        "id": f"ref-{index:03d}",
        "index": index,
        "title": raw.get("title") or "Untitled",
        "authors": [str(author) for author in raw.get("authors") or []],
        "year": _year(raw.get("year")),
        "venue": raw.get("venue") or None,
        "url": _url(raw),
        "status": status,
        "issues": [
            _issue(entry, raw) for entry in [*(raw.get("errors") or []), *(raw.get("warnings") or [])]
        ],
        "topicIds": [],
    }
    if status == "hallucinated":
        doc["hallucination"] = {
            "explanation": assessment.get("explanation"),
            "closestMatchTitle": assessment.get("found_title"),
            "closestMatchUrl": assessment.get("link"),
        }
    return doc


def count_statuses(statuses: Iterable[str]) -> dict[str, int]:
    counts = dict.fromkeys(STATUSES, 0)
    for status in statuses:
        counts[status] += 1
    return counts


def summarize(references: Iterable[Mapping[str, Any]]) -> dict[str, int]:
    statuses = [ref["status"] for ref in references]
    return {"totalRefs": len(statuses), **count_statuses(statuses)}


def done_message(title: str, summary: Mapping[str, Any]) -> str:
    return f"{title} · {summary.get('hallucinated', 0) + summary.get('error', 0)} flagged"


def _score(value: Any) -> float:
    # Saffron writes "NaN" for the links it has no score for.
    try:
        score = float(value)
    except (TypeError, ValueError):
        return 0.0
    return score if math.isfinite(score) else 0.0


def _topic_id(term: str, used: set[str]) -> str:
    slug = re.sub(r"[^a-z0-9]+", "-", term.lower()).strip("-")[:80] or "topic"
    candidate, suffix = f"t-{slug}", 2
    while candidate in used:
        candidate, suffix = f"t-{slug}-{suffix}", suffix + 1
    used.add(candidate)
    return candidate


def build_topics(
    references: list[dict[str, Any]],
    doc_terms: Iterable[Mapping[str, Any]],
    taxonomy: Mapping[str, Any],
    *,
    terms: Iterable[Mapping[str, Any]] = (),
    term_sim: Iterable[Mapping[str, Any]] = (),
    author_terms: Iterable[Mapping[str, Any]] = (),
) -> list[dict[str, Any]]:
    """Flattens the taxonomy and fills in `topicIds` on each reference.

    A topic keeps its own `refIds`; `counts` covers its whole subtree, each
    reference once. A reference joins only its strongest few terms. Branches with
    no reference are dropped. A reference with no term stays without topics, and the
    app shows it as Unclassified.

    The other Saffron files add how important each topic is in the corpus, the
    topics that share its references, and the authors who write most about it.
    """
    status_of = {ref["id"]: ref["status"] for ref in references}
    links_of_ref: dict[str, list[Mapping[str, Any]]] = {}
    for link in doc_terms:
        if link.get("document_id") in status_of and link.get("term_string"):
            links_of_ref.setdefault(link["document_id"], []).append(link)

    refs_of_term: dict[str, list[str]] = {}
    for ref_id in status_of:
        strongest = sorted(
            links_of_ref.get(ref_id, []),
            key=lambda link: (_score(link.get("tfidf")), link.get("occurrences") or 0),
            reverse=True,
        )
        kept = {link["term_string"].lower() for link in strongest[:MAX_TOPICS_PER_REFERENCE]}
        for term in kept:
            refs_of_term.setdefault(term, []).append(ref_id)

    topics: list[dict[str, Any]] = []
    used: set[str] = set()

    def visit(node: Mapping[str, Any], parent_id: str | None, depth: int) -> set[str]:
        term = node.get("root") or ""
        topic = {
            "id": _topic_id(term, used),
            "term": term,
            "parentId": parent_id,
            "depth": depth,
            "score": _score(node.get("score")),
            "refIds": refs_of_term.get(term.lower(), []),
        }
        slot = len(topics)
        topics.append(topic)
        subtree = set(topic["refIds"])
        for child in node.get("children") or []:
            subtree |= visit(child, topic["id"], depth + 1)
        if not subtree:
            del topics[slot:]
            return subtree
        topic["counts"] = count_statuses(status_of[ref_id] for ref_id in subtree)
        return subtree

    roots = taxonomy.get("children") or [] if taxonomy.get("root") == HEAD_TERM else [taxonomy]
    for root in roots:
        visit(root, None, 0)

    topics_of_ref: dict[str, list[str]] = {}
    for topic in topics:
        for ref_id in topic["refIds"]:
            topics_of_ref.setdefault(ref_id, []).append(topic["id"])
    for ref in references:
        ref["topicIds"] = topics_of_ref.get(ref["id"], [])

    _add_term_details(topics, terms, term_sim, author_terms)
    return topics


def _add_term_details(
    topics: list[dict[str, Any]],
    terms: Iterable[Mapping[str, Any]],
    term_sim: Iterable[Mapping[str, Any]],
    author_terms: Iterable[Mapping[str, Any]],
) -> None:
    """Sets `importance`, `occurrences`, `related` and `authors` on every topic.

    Saffron names terms by their text, so they are matched to topics by term.
    Terms that were dropped with an empty branch are skipped.
    """
    by_term: dict[str, list[dict[str, Any]]] = {}
    for topic in topics:
        by_term.setdefault(topic["term"].lower(), []).append(topic)
        topic.update(importance=0.0, occurrences=0, related=[], authors=[])

    for term in terms:
        for topic in by_term.get(str(term.get("term_string") or "").lower(), []):
            topic["importance"] = _score(term.get("score"))
            topic["occurrences"] = int(term.get("occurrences") or 0)

    related: dict[str, dict[str, float]] = {}
    names = {topic["id"]: topic["term"] for topic in topics}
    for pair in term_sim:
        similarity = _score(pair.get("similarity"))
        firsts = by_term.get(str(pair.get("term1_id") or "").lower(), [])
        seconds = by_term.get(str(pair.get("term2_id") or "").lower(), [])
        for first in firsts:
            for second in seconds:
                if first is second or similarity <= 0:
                    continue
                for a, b in ((first, second), (second, first)):
                    links = related.setdefault(a["id"], {})
                    links[b["id"]] = max(links.get(b["id"], 0.0), similarity)

    authors: dict[str, dict[str, float]] = {}
    for link in author_terms:
        name = str(link.get("authorId") or "").strip()
        for topic in by_term.get(str(link.get("termId") or "").lower(), []):
            if name:
                scores = authors.setdefault(topic["id"], {})
                scores[name] = max(scores.get(name, 0.0), _score(link.get("score")))

    for topic in topics:
        nearest = sorted(
            related.get(topic["id"], {}).items(), key=lambda item: (-item[1], names[item[0]])
        )
        topic["related"] = [
            {"topicId": other, "term": names[other], "similarity": round(similarity, 3)}
            for other, similarity in nearest[:MAX_RELATED_TOPICS]
        ]
        strongest = sorted(authors.get(topic["id"], {}).items(), key=lambda item: (-item[1], item[0]))
        topic["authors"] = [
            {"name": name, "score": round(score, 3)} for name, score in strongest[:MAX_TOPIC_AUTHORS]
        ]


def author_links(author_sim: Iterable[Mapping[str, Any]]) -> list[dict[str, Any]]:
    """The most similar pairs of authors, each pair once, for `analyses/{id}.authorLinks`.

    Two authors are similar when they write about the same topics.
    """
    best: dict[tuple[str, str], float] = {}
    for pair in author_sim:
        a = str(pair.get("author1_id") or "").strip()
        b = str(pair.get("author2_id") or "").strip()
        similarity = _score(pair.get("similarity"))
        if not a or not b or a == b or similarity <= 0:
            continue
        key = (a, b) if a < b else (b, a)
        best[key] = max(best.get(key, 0.0), similarity)
    strongest = sorted(best.items(), key=lambda item: (-item[1], item[0]))[:MAX_AUTHOR_LINKS]
    return [{"a": a, "b": b, "similarity": round(similarity, 3)} for (a, b), similarity in strongest]


MAX_TOPIC_SUMMARY = 200


def topic_summary(topics: Iterable[Mapping[str, Any]]) -> list[dict[str, Any]]:
    """Per-topic issue counts stored on the analysis, so the admin web can rank weak
    topics across papers without reading every `topics` subcollection.

    `total` and `flagged` (error + hallucinated) cover the topic's subtree, like
    `counts`. The weak-topic threshold lives in Remote Config, so the reader decides.
    Topics without a flagged reference can never be weak and are left out.
    """
    rows = []
    for topic in topics:
        counts = topic.get("counts") or {}
        total = sum(int(counts.get(status) or 0) for status in STATUSES)
        flagged = int(counts.get("error") or 0) + int(counts.get("hallucinated") or 0)
        term = str(topic.get("term") or "").strip()
        if term and flagged:
            rows.append({"term": term, "depth": int(topic.get("depth") or 0), "total": total, "flagged": flagged})
    rows.sort(key=lambda row: (-row["flagged"] / row["total"], -row["total"], row["term"]))
    return rows[:MAX_TOPIC_SUMMARY]
