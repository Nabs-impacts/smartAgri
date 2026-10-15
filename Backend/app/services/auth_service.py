from datetime import datetime, timedelta, timezone
from sqlalchemy import select, update
from sqlalchemy.ext.asyncio import AsyncSession
from app.core.config import settings
from app.core.errors import ConflictException, ForbiddenException, NotFoundException, UnauthorizedException
from app.core.security import (
    create_access_token,
    generate_refresh_token,
    hash_password,
    hash_refresh_token,
    normalize_phone,
    verify_password,
)
from app.db.models.billing import Plan, Subscription
from app.db.models.identity import Device, RefreshToken, User
from app.schemas.auth import (
    LoginRequest,
    OtpVerifyRequest,
    PasswordResetRequest,
    RegisterRequest,
    TokenResponse,
)
from app.schemas.user import UserResponse
from app.services.otp_service import otp_service


class AuthService:
    async def register(self, session: AsyncSession, data: RegisterRequest) -> None:
        norm_phone = normalize_phone(data.phone)

        query = select(User).where(
            User.phone == norm_phone,
            User.deleted_at.is_(None),
        )
        existing = (await session.execute(query)).scalar_one_or_none()
        if existing:
            raise ConflictException(
                message="Ce numero de telephone est deja enregistre."
            )

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
            current_period_start=datetime.now(timezone.utc),
            auto_renew=False,
        )
        session.add(subscription)
        await session.commit()

        await otp_service.send_otp(
            session=session,
            phone=norm_phone,
            purpose="verify_phone",
        )

    async def request_otp(
        self, session: AsyncSession, phone: str, purpose: str
    ) -> None:
        await otp_service.send_otp(
            session=session,
            phone=phone,
            purpose=purpose,
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
            raise NotFoundException(message="Utilisateur non trouve.")

        if not user.is_active:
            raise ForbiddenException(message="Compte utilisateur desactive.")

        now = datetime.now(timezone.utc)
        if data.purpose in ("login", "verify_phone"):
            user.phone_verified_at = user.phone_verified_at or now
            user.last_login_at = now

        device_id = None
        if data.device:
            dev_query = select(Device).where(
                Device.user_id == user.id,
                Device.fcm_token == data.device.fcm_token,
            )
            device = (await session.execute(dev_query)).scalar_one_or_none()
            if device:
                device.platform = data.device.platform
                device.app_version = data.device.app_version
                device.last_seen_at = now
                device_id = device.id
            else:
                new_device = Device(
                    user_id=user.id,
                    platform=data.device.platform,
                    fcm_token=data.device.fcm_token,
                    app_version=data.device.app_version,
                    last_seen_at=now,
                )
                session.add(new_device)
                await session.flush()
                device_id = new_device.id

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

    async def login_password(
        self, session: AsyncSession, data: LoginRequest
    ) -> TokenResponse:
        norm_phone = normalize_phone(data.phone)

        query = select(User).where(
            User.phone == norm_phone,
            User.deleted_at.is_(None),
        )
        user = (await session.execute(query)).scalar_one_or_none()
        if not user:
            raise UnauthorizedException(message="Identifiants incorrects.")

        if not user.is_active:
            raise ForbiddenException(message="Compte utilisateur desactive.")

        if not user.password_hash or not verify_password(data.password, user.password_hash):
            raise UnauthorizedException(message="Identifiants incorrects.")

        now = datetime.now(timezone.utc)
        user.last_login_at = now

        device_id = None
        if data.device:
            dev_query = select(Device).where(
                Device.user_id == user.id,
                Device.fcm_token == data.device.fcm_token,
            )
            device = (await session.execute(dev_query)).scalar_one_or_none()
            if device:
                device.platform = data.device.platform
                device.app_version = data.device.app_version
                device.last_seen_at = now
                device_id = device.id
            else:
                new_device = Device(
                    user_id=user.id,
                    platform=data.device.platform,
                    fcm_token=data.device.fcm_token,
                    app_version=data.device.app_version,
                    last_seen_at=now,
                )
                session.add(new_device)
                await session.flush()
                device_id = new_device.id

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

    async def refresh_token(
        self, session: AsyncSession, raw_refresh_token: str
    ) -> TokenResponse:
        token_hash = hash_refresh_token(raw_refresh_token)

        query = select(RefreshToken).where(RefreshToken.token_hash == token_hash)
        rec = (await session.execute(query)).scalar_one_or_none()

        if not rec:
            raise UnauthorizedException(
                message="Jeton de rafraichissement invalide."
            )

        now = datetime.now(timezone.utc)
        if rec.revoked_at is not None:
            await session.execute(
                update(RefreshToken)
                .where(
                    RefreshToken.user_id == rec.user_id,
                    RefreshToken.revoked_at.is_(None),
                )
                .values(revoked_at=now)
            )
            await session.commit()
            raise UnauthorizedException(
                message="Rejeu detecte. Toutes les sessions ont ete revoquees."
            )

        if rec.expires_at < now:
            raise UnauthorizedException(
                message="Jeton de rafraichissement expire."
            )

        rec.revoked_at = now

        user_query = select(User).where(
            User.id == rec.user_id,
            User.is_active.is_(True),
            User.deleted_at.is_(None),
        )
        user = (await session.execute(user_query)).scalar_one_or_none()
        if not user:
            raise UnauthorizedException(
                message="Utilisateur introuvable ou desactive."
            )

        access_token = create_access_token(user.id, user.role)
        new_raw_refresh = generate_refresh_token()
        new_hash = hash_refresh_token(new_raw_refresh)

        new_rec = RefreshToken(
            user_id=user.id,
            device_id=rec.device_id,
            token_hash=new_hash,
            expires_at=now + timedelta(days=settings.REFRESH_TOKEN_DAYS),
        )
        session.add(new_rec)
        await session.commit()
        await session.refresh(user)

        return TokenResponse(
            access_token=access_token,
            refresh_token=new_raw_refresh,
            token_type="bearer",
            expires_in=settings.ACCESS_TOKEN_MINUTES * 60,
            user=UserResponse.model_validate(user),
        )

    async def logout(self, session: AsyncSession, raw_refresh_token: str) -> None:
        token_hash = hash_refresh_token(raw_refresh_token)
        query = select(RefreshToken).where(RefreshToken.token_hash == token_hash)
        rec = (await session.execute(query)).scalar_one_or_none()
        if rec and rec.revoked_at is None:
            rec.revoked_at = datetime.now(timezone.utc)
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
        now = datetime.now(timezone.utc)
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
