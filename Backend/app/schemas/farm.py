import uuid
from datetime import datetime
from decimal import Decimal
from typing import Any, Literal

from pydantic import BaseModel, ConfigDict


class FarmCreateRequest(BaseModel):
    id: uuid.UUID | None = None
    name: str
    village: str | None = None
    admin_area_id: int | None = None
    location: dict[str, Any] | None = None


class FarmUpdateRequest(BaseModel):
    name: str | None = None
    village: str | None = None
    admin_area_id: int | None = None
    location: dict[str, Any] | None = None


class FarmResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    owner_id: uuid.UUID
    organization_id: uuid.UUID | None = None
    name: str
    village: str | None = None
    admin_area_id: int | None = None
    location: dict[str, Any] | None = None
    created_at: datetime
    updated_at: datetime


class PlotCreateRequest(BaseModel):
    id: uuid.UUID | None = None
    name: str
    area_ha: Decimal | None = None
    geom: dict[str, Any] | None = None
    soil_type: Literal["sandy", "loam", "clay", "laterite", "other"] | None = None
    irrigation: Literal["rainfed", "drip", "gravity", "well", "other"] | None = None


class PlotUpdateRequest(BaseModel):
    name: str | None = None
    area_ha: Decimal | None = None
    geom: dict[str, Any] | None = None
    soil_type: Literal["sandy", "loam", "clay", "laterite", "other"] | None = None
    irrigation: Literal["rainfed", "drip", "gravity", "well", "other"] | None = None


class PlotResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    farm_id: uuid.UUID
    name: str
    area_ha: Decimal | None = None
    geom: dict[str, Any] | None = None
    soil_type: str | None = None
    irrigation: str | None = None
    created_at: datetime
    updated_at: datetime
