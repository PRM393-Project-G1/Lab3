"""Values the app reads from Firestore, named once.

Keep in sync with `docs/architecture.md`, section 7, and the app's
`AnalysisStatus.parse`.
"""

from __future__ import annotations

QUEUED = "queued"
PROCESSING = "processing"
DONE = "done"
FAILED = "failed"
CANCELLED = "cancelled"

# The backend still owes a result.
RUNNING = (QUEUED, PROCESSING)

# The push and the inbox item sent when a paper is done.
DONE_TITLE = "Analysis done"
DONE_TYPE = "analysis_done"
