"""Signs report uploads to Cloudinary, so the secret stays on this machine.

Each signature names the full public ID, reports/{uid}/{file}, with the uid taken
from the caller's Firebase token. A user cannot write into another user's folder.
"""

from __future__ import annotations

import hashlib
import os
import time
from dataclasses import dataclass

_ENV = ("CLOUDINARY_CLOUD_NAME", "CLOUDINARY_API_KEY", "CLOUDINARY_API_SECRET")


@dataclass(frozen=True)
class CloudinarySigner:
    cloud_name: str
    api_key: str
    api_secret: str

    @classmethod
    def from_env(cls) -> "CloudinarySigner | None":
        values = [os.environ.get(name) for name in _ENV]
        return cls(*values) if all(values) else None

    def sign(self, uid: str, file_name: str, now: float | None = None) -> dict:
        public_id = f"reports/{uid}/{file_name}"
        timestamp = str(int(time.time() if now is None else now))
        # Cloudinary's scheme: the signed parameters sorted by name, joined like a
        # query string without encoding, then the secret, hashed with SHA-1.
        payload = f"public_id={public_id}&timestamp={timestamp}{self.api_secret}"
        return {
            # Raw keeps the PDF as is; the image type would treat it as an image.
            "uploadUrl": f"https://api.cloudinary.com/v1_1/{self.cloud_name}/raw/upload",
            "fields": {
                "api_key": self.api_key,
                "public_id": public_id,
                "timestamp": timestamp,
                "signature": hashlib.sha1(payload.encode("utf-8")).hexdigest(),
            },
        }
