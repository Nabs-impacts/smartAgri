import uuid
from datetime import date, datetime
from decimal import Decimal
from typing import Literal

from pydantic import BaseModel, ConfigDict, Field

CycleStatus = Literal["planned", "growing", "harvested", "failed"]
ActivityType = Literal[
    "sowing", "fertilizing", "irrigation", "weeding", "pesticide", "harvest", "other"
]
HarvestQuality = Literal["A", "B", "C"]


class CycleCreateRequest(BaseModel):
    id: uuid.UUID | None = None
    crop_id: int
    variety: str | None = None
    season: str | None = None
    sowing_date: date | None = None
    expected_harvest_date: date | None = None
    harvest_date: date | None = None
    status: CycleStatus = "planned"
    notes: str | None = None


class CycleUpdateRequest(BaseModel):
    variety: str | None = None
    season: str | None = None
    sowing_date: date | None = None
    expected_harvest_date: date | None = None
    harvest_date: date | None = None
    status: CycleStatus | None = None
    notes: str | None = None


class CycleResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    plot_id: uuid.UUID
    crop_id: int
    variety: str | None = None
    season: str | None = None
    sowing_date: date | None = None
    expected_harvest_date: date | None = None
    harvest_date: date | None = None
    status: str
    notes: str | None = None
    created_at: datetime
    updated_at: datetime


class ActivityCreateRequest(BaseModel):
    id: uuid.UUID | None = None
    type: ActivityType
    performed_on: date
    product_name: str | None = None
    quantity: Decimal | None = Field(default=None, ge=Decimal("0"))
    unit: str | None = None
    cost_xof: int | None = Field(default=None, ge=0)
    notes: str | None = None


class ActivityUpdateRequest(BaseModel):
    type: ActivityType | None = None
    performed_on: date | None = None
    product_name: str | None = None
    quantity: Decimal | None = Field(default=None, ge=Decimal("0"))
    unit: str | None = None
    cost_xof: int | None = Field(default=None, ge=0)
    notes: str | None = None


class ActivityResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    crop_cycle_id: uuid.UUID
    type: str
    performed_on: date
    product_name: str | None = None
    quantity: Decimal | None = None
    unit: str | None = None
    cost_xof: int | None = None
    notes: str | None = None
    created_at: datetime
    updated_at: datetime


class HarvestCreateRequest(BaseModel):
    id: uuid.UUID | None = None
    harvested_on: date
    quantity_kg: Decimal = Field(ge=Decimal("0"))
    quality: HarvestQuality | None = None
    sold_kg: Decimal = Field(default=Decimal("0"), ge=Decimal("0"))
    avg_price_xof_per_kg: Decimal | None = Field(default=None, ge=Decimal("0"))
    close_cycle: bool = False


class HarvestResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    crop_cycle_id: uuid.UUID
    harvested_on: date
    quantity_kg: Decimal
    quality: str | None = None
    sold_kg: Decimal
    avg_price_xof_per_kg: Decimal | None = None
    created_at: datetime
    updated_at: datetime


class CycleComparisonResponse(BaseModel):
    sample_size: int
    average_yield_kg_per_ha: Decimal | None = None


class CycleSummaryResponse(BaseModel):
    cycle_id: uuid.UUID
    area_ha: Decimal | None = None
    total_kg: Decimal
    yield_kg_per_ha: Decimal | None = None
    total_cost_xof: int
    revenue_xof: Decimal
    margin_xof: Decimal
    comparison: CycleComparisonResponse | None = None


class TimelineLabel(BaseModel):
    code: str
    name: str


class TimelineDiagnosticInfo(BaseModel):
    status: str
    top_label: TimelineLabel | None = None
    confidence: Decimal | None = None
    severity: str | None = None


class TimelineItem(BaseModel):
    id: uuid.UUID
    type: Literal["activity", "harvest", "diagnostic"]
    occurred_on: date
    created_at: datetime
    activity: ActivityResponse | None = None
    harvest: HarvestResponse | None = None
    diagnostic: TimelineDiagnosticInfo | None = None
