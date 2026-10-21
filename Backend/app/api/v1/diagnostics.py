import uuid
from datetime import date

from fastapi import APIRouter, Depends, Query, Response, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.deps import get_current_user
from app.core.idempotency import IdempotencyContext, idempotency_dependency
from app.core.pagination import PaginatedResponse, PaginationParams
from app.db.models.identity import User
from app.db.session import get_db
from app.schemas.diagnostic import (
    DiagnosticCreateRequest,
    DiagnosticDetailResponse,
    DiagnosticResponse,
    DiagnosticStatus,
)
from app.services.diagnostic_api_service import diagnostic_api_service

router = APIRouter()


@router.post("", response_model=DiagnosticResponse)
async def create_diagnostic(
    data: DiagnosticCreateRequest,
    response: Response,
    session: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
    idempotency: IdempotencyContext | None = Depends(
        idempotency_dependency(required=False)
    ),
) -> DiagnosticResponse:
    result, created = await diagnostic_api_service.create_diagnostic(
        session=session,
        user=current_user,
        data=data,
    )
    response.status_code = (
        status.HTTP_202_ACCEPTED if created else status.HTTP_200_OK
    )
    if idempotency is not None:
        await idempotency.save(
            response.status_code,
            result.model_dump(mode="json"),
        )
    return result


@router.get("", response_model=PaginatedResponse[DiagnosticResponse])
async def list_diagnostics(
    pagination: PaginationParams = Depends(),
    plot_id: uuid.UUID | None = Query(default=None),
    crop_id: int | None = Query(default=None),
    status_filter: DiagnosticStatus | None = Query(default=None, alias="status"),
    from_date: date | None = Query(default=None, alias="from"),
    to_date: date | None = Query(default=None, alias="to"),
    session: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
) -> PaginatedResponse[DiagnosticResponse]:
    items, next_cursor = await diagnostic_api_service.list_diagnostics(
        session=session,
        user_id=current_user.id,
        plot_id=plot_id,
        crop_id=crop_id,
        status=status_filter,
        from_date=from_date,
        to_date=to_date,
        limit=pagination.limit,
        cursor=pagination.cursor,
    )
    return PaginatedResponse[DiagnosticResponse](
        items=items, next_cursor=next_cursor
    )


@router.get("/{id}", response_model=DiagnosticDetailResponse)
async def get_diagnostic(
    id: uuid.UUID,
    session: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
) -> DiagnosticDetailResponse:
    return await diagnostic_api_service.get_diagnostic(
        session=session,
        user=current_user,
        diagnostic_id=id,
    )


@router.post("/{id}/retry", response_model=DiagnosticResponse)
async def retry_diagnostic(
    id: uuid.UUID,
    session: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
) -> DiagnosticResponse:
    return await diagnostic_api_service.retry_diagnostic(
        session=session,
        user_id=current_user.id,
        diagnostic_id=id,
    )


@router.delete("/{id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_diagnostic(
    id: uuid.UUID,
    session: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
) -> None:
    await diagnostic_api_service.delete_diagnostic(
        session=session,
        user_id=current_user.id,
        diagnostic_id=id,
    )
