import uuid
from datetime import UTC, date, datetime, time, timedelta
from decimal import Decimal

from sqlalchemy import and_, func, or_, select, text
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.errors import ConflictException, NotFoundException, ValidationException
from app.core.pagination import decode_cursor, encode_cursor
from app.db.models.farming import Crop, CropCycle, Farm, FarmActivity, Harvest, Plot
from app.db.models.identity import User
from app.schemas.cycle import (
    ActivityCreateRequest,
    ActivityResponse,
    ActivityUpdateRequest,
    CycleComparisonResponse,
    CycleCreateRequest,
    CycleResponse,
    CycleSummaryResponse,
    CycleUpdateRequest,
    HarvestCreateRequest,
    HarvestResponse,
    TimelineItem,
)
from app.services.access_service import can_read_farm

ALLOWED_TRANSITIONS: dict[str, set[str]] = {
    "planned": {"growing"},
    "growing": {"harvested", "failed"},
    "harvested": set(),
    "failed": set(),
}


def cycle_to_response(cycle: CropCycle) -> CycleResponse:
    return CycleResponse(
        id=cycle.id,
        plot_id=cycle.plot_id,
        crop_id=cycle.crop_id,
        variety=cycle.variety,
        season=cycle.season,
        sowing_date=cycle.sowing_date,
        expected_harvest_date=cycle.expected_harvest_date,
        harvest_date=cycle.harvest_date,
        status=cycle.status,
        notes=cycle.notes,
        created_at=cycle.created_at,
        updated_at=cycle.updated_at,
    )


def activity_to_response(activity: FarmActivity) -> ActivityResponse:
    return ActivityResponse(
        id=activity.id,
        crop_cycle_id=activity.crop_cycle_id,
        type=activity.type,
        performed_on=activity.performed_on,
        product_name=activity.product_name,
        quantity=activity.quantity,
        unit=activity.unit,
        cost_xof=activity.cost_xof,
        notes=activity.notes,
        created_at=activity.created_at,
        updated_at=activity.updated_at,
    )


def harvest_to_response(harvest: Harvest) -> HarvestResponse:
    return HarvestResponse(
        id=harvest.id,
        crop_cycle_id=harvest.crop_cycle_id,
        harvested_on=harvest.harvested_on,
        quantity_kg=harvest.quantity_kg,
        quality=harvest.quality,
        sold_kg=harvest.sold_kg,
        avg_price_xof_per_kg=harvest.avg_price_xof_per_kg,
        created_at=harvest.created_at,
        updated_at=harvest.updated_at,
    )


def _raise_existing_resource_conflict(
    owner_id: uuid.UUID,
    user_id: uuid.UUID,
    deleted: bool,
) -> None:
    if owner_id != user_id:
        raise ConflictException("Une ressource avec cet identifiant existe déjà.")
    if deleted:
        raise ConflictException("Cette ressource a été supprimée.")


def _date_cursor(value: date) -> datetime:
    return datetime.combine(value, time.min, tzinfo=UTC)


def _parse_uuid_cursor(cursor: str) -> tuple[datetime, uuid.UUID]:
    cursor_dt, cursor_id = decode_cursor(cursor)
    try:
        cursor_uuid = uuid.UUID(cursor_id)
    except (ValueError, TypeError) as err:
        raise ValidationException("Curseur de pagination invalide.") from err
    return cursor_dt, cursor_uuid


class CycleService:
    async def _load_owned_cycle(
        self,
        session: AsyncSession,
        user_id: uuid.UUID,
        cycle_id: uuid.UUID,
    ) -> tuple[CropCycle, Farm]:
        stmt = (
            select(CropCycle, Farm)
            .join(Plot, CropCycle.plot_id == Plot.id)
            .join(Farm, Plot.farm_id == Farm.id)
            .where(
                CropCycle.id == cycle_id,
                CropCycle.deleted_at.is_(None),
                Plot.deleted_at.is_(None),
                Farm.deleted_at.is_(None),
            )
        )
        row = (await session.execute(stmt)).first()
        if row is None or row[1].owner_id != user_id:
            raise NotFoundException("Cycle cultural introuvable.")
        return row[0], row[1]

    async def _load_owned_plot(
        self,
        session: AsyncSession,
        user_id: uuid.UUID,
        plot_id: uuid.UUID,
    ) -> Plot:
        stmt = (
            select(Plot, Farm.owner_id)
            .join(Farm, Plot.farm_id == Farm.id)
            .where(
                Plot.id == plot_id,
                Plot.deleted_at.is_(None),
                Farm.deleted_at.is_(None),
            )
        )
        row = (await session.execute(stmt)).first()
        if row is None or row[1] != user_id:
            raise NotFoundException("Parcelle introuvable.")
        return row[0]

    async def _load_readable_cycle(
        self,
        session: AsyncSession,
        user_id: uuid.UUID,
        cycle_id: uuid.UUID,
    ) -> tuple[CropCycle, Farm]:
        stmt = (
            select(CropCycle, Farm)
            .join(Plot, CropCycle.plot_id == Plot.id)
            .join(Farm, Plot.farm_id == Farm.id)
            .where(
                CropCycle.id == cycle_id,
                CropCycle.deleted_at.is_(None),
                Plot.deleted_at.is_(None),
                Farm.deleted_at.is_(None),
            )
        )
        row = (await session.execute(stmt)).first()
        if row is None or not await can_read_farm(session, user_id, row[1]):
            raise NotFoundException("Cycle cultural introuvable.")
        return row[0], row[1]

    async def _load_readable_plot(
        self,
        session: AsyncSession,
        user_id: uuid.UUID,
        plot_id: uuid.UUID,
    ) -> Plot:
        stmt = (
            select(Plot, Farm)
            .join(Farm, Plot.farm_id == Farm.id)
            .where(
                Plot.id == plot_id,
                Plot.deleted_at.is_(None),
                Farm.deleted_at.is_(None),
            )
        )
        row = (await session.execute(stmt)).first()
        if row is None or not await can_read_farm(session, user_id, row[1]):
            raise NotFoundException("Parcelle introuvable.")
        return row[0]

    async def _load_owned_activity(
        self,
        session: AsyncSession,
        user_id: uuid.UUID,
        activity_id: uuid.UUID,
    ) -> FarmActivity:
        stmt = (
            select(FarmActivity, Farm.owner_id)
            .join(CropCycle, FarmActivity.crop_cycle_id == CropCycle.id)
            .join(Plot, CropCycle.plot_id == Plot.id)
            .join(Farm, Plot.farm_id == Farm.id)
            .where(
                FarmActivity.id == activity_id,
                FarmActivity.deleted_at.is_(None),
                CropCycle.deleted_at.is_(None),
                Plot.deleted_at.is_(None),
                Farm.deleted_at.is_(None),
            )
        )
        row = (await session.execute(stmt)).first()
        if row is None or row[1] != user_id:
            raise NotFoundException("Activité introuvable.")
        return row[0]

    async def _find_cycle_for_id(
        self,
        session: AsyncSession,
        resource_id: uuid.UUID,
    ) -> tuple[CropCycle, uuid.UUID, bool] | None:
        stmt = (
            select(
                CropCycle,
                Farm.owner_id,
                Plot.deleted_at,
                Farm.deleted_at,
            )
            .join(Plot, CropCycle.plot_id == Plot.id)
            .join(Farm, Plot.farm_id == Farm.id)
            .where(CropCycle.id == resource_id)
        )
        row = (await session.execute(stmt)).first()
        if row is None:
            return None
        cycle, owner_id, plot_deleted_at, farm_deleted_at = row
        deleted = (
            cycle.deleted_at is not None
            or plot_deleted_at is not None
            or farm_deleted_at is not None
        )
        return cycle, owner_id, deleted

    async def _find_activity_for_id(
        self,
        session: AsyncSession,
        resource_id: uuid.UUID,
    ) -> tuple[FarmActivity, uuid.UUID, bool] | None:
        stmt = (
            select(
                FarmActivity,
                Farm.owner_id,
                CropCycle.deleted_at,
                Plot.deleted_at,
                Farm.deleted_at,
            )
            .join(CropCycle, FarmActivity.crop_cycle_id == CropCycle.id)
            .join(Plot, CropCycle.plot_id == Plot.id)
            .join(Farm, Plot.farm_id == Farm.id)
            .where(FarmActivity.id == resource_id)
        )
        row = (await session.execute(stmt)).first()
        if row is None:
            return None
        activity, owner_id, cycle_deleted_at, plot_deleted_at, farm_deleted_at = row
        deleted = (
            activity.deleted_at is not None
            or cycle_deleted_at is not None
            or plot_deleted_at is not None
            or farm_deleted_at is not None
        )
        return activity, owner_id, deleted

    async def _find_harvest_for_id(
        self,
        session: AsyncSession,
        resource_id: uuid.UUID,
    ) -> tuple[Harvest, uuid.UUID, bool] | None:
        stmt = (
            select(
                Harvest,
                Farm.owner_id,
                CropCycle.deleted_at,
                Plot.deleted_at,
                Farm.deleted_at,
            )
            .join(CropCycle, Harvest.crop_cycle_id == CropCycle.id)
            .join(Plot, CropCycle.plot_id == Plot.id)
            .join(Farm, Plot.farm_id == Farm.id)
            .where(Harvest.id == resource_id)
        )
        row = (await session.execute(stmt)).first()
        if row is None:
            return None
        harvest, owner_id, cycle_deleted_at, plot_deleted_at, farm_deleted_at = row
        deleted = (
            harvest.deleted_at is not None
            or cycle_deleted_at is not None
            or plot_deleted_at is not None
            or farm_deleted_at is not None
        )
        return harvest, owner_id, deleted

    async def list_cycles(
        self,
        session: AsyncSession,
        user_id: uuid.UUID,
        plot_id: uuid.UUID,
        limit: int = 20,
        cursor: str | None = None,
    ) -> tuple[list[CycleResponse], str | None]:
        await self._load_readable_plot(session, user_id, plot_id)

        stmt = select(CropCycle).where(
            CropCycle.plot_id == plot_id,
            CropCycle.deleted_at.is_(None),
        )

        if cursor:
            cursor_dt, cursor_uuid = _parse_uuid_cursor(cursor)
            stmt = stmt.where(
                or_(
                    CropCycle.created_at < cursor_dt,
                    and_(
                        CropCycle.created_at == cursor_dt,
                        CropCycle.id < cursor_uuid,
                    ),
                )
            )

        stmt = stmt.order_by(
            CropCycle.created_at.desc(), CropCycle.id.desc()
        ).limit(limit + 1)
        rows = list((await session.scalars(stmt)).all())

        if len(rows) > limit:
            items = rows[:limit]
            next_cursor = encode_cursor(items[-1].created_at, items[-1].id)
        else:
            items = rows
            next_cursor = None

        return [cycle_to_response(cycle) for cycle in items], next_cursor

    async def create_cycle(
        self,
        session: AsyncSession,
        user: User,
        plot_id: uuid.UUID,
        data: CycleCreateRequest,
    ) -> tuple[CycleResponse, bool]:
        user_id = user.id
        await self._load_owned_plot(session, user_id, plot_id)

        if data.id is not None:
            existing = await self._find_cycle_for_id(session, data.id)
            if existing is not None:
                cycle, owner_id, deleted = existing
                _raise_existing_resource_conflict(owner_id, user_id, deleted)
                return cycle_to_response(cycle), False

        crop = await session.get(Crop, data.crop_id)
        if crop is None:
            raise NotFoundException("Culture introuvable.")

        expected_harvest_date = data.expected_harvest_date
        if (
            expected_harvest_date is None
            and data.sowing_date is not None
            and crop.cycle_days is not None
        ):
            expected_harvest_date = data.sowing_date + timedelta(days=crop.cycle_days)

        cycle = CropCycle(
            id=data.id or uuid.uuid4(),
            plot_id=plot_id,
            crop_id=data.crop_id,
            variety=data.variety,
            season=data.season,
            sowing_date=data.sowing_date,
            expected_harvest_date=expected_harvest_date,
            harvest_date=data.harvest_date,
            status=data.status,
            notes=data.notes,
        )
        session.add(cycle)
        try:
            await session.commit()
        except IntegrityError:
            await session.rollback()
            if data.id is not None:
                existing = await self._find_cycle_for_id(session, data.id)
                if existing is not None:
                    cycle, owner_id, deleted = existing
                    _raise_existing_resource_conflict(owner_id, user_id, deleted)
                    return cycle_to_response(cycle), False
            raise

        await session.refresh(cycle)
        return cycle_to_response(cycle), True

    async def get_cycle(
        self,
        session: AsyncSession,
        user_id: uuid.UUID,
        cycle_id: uuid.UUID,
    ) -> CycleResponse:
        cycle, _ = await self._load_readable_cycle(session, user_id, cycle_id)
        return cycle_to_response(cycle)

    async def update_cycle(
        self,
        session: AsyncSession,
        user_id: uuid.UUID,
        cycle_id: uuid.UUID,
        data: CycleUpdateRequest,
    ) -> CycleResponse:
        cycle, _ = await self._load_owned_cycle(session, user_id, cycle_id)

        if data.status is not None and data.status != cycle.status:
            if data.status not in ALLOWED_TRANSITIONS.get(cycle.status, set()):
                raise ConflictException("Transition de statut non autorisée.")
            cycle.status = data.status

        if data.variety is not None:
            cycle.variety = data.variety
        if data.season is not None:
            cycle.season = data.season
        if data.sowing_date is not None:
            cycle.sowing_date = data.sowing_date
        if data.expected_harvest_date is not None:
            cycle.expected_harvest_date = data.expected_harvest_date
        if data.harvest_date is not None:
            cycle.harvest_date = data.harvest_date
        if data.notes is not None:
            cycle.notes = data.notes

        await session.commit()
        await session.refresh(cycle)
        return cycle_to_response(cycle)

    async def list_activities(
        self,
        session: AsyncSession,
        user_id: uuid.UUID,
        cycle_id: uuid.UUID,
        limit: int = 20,
        cursor: str | None = None,
    ) -> tuple[list[ActivityResponse], str | None]:
        await self._load_readable_cycle(session, user_id, cycle_id)

        stmt = select(FarmActivity).where(
            FarmActivity.crop_cycle_id == cycle_id,
            FarmActivity.deleted_at.is_(None),
        )

        if cursor:
            cursor_dt, cursor_uuid = _parse_uuid_cursor(cursor)
            cursor_date = cursor_dt.date()
            stmt = stmt.where(
                or_(
                    FarmActivity.performed_on < cursor_date,
                    and_(
                        FarmActivity.performed_on == cursor_date,
                        FarmActivity.id < cursor_uuid,
                    ),
                )
            )

        stmt = stmt.order_by(
            FarmActivity.performed_on.desc(), FarmActivity.id.desc()
        ).limit(limit + 1)
        rows = list((await session.scalars(stmt)).all())

        if len(rows) > limit:
            items = rows[:limit]
            next_cursor = encode_cursor(
                _date_cursor(items[-1].performed_on), items[-1].id
            )
        else:
            items = rows
            next_cursor = None

        return [activity_to_response(activity) for activity in items], next_cursor

    async def create_activity(
        self,
        session: AsyncSession,
        user: User,
        cycle_id: uuid.UUID,
        data: ActivityCreateRequest,
    ) -> tuple[ActivityResponse, bool]:
        user_id = user.id
        await self._load_owned_cycle(session, user_id, cycle_id)

        if data.id is not None:
            existing = await self._find_activity_for_id(session, data.id)
            if existing is not None:
                activity, owner_id, deleted = existing
                _raise_existing_resource_conflict(owner_id, user_id, deleted)
                return activity_to_response(activity), False

        activity = FarmActivity(
            id=data.id or uuid.uuid4(),
            crop_cycle_id=cycle_id,
            type=data.type,
            performed_on=data.performed_on,
            product_name=data.product_name,
            quantity=data.quantity,
            unit=data.unit,
            cost_xof=data.cost_xof,
            notes=data.notes,
        )
        session.add(activity)
        try:
            await session.commit()
        except IntegrityError:
            await session.rollback()
            if data.id is not None:
                existing = await self._find_activity_for_id(session, data.id)
                if existing is not None:
                    activity, owner_id, deleted = existing
                    _raise_existing_resource_conflict(owner_id, user_id, deleted)
                    return activity_to_response(activity), False
            raise

        await session.refresh(activity)
        return activity_to_response(activity), True

    async def update_activity(
        self,
        session: AsyncSession,
        user_id: uuid.UUID,
        activity_id: uuid.UUID,
        data: ActivityUpdateRequest,
    ) -> ActivityResponse:
        activity = await self._load_owned_activity(session, user_id, activity_id)

        if data.type is not None:
            activity.type = data.type
        if data.performed_on is not None:
            activity.performed_on = data.performed_on
        if data.product_name is not None:
            activity.product_name = data.product_name
        if data.quantity is not None:
            activity.quantity = data.quantity
        if data.unit is not None:
            activity.unit = data.unit
        if data.cost_xof is not None:
            activity.cost_xof = data.cost_xof
        if data.notes is not None:
            activity.notes = data.notes

        await session.commit()
        await session.refresh(activity)
        return activity_to_response(activity)

    async def delete_activity(
        self,
        session: AsyncSession,
        user_id: uuid.UUID,
        activity_id: uuid.UUID,
    ) -> None:
        activity = await self._load_owned_activity(session, user_id, activity_id)
        activity.deleted_at = datetime.now(UTC)
        await session.commit()

    async def create_harvest(
        self,
        session: AsyncSession,
        user: User,
        cycle_id: uuid.UUID,
        data: HarvestCreateRequest,
    ) -> tuple[HarvestResponse, bool]:
        user_id = user.id
        cycle, _ = await self._load_owned_cycle(session, user_id, cycle_id)

        if data.id is not None:
            existing = await self._find_harvest_for_id(session, data.id)
            if existing is not None:
                harvest, owner_id, deleted = existing
                _raise_existing_resource_conflict(owner_id, user_id, deleted)
                return harvest_to_response(harvest), False

        harvest = Harvest(
            id=data.id or uuid.uuid4(),
            crop_cycle_id=cycle_id,
            harvested_on=data.harvested_on,
            quantity_kg=data.quantity_kg,
            quality=data.quality,
            sold_kg=data.sold_kg,
            avg_price_xof_per_kg=data.avg_price_xof_per_kg,
        )
        session.add(harvest)

        if data.close_cycle:
            if cycle.status == "failed":
                raise ConflictException("Transition de statut non autorisée.")
            if cycle.status in ("planned", "growing"):
                cycle.status = "harvested"
                cycle.harvest_date = data.harvested_on

        try:
            await session.commit()
        except IntegrityError:
            await session.rollback()
            if data.id is not None:
                existing = await self._find_harvest_for_id(session, data.id)
                if existing is not None:
                    harvest, owner_id, deleted = existing
                    _raise_existing_resource_conflict(owner_id, user_id, deleted)
                    return harvest_to_response(harvest), False
            raise

        await session.refresh(harvest)
        return harvest_to_response(harvest), True

    async def get_summary(
        self,
        session: AsyncSession,
        user_id: uuid.UUID,
        cycle_id: uuid.UUID,
    ) -> CycleSummaryResponse:
        cycle, farm = await self._load_readable_cycle(session, user_id, cycle_id)

        view_row = (
            await session.execute(
                text(
                    "SELECT area_ha, total_kg, yield_kg_per_ha "
                    "FROM v_cycle_yield WHERE crop_cycle_id = :cycle_id"
                ),
                {"cycle_id": cycle_id},
            )
        ).mappings().first()

        if view_row is None:
            area_ha = None
            total_kg = Decimal("0")
            yield_kg_per_ha = None
        else:
            area_ha = view_row["area_ha"]
            total_kg = view_row["total_kg"] or Decimal("0")
            yield_kg_per_ha = view_row["yield_kg_per_ha"]

        total_cost = (
            await session.execute(
                select(func.coalesce(func.sum(FarmActivity.cost_xof), 0)).where(
                    FarmActivity.crop_cycle_id == cycle_id,
                    FarmActivity.deleted_at.is_(None),
                )
            )
        ).scalar_one()

        revenue = (
            await session.execute(
                select(
                    func.coalesce(
                        func.sum(
                            Harvest.sold_kg * Harvest.avg_price_xof_per_kg
                        ),
                        0,
                    )
                ).where(
                    Harvest.crop_cycle_id == cycle_id,
                    Harvest.deleted_at.is_(None),
                )
            )
        ).scalar_one()

        revenue = Decimal(revenue or 0)
        total_cost = int(total_cost or 0)
        margin = revenue - Decimal(total_cost)

        comparison = None
        if farm.admin_area_id is not None:
            row = (
                await session.execute(
                    text(
                        "SELECT COUNT(*) AS sample_size, "
                        "ROUND(AVG(v.yield_kg_per_ha), 1) AS average_yield "
                        "FROM v_cycle_yield v "
                        "JOIN crop_cycles cc ON cc.id = v.crop_cycle_id "
                        "JOIN plots p ON p.id = cc.plot_id "
                        "JOIN farms f ON f.id = p.farm_id "
                        "WHERE cc.crop_id = :crop_id "
                        "AND f.admin_area_id = :admin_area_id "
                        "AND f.owner_id <> :owner_id "
                        "AND cc.deleted_at IS NULL "
                        "AND p.deleted_at IS NULL "
                        "AND f.deleted_at IS NULL"
                    ),
                    {
                        "crop_id": cycle.crop_id,
                        "admin_area_id": farm.admin_area_id,
                        "owner_id": farm.owner_id,
                    },
                )
            ).mappings().one()
            if row["sample_size"] >= 5:
                comparison = CycleComparisonResponse(
                    sample_size=row["sample_size"],
                    average_yield_kg_per_ha=row["average_yield"],
                )

        return CycleSummaryResponse(
            cycle_id=cycle_id,
            area_ha=area_ha,
            total_kg=total_kg,
            yield_kg_per_ha=yield_kg_per_ha,
            total_cost_xof=total_cost,
            revenue_xof=revenue,
            margin_xof=margin,
            comparison=comparison,
        )

    async def get_timeline(
        self,
        session: AsyncSession,
        user_id: uuid.UUID,
        plot_id: uuid.UUID,
        limit: int = 20,
        cursor: str | None = None,
    ) -> tuple[list[TimelineItem], str | None]:
        await self._load_readable_plot(session, user_id, plot_id)

        cursor_date = None
        cursor_uuid = None
        if cursor:
            cursor_dt, cursor_uuid = _parse_uuid_cursor(cursor)
            cursor_date = cursor_dt.date()

        activities_stmt = (
            select(FarmActivity)
            .join(CropCycle, FarmActivity.crop_cycle_id == CropCycle.id)
            .where(
                CropCycle.plot_id == plot_id,
                FarmActivity.deleted_at.is_(None),
                CropCycle.deleted_at.is_(None),
            )
        )
        harvests_stmt = (
            select(Harvest)
            .join(CropCycle, Harvest.crop_cycle_id == CropCycle.id)
            .where(
                CropCycle.plot_id == plot_id,
                Harvest.deleted_at.is_(None),
                CropCycle.deleted_at.is_(None),
            )
        )

        if cursor_date is not None and cursor_uuid is not None:
            activities_stmt = activities_stmt.where(
                or_(
                    FarmActivity.performed_on < cursor_date,
                    and_(
                        FarmActivity.performed_on == cursor_date,
                        FarmActivity.id < cursor_uuid,
                    ),
                )
            )
            harvests_stmt = harvests_stmt.where(
                or_(
                    Harvest.harvested_on < cursor_date,
                    and_(
                        Harvest.harvested_on == cursor_date,
                        Harvest.id < cursor_uuid,
                    ),
                )
            )

        activities_stmt = activities_stmt.order_by(
            FarmActivity.performed_on.desc(), FarmActivity.id.desc()
        ).limit(limit + 1)
        harvests_stmt = harvests_stmt.order_by(
            Harvest.harvested_on.desc(), Harvest.id.desc()
        ).limit(limit + 1)

        activities = list((await session.scalars(activities_stmt)).all())
        harvests = list((await session.scalars(harvests_stmt)).all())

        events: list[tuple[date, uuid.UUID, str, FarmActivity | Harvest]] = []
        events.extend(
            (activity.performed_on, activity.id, "activity", activity)
            for activity in activities
        )
        events.extend(
            (harvest.harvested_on, harvest.id, "harvest", harvest)
            for harvest in harvests
        )
        events.sort(key=lambda event: (event[0], event[1]), reverse=True)

        has_more = len(events) > limit
        selected = events[:limit]
        next_cursor = None
        if has_more and selected:
            last_date, last_id, _, _ = selected[-1]
            next_cursor = encode_cursor(_date_cursor(last_date), last_id)

        items: list[TimelineItem] = []
        for occurred_on, event_id, event_type, event in selected:
            activity = activity_to_response(event) if event_type == "activity" else None
            harvest = harvest_to_response(event) if event_type == "harvest" else None
            items.append(
                TimelineItem(
                    id=event_id,
                    type=event_type,
                    occurred_on=occurred_on,
                    created_at=event.created_at,
                    activity=activity,
                    harvest=harvest,
                )
            )

        return items, next_cursor


cycle_service = CycleService()
