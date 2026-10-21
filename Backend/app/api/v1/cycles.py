import uuid

from fastapi import APIRouter, Depends, Response, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.deps import get_current_user
from app.core.pagination import PaginatedResponse, PaginationParams
from app.db.models.identity import User
from app.db.session import get_db
from app.schemas.cycle import (
    ActivityCreateRequest,
    ActivityResponse,
    ActivityUpdateRequest,
    CycleCreateRequest,
    CycleResponse,
    CycleSummaryResponse,
    CycleUpdateRequest,
    HarvestCreateRequest,
    HarvestResponse,
    TimelineItem,
)
from app.services.cycle_service import cycle_service

router = APIRouter()


@router.get("/plots/{id}/cycles", response_model=PaginatedResponse[CycleResponse])
async def list_cycles(
    id: uuid.UUID,
    pagination: PaginationParams = Depends(),
    session: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
) -> PaginatedResponse[CycleResponse]:
    items, next_cursor = await cycle_service.list_cycles(
        session=session,
        user_id=current_user.id,
        plot_id=id,
        limit=pagination.limit,
        cursor=pagination.cursor,
    )
    return PaginatedResponse[CycleResponse](items=items, next_cursor=next_cursor)


@router.post("/plots/{id}/cycles", response_model=CycleResponse)
async def create_cycle(
    id: uuid.UUID,
    data: CycleCreateRequest,
    response: Response,
    session: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
) -> CycleResponse:
    cycle, is_created = await cycle_service.create_cycle(
        session=session,
        user=current_user,
        plot_id=id,
        data=data,
    )
    response.status_code = (
        status.HTTP_201_CREATED if is_created else status.HTTP_200_OK
    )
    return cycle


@router.get("/cycles/{id}", response_model=CycleResponse)
async def get_cycle(
    id: uuid.UUID,
    session: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
) -> CycleResponse:
    return await cycle_service.get_cycle(
        session=session,
        user_id=current_user.id,
        cycle_id=id,
    )


@router.patch("/cycles/{id}", response_model=CycleResponse)
async def update_cycle(
    id: uuid.UUID,
    data: CycleUpdateRequest,
    session: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
) -> CycleResponse:
    return await cycle_service.update_cycle(
        session=session,
        user_id=current_user.id,
        cycle_id=id,
        data=data,
    )


@router.get(
    "/cycles/{id}/activities", response_model=PaginatedResponse[ActivityResponse]
)
async def list_activities(
    id: uuid.UUID,
    pagination: PaginationParams = Depends(),
    session: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
) -> PaginatedResponse[ActivityResponse]:
    items, next_cursor = await cycle_service.list_activities(
        session=session,
        user_id=current_user.id,
        cycle_id=id,
        limit=pagination.limit,
        cursor=pagination.cursor,
    )
    return PaginatedResponse[ActivityResponse](items=items, next_cursor=next_cursor)


@router.post("/cycles/{id}/activities", response_model=ActivityResponse)
async def create_activity(
    id: uuid.UUID,
    data: ActivityCreateRequest,
    response: Response,
    session: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
) -> ActivityResponse:
    activity, is_created = await cycle_service.create_activity(
        session=session,
        user=current_user,
        cycle_id=id,
        data=data,
    )
    response.status_code = (
        status.HTTP_201_CREATED if is_created else status.HTTP_200_OK
    )
    return activity


@router.patch("/activities/{id}", response_model=ActivityResponse)
async def update_activity(
    id: uuid.UUID,
    data: ActivityUpdateRequest,
    session: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
) -> ActivityResponse:
    return await cycle_service.update_activity(
        session=session,
        user_id=current_user.id,
        activity_id=id,
        data=data,
    )


@router.delete("/activities/{id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_activity(
    id: uuid.UUID,
    session: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
) -> None:
    await cycle_service.delete_activity(
        session=session,
        user_id=current_user.id,
        activity_id=id,
    )


@router.post("/cycles/{id}/harvests", response_model=HarvestResponse)
async def create_harvest(
    id: uuid.UUID,
    data: HarvestCreateRequest,
    response: Response,
    session: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
) -> HarvestResponse:
    harvest, is_created = await cycle_service.create_harvest(
        session=session,
        user=current_user,
        cycle_id=id,
        data=data,
    )
    response.status_code = (
        status.HTTP_201_CREATED if is_created else status.HTTP_200_OK
    )
    return harvest


@router.get("/cycles/{id}/summary", response_model=CycleSummaryResponse)
async def get_summary(
    id: uuid.UUID,
    session: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
) -> CycleSummaryResponse:
    return await cycle_service.get_summary(
        session=session,
        user_id=current_user.id,
        cycle_id=id,
    )


@router.get("/plots/{id}/timeline", response_model=PaginatedResponse[TimelineItem])
async def get_timeline(
    id: uuid.UUID,
    pagination: PaginationParams = Depends(),
    session: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
) -> PaginatedResponse[TimelineItem]:
    items, next_cursor = await cycle_service.get_timeline(
        session=session,
        user_id=current_user.id,
        plot_id=id,
        language=current_user.language,
        limit=pagination.limit,
        cursor=pagination.cursor,
    )
    return PaginatedResponse[TimelineItem](items=items, next_cursor=next_cursor)
