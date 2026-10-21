import uuid
from datetime import UTC, date, datetime
from decimal import Decimal
from typing import Any

from sqlalchemy import case, delete, func, select, update
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.errors import (
    ConflictException,
    ForbiddenException,
    NotFoundException,
    UnauthorizedException,
    ValidationException,
)
from app.core.logging import get_logger
from app.core.security import hash_password, verify_password
from app.db.models.billing import Payment, Plan, Subscription, UsageRecord
from app.db.models.farming import CropCycle, Farm, FarmActivity, Harvest, Plot
from app.db.models.field_data import Notification
from app.db.models.identity import (
    AdminArea,
    Consent,
    Device,
    OtpCode,
    RefreshToken,
    User,
)
from app.db.models.knowledge import ChatMessage, ChatSession
from app.db.models.media_ai import Diagnostic, MediaFile, Recommendation
from app.db.models.organizations import OrganizationMember
from app.schemas.user import (
    ConsentCreateRequest,
    ConsentResponse,
    DeviceCreateRequest,
    DeviceResponse,
    PasswordUpdateRequest,
    PlanSummary,
    QuotaStatus,
    UserDataExportResponse,
    UserMeResponse,
    UserResponse,
    UserUpdateRequest,
)
from app.services.audit_service import audit_service
from app.services.subscription_service import subscription_service

logger = get_logger("user_service")

_QUOTA_METRIC_MAP = {
    "diagnostics_per_month": "diagnostic",
    "llm_messages_per_month": "llm_message",
    "video_analyses_per_month": "video_analysis",
    "storage_mb": "storage_mb",
}

_USER_FIELDS = (
    "id",
    "phone",
    "email",
    "full_name",
    "role",
    "language",
    "admin_area_id",
    "is_active",
    "phone_verified_at",
    "created_at",
    "updated_at",
    "last_login_at",
)
_DEVICE_FIELDS = (
    "id",
    "platform",
    "fcm_token",
    "app_version",
    "last_seen_at",
    "created_at",
)
_CONSENT_FIELDS = ("id", "type", "version", "accepted", "created_at")
_FARM_FIELDS = (
    "id",
    "name",
    "village",
    "admin_area_id",
    "organization_id",
    "created_at",
    "updated_at",
)
_PLOT_FIELDS = (
    "id",
    "farm_id",
    "name",
    "area_ha",
    "soil_type",
    "irrigation",
    "created_at",
    "updated_at",
)
_CROP_CYCLE_FIELDS = (
    "id",
    "plot_id",
    "crop_id",
    "variety",
    "season",
    "sowing_date",
    "expected_harvest_date",
    "harvest_date",
    "status",
    "notes",
    "created_at",
    "updated_at",
)
_ACTIVITY_FIELDS = (
    "id",
    "crop_cycle_id",
    "type",
    "performed_on",
    "product_name",
    "quantity",
    "unit",
    "cost_xof",
    "notes",
    "created_at",
    "updated_at",
)
_HARVEST_FIELDS = (
    "id",
    "crop_cycle_id",
    "harvested_on",
    "quantity_kg",
    "quality",
    "sold_kg",
    "avg_price_xof_per_kg",
    "created_at",
    "updated_at",
)
_DIAGNOSTIC_FIELDS = (
    "id",
    "plot_id",
    "crop_cycle_id",
    "crop_id",
    "model_id",
    "source",
    "status",
    "top_label_id",
    "confidence",
    "severity",
    "user_note",
    "error",
    "completed_at",
    "created_at",
    "updated_at",
)
_RECOMMENDATION_FIELDS = (
    "id",
    "diagnostic_id",
    "plot_id",
    "crop_cycle_id",
    "source",
    "language",
    "title",
    "body",
    "steps",
    "citations",
    "model_id",
    "status",
    "validated_by",
    "created_at",
)
_PAYMENT_FIELDS = (
    "id",
    "subscription_id",
    "plan_id",
    "provider",
    "provider_ref",
    "idempotency_key",
    "purpose",
    "amount_xof",
    "currency",
    "payer_phone",
    "status",
    "paid_at",
    "created_at",
)
_SUBSCRIPTION_FIELDS = (
    "id",
    "user_id",
    "organization_id",
    "plan_id",
    "status",
    "current_period_start",
    "current_period_end",
    "auto_renew",
    "canceled_at",
    "created_at",
    "updated_at",
)
_ORGANIZATION_MEMBERSHIP_FIELDS = (
    "organization_id",
    "member_role",
    "joined_at",
)
_NOTIFICATION_FIELDS = (
    "id",
    "user_id",
    "alert_id",
    "channel",
    "title",
    "body",
    "status",
    "sent_at",
    "read_at",
    "created_at",
)
_CHAT_SESSION_FIELDS = ("id", "plot_id", "title", "created_at")
_CHAT_MESSAGE_FIELDS = (
    "id",
    "session_id",
    "role",
    "content",
    "media_id",
    "citations",
    "tokens_in",
    "tokens_out",
    "created_at",
)
_MEDIA_FIELDS = (
    "id",
    "owner_id",
    "plot_id",
    "crop_cycle_id",
    "kind",
    "mime_type",
    "size_bytes",
    "width",
    "height",
    "duration_s",
    "sha256",
    "captured_at",
    "upload_status",
    "created_at",
)


def _dump_record(obj: Any, fields: tuple[str, ...]) -> dict[str, Any]:
    record: dict[str, Any] = {}
    for field in fields:
        value = getattr(obj, field)
        if isinstance(value, uuid.UUID):
            value = str(value)
        elif isinstance(value, date):
            value = value.isoformat()
        elif isinstance(value, Decimal):
            value = float(value)
        record[field] = value
    return record


class UserService:
    async def _effective_subscription(
        self, session: AsyncSession, user_id: uuid.UUID
    ) -> tuple[Subscription | None, Plan]:
        return await subscription_service.get_effective_subscription(session, user_id)

    async def _quota_statuses(
        self,
        session: AsyncSession,
        user_id: uuid.UUID,
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

        plots_used = 0
        if "plots" in quotas:
            plots_query = (
                select(func.count(Plot.id))
                .join(Farm, Plot.farm_id == Farm.id)
                .where(
                    Farm.owner_id == user_id,
                    Farm.deleted_at.is_(None),
                    Plot.deleted_at.is_(None),
                )
            )
            plots_used = int((await session.execute(plots_query)).scalar_one())

        statuses: list[QuotaStatus] = []
        for key, limit in quotas.items():
            if not isinstance(limit, int):
                continue
            if key == "plots":
                used = plots_used
            else:
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
        quotas = await self._quota_statuses(session, user.id, subscription, plan)
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
            email = email.lower()
            changes["email"] = email
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

        try:
            await session.commit()
        except IntegrityError:
            await session.rollback()
            raise ConflictException(
                message="Cette adresse e-mail est déjà utilisée."
            ) from None
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

    async def export_data(
        self, session: AsyncSession, user: User
    ) -> UserDataExportResponse:
        devices = (
            await session.execute(
                select(Device)
                .where(Device.user_id == user.id)
                .order_by(Device.created_at, Device.id)
            )
        ).scalars().all()
        consents = (
            await session.execute(
                select(Consent)
                .where(Consent.user_id == user.id)
                .order_by(Consent.created_at, Consent.id)
            )
        ).scalars().all()
        farms = (
            await session.execute(
                select(Farm)
                .where(Farm.owner_id == user.id, Farm.deleted_at.is_(None))
                .order_by(Farm.created_at, Farm.id)
            )
        ).scalars().all()
        plots = (
            await session.execute(
                select(Plot)
                .join(Farm, Plot.farm_id == Farm.id)
                .where(
                    Farm.owner_id == user.id,
                    Farm.deleted_at.is_(None),
                    Plot.deleted_at.is_(None),
                )
                .order_by(Plot.created_at, Plot.id)
            )
        ).scalars().all()
        crop_cycles = (
            await session.execute(
                select(CropCycle)
                .join(Plot, CropCycle.plot_id == Plot.id)
                .join(Farm, Plot.farm_id == Farm.id)
                .where(
                    Farm.owner_id == user.id,
                    Farm.deleted_at.is_(None),
                    Plot.deleted_at.is_(None),
                    CropCycle.deleted_at.is_(None),
                )
                .order_by(CropCycle.created_at, CropCycle.id)
            )
        ).scalars().all()
        activities = (
            await session.execute(
                select(FarmActivity)
                .join(CropCycle, FarmActivity.crop_cycle_id == CropCycle.id)
                .join(Plot, CropCycle.plot_id == Plot.id)
                .join(Farm, Plot.farm_id == Farm.id)
                .where(
                    Farm.owner_id == user.id,
                    Farm.deleted_at.is_(None),
                    Plot.deleted_at.is_(None),
                    CropCycle.deleted_at.is_(None),
                    FarmActivity.deleted_at.is_(None),
                )
                .order_by(FarmActivity.created_at, FarmActivity.id)
            )
        ).scalars().all()
        harvests = (
            await session.execute(
                select(Harvest)
                .join(CropCycle, Harvest.crop_cycle_id == CropCycle.id)
                .join(Plot, CropCycle.plot_id == Plot.id)
                .join(Farm, Plot.farm_id == Farm.id)
                .where(
                    Farm.owner_id == user.id,
                    Farm.deleted_at.is_(None),
                    Plot.deleted_at.is_(None),
                    CropCycle.deleted_at.is_(None),
                    Harvest.deleted_at.is_(None),
                )
                .order_by(Harvest.created_at, Harvest.id)
            )
        ).scalars().all()
        diagnostics = (
            await session.execute(
                select(Diagnostic)
                .where(Diagnostic.user_id == user.id, Diagnostic.deleted_at.is_(None))
                .order_by(Diagnostic.created_at, Diagnostic.id)
            )
        ).scalars().all()
        recommendations = (
            await session.execute(
                select(Recommendation)
                .where(Recommendation.user_id == user.id)
                .order_by(Recommendation.created_at, Recommendation.id)
            )
        ).scalars().all()
        payments = (
            await session.execute(
                select(Payment)
                .where(Payment.user_id == user.id)
                .order_by(Payment.created_at, Payment.id)
            )
        ).scalars().all()
        subscriptions = (
            await session.execute(
                select(Subscription)
                .where(Subscription.user_id == user.id)
                .order_by(Subscription.created_at, Subscription.id)
            )
        ).scalars().all()
        organization_memberships = (
            await session.execute(
                select(OrganizationMember)
                .where(OrganizationMember.user_id == user.id)
                .order_by(
                    OrganizationMember.joined_at,
                    OrganizationMember.organization_id,
                )
            )
        ).scalars().all()
        notifications = (
            await session.execute(
                select(Notification)
                .where(Notification.user_id == user.id)
                .order_by(Notification.created_at, Notification.id)
            )
        ).scalars().all()
        chat_sessions = (
            await session.execute(
                select(ChatSession)
                .where(ChatSession.user_id == user.id)
                .order_by(ChatSession.created_at, ChatSession.id)
            )
        ).scalars().all()
        chat_messages = (
            await session.execute(
                select(ChatMessage)
                .join(ChatSession, ChatMessage.session_id == ChatSession.id)
                .where(ChatSession.user_id == user.id)
                .order_by(ChatMessage.created_at, ChatMessage.id)
            )
        ).scalars().all()
        media_files = (
            await session.execute(
                select(MediaFile)
                .where(
                    MediaFile.owner_id == user.id,
                    MediaFile.deleted_at.is_(None),
                )
                .order_by(MediaFile.created_at, MediaFile.id)
            )
        ).scalars().all()

        return UserDataExportResponse(
            user=_dump_record(user, _USER_FIELDS),
            devices=[_dump_record(item, _DEVICE_FIELDS) for item in devices],
            consents=[_dump_record(item, _CONSENT_FIELDS) for item in consents],
            farms=[_dump_record(item, _FARM_FIELDS) for item in farms],
            plots=[_dump_record(item, _PLOT_FIELDS) for item in plots],
            crop_cycles=[
                _dump_record(item, _CROP_CYCLE_FIELDS) for item in crop_cycles
            ],
            activities=[_dump_record(item, _ACTIVITY_FIELDS) for item in activities],
            harvests=[_dump_record(item, _HARVEST_FIELDS) for item in harvests],
            diagnostics=[
                _dump_record(item, _DIAGNOSTIC_FIELDS) for item in diagnostics
            ],
            recommendations=[
                _dump_record(item, _RECOMMENDATION_FIELDS)
                for item in recommendations
            ],
            payments=[_dump_record(item, _PAYMENT_FIELDS) for item in payments],
            subscriptions=[
                _dump_record(item, _SUBSCRIPTION_FIELDS)
                for item in subscriptions
            ],
            organization_memberships=[
                _dump_record(item, _ORGANIZATION_MEMBERSHIP_FIELDS)
                for item in organization_memberships
            ],
            notifications=[
                _dump_record(item, _NOTIFICATION_FIELDS)
                for item in notifications
            ],
            chat_sessions=[
                _dump_record(item, _CHAT_SESSION_FIELDS)
                for item in chat_sessions
            ],
            chat_messages=[
                _dump_record(item, _CHAT_MESSAGE_FIELDS)
                for item in chat_messages
            ],
            media_files=[
                _dump_record(item, _MEDIA_FIELDS) for item in media_files
            ],
        )

    async def delete_account(
        self,
        session: AsyncSession,
        user: User,
        client_ip: str | None = None,
    ) -> None:
        owned_org_ids = list(
            (
                await session.scalars(
                    select(OrganizationMember.organization_id).where(
                        OrganizationMember.user_id == user.id,
                        OrganizationMember.member_role == "owner",
                    )
                )
            ).all()
        )
        for organization_id in owned_org_ids:
            owner_count = int(
                (
                    await session.execute(
                        select(func.count(OrganizationMember.user_id)).where(
                            OrganizationMember.organization_id == organization_id,
                            OrganizationMember.member_role == "owner",
                        )
                    )
                ).scalar_one()
            )
            member_count = int(
                (
                    await session.execute(
                        select(func.count(OrganizationMember.user_id)).where(
                            OrganizationMember.organization_id == organization_id
                        )
                    )
                ).scalar_one()
            )
            if owner_count == 1 and member_count > 1:
                raise ConflictException(
                    "Vous êtes le seul propriétaire d'une organisation qui compte "
                    "d'autres membres. Transférez la propriété avant de supprimer "
                    "votre compte."
                )

        now = datetime.now(UTC)
        old_phone = user.phone
        anonymized_phone = f"deleted-{uuid.uuid4().hex}"
        user.phone = anonymized_phone
        user.email = None
        user.full_name = ""
        user.password_hash = None
        user.is_active = False
        user.deleted_at = now

        await session.execute(delete(OtpCode).where(OtpCode.phone == old_phone))
        await session.execute(
            update(Payment)
            .where(Payment.user_id == user.id)
            .values(
                payer_phone=case(
                    (Payment.payer_phone.is_(None), None),
                    else_=func.concat(
                        "**", func.right(Payment.payer_phone, 2)
                    ),
                )
            )
        )
        await session.execute(
            update(Farm)
            .where(Farm.owner_id == user.id)
            .values(
                location=None,
                village=None,
                name="Exploitation supprimée",
            )
        )
        user_farm_ids = select(Farm.id).where(Farm.owner_id == user.id)
        await session.execute(
            update(Plot)
            .where(Plot.farm_id.in_(user_farm_ids))
            .values(geom=None, name="Parcelle supprimée")
        )
        user_plot_ids = select(Plot.id).where(Plot.farm_id.in_(user_farm_ids))
        await session.execute(
            update(CropCycle)
            .where(CropCycle.plot_id.in_(user_plot_ids))
            .values(notes=None)
        )
        user_cycle_ids = select(CropCycle.id).where(
            CropCycle.plot_id.in_(user_plot_ids)
        )
        await session.execute(
            update(FarmActivity)
            .where(FarmActivity.crop_cycle_id.in_(user_cycle_ids))
            .values(notes=None)
        )
        await session.execute(
            update(Diagnostic)
            .where(Diagnostic.user_id == user.id)
            .values(location=None, user_note=None)
        )
        user_chat_session_ids = select(ChatSession.id).where(
            ChatSession.user_id == user.id
        )
        await session.execute(
            delete(ChatMessage).where(
                ChatMessage.session_id.in_(user_chat_session_ids)
            )
        )
        await session.execute(
            delete(ChatSession).where(ChatSession.user_id == user.id)
        )
        await session.execute(
            delete(Notification).where(Notification.user_id == user.id)
        )
        await session.execute(
            delete(OrganizationMember).where(
                OrganizationMember.user_id == user.id
            )
        )
        await session.execute(delete(Device).where(Device.user_id == user.id))
        await session.execute(
            delete(RefreshToken).where(RefreshToken.user_id == user.id)
        )
        audit_service.record(
            session,
            action="account_deleted",
            user_id=user.id,
            entity="users",
            entity_id=str(user.id),
            ip=client_ip,
            meta={"phone": anonymized_phone},
        )
        await session.commit()

        try:
            from app.workers.tasks_media import purge_user_media

            purge_user_media.delay(str(user.id))
        except Exception as exc:
            logger.warning(
                "purge_user_media_enqueue_failed",
                user_id=str(user.id),
                error=str(exc),
            )


user_service = UserService()
