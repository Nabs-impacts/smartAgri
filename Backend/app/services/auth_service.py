import uuid
from datetime import UTC, datetime, timedelta

from fastapi import BackgroundTasks
from sqlalchemy import delete, select, update
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import settings
from app.core.errors import (
    ConflictException,
    ForbiddenException,
    NotFoundException,
    RateLimitedException,
    UnauthorizedException,
)
from app.core.rate_limit import check_rate_limit, get_redis_client
from app.core.security import (
    create_access_token,
    generate_refresh_token,
    hash_password,
    hash_refresh_token,
    normalize_phone,
    verify_password,
)
from app.db.models.billing import Plan, Subscription
from app.db.models.identity import Device, OtpCode, RefreshToken, User
from app.schemas.auth import (
    DevicePayload,
    LoginRequest,
    OtpVerifyRequest,
    PasswordResetRequest,
    RegisterRequest,
    TokenResponse,
)
from app.schemas.user import UserResponse
from app.services.otp_service import otp_service

_DUMMY_PASSWORD_HASH = hash_password("smartagri-dummy-password-timing")


class AuthService:
    async def register(
        self,
        session: AsyncSession,
        data: RegisterRequest,
        background_tasks: BackgroundTasks,
        client_ip: str,
    ) -> None:
        allowed = await check_rate_limit(
            f"rl:register:ip:{client_ip}",
            settings.REGISTER_REQUESTS_PER_IP_WINDOW,
            settings.OTP_WINDOW_SECONDS,
        )
        if not allowed:
            raise RateLimitedException(
                message="Trop de tentatives d'inscription, veuillez patienter.",
                details={"window_seconds": settings.OTP_WINDOW_SECONDS},
            )

        norm_phone = normalize_phone(data.phone)

        query = select(User).where(
            User.phone == norm_phone,
            User.deleted_at.is_(None),
        )
        existing = (await session.execute(query)).scalar_one_or_none()
        if existing:
            if existing.phone_verified_at is not None:
                raise ConflictException(
                    message="Ce numéro de téléphone est déjà enregistré."
                )
            existing.full_name = data.full_name
            existing.language = data.language
            existing.password_hash = (
                hash_password(data.password) if data.password else None
            )
            await session.execute(
                delete(OtpCode).where(
                    OtpCode.phone == norm_phone,
                    OtpCode.consumed_at.is_(None),
                )
            )
            await session.commit()

            await otp_service.send_otp(
                session=session,
                phone=norm_phone,
                purpose="verify_phone",
                background_tasks=background_tasks,
            )
            return

        pwd_hash = hash_password(data.password) if data.password else None
        user = User(
            phone=norm_phone,
            full_name=data.full_name,
            language=data.language,
            password_hash=pwd_hash,
            role="farmer",
        )
        session.add(user)
        await session.flush()

        plan_query = select(Plan).where(Plan.code == "free")
        free_plan = (await session.execute(plan_query)).scalar_one_or_none()
        if not free_plan:
            free_plan = Plan(
                code="free",
                name="Forfait Gratuit",
                audience="farmer",
                billing_model="free",
                price_xof=0,
                quotas={
                    "diagnostics_per_month": 10,
                    "llm_messages_per_month": 20,
                    "video_analyses_per_month": 0,
                    "plots": 3,
                    "storage_mb": 100,
                },
                features={"offline_sync": True, "weather": True},
                is_active=True,
            )
            session.add(free_plan)
            await session.flush()

        subscription = Subscription(
            user_id=user.id,
            plan_id=free_plan.id,
            status="active",
            current_period_start=datetime.now(UTC),
            auto_renew=False,
        )
        session.add(subscription)
        await session.commit()

        await otp_service.send_otp(
            session=session,
            phone=norm_phone,
            purpose="verify_phone",
            background_tasks=background_tasks,
        )

    async def request_otp(
        self,
        session: AsyncSession,
        phone: str,
        purpose: str,
        client_ip: str,
        background_tasks: BackgroundTasks,
    ) -> None:
        norm_phone = normalize_phone(phone)
        allowed = await check_rate_limit(
            f"rl:otp:ip:{client_ip}",
            settings.OTP_REQUESTS_PER_IP_WINDOW,
            settings.OTP_WINDOW_SECONDS,
        )
        if not allowed:
            raise RateLimitedException(
                message="Trop de demandes de code, veuillez patienter.",
                details={"window_seconds": settings.OTP_WINDOW_SECONDS},
            )

        await otp_service.enforce_phone_rate_limit(norm_phone)

        query = select(User.id).where(
            User.phone == norm_phone,
            User.deleted_at.is_(None),
        )
        exists = (await session.execute(query)).scalar_one_or_none()
        if exists is None:
            return

        await otp_service.send_otp(
            session=session,
            phone=norm_phone,
            purpose=purpose,
            background_tasks=background_tasks,
            apply_rate_limit=False,
        )

    async def _upsert_device(
        self,
        session: AsyncSession,
        user_id: uuid.UUID,
        device: DevicePayload | None,
        now: datetime,
    ) -> uuid.UUID | None:
        if device is None:
            return None
        query = select(Device).where(
            Device.user_id == user_id,
            Device.fcm_token == device.fcm_token,
        )
        existing = (await session.execute(query)).scalar_one_or_none()
        if existing:
            existing.platform = device.platform
            existing.app_version = device.app_version
            existing.last_seen_at = now
            return existing.id
        new_device = Device(
            user_id=user_id,
            platform=device.platform,
            fcm_token=device.fcm_token,
            app_version=device.app_version,
            last_seen_at=now,
        )
        session.add(new_device)
        await session.flush()
        return new_device.id

    async def _issue_tokens(
        self,
        session: AsyncSession,
        user: User,
        device_id: uuid.UUID | None,
        now: datetime,
    ) -> TokenResponse:
        access_token = create_access_token(user.id, user.role)
        raw_refresh = generate_refresh_token()
        refresh_hash = hash_refresh_token(raw_refresh)

        refresh_rec = RefreshToken(
            user_id=user.id,
            device_id=device_id,
            token_hash=refresh_hash,
            expires_at=now + timedelta(days=settings.REFRESH_TOKEN_DAYS),
        )
        session.add(refresh_rec)
        await session.commit()
        await session.refresh(user)

        return TokenResponse(
            access_token=access_token,
            refresh_token=raw_refresh,
            token_type="bearer",
            expires_in=settings.ACCESS_TOKEN_MINUTES * 60,
            user=UserResponse.model_validate(user),
        )

    async def verify_otp_and_login(
        self, session: AsyncSession, data: OtpVerifyRequest
    ) -> TokenResponse:
        norm_phone = normalize_phone(data.phone)
        await otp_service.verify_otp(
            session=session,
            phone=norm_phone,
            code=data.code,
            purpose=data.purpose,
        )

        query = select(User).where(
            User.phone == norm_phone,
            User.deleted_at.is_(None),
        )
        user = (await session.execute(query)).scalar_one_or_none()
        if not user:
            raise NotFoundException(message="Utilisateur non trouvé.")

        if not user.is_active:
            raise ForbiddenException(message="Compte utilisateur désactivé.")

        now = datetime.now(UTC)
        if data.purpose in ("login", "verify_phone"):
            if user.phone_verified_at is None:
                user.password_hash = None
                user.phone_verified_at = now
            user.last_login_at = now

        device_id = await self._upsert_device(session, user.id, data.device, now)
        return await self._issue_tokens(session, user, device_id, now)

    async def login_password(
        self, session: AsyncSession, data: LoginRequest, client_ip: str
    ) -> TokenResponse:
        norm_phone = normalize_phone(data.phone)

        allowed = await check_rate_limit(
            f"rl:login:ip:{client_ip}",
            settings.RATE_LIMIT_LOGIN_PER_MINUTE,
            60,
        )
        if not allowed:
            raise RateLimitedException(
                message="Trop de tentatives de connexion, veuillez patienter.",
                details={"window_seconds": 60},
            )

        allowed = await check_rate_limit(
            f"rl:login:phone:{norm_phone}",
            settings.RATE_LIMIT_LOGIN_PER_MINUTE,
            60,
        )
        if not allowed:
            raise RateLimitedException(
                message="Trop de tentatives de connexion, veuillez patienter.",
                details={"window_seconds": 60},
            )

        query = select(User).where(
            User.phone == norm_phone,
            User.deleted_at.is_(None),
        )
        user = (await session.execute(query)).scalar_one_or_none()
        if not user:
            verify_password(data.password, _DUMMY_PASSWORD_HASH)
            raise UnauthorizedException(message="Identifiants incorrects.")

        if not user.is_active:
            raise ForbiddenException(message="Compte utilisateur désactivé.")

        if user.phone_verified_at is None:
            verify_password(data.password, _DUMMY_PASSWORD_HASH)
            raise UnauthorizedException(message="Identifiants incorrects.")

        if not user.password_hash:
            verify_password(data.password, _DUMMY_PASSWORD_HASH)
            raise UnauthorizedException(message="Identifiants incorrects.")

        if not verify_password(data.password, user.password_hash):
            raise UnauthorizedException(message="Identifiants incorrects.")

        now = datetime.now(UTC)
        user.last_login_at = now

        device_id = await self._upsert_device(session, user.id, data.device, now)
        return await self._issue_tokens(session, user, device_id, now)

    async def _consume_refresh_grace(
        self,
        user_id: uuid.UUID,
        revoked_at: datetime,
        token_hash: str,
        now: datetime,
    ) -> bool:
        grace = settings.REFRESH_REUSE_GRACE_SECONDS
        if grace <= 0:
            return False
        if now - revoked_at > timedelta(seconds=grace):
            return False
        client = get_redis_client()
        try:
            if await client.exists(f"rl:refresh:replay:{user_id}"):
                return False
            claimed = await client.set(
                f"rl:refresh:grace:{token_hash}",
                "1",
                nx=True,
                ex=grace + 1,
            )
        except Exception:
            return False
        return bool(claimed)

    async def _mark_refresh_replay(self, user_id: uuid.UUID) -> None:
        grace = settings.REFRESH_REUSE_GRACE_SECONDS
        if grace <= 0:
            return
        try:
            await get_redis_client().set(
                f"rl:refresh:replay:{user_id}",
                "1",
                ex=grace + 1,
            )
        except Exception:
            return

    async def refresh_token(
        self, session: AsyncSession, raw_refresh_token: str
    ) -> TokenResponse:
        token_hash = hash_refresh_token(raw_refresh_token)

        query = (
            select(RefreshToken)
            .where(RefreshToken.token_hash == token_hash)
            .with_for_update()
        )
        rec = (await session.execute(query)).scalar_one_or_none()

        if not rec:
            raise UnauthorizedException(
                message="Jeton de rafraîchissement invalide."
            )

        now = datetime.now(UTC)
        if rec.revoked_at is not None:
            within_grace = await self._consume_refresh_grace(
                rec.user_id, rec.revoked_at, token_hash, now
            )
            if not within_grace:
                await session.execute(
                    update(RefreshToken)
                    .where(
                        RefreshToken.user_id == rec.user_id,
                        RefreshToken.revoked_at.is_(None),
                    )
                    .values(revoked_at=now)
                )
                await session.commit()
                await self._mark_refresh_replay(rec.user_id)
                raise UnauthorizedException(
                    message="Rejeu détecté. Toutes les sessions ont été révoquées."
                )
        elif rec.expires_at < now:
            raise UnauthorizedException(
                message="Jeton de rafraîchissement expiré."
            )

        if rec.revoked_at is None:
            rec.revoked_at = now

        user_query = select(User).where(
            User.id == rec.user_id,
            User.is_active.is_(True),
            User.deleted_at.is_(None),
        )
        user = (await session.execute(user_query)).scalar_one_or_none()
        if not user:
            raise UnauthorizedException(
                message="Utilisateur introuvable ou désactivé."
            )

        return await self._issue_tokens(session, user, rec.device_id, now)

    async def logout(
        self, session: AsyncSession, raw_refresh_token: str, user_id: uuid.UUID
    ) -> None:
        token_hash = hash_refresh_token(raw_refresh_token)
        query = select(RefreshToken).where(RefreshToken.token_hash == token_hash)
        rec = (await session.execute(query)).scalar_one_or_none()
        if rec is None:
            return
        if rec.user_id != user_id:
            raise ForbiddenException(
                message="Ce jeton de rafraîchissement n'appartient pas à cet utilisateur."
            )
        if rec.revoked_at is None:
            rec.revoked_at = datetime.now(UTC)
            await session.commit()

    async def reset_password(
        self, session: AsyncSession, data: PasswordResetRequest
    ) -> None:
        norm_phone = normalize_phone(data.phone)
        await otp_service.verify_otp(
            session=session,
            phone=norm_phone,
            code=data.code,
            purpose="reset_password",
        )

        query = select(User).where(
            User.phone == norm_phone,
            User.deleted_at.is_(None),
        )
        user = (await session.execute(query)).scalar_one_or_none()
        if not user:
            raise NotFoundException(message="Utilisateur introuvable.")

        user.password_hash = hash_password(data.new_password)
        now = datetime.now(UTC)
        await session.execute(
            update(RefreshToken)
            .where(
                RefreshToken.user_id == user.id,
                RefreshToken.revoked_at.is_(None),
            )
            .values(revoked_at=now)
        )
        await session.commit()


auth_service = AuthService()
