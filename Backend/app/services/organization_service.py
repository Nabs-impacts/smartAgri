import uuid
from datetime import UTC, datetime
from decimal import Decimal

from sqlalchemy import and_, func, or_, select, text
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.errors import (
    ConflictException,
    ForbiddenException,
    NotFoundException,
    ValidationException,
)
from app.core.pagination import decode_cursor, encode_cursor
from app.core.security import normalize_phone
from app.db.models.billing import Plan, Subscription
from app.db.models.farming import Farm, Plot
from app.db.models.identity import AdminArea, User
from app.db.models.organizations import Organization, OrganizationMember
from app.schemas.farm import FarmResponse
from app.schemas.organization import (
    CropYieldResponse,
    OrganizationCreateRequest,
    OrganizationDashboardResponse,
    OrganizationMemberResponse,
    OrganizationResponse,
    OrganizationUpdateRequest,
)
from app.services.farm_service import farm_to_response

READ_ROLES = ("owner", "admin", "agent")
WRITE_ROLES = ("owner", "admin")


class OrganizationService:
    async def _ensure_admin_area(
        self, session: AsyncSession, admin_area_id: int
    ) -> None:
        exists = (
            await session.execute(
                select(AdminArea.id).where(AdminArea.id == admin_area_id)
            )
        ).scalar_one_or_none()
        if not exists:
            raise NotFoundException("Zone administrative introuvable.")

    async def _require_member(
        self,
        session: AsyncSession,
        organization_id: uuid.UUID,
        user_id: uuid.UUID,
    ) -> tuple[Organization, OrganizationMember]:
        organization = await session.get(Organization, organization_id)
        if organization is None:
            raise NotFoundException("Organisation introuvable.")
        membership = (
            await session.execute(
                select(OrganizationMember).where(
                    OrganizationMember.organization_id == organization_id,
                    OrganizationMember.user_id == user_id,
                )
            )
        ).scalar_one_or_none()
        if membership is None:
            raise NotFoundException("Organisation introuvable.")
        return organization, membership

    async def _require_roles(
        self,
        session: AsyncSession,
        organization_id: uuid.UUID,
        user_id: uuid.UUID,
        roles: tuple[str, ...],
    ) -> tuple[Organization, OrganizationMember]:
        organization, membership = await self._require_member(
            session, organization_id, user_id
        )
        if membership.member_role not in roles:
            raise ForbiddenException("Accès refusé pour ce rôle.")
        return organization, membership

    async def create_organization(
        self,
        session: AsyncSession,
        user: User,
        data: OrganizationCreateRequest,
    ) -> OrganizationResponse:
        if data.admin_area_id is not None:
            await self._ensure_admin_area(session, data.admin_area_id)
        organization = Organization(
            name=data.name,
            type=data.type,
            registration_no=data.registration_no,
            admin_area_id=data.admin_area_id,
            contact_phone=data.contact_phone,
            contact_email=data.contact_email,
        )
        session.add(organization)
        await session.flush()
        session.add(
            OrganizationMember(
                organization_id=organization.id,
                user_id=user.id,
                member_role="owner",
            )
        )
        await session.commit()
        await session.refresh(organization)
        return OrganizationResponse.model_validate(
            organization
        ).model_copy(update={"member_role": "owner"})

    async def list_organizations(
        self,
        session: AsyncSession,
        user_id: uuid.UUID,
        limit: int = 20,
        cursor: str | None = None,
    ) -> tuple[list[OrganizationResponse], str | None]:
        stmt = (
            select(Organization, OrganizationMember.member_role)
            .join(
                OrganizationMember,
                OrganizationMember.organization_id == Organization.id,
            )
            .where(OrganizationMember.user_id == user_id)
        )

        if cursor:
            cursor_dt, cursor_id = decode_cursor(cursor)
            try:
                cursor_uuid = uuid.UUID(cursor_id)
            except (ValueError, TypeError) as err:
                raise ValidationException("Curseur de pagination invalide.") from err
            stmt = stmt.where(
                or_(
                    Organization.created_at < cursor_dt,
                    and_(
                        Organization.created_at == cursor_dt,
                        Organization.id < cursor_uuid,
                    ),
                )
            )

        stmt = stmt.order_by(
            Organization.created_at.desc(), Organization.id.desc()
        ).limit(limit + 1)
        rows = list((await session.execute(stmt)).all())

        if len(rows) > limit:
            items = rows[:limit]
            next_cursor = encode_cursor(items[-1][0].created_at, items[-1][0].id)
        else:
            items = rows
            next_cursor = None

        responses = [
            OrganizationResponse.model_validate(organization).model_copy(
                update={"member_role": role}
            )
            for organization, role in items
        ]
        return responses, next_cursor

    async def get_organization(
        self,
        session: AsyncSession,
        user_id: uuid.UUID,
        organization_id: uuid.UUID,
    ) -> OrganizationResponse:
        organization, membership = await self._require_member(
            session, organization_id, user_id
        )
        return OrganizationResponse.model_validate(organization).model_copy(
            update={"member_role": membership.member_role}
        )

    async def update_organization(
        self,
        session: AsyncSession,
        user_id: uuid.UUID,
        organization_id: uuid.UUID,
        data: OrganizationUpdateRequest,
    ) -> OrganizationResponse:
        organization, membership = await self._require_roles(
            session, organization_id, user_id, WRITE_ROLES
        )

        if data.name is not None:
            organization.name = data.name
        if data.type is not None:
            organization.type = data.type
        if data.registration_no is not None:
            organization.registration_no = data.registration_no
        if data.admin_area_id is not None:
            await self._ensure_admin_area(session, data.admin_area_id)
            organization.admin_area_id = data.admin_area_id
        if data.contact_phone is not None:
            organization.contact_phone = data.contact_phone
        if data.contact_email is not None:
            organization.contact_email = data.contact_email

        await session.commit()
        await session.refresh(organization)
        return OrganizationResponse.model_validate(organization).model_copy(
            update={"member_role": membership.member_role}
        )

    async def _user_plot_metrics(
        self,
        session: AsyncSession,
        user_id: uuid.UUID,
    ) -> tuple[int, Decimal]:
        row = (
            await session.execute(
                select(
                    func.count(Plot.id),
                    func.coalesce(func.sum(Plot.area_ha), 0),
                )
                .join(Farm, Plot.farm_id == Farm.id)
                .where(
                    Farm.owner_id == user_id,
                    Farm.deleted_at.is_(None),
                    Plot.deleted_at.is_(None),
                )
            )
        ).one()
        return int(row[0]), Decimal(row[1] or 0)

    async def _member_response(
        self,
        session: AsyncSession,
        membership: OrganizationMember,
        user: User,
    ) -> OrganizationMemberResponse:
        plot_count, area_ha = await self._user_plot_metrics(session, user.id)
        return OrganizationMemberResponse(
            user_id=user.id,
            phone=user.phone,
            full_name=user.full_name,
            member_role=membership.member_role,
            joined_at=membership.joined_at,
            plot_count=plot_count,
            area_ha=area_ha,
        )

    async def list_members(
        self,
        session: AsyncSession,
        user_id: uuid.UUID,
        organization_id: uuid.UUID,
    ) -> list[OrganizationMemberResponse]:
        await self._require_roles(
            session, organization_id, user_id, READ_ROLES
        )
        rows = (
            await session.execute(
                select(OrganizationMember, User)
                .join(User, User.id == OrganizationMember.user_id)
                .where(OrganizationMember.organization_id == organization_id)
                .order_by(
                    OrganizationMember.joined_at, OrganizationMember.user_id
                )
            )
        ).all()
        return [
            await self._member_response(session, membership, member)
            for membership, member in rows
        ]

    async def add_member(
        self,
        session: AsyncSession,
        user_id: uuid.UUID,
        organization_id: uuid.UUID,
        phone: str,
        member_role: str,
    ) -> OrganizationMemberResponse:
        await self._require_roles(
            session, organization_id, user_id, WRITE_ROLES
        )
        norm_phone = normalize_phone(phone)
        member = (
            await session.execute(select(User).where(User.phone == norm_phone))
        ).scalar_one_or_none()

        if member is None:
            member = User(
                phone=norm_phone,
                full_name=norm_phone,
                role="farmer",
                is_active=True,
                password_hash=None,
            )
            session.add(member)
            await session.flush()
            free_plan = (
                await session.execute(
                    select(Plan).where(Plan.code == "free")
                )
            ).scalar_one_or_none()
            if free_plan is not None:
                session.add(
                    Subscription(
                        user_id=member.id,
                        plan_id=free_plan.id,
                        status="active",
                        current_period_start=datetime.now(UTC),
                        auto_renew=False,
                    )
                )
        elif member.deleted_at is not None:
            raise ConflictException(
                "Ce numéro de téléphone appartient à un compte supprimé."
            )

        existing = (
            await session.execute(
                select(OrganizationMember).where(
                    OrganizationMember.organization_id == organization_id,
                    OrganizationMember.user_id == member.id,
                )
            )
        ).scalar_one_or_none()
        if existing is not None:
            raise ConflictException(
                "Cet utilisateur est déjà membre de l'organisation."
            )

        membership = OrganizationMember(
            organization_id=organization_id,
            user_id=member.id,
            member_role=member_role,
        )
        session.add(membership)
        await session.commit()
        await session.refresh(membership)
        await session.refresh(member)
        return await self._member_response(session, membership, member)

    async def remove_member(
        self,
        session: AsyncSession,
        user_id: uuid.UUID,
        organization_id: uuid.UUID,
        member_user_id: uuid.UUID,
    ) -> None:
        await self._require_roles(
            session, organization_id, user_id, WRITE_ROLES
        )
        membership = (
            await session.execute(
                select(OrganizationMember).where(
                    OrganizationMember.organization_id == organization_id,
                    OrganizationMember.user_id == member_user_id,
                )
            )
        ).scalar_one_or_none()
        if membership is None:
            raise NotFoundException("Membre introuvable.")

        if membership.member_role == "owner":
            owner_count = (
                await session.execute(
                    select(func.count(OrganizationMember.user_id)).where(
                        OrganizationMember.organization_id == organization_id,
                        OrganizationMember.member_role == "owner",
                    )
                )
            ).scalar_one()
            if owner_count <= 1:
                raise ConflictException(
                    "Le dernier propriétaire ne peut pas être retiré."
                )

        await session.delete(membership)
        await session.commit()

    async def list_member_farms(
        self,
        session: AsyncSession,
        user_id: uuid.UUID,
        organization_id: uuid.UUID,
        limit: int = 20,
        cursor: str | None = None,
    ) -> tuple[list[FarmResponse], str | None]:
        await self._require_roles(
            session, organization_id, user_id, READ_ROLES
        )
        stmt = (
            select(Farm)
            .join(
                OrganizationMember,
                OrganizationMember.user_id == Farm.owner_id,
            )
            .where(
                OrganizationMember.organization_id == organization_id,
                Farm.deleted_at.is_(None),
            )
        )

        if cursor:
            cursor_dt, cursor_id = decode_cursor(cursor)
            try:
                cursor_uuid = uuid.UUID(cursor_id)
            except (ValueError, TypeError) as err:
                raise ValidationException("Curseur de pagination invalide.") from err
            stmt = stmt.where(
                or_(
                    Farm.created_at < cursor_dt,
                    and_(
                        Farm.created_at == cursor_dt,
                        Farm.id < cursor_uuid,
                    ),
                )
            )

        stmt = stmt.order_by(Farm.created_at.desc(), Farm.id.desc()).limit(limit + 1)
        rows = list((await session.scalars(stmt)).all())

        if len(rows) > limit:
            items = rows[:limit]
            next_cursor = encode_cursor(items[-1].created_at, items[-1].id)
        else:
            items = rows
            next_cursor = None

        return [farm_to_response(farm) for farm in items], next_cursor

    async def dashboard(
        self,
        session: AsyncSession,
        user_id: uuid.UUID,
        organization_id: uuid.UUID,
    ) -> OrganizationDashboardResponse:
        await self._require_roles(
            session, organization_id, user_id, WRITE_ROLES
        )

        member_count = (
            await session.execute(
                select(func.count(OrganizationMember.user_id)).where(
                    OrganizationMember.organization_id == organization_id
                )
            )
        ).scalar_one()

        aggregates = (
            await session.execute(
                select(
                    func.count(Plot.id),
                    func.coalesce(func.sum(Plot.area_ha), 0),
                )
                .join(Farm, Plot.farm_id == Farm.id)
                .join(
                    OrganizationMember,
                    OrganizationMember.user_id == Farm.owner_id,
                )
                .where(
                    OrganizationMember.organization_id == organization_id,
                    Farm.deleted_at.is_(None),
                    Plot.deleted_at.is_(None),
                )
            )
        ).one()

        yield_rows = (
            await session.execute(
                text(
                    "SELECT c.id AS crop_id, c.code AS crop_code, "
                    "c.name_fr AS crop_name, "
                    "COUNT(v.yield_kg_per_ha) AS sample_size, "
                    "ROUND(AVG(v.yield_kg_per_ha), 1) AS average_yield "
                    "FROM v_cycle_yield v "
                    "JOIN crop_cycles cc ON cc.id = v.crop_cycle_id "
                    "JOIN plots p ON p.id = cc.plot_id "
                    "JOIN farms f ON f.id = p.farm_id "
                    "JOIN crops c ON c.id = v.crop_id "
                    "JOIN organization_members om ON om.user_id = f.owner_id "
                    "WHERE om.organization_id = :organization_id "
                    "AND cc.deleted_at IS NULL "
                    "AND p.deleted_at IS NULL "
                    "AND f.deleted_at IS NULL "
                    "GROUP BY c.id, c.code, c.name_fr "
                    "ORDER BY c.name_fr"
                ),
                {"organization_id": organization_id},
            )
        ).mappings().all()

        yields = [
            CropYieldResponse(
                crop_id=row["crop_id"],
                crop_code=row["crop_code"],
                crop_name=row["crop_name"],
                average_yield_kg_per_ha=row["average_yield"],
                sample_size=int(row["sample_size"] or 0),
            )
            for row in yield_rows
        ]

        return OrganizationDashboardResponse(
            member_count=int(member_count),
            plot_count=int(aggregates[0]),
            total_area_ha=Decimal(aggregates[1] or 0),
            average_yield_by_crop=yields,
            diagnostics_this_month=0,
            active_alerts=0,
        )


organization_service = OrganizationService()
