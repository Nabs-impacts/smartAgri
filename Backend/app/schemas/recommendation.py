import uuid
from datetime import datetime
from typing import Any

from pydantic import BaseModel, Field


class RecommendationResponse(BaseModel):
    id: uuid.UUID
    diagnostic_id: uuid.UUID | None = None
    plot_id: uuid.UUID | None = None
    crop_cycle_id: uuid.UUID | None = None
    source: str
    language: str
    title: str
    body: str
    steps: list[Any] | None = None
    citations: list[Any] | None = None
    status: str
    validated_by: uuid.UUID | None = None
    created_at: datetime


class RecommendationFeedbackRequest(BaseModel):
    helpful: bool
    applied: bool | None = None
    comment: str | None = Field(default=None, max_length=500)


class RecommendationFeedbackResponse(BaseModel):
    recommendation_id: uuid.UUID
    user_id: uuid.UUID
    helpful: bool | None = None
    applied: bool | None = None
    comment: str | None = None
    created_at: datetime
