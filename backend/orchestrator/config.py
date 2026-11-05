"""Settings, read from the environment so no key ends up in the repository."""

from __future__ import annotations

import os
from dataclasses import dataclass
from pathlib import Path

BACKEND_DIR = Path(__file__).resolve().parent.parent


@dataclass(frozen=True)
class Settings:
    work_dir: Path
    llm_provider: str | None
    llm_model: str | None
    semantic_scholar_key: str | None
    saffron_command: str | None
    saffron_config: Path
    saffron_timeout_seconds: int
    arxiv_delay_seconds: float

    @classmethod
    def from_env(cls) -> "Settings":
        return cls(
            work_dir=Path(os.environ.get("REALTRON_WORK_DIR", BACKEND_DIR / "work")),
            llm_provider=os.environ.get("REFCHECKER_LLM_PROVIDER") or None,
            llm_model=os.environ.get("REFCHECKER_LLM_MODEL") or None,
            semantic_scholar_key=os.environ.get("SEMANTIC_SCHOLAR_API_KEY") or None,
            saffron_command=os.environ.get("SAFFRON_COMMAND") or None,
            saffron_config=Path(
                os.environ.get("SAFFRON_CONFIG", BACKEND_DIR / "saffron-config.json")
            ),
            saffron_timeout_seconds=int(os.environ.get("SAFFRON_TIMEOUT_SECONDS", 1800)),
            arxiv_delay_seconds=float(os.environ.get("ARXIV_DELAY_SECONDS", 3)),
        )
