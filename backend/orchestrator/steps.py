"""The slow parts of a job. Each one talks to something outside this process."""

from __future__ import annotations

import asyncio
import json
import logging
import os
import re
import subprocess
import sys
import time
import xml.etree.ElementTree as ElementTree
from collections.abc import Callable, Mapping
from dataclasses import dataclass, field
from io import BytesIO
from pathlib import Path
from typing import Any

import requests
from pypdf import PdfReader

from .config import BACKEND_DIR, Settings
from .refchecker_worker import EVENT_PREFIX

logger = logging.getLogger(__name__)

MAX_PDF_CHARS = 80_000
MAX_TEXT_CHARS = 30_000
TIMEOUT_SECONDS = 60
_ATOM = {"atom": "http://www.w3.org/2005/Atom"}
_ARXIV_URL = re.compile(r"arxiv\.org/(?:abs|pdf)/(?:arxiv:)?(\d{4}\.\d{4,5})", re.IGNORECASE)
_REFERENCES_HEADING = re.compile(r"^\s*(?:references|bibliography)\s*$", re.IGNORECASE | re.MULTILINE)
_CITATION_NOISE = re.compile(r"\b[\w'-]+(?:\s+and\s+[\w'-]+)?\s+et\s+al\.?|\[\s*\d+(?:\s*[,-]\s*\d+)*\s*\]")
_ET_AL = re.compile(r"\s*,?\s+et\.?\s*al\.?$", re.IGNORECASE)
_NOT_A_NAME = re.compile(r"^(?:and\s+)?(?:et\.?\s*al\.?|others|anonymous)$", re.IGNORECASE)

# PDFs from arXiv make it warn about every embedded font.
logging.getLogger("pypdf").setLevel(logging.ERROR)


class StepError(Exception):
    """A failure whose message is short enough to show on the phone."""


@dataclass(frozen=True)
class SaffronOutput:
    """The files of one Saffron run that the results use."""

    doc_terms: list[dict[str, Any]]
    taxonomy: dict[str, Any]
    terms: list[dict[str, Any]] = field(default_factory=list)
    term_sim: list[dict[str, Any]] = field(default_factory=list)
    author_terms: list[dict[str, Any]] = field(default_factory=list)
    author_sim: list[dict[str, Any]] = field(default_factory=list)


def arxiv_id_of(raw: Mapping[str, Any]) -> str | None:
    if raw.get("arxiv_id"):
        return raw["arxiv_id"]
    match = _ARXIV_URL.search(raw.get("cited_url") or "")
    return match.group(1) if match else None


def clean_fulltext(text: str) -> str:
    """Drops the bibliography and citation marks, which Saffron would take for topics."""
    headings = list(_REFERENCES_HEADING.finditer(text))
    body = text[: headings[-1].start()] if headings else text
    return _CITATION_NOISE.sub(" ", body)[:MAX_TEXT_CHARS]


def _author_name(name: str) -> str | None:
    """One spelling of a cited author, "Given Surname", or None for "et al." and the like."""
    name = _ET_AL.sub("", " ".join(name.split())).strip(" ,")
    if "," in name:
        surname, given = name.split(",", 1)
        name = f"{given.strip()} {surname.strip()}".strip()
    if not name or _NOT_A_NAME.match(name) or not any(c.isalpha() for c in name):
        return None
    return name


def _author_key(name: str) -> tuple[str, str]:
    """Surname and first initial, so "A. Vaswani" and "Ashish Vaswani" match."""
    words = [word for word in re.split(r"[\s.]+", name) if any(c.isalpha() for c in word)]
    return words[-1].lower(), words[0][0].lower() if len(words) > 1 else ""


def canonical_authors(references: list[Mapping[str, Any]]) -> list[list[str]]:
    """The authors of each reference, one spelling per person across the paper.

    Saffron treats "A. Vaswani" and "Ashish Vaswani" as two people, so each person
    takes their longest spelling. A bare surname joins the only person who has it.
    """
    spellings: dict[tuple[str, str], str] = {}
    keyed: list[list[tuple[str, str]]] = []
    for raw in references:
        keys = []
        for author in raw.get("authors") or []:
            name = _author_name(str(author))
            if name is None:
                continue
            key = _author_key(name)
            keys.append(key)
            if len(name) > len(spellings.get(key, "")):
                spellings[key] = name
        keyed.append(keys)

    initials_of: dict[str, list[tuple[str, str]]] = {}
    for key in spellings:
        if key[1]:
            initials_of.setdefault(key[0], []).append(key)

    def resolve(key: tuple[str, str]) -> tuple[str, str]:
        full = initials_of.get(key[0], [])
        return full[0] if not key[1] and len(full) == 1 else key

    return [list(dict.fromkeys(spellings[resolve(key)] for key in keys)) for keys in keyed]


async def _stop(process: asyncio.subprocess.Process) -> None:
    """Stops a process and its children. Maven and the JVM run as children."""
    if process.returncode is not None:
        return
    if os.name == "nt":
        subprocess.run(
            ["taskkill", "/T", "/F", "/PID", str(process.pid)],
            capture_output=True,
            check=False,
        )
    else:
        process.kill()
    await process.wait()


def _text_of_pdf(content: bytes) -> str:
    reader = PdfReader(BytesIO(content))
    parts: list[str] = []
    size = 0
    for page in reader.pages:
        text = page.extract_text() or ""
        parts.append(text)
        size += len(text)
        if size >= MAX_PDF_CHARS:
            break
    return "\n".join(parts)


class Steps:
    def __init__(self, settings: Settings) -> None:
        self._settings = settings

    def _job_dir(self, analysis_id: str) -> Path:
        path = self._settings.work_dir / analysis_id
        path.mkdir(parents=True, exist_ok=True)
        return path

    async def paper_metadata(self, analysis_id: str) -> dict[str, Any]:
        """Title and authors from arXiv. The job can go on without them."""
        return await asyncio.to_thread(self._arxiv_metadata, analysis_id)

    def _arxiv_metadata(self, arxiv_id: str) -> dict[str, Any]:
        try:
            response = requests.get(
                "https://export.arxiv.org/api/query",
                params={"id_list": arxiv_id},
                timeout=TIMEOUT_SECONDS,
            )
            response.raise_for_status()
            entry = ElementTree.fromstring(response.content).find("atom:entry", _ATOM)
        except (requests.RequestException, ElementTree.ParseError) as error:
            logger.warning("No arXiv metadata for %s: %s", arxiv_id, error)
            return {}
        title = entry.findtext("atom:title", default="", namespaces=_ATOM) if entry is not None else ""
        if not title:
            return {}
        return {
            "paperTitle": " ".join(title.split()),
            "paperAuthors": [
                name.text
                for name in entry.findall("atom:author/atom:name", _ATOM)
                if name.text
            ],
        }

    async def check_references(
        self,
        analysis_id: str,
        ai_assisted: bool,
        on_event: Callable[[dict[str, Any]], None],
    ) -> dict[str, Any]:
        """Runs RefChecker. Keeps the result, so a retry does not pay for it twice."""
        job_dir = self._job_dir(analysis_id)
        provider = self._settings.llm_provider if ai_assisted else None
        result_file = job_dir / f"refchecker-{'ai' if provider else 'plain'}.json"
        if result_file.exists():
            return json.loads(result_file.read_text(encoding="utf-8"))

        partial = result_file.with_suffix(".partial")
        command = [
            sys.executable,
            "-m",
            "orchestrator.refchecker_worker",
            "--paper",
            analysis_id,
            "--result",
            str(partial),
        ]
        if provider:
            command += ["--llm-provider", provider, "--hallucinations"]
            if self._settings.llm_model:
                command += ["--llm-model", self._settings.llm_model]

        with (job_dir / "refchecker.log").open("ab") as log:
            process = await asyncio.create_subprocess_exec(
                *command,
                cwd=job_dir,
                env={**os.environ, "PYTHONPATH": str(BACKEND_DIR), "PYTHONUTF8": "1"},
                stdout=asyncio.subprocess.PIPE,
                stderr=log,
                limit=1 << 20,
            )
            try:
                async for raw in process.stdout:
                    line = raw.decode("utf-8", "replace").strip()
                    if line.startswith(EVENT_PREFIX):
                        on_event(json.loads(line[len(EVENT_PREFIX) :]))
                code = await process.wait()
            finally:
                await _stop(process)
        if code != 0 or not partial.exists():
            raise StepError("Couldn't read this paper's references.")
        partial.replace(result_file)
        return json.loads(result_file.read_text(encoding="utf-8"))

    async def collect_texts(
        self,
        references: list[Mapping[str, Any]],
        on_progress: Callable[[int], None],
    ) -> list[dict[str, Any]]:
        """Finds the best text of each raw reference, one corpus document each.

        Full text first, then the abstract, then the title with the sentences that
        cite it. A fabricated reference has only the last, and still gets a topic.
        Each document also names the reference's authors, for Saffron's author links.
        """
        authors_of = canonical_authors(references)

        def collect() -> list[dict[str, Any]]:
            documents = []
            self._last_arxiv_call = 0.0
            for position, raw in enumerate(references, 1):
                enrichment = raw.get("enrichment") or {}
                arxiv_id = arxiv_id_of(raw)
                title = raw.get("title") or ""
                if title.startswith("http") and arxiv_id:
                    self._respect_arxiv_limit()
                    title = self._arxiv_metadata(arxiv_id).get("paperTitle") or title

                text = ""
                if arxiv_id:
                    self._respect_arxiv_limit()
                    text = self._pdf_text(f"https://arxiv.org/pdf/{arxiv_id}")
                if not text and enrichment.get("oa_pdf_url"):
                    text = self._pdf_text(enrichment["oa_pdf_url"])
                source = "fulltext" if text else ""
                if not text and enrichment.get("abstract"):
                    text, source = clean_fulltext(enrichment["abstract"]), "abstract"
                if not text:
                    text, source = clean_fulltext(raw.get("citation_context") or ""), "citation"

                documents.append(
                    {
                        "id": f"ref-{position:03d}",
                        "name": title or f"Reference {position}",
                        "contents": ". ".join(part for part in (title, text) if part) or "Untitled",
                        "mime_type": "text/plain",
                        "authors": authors_of[position - 1],
                        "textSource": source,
                    }
                )
                on_progress(position)
            return documents

        return await asyncio.to_thread(collect)

    def _respect_arxiv_limit(self) -> None:
        wait = self._settings.arxiv_delay_seconds - (time.monotonic() - self._last_arxiv_call)
        if wait > 0:
            time.sleep(wait)
        self._last_arxiv_call = time.monotonic()

    def _pdf_text(self, url: str) -> str:
        try:
            response = requests.get(url, timeout=TIMEOUT_SECONDS)
            response.raise_for_status()
            return clean_fulltext(_text_of_pdf(response.content))
        except Exception as error:  # A broken PDF only costs this reference its full text.
            logger.warning("No full text at %s: %s", url, error)
            return ""

    async def extract_topics(
        self,
        analysis_id: str,
        documents: list[dict[str, Any]],
    ) -> SaffronOutput:
        """Runs Saffron and reads what it wrote.

        Without doc-terms and the taxonomy there are no topics, so the step fails.
        The other files only add to the topics, and a missing one is left empty.
        """
        command = self._settings.saffron_command
        if not command:
            raise StepError("Topic extraction isn't set up on the server.")

        job_dir = self._job_dir(analysis_id)
        output = job_dir / "saffron"
        output.mkdir(exist_ok=True)
        corpus = job_dir / "corpus.json"
        corpus.write_text(json.dumps(saffron_corpus(documents), ensure_ascii=False), encoding="utf-8")
        with (job_dir / "saffron.log").open("ab") as log:
            process = await asyncio.create_subprocess_shell(
                command.format(corpus=corpus, output=output, config=self._settings.saffron_config),
                cwd=job_dir,
                stdout=log,
                stderr=asyncio.subprocess.STDOUT,
            )
            try:
                code = await asyncio.wait_for(process.wait(), self._settings.saffron_timeout_seconds)
            except TimeoutError as error:
                raise StepError("Topic extraction took too long.") from error
            finally:
                await _stop(process)

        doc_terms = output / "doc-terms.json"
        taxonomy = output / "taxonomy.json"
        if code != 0 or not doc_terms.exists() or not taxonomy.exists():
            raise StepError("Couldn't extract topics.")
        return SaffronOutput(
            doc_terms=json.loads(doc_terms.read_text(encoding="utf-8")),
            taxonomy=json.loads(taxonomy.read_text(encoding="utf-8")),
            terms=_optional_list(output / "terms.json"),
            term_sim=_optional_list(output / "term-sim.json"),
            author_terms=_optional_list(output / "author-terms.json"),
            author_sim=_optional_list(output / "author-sim.json"),
        )


def saffron_corpus(documents: list[Mapping[str, Any]]) -> dict[str, Any]:
    """The corpus file Saffron reads: text and authors, none of our own fields."""
    return {
        "documents": [
            {
                **{key: doc[key] for key in ("id", "name", "contents", "mime_type")},
                "authors": [{"id": name, "name": name} for name in doc.get("authors") or []],
            }
            for doc in documents
        ]
    }


def _optional_list(path: Path) -> list[dict[str, Any]]:
    try:
        value = json.loads(path.read_text(encoding="utf-8"))
    except FileNotFoundError:
        return []
    except (OSError, ValueError) as error:
        logger.warning("Ignoring %s: %s", path.name, error)
        return []
    return value if isinstance(value, list) else []
