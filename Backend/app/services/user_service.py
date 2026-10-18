import uuid
from datetime import UTC, date, datetime

from sqlalchemy import func, or_, select, update
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.errors import (
    ConflictException,
    ForbiddenException,
    InternalErrorException,
    NotFoundException,
    UnauthorizedException,
    ValidationException,
)
from app.core.security import hash_password, verify_password
from app.db.models.billing import Plan, Subscription, UsageRecord
from app.db.models.identity import AdminArea, Consent, Device, RefreshToken, User
from app.db.models.organizations import OrganizationMember
from app.schemas.user import (
    ConsentCreateRequest,
    ConsentResponse,
    DeviceCreateRequest,
    DeviceResponse,
    PasswordUpdateRequest,
    PlanSummary,
    QuotaStatus,
    UserMeResponse,
    UserResponse,
    UserUpdateRequest,
)

_QUOTA_METRIC_MAP = {
    "diagnostics_per_month": "diagnostic",
    "llm_messages_per_month": "llm_message",
    "video_analyses_per_month": "video_analysis",
    "storage_mb": "storage_mb",
}


class UserService:
    async def _effective_subscription(
        self, session: AsyncSession, user_id: uuid.UUID
    ) -> tuple[Subscription | None, Plan]:
        now = datetime.now(UTC)

        own_query = (
            select(Subscription, Plan)
            .join(Plan, Subscription.plan_id == Plan.id)
            .where(
                Subscription.user_id == user_id,
                Subscription.status.in_(("active", "trialing")),
                or_(
                    Subscription.current_period_end.is_(None),
                    Subscription.current_period_end > now,
                ),
            )
            .order_by(Plan.price_xof.desc())
            .limit(1)
        )
        row = (await session.execute(own_query)).first()
        if row is not None:
            return row[0], row[1]

        org_query = (
            select(Subscription, Plan)
            .join(Plan, Subscription.plan_id == Plan.id)
            .join(
                OrganizationMember,
                OrganizationMember.organization_id == Subscription.organization_id,
            )
            .where(
                OrganizationMember.user_id == user_id,
                Subscription.status.in_(("active", "trialing")),
                or_(
                    Subscription.current_period_end.is_(None),
                    Subscription.current_period_end > now,
                ),
            )
            .order_by(Plan.price_xof.desc())
            .limit(1)
        )
        row = (await session.execute(org_query)).first()
        if row is not None:
            return row[0], row[1]

        free_query = select(Plan).where(Plan.code == "free")
        free_plan = (await session.execute(free_query)).scalar_one_or_none()
        if free_plan is None:
            raise InternalErrorException(message="Forfait gratuit introuvable.")
        return None, free_plan

    async def _quota_statuses(
        self,
        session: AsyncSession,
        subscription: Subscription | None,
        plan: Plan,
    ) -> list[QuotaStatus]:
        quotas = plan.quotas or {}
        usage_by_metric: dict[str, int] = {}
        if subscription is not None:
            month_start = date.today().replace(day=1)
            usage_query = (
                select(
                    UsageRecord.metric,
                    func.coalesce(func.sum(UsageRecord.quantity), 0),
                )
                .where(
                    UsageRecord.subscription_id == subscription.id,
                    UsageRecord.period >= month_start,
                )
                .group_by(UsageRecord.metric)
            )
            usage_by_metric = {
                metric: int(total)
                for metric, total in (await session.execute(usage_query)).all()
            }

        statuses: list[QuotaStatus] = []
        for key, limit in quotas.items():
            if not isinstance(limit, int):
                continue
            metric = _QUOTA_METRIC_MAP.get(key)
            used = usage_by_metric.get(metric, 0) if metric else 0
            statuses.append(
                QuotaStatus(
                    metric=key,
                    limit=limit,
                    used=used,
                    remaining=max(limit - used, 0),
                )
            )
        return statuses

    async def get_profile(
        self, session: AsyncSession, user: User
    ) -> UserMeResponse:
        subscription, plan = await self._effective_subscription(session, user.id)
        quotas = await self._quota_statuses(session, subscription, plan)
        return UserMeResponse(
            user=UserResponse.model_validate(user),
            effective_plan=PlanSummary.model_validate(plan),
            quotas=quotas,
        )

    async def update_profile(
        self,
        session: AsyncSession,
        user: User,
        data: UserUpdateRequest,
    ) -> UserResponse:
        changes = data.model_dump(exclude_unset=True)

        admin_area_id = changes.get("admin_area_id")
        if admin_area_id is not None:
            area = await session.get(AdminArea, admin_area_id)
            if area is None:
                raise NotFoundException(message="Zone administrative introuvable.")

        email = changes.get("email")
        if email is not None:
            email_query = select(User.id).where(
                User.email == email,
                User.id != user.id,
                User.deleted_at.is_(None),
            )
            taken = (await session.execute(email_query)).scalar_one_or_none()
            if taken is not None:
                raise ConflictException(
                    message="Cette adresse e-mail est déjà utilisée."
                )

        for field, value in changes.items():
            setattr(user, field, value)

        await session.commit()
        await session.refresh(user)
        return UserResponse.model_validate(user)

    async def change_password(
        self,
        session: AsyncSession,
        user: User,
        data: PasswordUpdateRequest,
    ) -> None:
        if user.phone_verified_at is None:
            raise ForbiddenException(
                message="Vérifiez votre numéro de téléphone avant de définir un mot de passe."
            )

        if user.password_hash is not None:
            if not data.current_password:
                raise ValidationException(
                    message="Le mot de passe actuel est obligatoire."
                )
            if not verify_password(data.current_password, user.password_hash):
                raise UnauthorizedException(message="Mot de passe actuel incorrect.")

        user.password_hash = hash_password(data.new_password)
        await session.execute(
            update(RefreshToken)
            .where(
                RefreshToken.user_id == user.id,
                RefreshToken.revoked_at.is_(None),
            )
            .values(revoked_at=datetime.now(UTC))
        )
        await session.commit()

    async def upsert_device(
        self,
        session: AsyncSession,
        user: User,
        data: DeviceCreateRequest,
    ) -> DeviceResponse:
        now = datetime.now(UTC)
        device_query = select(Device).where(
            Device.user_id == user.id,
            Device.fcm_token == data.fcm_token,
        )
        device = (await session.execute(device_query)).scalar_one_or_none()
        if device is None:
            device = Device(
                user_id=user.id,
                platform=data.platform,
                fcm_token=data.fcm_token,
                app_version=data.app_version,
                last_seen_at=now,
            )
            session.add(device)
        else:
            device.platform = data.platform
            device.app_version = data.app_version
            device.last_seen_at = now

        await session.commit()
        await session.refresh(device)
        return DeviceResponse.model_validate(device)

    async def delete_device(
        self,
        session: AsyncSession,
        user: User,
        device_id: uuid.UUID,
    ) -> None:
        device_query = select(Device).where(
            Device.id == device_id,
            Device.user_id == user.id,
        )
        device = (await session.execute(device_query)).scalar_one_or_none()
        if device is None:
            raise NotFoundException(message="Appareil introuvable.")
        await session.delete(device)
        await session.commit()

    async def create_consent(
        self,
        session: AsyncSession,
        user: User,
        data: ConsentCreateRequest,
    ) -> ConsentResponse:
        consent = Consent(
            user_id=user.id,
            type=data.type,
            version=data.version,
            accepted=data.accepted,
        )
        session.add(consent)
        await session.commit()
        await session.refresh(consent)
        return ConsentResponse.model_validate(consent)

    async def list_consents(
        self,
        session: AsyncSession,
        user: User,
    ) -> list[ConsentResponse]:
        consent_query = (
            select(Consent)
            .where(Consent.user_id == user.id)
            .order_by(Consent.created_at.desc(), Consent.id.desc())
        )
        consents = (await session.execute(consent_query)).scalars().all()
        latest: dict[str, Consent] = {}
        for consent in consents:
            latest.setdefault(consent.type, consent)
        return [
            ConsentResponse.model_validate(latest[consent_type])
            for consent_type in sorted(latest)
        ]


user_service = UserService()
