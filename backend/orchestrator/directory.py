"""The admin web's user list: `users/{uid}` joined with Firebase Auth.

Admins cannot read other users' profiles (they hold device tokens), so the
backend keeps this projection at `adminUserDirectory/{uid}`. It never copies
tokens, only whether a device is registered.
"""

from __future__ import annotations

from dataclasses import dataclass
from datetime import datetime, timezone
from typing import Any

AUTH_FIELDS = ("email", "disabled", "createdAt", "lastSignInAt")


@dataclass(frozen=True)
class Account:
    """The parts of a Firebase Auth record the directory shows."""

    email: str | None = None
    disabled: bool = False
    created_at: datetime | None = None
    last_sign_in_at: datetime | None = None

    @classmethod
    def from_record(cls, record: Any) -> "Account":
        metadata = getattr(record, "user_metadata", None)

        def moment(milliseconds: Any) -> datetime | None:
            return datetime.fromtimestamp(milliseconds / 1000, timezone.utc) if isinstance(milliseconds, (int, float)) else None

        return cls(
            email=record.email if isinstance(getattr(record, "email", None), str) else None,
            disabled=getattr(record, "disabled", False) is True,
            created_at=moment(getattr(metadata, "creation_timestamp", None)),
            last_sign_in_at=moment(getattr(metadata, "last_sign_in_timestamp", None)),
        )


def directory_fields(user: dict[str, Any], account: Account | None, previous: dict[str, Any] | None = None) -> dict[str, Any]:
    """The directory entry for one profile. Without an Auth record, the previous
    Auth fields are kept, so a failed Auth lookup never blanks the list."""
    name, tokens = user.get("displayName"), user.get("fcmTokens")
    fields: dict[str, Any] = {
        "displayName": name if isinstance(name, str) and name.strip() else "Unnamed user",
        "hasDevice": isinstance(tokens, list) and any(isinstance(token, str) and token for token in tokens),
        "role": "admin" if user.get("role") == "admin" else "user",
    }
    if account is not None:
        fields.update(email=account.email, disabled=account.disabled,
                      createdAt=account.created_at, lastSignInAt=account.last_sign_in_at)
    else:
        fields.update({key: (previous or {}).get(key) for key in AUTH_FIELDS})
        fields["disabled"] = fields["disabled"] is True
    return fields


def changed(previous: dict[str, Any] | None, fields: dict[str, Any]) -> bool:
    return any((previous or {}).get(key) != value for key, value in fields.items())
