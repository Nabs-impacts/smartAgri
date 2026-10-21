import uuid
from datetime import datetime
from decimal import Decimal
from typing import Any, Literal

from pydantic import BaseModel, Field, model_validator

from app.schemas.recommendation import RecommendationResponse

DiagnosticStatus = Literal[
    "pending", "processing", "done", "needs_review", "failed"
]
DiagnosticSource = Literal["on_device", "server"]


class OnDeviceResult(BaseModel):
    label_code: str
    confidence: float = Field(ge=0, le=1)


class DiagnosticCreateRequest(BaseModel):
    id: uuid.UUID | None = None
    media_ids: list[uuid.UUID] = Field(min_length=1, max_length=6)
    crop_id: int | None = None
    plot_id: uuid.UUID | None = None
    crop_cycle_id: uuid.UUID | None = None
    user_note: str | None = Field(default=None, max_length=1000)
    lat: float | None = Field(default=None, ge=-90, le=90)
    lng: float | None = Field(default=None, ge=-180, le=180)
    source: DiagnosticSource | None = None
    on_device_result: OnDeviceResult | None = None

    @model_validator(mode="after")
    def _validate_consistency(self) -> "DiagnosticCreateRequest":
        if len(set(self.media_ids)) != len(self.media_ids):
            raise ValueError("Les identifiants de médias doivent être uniques.")
        if (self.lat is None) != (self.lng is None):
            raise ValueError(
                "La latitude et la longitude doivent être fournies ensemble."
            )
        return self


class DiagnosticLabelBrief(BaseModel):
    id: int
    code: str
    kind: str
    name: str


class DiagnosticPredictionResponse(BaseModel):
    rank: int
    confidence: Decimal
    label: DiagnosticLabelBrief


class DiagnosticMediaResponse(BaseModel):
    id: uuid.UUID
    kind: str
    mime_type: str
    url: str | None = None


class DiagnosticResponse(BaseModel):
    id: uuid.UUID
    status: str
    error: str | None = None
    confidence: Decimal | None = None
    severity: str | None = None
    crop_id: int | None = None
    plot_id: uuid.UUID | None = None
    crop_cycle_id: uuid.UUID | None = None
    source: str
    user_note: str | None = None
    location: dict[str, Any] | None = None
    created_at: datetime
    updated_at: datetime
    completed_at: datetime | None = None


class DiagnosticDetailResponse(DiagnosticResponse):
    media: list[DiagnosticMediaResponse] = Field(default_factory=list)
    predictions: list[DiagnosticPredictionResponse] = Field(default_factory=list)
    on_device_prediction: DiagnosticPredictionResponse | None = None
    recommendation: RecommendationResponse | None = None
