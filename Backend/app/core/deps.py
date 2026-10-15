import uuid
from collections.abc import Callable
from fastapi import Depends
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from app.core.errors import ForbiddenException, UnauthorizedException
from app.core.security import decode_access_token
from app.db.models.identity import User
from app.db.session import get_db

oauth2_scheme = HTTPBearer(auto_error=False)


async def get_current_user(
    credentials: HTTPAuthorizationCredentials | None = Depends(oauth2_scheme),
    session: AsyncSession = Depends(get_db),
) -> User:
    if not credentials or not credentials.credentials:
        raise UnauthorizedException(message="Authentification requise.")

    payload = decode_access_token(credentials.credentials)
    user_id_str = payload.get("sub")
    if not user_id_str:
        raise UnauthorizedException(message="Jeton invalide.")

    try:
        user_id = uuid.UUID(user_id_str)
    except ValueError:
        raise UnauthorizedException(message="Identifiant utilisateur invalide.")

    result = await session.execute(
        select(User).where(
            User.id == user_id,
            User.is_active.is_(True),
            User.deleted_at.is_(None),
        )
    )
    user = result.scalar_one_or_none()
    if not user:
        raise UnauthorizedException(message="Utilisateur non trouvé ou inactif.")

    return user


async def get_current_active_user(
    user: User = Depends(get_current_user),
) -> User:
    return user


def require_roles(*roles: str) -> Callable:
    async def role_checker(user: User = Depends(get_current_user)) -> User:
        if user.role not in roles and user.role != "super_admin":
            raise ForbiddenException(message="Accès refusé pour ce rôle.")
        return user

    return role_checker


async def get_optional_user(
    credentials: HTTPAuthorizationCredentials | None = Depends(oauth2_scheme),
    session: AsyncSession = Depends(get_db),
) -> User | None:
    if not credentials or not credentials.credentials:
        return None
    try:
        return await get_current_user(credentials=credentials, session=session)
    except Exception:
        return None
