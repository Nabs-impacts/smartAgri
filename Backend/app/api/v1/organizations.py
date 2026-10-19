import uuid

from fastapi import APIRouter, Depends, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.deps import get_current_user
from app.core.pagination import PaginatedResponse, PaginationParams
from app.db.models.identity import User
from app.db.session import get_db
from app.schemas.farm import FarmResponse
from app.schemas.organization import (
    OrganizationCreateRequest,
    OrganizationDashboardResponse,
    OrganizationMemberCreateRequest,
    OrganizationMemberResponse,
    OrganizationResponse,
    OrganizationUpdateRequest,
)
from app.services.organization_service import organization_service

router = APIRouter()


@router.post(
    "/organizations",
    response_model=OrganizationResponse,
    status_code=status.HTTP_201_CREATED,
)
async def create_organization(
    data: OrganizationCreateRequest,
    session: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
) -> OrganizationResponse:
    return await organization_service.create_organization(
        session, current_user, data
    )


@router.get(
    "/organizations",
    response_model=PaginatedResponse[OrganizationResponse],
)
async def list_organizations(
    pagination: PaginationParams = Depends(),
    session: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
) -> PaginatedResponse[OrganizationResponse]:
    items, next_cursor = await organization_service.list_organizations(
        session,
        current_user.id,
        limit=pagination.limit,
        cursor=pagination.cursor,
    )
    return PaginatedResponse[OrganizationResponse](
        items=items, next_cursor=next_cursor
    )


@router.get(
    "/organizations/{id}",
    response_model=OrganizationResponse,
)
async def get_organization(
    id: uuid.UUID,
    session: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
) -> OrganizationResponse:
    return await organization_service.get_organization(
        session, current_user.id, id
    )


@router.patch(
    "/organizations/{id}",
    response_model=OrganizationResponse,
)
async def update_organization(
    id: uuid.UUID,
    data: OrganizationUpdateRequest,
    session: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
) -> OrganizationResponse:
    return await organization_service.update_organization(
        session, current_user.id, id, data
    )


@router.get(
    "/organizations/{id}/members",
    response_model=list[OrganizationMemberResponse],
)
async def list_members(
    id: uuid.UUID,
    session: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
) -> list[OrganizationMemberResponse]:
    return await organization_service.list_members(
        session, current_user.id, id
    )


@router.post(
    "/organizations/{id}/members",
    response_model=OrganizationMemberResponse,
    status_code=status.HTTP_201_CREATED,
)
async def add_member(
    id: uuid.UUID,
    data: OrganizationMemberCreateRequest,
    session: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
) -> OrganizationMemberResponse:
    return await organization_service.add_member(
        session,
        current_user.id,
        id,
        data.phone,
        data.member_role,
    )


@router.delete(
    "/organizations/{id}/members/{user_id}",
    status_code=status.HTTP_204_NO_CONTENT,
)
async def remove_member(
    id: uuid.UUID,
    user_id: uuid.UUID,
    session: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
) -> None:
    await organization_service.remove_member(
        session, current_user.id, id, user_id
    )


@router.get(
    "/organizations/{id}/farms",
    response_model=PaginatedResponse[FarmResponse],
)
async def list_member_farms(
    id: uuid.UUID,
    pagination: PaginationParams = Depends(),
    session: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
) -> PaginatedResponse[FarmResponse]:
    items, next_cursor = await organization_service.list_member_farms(
        session,
        current_user.id,
        id,
        limit=pagination.limit,
        cursor=pagination.cursor,
    )
    return PaginatedResponse[FarmResponse](
        items=items, next_cursor=next_cursor
    )


@router.get(
    "/organizations/{id}/dashboard",
    response_model=OrganizationDashboardResponse,
)
async def organization_dashboard(
    id: uuid.UUID,
    session: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
) -> OrganizationDashboardResponse:
    return await organization_service.dashboard(session, current_user.id, id)
