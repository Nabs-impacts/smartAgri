import uuid

from fastapi import APIRouter, Depends, Request, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.deps import get_current_user
from app.db.models.identity import User
from app.db.session import get_db
from app.schemas.auth import MessageResponse
from app.schemas.user import (
    ConsentCreateRequest,
    ConsentResponse,
    DeviceCreateRequest,
    DeviceResponse,
    PasswordUpdateRequest,
    UserDataExportResponse,
    UserMeResponse,
    UserResponse,
    UserUpdateRequest,
)
from app.services.user_service import user_service

router = APIRouter()


@router.get("/me", response_model=UserMeResponse)
async def get_me(
    current_user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_db),
) -> UserMeResponse:
    return await user_service.get_profile(session, current_user)


@router.get("/me/export", response_model=UserDataExportResponse)
async def export_me(
    current_user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_db),
) -> UserDataExportResponse:
    return await user_service.export_data(session, current_user)


@router.delete("/me", response_model=MessageResponse)
async def delete_me(
    request: Request,
    current_user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_db),
) -> MessageResponse:
    client_ip = request.client.host if request.client else None
    await user_service.delete_account(session, current_user, client_ip)
    return MessageResponse(message="Compte supprimé.")


@router.patch("/me", response_model=UserResponse)
async def update_me(
    payload: UserUpdateRequest,
    current_user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_db),
) -> UserResponse:
    return await user_service.update_profile(session, current_user, payload)


@router.put("/me/password", response_model=MessageResponse)
async def update_password(
    payload: PasswordUpdateRequest,
    current_user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_db),
) -> MessageResponse:
    await user_service.change_password(session, current_user, payload)
    return MessageResponse(message="Mot de passe mis à jour.")


@router.post(
    "/me/devices",
    response_model=DeviceResponse,
    status_code=status.HTTP_201_CREATED,
)
async def create_device(
    payload: DeviceCreateRequest,
    current_user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_db),
) -> DeviceResponse:
    return await user_service.upsert_device(session, current_user, payload)


@router.delete("/me/devices/{device_id}", response_model=MessageResponse)
async def delete_device(
    device_id: uuid.UUID,
    current_user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_db),
) -> MessageResponse:
    await user_service.delete_device(session, current_user, device_id)
    return MessageResponse(message="Appareil supprimé.")


@router.post(
    "/me/consents",
    response_model=ConsentResponse,
    status_code=status.HTTP_201_CREATED,
)
async def create_consent(
    payload: ConsentCreateRequest,
    current_user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_db),
) -> ConsentResponse:
    return await user_service.create_consent(session, current_user, payload)


@router.get("/me/consents", response_model=list[ConsentResponse])
async def list_consents(
    current_user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_db),
) -> list[ConsentResponse]:
    return await user_service.list_consents(session, current_user)
