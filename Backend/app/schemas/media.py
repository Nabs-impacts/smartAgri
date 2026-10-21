import uuid
from datetime import datetime
from decimal import Decimal
from typing import Any, Literal

from pydantic import BaseModel, ConfigDict, Field


class MediaUploadRequest(BaseModel):
    id: uuid.UUID | None = None
    kind: Literal["image", "video", "audio"]
    mime_type: str
    size_bytes: int
    sha256: str = Field(pattern=r"^[0-9a-f]{64}$")
    width: int | None = Field(default=None, ge=1)
    height: int | None = Field(default=None, ge=1)
    duration_s: Decimal | None = None
    lat: float | None = Field(default=None, ge=-90, le=90)
    lng: float | None = Field(default=None, ge=-180, le=180)
    captured_at: datetime | None = None
    plot_id: uuid.UUID | None = None
    crop_cycle_id: uuid.UUID | None = None


class MediaResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    owner_id: uuid.UUID
    plot_id: uuid.UUID | None = None
    crop_cycle_id: uuid.UUID | None = None
    kind: str
    mime_type: str
    size_bytes: int
    width: int | None = None
    height: int | None = None
    duration_s: Decimal | None = None
    sha256: str
    location: dict[str, Any] | None = None
    captured_at: datetime | None = None
    upload_status: str
    created_at: datetime
    url: str | None = None


class MediaUploadPart(BaseModel):
    part_number: int
    url: str


class MediaUploadInstructions(BaseModel):
    method: str
    url: str | None = None
    headers: dict[str, str] = Field(default_factory=dict)
    expires_in: int | None = None
    upload_id: str | None = None
    part_size: int | None = None
    parts: list[MediaUploadPart] | None = None


class MediaUploadResponse(BaseModel):
    media: MediaResponse
    upload: MediaUploadInstructions | None = None
    already_uploaded: bool = False


class MediaCompletedPart(BaseModel):
    part_number: int = Field(ge=1)
    etag: str = Field(min_length=1)


class MediaCompleteRequest(BaseModel):
    parts: list[MediaCompletedPart] | None = None
