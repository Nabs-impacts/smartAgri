import uuid
from datetime import UTC, datetime

from sqlalchemy import or_, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.errors import InternalErrorException
from app.db.models.billing import Plan, Subscription
from app.db.models.organizations import OrganizationMember


class SubscriptionService:
    async def get_effective_subscription(
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


subscription_service = SubscriptionService()
