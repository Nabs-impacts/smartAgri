from typing import Literal

from pydantic import BaseModel

SeasonType = Literal["rainy", "dry"]


class StatsCrop(BaseModel):
    id: int
    code: str
    name_fr: str


class StatsRegion(BaseModel):
    id: int
    name_fr: str


class YieldCell(BaseModel):
    crop: StatsCrop
    region: StatsRegion
    season_year: int
    season_type: SeasonType
    masked: bool
    cycles: int | None = None
    farmers: int | None = None
    avg_yield_kg_per_ha: float | None = None
    min_yield_kg_per_ha: float | None = None
    max_yield_kg_per_ha: float | None = None


class YieldsResponse(BaseModel):
    items: list[YieldCell]


class RegionAdoption(BaseModel):
    region: StatsRegion
    masked: bool
    users: int | None = None
    plots: int | None = None


class OverviewResponse(BaseModel):
    active_users_30d: int
    diagnostics_30d: int
    tracked_area_ha: float
    adoption: list[RegionAdoption]
