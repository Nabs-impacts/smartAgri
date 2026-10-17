import base64
import json
import uuid
from datetime import datetime

from fastapi import Query
from pydantic import BaseModel


def encode_cursor(dt: datetime, item_id: str | uuid.UUID | int) -> str:
    payload = {
        "t": dt.isoformat(),
        "id": str(item_id),
    }
    raw = json.dumps(payload).encode("utf-8")
    return base64.urlsafe_b64encode(raw).decode("utf-8").rstrip("=")


def decode_cursor(cursor: str) -> tuple[datetime, str]:
    padded = cursor + "=" * (-len(cursor) % 4)
    raw = base64.urlsafe_b64decode(padded.encode("utf-8"))
    payload = json.loads(raw.decode("utf-8"))
    return datetime.fromisoformat(payload["t"]), str(payload["id"])


class PaginationParams:
    def __init__(
        self,
        limit: int = Query(default=20, ge=1, le=100),
        cursor: str | None = Query(default=None),
    ) -> None:
        self.limit = limit
        self.cursor = cursor

    @property
    def decoded_cursor(self) -> tuple[datetime, str] | None:
        if not self.cursor:
            return None
        try:
            return decode_cursor(self.cursor)
        except Exception:
            return None


class PaginatedResponse[T](BaseModel):
    items: list[T]
    next_cursor: str | None = None
