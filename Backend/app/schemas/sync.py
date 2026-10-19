import uuid
from datetime import date, datetime
from decimal import Decimal
from typing import Any, Literal

from pydantic import BaseModel, Field

SyncEntity = Literal["farm", "plot", "crop_cycle", "farm_activity", "harvest"]
SyncOp = Literal["upsert", "delete"]
SyncStatus = Literal["applied", "conflict", "rejected"]
CycleStatus = Literal["planned", "growing", "harvested", "failed"]
ActivityType = Literal[
    "sowing", "fertilizing", "irrigation", "weeding", "pesticide", "harvest", "other"
]
HarvestQuality = Literal["A", "B", "C"]


class SyncChange(BaseModel):
    entity: SyncEntity
    op: SyncOp
    id: uuid.UUID
    data: dict[str, Any] = Field(default_factory=dict)
    updated_at: datetime


class SyncPushRequest(BaseModel):
    changes: list[SyncChange] = Field(default_factory=list, max_length=200)


class SyncResult(BaseModel):
    id: uuid.UUID
    entity: SyncEntity
    status: SyncStatus
    server_updated_at: datetime | None = None
    error: str | None = None


class SyncPushResponse(BaseModel):
    results: list[SyncResult]


class SyncChangeItem(BaseModel):
    entity: SyncEntity
    id: uuid.UUID
    data: dict[str, Any]
    updated_at: datetime
    deleted_at: datetime | None = None


class SyncPullResponse(BaseModel):
    changes: list[SyncChangeItem]
    next_cursor: str | None = None
    has_more: bool


class FarmSyncData(BaseModel):
    name: str = Field(min_length=1)
    village: str | None = None
    admin_area_id: int | None = None
    location: dict[str, Any] | None = None


class PlotSyncData(BaseModel):
    farm_id: uuid.UUID
    name: str = Field(min_length=1)
    area_ha: Decimal | None = Field(default=None, gt=Decimal("0"), le=Decimal("10000"))
    geom: dict[str, Any] | None = None
    soil_type: Literal["sandy", "loam", "clay", "laterite", "other"] | None = None
    irrigation: Literal["rainfed", "drip", "gravity", "well", "other"] | None = None


class CropCycleSyncData(BaseModel):
    plot_id: uuid.UUID
    crop_id: int
    variety: str | None = None
    season: str | None = None
    sowing_date: date | None = None
    expected_harvest_date: date | None = None
    harvest_date: date | None = None
    status: CycleStatus = "planned"
    notes: str | None = None


class FarmActivitySyncData(BaseModel):
    crop_cycle_id: uuid.UUID
    type: ActivityType
    performed_on: date
    product_name: str | None = None
    quantity: Decimal | None = Field(default=None, ge=Decimal("0"))
    unit: str | None = None
    cost_xof: int | None = Field(default=None, ge=0)
    notes: str | None = None


class HarvestSyncData(BaseModel):
    crop_cycle_id: uuid.UUID
    harvested_on: date
    quantity_kg: Decimal = Field(ge=Decimal("0"))
    quality: HarvestQuality | None = None
    sold_kg: Decimal = Field(default=Decimal("0"), ge=Decimal("0"))
    avg_price_xof_per_kg: Decimal | None = Field(default=None, ge=Decimal("0"))
