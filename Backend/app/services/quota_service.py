from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.errors import QuotaExceededException
from app.db.models.farming import Farm, Plot
from app.db.models.identity import User
from app.services.subscription_service import subscription_service


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


quota_service = QuotaService()


async def ensure_quota(
    session: AsyncSession,
    user: User,
    metric: str,
) -> None:
    await quota_service.ensure_quota(session, user, metric)
