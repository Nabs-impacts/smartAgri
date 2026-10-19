from typing import Any

from pydantic import BaseModel, ConfigDict, Field


class CropResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    code: str
    name_fr: str
    name_ha: str | None = None
    name_dje: str | None = None
    category: str
    cycle_days: int | None = None


class DiagnosisLabelResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    code: str
    kind: str
    name_fr: str
    name_ha: str | None = None
    name_dje: str | None = None
    description: str | None = None
    guideline: dict[str, Any] | None = None
    crop_ids: list[int] = Field(default_factory=list)


class AdminAreaResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    parent_id: int | None = None
    level: str
    name: str
    code: str
    geom: dict[str, Any] | None = None


class PlanResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    code: str
    name: str
    audience: str
    billing_model: str
    interval: str | None = None
    price_xof: int
    quotas: dict[str, Any]
    features: dict[str, Any]
    is_active: bool
