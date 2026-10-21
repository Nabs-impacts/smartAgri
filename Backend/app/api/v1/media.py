import uuid

from fastapi import APIRouter, Depends, Response, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.deps import get_current_user
from app.core.idempotency import IdempotencyContext, idempotency_dependency
from app.db.models.identity import User
from app.db.session import get_db
from app.schemas.media import (
    MediaCompleteRequest,
    MediaResponse,
    MediaUploadRequest,
    MediaUploadResponse,
)
from app.services.media_service import media_service

router = APIRouter()


@router.post("/uploads", response_model=MediaUploadResponse)
async def request_upload(
    data: MediaUploadRequest,
    response: Response,
    session: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
    idempotency: IdempotencyContext | None = Depends(
        idempotency_dependency(required=False)
    ),
) -> MediaUploadResponse:
    result, created = await media_service.request_upload(
        session=session,
        user=current_user,
        data=data,
    )
    response.status_code = (
        status.HTTP_201_CREATED if created else status.HTTP_200_OK
    )
    if idempotency is not None:
        await idempotency.save(
            response.status_code,
            result.model_dump(mode="json"),
        )
    return result


@router.post("/{id}/complete", response_model=MediaResponse)
async def complete_upload(
    id: uuid.UUID,
    data: MediaCompleteRequest,
    session: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
) -> MediaResponse:
    return await media_service.complete_upload(
        session=session,
        user=current_user,
        media_id=id,
        data=data,
    )


@router.get("/{id}", response_model=MediaResponse)
async def get_media(
    id: uuid.UUID,
    session: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
) -> MediaResponse:
    return await media_service.get_media(
        session=session,
        user=current_user,
        media_id=id,
    )


@router.delete("/{id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_media(
    id: uuid.UUID,
    session: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
) -> None:
    await media_service.delete_media(
        session=session,
        user_id=current_user.id,
        media_id=id,
    )
