import uuid

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.db.models.farming import Farm
from app.db.models.organizations import OrganizationMember

READ_ROLES = ("owner", "admin", "agent")


async def can_read_farm(
    session: AsyncSession,
    user_id: uuid.UUID,
    farm: Farm,
) -> bool:
    if farm.owner_id == user_id:
        return True
    owner_orgs = select(OrganizationMember.organization_id).where(
        OrganizationMember.user_id == farm.owner_id
    )
    membership = (
        await session.execute(
            select(OrganizationMember.organization_id)
            .where(
                OrganizationMember.organization_id.in_(owner_orgs),
                OrganizationMember.user_id == user_id,
                OrganizationMember.member_role.in_(READ_ROLES),
            )
            .limit(1)
        )
    ).scalar_one_or_none()
    return membership is not None
