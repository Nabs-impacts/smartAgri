from fastapi import APIRouter, Depends, Query, Request, Response, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.deps import get_current_user
from app.db.models.identity import User
from app.db.session import get_db
from app.schemas.catalog import (
    AdminAreaResponse,
    CropResponse,
    DiagnosisLabelResponse,
    PlanResponse,
)
from app.services.catalog_service import catalog_service

router = APIRouter()


@router.get("/crops", response_model=list[CropResponse])
async def get_crops(
    request: Request,
    response: Response,
    session: AsyncSession = Depends(get_db),
    _: User = Depends(get_current_user),
) -> list[CropResponse] | Response:
    crops = await catalog_service.list_crops(session)
    etag = catalog_service.compute_etag(crops)

    if_none_match = request.headers.get("if-none-match")
    if if_none_match and if_none_match.strip('"') == etag.strip('"'):
        return Response(status_code=status.HTTP_304_NOT_MODIFIED, headers={"ETag": etag})

    response.headers["ETag"] = etag
    return crops


@router.get("/diagnosis-labels", response_model=list[DiagnosisLabelResponse])
async def get_diagnosis_labels(
    request: Request,
    response: Response,
    crop_id: int | None = Query(default=None),
    session: AsyncSession = Depends(get_db),
    _: User = Depends(get_current_user),
) -> list[DiagnosisLabelResponse] | Response:
    labels = await catalog_service.list_diagnosis_labels(session, crop_id=crop_id)
    etag = catalog_service.compute_etag(labels)

    if_none_match = request.headers.get("if-none-match")
    if if_none_match and if_none_match.strip('"') == etag.strip('"'):
        return Response(status_code=status.HTTP_304_NOT_MODIFIED, headers={"ETag": etag})

    response.headers["ETag"] = etag
    return labels


@router.get("/admin-areas", response_model=list[AdminAreaResponse])
async def get_admin_areas(
    parent_id: int | None = Query(default=None),
    level: str | None = Query(default=None),
    include_geom: bool = Query(default=False),
    session: AsyncSession = Depends(get_db),
    _: User = Depends(get_current_user),
) -> list[AdminAreaResponse]:
    return await catalog_service.list_admin_areas(
        session=session,
        parent_id=parent_id,
        level=level,
        include_geom=include_geom,
    )


@router.get("/plans", response_model=list[PlanResponse])
async def get_plans(
    audience: str | None = Query(default=None),
    session: AsyncSession = Depends(get_db),
) -> list[PlanResponse]:
    return await catalog_service.list_plans(session, audience=audience)
