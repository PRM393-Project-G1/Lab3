"""Repairs references that RefChecker misreads from year-first .bbl files.

ACL-style bibliographies put the year before the title:

    \\bibitem[...]{key}
    Authors.
    \\newblock 2015.
    \\newblock Title.
    \\newblock In {\\em Venue}.

RefChecker takes the year for the title and the title for the venue, then checks
the reference with no title. That finds the wrong paper or none, so the repair has
to happen before verification.
"""

from __future__ import annotations

import re
from typing import Any

_BIBITEM = re.compile(r"\\bibitem\s*(?:\[[^\]]*\]\s*)?\{([^}]+)\}", re.DOTALL)
_YEAR = re.compile(r"^\d{4}[a-z]?\.?$")
_LEADING_IN = re.compile(r"^in\s+", re.IGNORECASE)
_TEX_COMMAND = re.compile(r"\\[a-zA-Z]+\s*")


def _plain(tex: str) -> str:
    text = _TEX_COMMAND.sub("", tex.replace("~", " "))
    return " ".join(text.replace("{", "").replace("}", "").split()).strip(" .,")


def _blocks(bbl: str) -> list[tuple[str, list[str]]]:
    matches = list(_BIBITEM.finditer(bbl))
    blocks = []
    for match, following in zip(matches, [*matches[1:], None]):
        end = following.start() if following else len(bbl)
        body = bbl[match.end() : end].replace(r"\end{thebibliography}", "")
        blocks.append((match.group(1).strip(), re.split(r"\\newblock", body)))
    return blocks


def repair_year_first(references: list[dict[str, Any]], bbl: str) -> list[dict[str, Any]]:
    """Fills in the title and venue of each untitled reference in the year-first form."""
    blocks = _blocks(bbl)
    by_key = dict(blocks)
    # RefChecker can drop the key when it tidies its fields, but it keeps the order.
    same_order = len(blocks) == len(references)
    for position, reference in enumerate(references):
        if reference.get("title"):
            continue
        key = reference.get("bibitem_key")
        parts = by_key.get(key, []) if key else blocks[position][1] if same_order else []
        if len(parts) < 3 or not _YEAR.match(parts[1].strip()):
            continue
        reference["title"] = _plain(parts[2])
        venue = _LEADING_IN.sub("", _plain(parts[3])) if len(parts) > 3 else ""
        reference["journal"] = reference["venue"] = venue
    return references
