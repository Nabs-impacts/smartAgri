import math

from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.errors import QuotaExceededException
from app.db.models.farming import Farm, Plot
from app.db.models.identity import User
from app.db.models.media_ai import MediaFile
from app.services.subscription_service import subscription_service

_MEGABYTE = 1024 * 1024


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

        used_bytes = (
            await session.execute(
                select(func.coalesce(func.sum(MediaFile.size_bytes), 0)).where(
                    MediaFile.owner_id == user.id,
                    MediaFile.deleted_at.is_(None),
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


async def ensure_storage_quota(
    session: AsyncSession,
    user: User,
    additional_bytes: int,
) -> None:
    await quota_service.ensure_storage_quota(session, user, additional_bytes)
