from typing import Literal

from fastapi import APIRouter, Depends, Query
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.deps import require_roles
from app.db.models.identity import User
from app.db.session import get_db
from app.schemas.stats import OverviewResponse, YieldsResponse
from app.services.stats_service import stats_service

router = APIRouter()


@router.get(
    "/yields",
    response_model=YieldsResponse,
    response_model_exclude_none=True,
)
async def get_yields(
    crop_id: int | None = Query(default=None),
    region_id: int | None = Query(default=None),
    season_year: int | None = Query(default=None),
    season_type: Literal["rainy", "dry"] | None = Query(default=None),
    session: AsyncSession = Depends(get_db),
    current_user: User = Depends(
        require_roles("gov_admin", "super_admin")
    ),
) -> YieldsResponse:
    return await stats_service.get_yields(
        session=session,
        crop_id=crop_id,
        region_id=region_id,
        season_year=season_year,
        season_type=season_type,
    )


@router.get(
    "/overview",
    response_model=OverviewResponse,
    response_model_exclude_none=True,
)
async def get_overview(
    session: AsyncSession = Depends(get_db),
    current_user: User = Depends(
        require_roles("gov_admin", "super_admin")
    ),
) -> OverviewResponse:
    return await stats_service.get_overview(session=session)
