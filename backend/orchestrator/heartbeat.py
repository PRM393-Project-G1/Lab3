"""Tells the admin web which background processes are alive.

Each process writes `workerStatus/{name}` about once a minute. The web treats a
record older than a few minutes as offline, and a clean shutdown says so at once.
At one write a minute, two processes cost under 3,000 of the Spark plan's daily
20,000 writes.
"""

from __future__ import annotations

import asyncio
import logging
from collections.abc import Callable
from datetime import datetime, timezone
from typing import Any

from . import __version__

logger = logging.getLogger(__name__)

WORKER_STATUS = "workerStatus"
INTERVAL_SECONDS = 60.0

Write = Callable[[str, dict[str, Any]], None]


class Heartbeat:
    def __init__(
        self,
        name: str,
        write: Write,
        interval: float = INTERVAL_SECONDS,
        extra: Callable[[], dict[str, Any]] | None = None,
    ) -> None:
        self._name = name
        self._write = write
        self._interval = interval
        self._extra = extra
        self._started = datetime.now(timezone.utc)

    def beat(self) -> None:
        fields = {"state": "running", "version": __version__, "startedAt": self._started,
                  "intervalSeconds": self._interval}
        if self._extra:
            fields.update(self._extra())
        self._write(self._name, fields)

    async def run(self, stop: asyncio.Event) -> None:
        try:
            while not stop.is_set():
                try:
                    await asyncio.to_thread(self.beat)
                except Exception:
                    logger.warning("Could not write the %s heartbeat", self._name, exc_info=True)
                try:
                    await asyncio.wait_for(stop.wait(), timeout=self._interval)
                except TimeoutError:
                    pass
        finally:
            try:
                await asyncio.to_thread(self._write, self._name, {"state": "stopped"})
            except Exception:
                logger.warning("Could not mark %s as stopped", self._name, exc_info=True)
