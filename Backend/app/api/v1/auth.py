from fastapi import APIRouter, Depends, Request, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.deps import get_current_user
from app.core.security import normalize_phone
from app.db.models.identity import User
from app.db.session import get_db
from app.schemas.auth import (
    LoginRequest,
    LogoutRequest,
    MessageResponse,
    OtpRequest,
    OtpRequestResponse,
    OtpVerifyRequest,
    PasswordResetRequest,
    RefreshRequest,
    RegisterRequest,
    RegisterResponse,
    TokenResponse,
)
from app.services.auth_service import auth_service

router = APIRouter()


@router.post(
    "/register",
    status_code=status.HTTP_201_CREATED,
    response_model=RegisterResponse,
)
async def register(
    payload: RegisterRequest,
    session: AsyncSession = Depends(get_db),
) -> RegisterResponse:
    await auth_service.register(session, payload)
    return RegisterResponse(
        message="Compte cree. Un code de verification a ete envoye.",
        phone=normalize_phone(payload.phone),
    )


@router.post(
    "/otp/request",
    status_code=status.HTTP_202_ACCEPTED,
    response_model=OtpRequestResponse,
)
async def request_otp(
    payload: OtpRequest,
    request: Request,
    session: AsyncSession = Depends(get_db),
) -> OtpRequestResponse:
    client_ip = request.client.host if request.client else "unknown"
    await auth_service.request_otp(
        session, payload.phone, payload.purpose, client_ip
    )
    return OtpRequestResponse(
        message="Si le numero est valide, un code de verification sera envoye."
    )


@router.post("/otp/verify", response_model=TokenResponse)
async def verify_otp(
    payload: OtpVerifyRequest,
    session: AsyncSession = Depends(get_db),
) -> TokenResponse:
    return await auth_service.verify_otp_and_login(session, payload)


@router.post("/login", response_model=TokenResponse)
async def login(
    payload: LoginRequest,
    session: AsyncSession = Depends(get_db),
) -> TokenResponse:
    return await auth_service.login_password(session, payload)


@router.post("/refresh", response_model=TokenResponse)
async def refresh(
    payload: RefreshRequest,
    session: AsyncSession = Depends(get_db),
) -> TokenResponse:
    return await auth_service.refresh_token(session, payload.refresh_token)


@router.post("/logout", response_model=MessageResponse)
async def logout(
    payload: LogoutRequest,
    session: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
) -> MessageResponse:
    await auth_service.logout(session, payload.refresh_token)
    return MessageResponse(message="Deconnexion reussie.")


@router.post("/password/reset", response_model=MessageResponse)
async def reset_password(
    payload: PasswordResetRequest,
    session: AsyncSession = Depends(get_db),
) -> MessageResponse:
    await auth_service.reset_password(session, payload)
    return MessageResponse(message="Mot de passe reinitialise.")
