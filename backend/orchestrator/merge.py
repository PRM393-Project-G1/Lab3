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
) -> list[dict[str, Any]]:
    """Flattens the taxonomy and fills in `topicIds` on each reference.

    A topic keeps its own `refIds`; `counts` covers its whole subtree, each
    reference once. A reference joins only its strongest few terms. Branches with
    no reference are dropped. A reference with no term stays without topics, and the
    app shows it as Unclassified.
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
        terms = {link["term_string"].lower() for link in strongest[:MAX_TOPICS_PER_REFERENCE]}
        for term in terms:
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
    return topics
