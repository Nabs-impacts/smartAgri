import math
from datetime import UTC, datetime, timedelta

from sqlalchemy import func, or_, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.errors import QuotaExceededException
from app.db.models.billing import UsageRecord
from app.db.models.farming import Farm, Plot
from app.db.models.identity import User
from app.db.models.media_ai import MediaFile
from app.services.subscription_service import subscription_service

_MEGABYTE = 1024 * 1024

_MONTHLY_METRIC_KEYS = {
    "diagnostic": "diagnostics_per_month",
    "video_analysis": "video_analyses_per_month",
}


class QuotaService:
    async def ensure_quota(
        self,
        session: AsyncSession,
        user: User,
        metric: str,
    ) -> None:
        _, plan = await subscription_service.get_effective_subscription(session, user.id)
        quotas = plan.quotas or {}
        limit = quotas.get(metric, 0)

        if limit == -1:
            return

        if metric == "plots":
            stmt = (
                select(func.count(Plot.id))
                .select_from(Plot)
                .join(Farm, Plot.farm_id == Farm.id)
                .where(
                    Farm.owner_id == user.id,
                    Farm.deleted_at.is_(None),
                    Plot.deleted_at.is_(None),
                )
            )
            used = (await session.execute(stmt)).scalar_one() or 0

            if used >= limit:
                raise QuotaExceededException(
                    message="Quota de parcelles dépassé pour votre forfait.",
                    details={"metric": metric, "limit": limit, "used": used},
                )

    async def ensure_monthly_quota(
        self,
        session: AsyncSession,
        user: User,
        metric: str,
    ) -> None:
        key = _MONTHLY_METRIC_KEYS.get(metric, metric)
        subscription, plan = await subscription_service.get_effective_subscription(
            session, user.id
        )
        quotas = plan.quotas or {}
        limit = quotas.get(key)
        if limit is None or limit == -1:
            return

        used = 0
        if subscription is not None:
            period = datetime.now(UTC).date().replace(day=1)
            stmt = select(
                func.coalesce(func.sum(UsageRecord.quantity), 0)
            ).where(
                UsageRecord.subscription_id == subscription.id,
                UsageRecord.metric == metric,
                UsageRecord.period == period,
            )
            used = int((await session.execute(stmt)).scalar_one() or 0)

        if used >= limit:
            raise QuotaExceededException(
                details={"metric": metric, "limit": limit, "used": used},
            )

    async def ensure_storage_quota(
        self,
        session: AsyncSession,
        user: User,
        additional_bytes: int,
    ) -> None:
        _, plan = await subscription_service.get_effective_subscription(session, user.id)
        quotas = plan.quotas or {}
        if "storage_mb" not in quotas:
            return
        limit = quotas["storage_mb"]
        if limit is None or limit == -1:
            return

        pending_cutoff = datetime.now(UTC) - timedelta(hours=24)
        used_bytes = (
            await session.execute(
                select(func.coalesce(func.sum(MediaFile.size_bytes), 0)).where(
                    MediaFile.owner_id == user.id,
                    MediaFile.deleted_at.is_(None),
                    or_(
                        MediaFile.upload_status == "uploaded",
                        (
                            (MediaFile.upload_status == "pending")
                            & (MediaFile.created_at >= pending_cutoff)
                        ),
                    ),
                )
            )
        ).scalar_one() or 0
        used_mb = math.ceil(int(used_bytes) / _MEGABYTE)
        projected_mb = math.ceil((int(used_bytes) + additional_bytes) / _MEGABYTE)

        if projected_mb > limit:
            raise QuotaExceededException(
                message="Quota de stockage dépassé pour votre forfait.",
                details={"metric": "storage_mb", "limit": limit, "used": used_mb},
            )


quota_service = QuotaService()


async def ensure_quota(
    session: AsyncSession,
    user: User,
    metric: str,
) -> None:
    await quota_service.ensure_quota(session, user, metric)


async def ensure_monthly_quota(
    session: AsyncSession,
    user: User,
    metric: str,
) -> None:
    await quota_service.ensure_monthly_quota(session, user, metric)


async def ensure_storage_quota(
    session: AsyncSession,
    user: User,
    additional_bytes: int,
) -> None:
    await quota_service.ensure_storage_quota(session, user, additional_bytes)
