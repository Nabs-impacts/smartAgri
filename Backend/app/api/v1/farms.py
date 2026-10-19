import uuid

from fastapi import APIRouter, Depends, Response, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.deps import get_current_user
from app.core.pagination import PaginatedResponse, PaginationParams
from app.db.models.identity import User
from app.db.session import get_db
from app.schemas.farm import (
    FarmCreateRequest,
    FarmResponse,
    FarmUpdateRequest,
    PlotCreateRequest,
    PlotResponse,
    PlotUpdateRequest,
)
from app.services.farm_service import farm_service

router = APIRouter()


@router.get("/farms", response_model=PaginatedResponse[FarmResponse])
async def list_farms(
    pagination: PaginationParams = Depends(),
    session: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
) -> PaginatedResponse[FarmResponse]:
    items, next_cursor = await farm_service.list_farms(
        session=session,
        user_id=current_user.id,
        limit=pagination.limit,
        cursor=pagination.cursor,
    )
    return PaginatedResponse[FarmResponse](items=items, next_cursor=next_cursor)


@router.post("/farms", response_model=FarmResponse)
async def create_farm(
    data: FarmCreateRequest,
    response: Response,
    session: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
) -> FarmResponse:
    farm, is_created = await farm_service.create_farm(
        session=session,
        user=current_user,
        data=data,
    )
    response.status_code = (
        status.HTTP_201_CREATED if is_created else status.HTTP_200_OK
    )
    return farm


@router.get("/farms/{id}", response_model=FarmResponse)
async def get_farm(
    id: uuid.UUID,
    session: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
) -> FarmResponse:
    return await farm_service.get_farm(
        session=session,
        user_id=current_user.id,
        farm_id=id,
    )


@router.patch("/farms/{id}", response_model=FarmResponse)
async def update_farm(
    id: uuid.UUID,
    data: FarmUpdateRequest,
    session: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
) -> FarmResponse:
    return await farm_service.update_farm(
        session=session,
        user_id=current_user.id,
        farm_id=id,
        data=data,
    )


@router.delete("/farms/{id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_farm(
    id: uuid.UUID,
    session: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
) -> None:
    await farm_service.delete_farm(
        session=session,
        user_id=current_user.id,
        farm_id=id,
    )


@router.get("/farms/{id}/plots", response_model=PaginatedResponse[PlotResponse])
async def list_plots(
    id: uuid.UUID,
    pagination: PaginationParams = Depends(),
    session: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
) -> PaginatedResponse[PlotResponse]:
    items, next_cursor = await farm_service.list_plots(
        session=session,
        user_id=current_user.id,
        farm_id=id,
        limit=pagination.limit,
        cursor=pagination.cursor,
    )
    return PaginatedResponse[PlotResponse](items=items, next_cursor=next_cursor)


@router.post("/farms/{id}/plots", response_model=PlotResponse)
async def create_plot(
    id: uuid.UUID,
    data: PlotCreateRequest,
    response: Response,
    session: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
) -> PlotResponse:
    plot, is_created = await farm_service.create_plot(
        session=session,
        user=current_user,
        farm_id=id,
        data=data,
    )
    response.status_code = (
        status.HTTP_201_CREATED if is_created else status.HTTP_200_OK
    )
    return plot


@router.get("/plots/{id}", response_model=PlotResponse)
async def get_plot(
    id: uuid.UUID,
    session: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
) -> PlotResponse:
    return await farm_service.get_plot(
        session=session,
        user_id=current_user.id,
        plot_id=id,
    )


@router.patch("/plots/{id}", response_model=PlotResponse)
async def update_plot(
    id: uuid.UUID,
    data: PlotUpdateRequest,
    session: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
) -> PlotResponse:
    return await farm_service.update_plot(
        session=session,
        user_id=current_user.id,
        plot_id=id,
        data=data,
    )


@router.delete("/plots/{id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_plot(
    id: uuid.UUID,
    session: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
) -> None:
    await farm_service.delete_plot(
        session=session,
        user_id=current_user.id,
        plot_id=id,
    )
