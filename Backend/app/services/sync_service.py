import uuid
from datetime import UTC, datetime, timedelta

from pydantic import ValidationError
from sqlalchemy import and_, literal, or_, select, union_all, update
from sqlalchemy.exc import SQLAlchemyError
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.errors import AppException
from app.core.geo import (
    compute_area_ha,
    geojson_to_postgis_point,
    geojson_to_postgis_polygon,
    postgis_to_geojson,
)
from app.core.pagination import decode_cursor, encode_cursor
from app.db.models.farming import Crop, CropCycle, Farm, FarmActivity, Harvest, Plot
from app.db.models.identity import User
from app.schemas.sync import (
    CropCycleSyncData,
    FarmActivitySyncData,
    FarmSyncData,
    HarvestSyncData,
    PlotSyncData,
    SyncChange,
    SyncChangeItem,
    SyncPullResponse,
    SyncPushResponse,
    SyncResult,
)
from app.services.quota_service import ensure_quota

FUTURE_TOLERANCE = timedelta(minutes=5)
OTHER_USER_ERROR = "Cette ressource appartient à un autre utilisateur."
DELETED_ERROR = "Cette ressource a été supprimée."
INVALID_ERROR = "Donnée synchronisée invalide."
PARENT_ERROR = "Ressource parente introuvable."


def _as_utc(value: datetime) -> datetime:
    if value.tzinfo is None:
        return value.replace(tzinfo=UTC)
    return value.astimezone(UTC)


class SyncService:
    async def push(
        self,
        session: AsyncSession,
        user: User,
        changes: list[SyncChange],
    ) -> SyncPushResponse:
        now = datetime.now(UTC)
        results: list[SyncResult] = []
        for change in changes:
            client_updated = _as_utc(change.updated_at)
            if client_updated > now + FUTURE_TOLERANCE:
                client_updated = now
            try:
                async with session.begin_nested():
                    result = await self._process(
                        session, user, change, client_updated, now
                    )
            except AppException as err:
                result = SyncResult(
                    id=change.id,
                    entity=change.entity,
                    status="rejected",
                    error=err.message,
                )
            except (ValidationError, SQLAlchemyError, ValueError):
                result = SyncResult(
                    id=change.id,
                    entity=change.entity,
                    status="rejected",
                    error=INVALID_ERROR,
                )
            results.append(result)
        await session.commit()
        return SyncPushResponse(results=results)

    async def _process(
        self,
        session: AsyncSession,
        user: User,
        change: SyncChange,
        client_updated: datetime,
        now: datetime,
    ) -> SyncResult:
        if change.op == "delete":
            return await self._delete(session, user, change)
        return await self._upsert(session, user, change, client_updated)

    def _applied(
        self, change: SyncChange, server_updated_at: datetime | None
    ) -> SyncResult:
        return SyncResult(
            id=change.id,
            entity=change.entity,
            status="applied",
            server_updated_at=server_updated_at,
        )

    def _conflict(
        self, change: SyncChange, server_updated_at: datetime
    ) -> SyncResult:
        return SyncResult(
            id=change.id,
            entity=change.entity,
            status="conflict",
            server_updated_at=server_updated_at,
        )

    def _rejected(self, change: SyncChange, error: str) -> SyncResult:
        return SyncResult(
            id=change.id,
            entity=change.entity,
            status="rejected",
            error=error,
        )

    async def _upsert(
        self,
        session: AsyncSession,
        user: User,
        change: SyncChange,
        client_updated: datetime,
    ) -> SyncResult:
        handlers = {
            "farm": self._upsert_farm,
            "plot": self._upsert_plot,
            "crop_cycle": self._upsert_cycle,
            "farm_activity": self._upsert_activity,
            "harvest": self._upsert_harvest,
        }
        return await handlers[change.entity](session, user, change, client_updated)

    async def _upsert_farm(
        self,
        session: AsyncSession,
        user: User,
        change: SyncChange,
        client_updated: datetime,
    ) -> SyncResult:
        data = FarmSyncData.model_validate(change.data)
        existing = await session.get(Farm, change.id)
        if existing is not None:
            if existing.owner_id != user.id:
                return self._rejected(change, OTHER_USER_ERROR)
            if existing.deleted_at is not None:
                return self._rejected(change, DELETED_ERROR)
            if client_updated <= existing.updated_at:
                return self._conflict(change, existing.updated_at)
            await self._apply_farm(session, existing, data)
            await session.flush()
            await session.refresh(existing)
            return self._applied(change, existing.updated_at)

        farm = Farm(id=change.id, owner_id=user.id)
        await self._apply_farm(session, farm, data)
        session.add(farm)
        await session.flush()
        await session.refresh(farm)
        return self._applied(change, farm.updated_at)

    async def _apply_farm(
        self,
        session: AsyncSession,
        farm: Farm,
        data: FarmSyncData,
    ) -> None:
        farm.name = data.name
        farm.village = data.village
        farm.admin_area_id = data.admin_area_id
        farm.location = (
            geojson_to_postgis_point(data.location) if data.location else None
        )

    async def _upsert_plot(
        self,
        session: AsyncSession,
        user: User,
        change: SyncChange,
        client_updated: datetime,
    ) -> SyncResult:
        data = PlotSyncData.model_validate(change.data)
        parent_error = await self._farm_parent_error(session, user, data.farm_id)
        if parent_error is not None:
            return self._rejected(change, parent_error)

        existing = await session.get(Plot, change.id)
        if existing is not None:
            if existing.farm_id != data.farm_id:
                parent_owner = await self._farm_owner(session, existing.farm_id)
                if parent_owner != user.id:
                    return self._rejected(change, OTHER_USER_ERROR)
            if existing.deleted_at is not None:
                return self._rejected(change, DELETED_ERROR)
            if client_updated <= existing.updated_at:
                return self._conflict(change, existing.updated_at)
            await self._apply_plot(session, existing, data)
            await session.flush()
            await session.refresh(existing)
            return self._applied(change, existing.updated_at)

        await ensure_quota(session, user, "plots")
        plot = Plot(id=change.id, farm_id=data.farm_id)
        await self._apply_plot(session, plot, data)
        session.add(plot)
        await session.flush()
        await session.refresh(plot)
        return self._applied(change, plot.updated_at)

    async def _apply_plot(
        self,
        session: AsyncSession,
        plot: Plot,
        data: PlotSyncData,
    ) -> None:
        plot.farm_id = data.farm_id
        plot.name = data.name
        plot.soil_type = data.soil_type
        plot.irrigation = data.irrigation
        if data.geom is not None:
            geom = geojson_to_postgis_polygon(data.geom)
            plot.geom = geom
            plot.area_ha = await compute_area_ha(session, geom)
        else:
            plot.geom = None
            plot.area_ha = data.area_ha

    async def _upsert_cycle(
        self,
        session: AsyncSession,
        user: User,
        change: SyncChange,
        client_updated: datetime,
    ) -> SyncResult:
        data = CropCycleSyncData.model_validate(change.data)
        parent_error = await self._plot_parent_error(session, user, data.plot_id)
        if parent_error is not None:
            return self._rejected(change, parent_error)
        crop = await session.get(Crop, data.crop_id)
        if crop is None:
            return self._rejected(change, PARENT_ERROR)

        expected = data.expected_harvest_date
        if expected is None and data.sowing_date is not None and crop.cycle_days:
            expected = data.sowing_date + timedelta(days=crop.cycle_days)

        existing = await session.get(CropCycle, change.id)
        if existing is not None:
            if existing.deleted_at is not None:
                return self._rejected(change, DELETED_ERROR)
            if client_updated <= existing.updated_at:
                return self._conflict(change, existing.updated_at)
            existing.plot_id = data.plot_id
            existing.crop_id = data.crop_id
            existing.variety = data.variety
            existing.season = data.season
            existing.sowing_date = data.sowing_date
            existing.expected_harvest_date = expected
            existing.harvest_date = data.harvest_date
            existing.status = data.status
            existing.notes = data.notes
            await session.flush()
            await session.refresh(existing)
            return self._applied(change, existing.updated_at)

        cycle = CropCycle(
            id=change.id,
            plot_id=data.plot_id,
            crop_id=data.crop_id,
            variety=data.variety,
            season=data.season,
            sowing_date=data.sowing_date,
            expected_harvest_date=expected,
            harvest_date=data.harvest_date,
            status=data.status,
            notes=data.notes,
        )
        session.add(cycle)
        await session.flush()
        await session.refresh(cycle)
        return self._applied(change, cycle.updated_at)

    async def _upsert_activity(
        self,
        session: AsyncSession,
        user: User,
        change: SyncChange,
        client_updated: datetime,
    ) -> SyncResult:
        data = FarmActivitySyncData.model_validate(change.data)
        parent_error = await self._cycle_parent_error(
            session, user, data.crop_cycle_id
        )
        if parent_error is not None:
            return self._rejected(change, parent_error)

        existing = await session.get(FarmActivity, change.id)
        if existing is not None:
            if existing.deleted_at is not None:
                return self._rejected(change, DELETED_ERROR)
            if client_updated <= existing.updated_at:
                return self._conflict(change, existing.updated_at)
            existing.crop_cycle_id = data.crop_cycle_id
            existing.type = data.type
            existing.performed_on = data.performed_on
            existing.product_name = data.product_name
            existing.quantity = data.quantity
            existing.unit = data.unit
            existing.cost_xof = data.cost_xof
            existing.notes = data.notes
            await session.flush()
            await session.refresh(existing)
            return self._applied(change, existing.updated_at)

        activity = FarmActivity(
            id=change.id,
            crop_cycle_id=data.crop_cycle_id,
            type=data.type,
            performed_on=data.performed_on,
            product_name=data.product_name,
            quantity=data.quantity,
            unit=data.unit,
            cost_xof=data.cost_xof,
            notes=data.notes,
        )
        session.add(activity)
        await session.flush()
        await session.refresh(activity)
        return self._applied(change, activity.updated_at)

    async def _upsert_harvest(
        self,
        session: AsyncSession,
        user: User,
        change: SyncChange,
        client_updated: datetime,
    ) -> SyncResult:
        data = HarvestSyncData.model_validate(change.data)
        parent_error = await self._cycle_parent_error(
            session, user, data.crop_cycle_id
        )
        if parent_error is not None:
            return self._rejected(change, parent_error)

        existing = await session.get(Harvest, change.id)
        if existing is not None:
            if existing.deleted_at is not None:
                return self._rejected(change, DELETED_ERROR)
            if client_updated <= existing.updated_at:
                return self._conflict(change, existing.updated_at)
            existing.crop_cycle_id = data.crop_cycle_id
            existing.harvested_on = data.harvested_on
            existing.quantity_kg = data.quantity_kg
            existing.quality = data.quality
            existing.sold_kg = data.sold_kg
            existing.avg_price_xof_per_kg = data.avg_price_xof_per_kg
            await session.flush()
            await session.refresh(existing)
            return self._applied(change, existing.updated_at)

        harvest = Harvest(
            id=change.id,
            crop_cycle_id=data.crop_cycle_id,
            harvested_on=data.harvested_on,
            quantity_kg=data.quantity_kg,
            quality=data.quality,
            sold_kg=data.sold_kg,
            avg_price_xof_per_kg=data.avg_price_xof_per_kg,
        )
        session.add(harvest)
        await session.flush()
        await session.refresh(harvest)
        return self._applied(change, harvest.updated_at)

    async def _farm_owner(
        self, session: AsyncSession, farm_id: uuid.UUID
    ) -> uuid.UUID | None:
        return (
            await session.execute(select(Farm.owner_id).where(Farm.id == farm_id))
        ).scalar_one_or_none()

    async def _farm_parent_error(
        self, session: AsyncSession, user: User, farm_id: uuid.UUID
    ) -> str | None:
        row = (
            await session.execute(
                select(Farm.owner_id, Farm.deleted_at).where(Farm.id == farm_id)
            )
        ).first()
        if row is None:
            return PARENT_ERROR
        if row[0] != user.id:
            return OTHER_USER_ERROR
        if row[1] is not None:
            return DELETED_ERROR
        return None

    async def _plot_parent_error(
        self, session: AsyncSession, user: User, plot_id: uuid.UUID
    ) -> str | None:
        row = (
            await session.execute(
                select(Plot.deleted_at, Farm.owner_id, Farm.deleted_at)
                .join(Farm, Plot.farm_id == Farm.id)
                .where(Plot.id == plot_id)
            )
        ).first()
        if row is None:
            return PARENT_ERROR
        if row[1] != user.id:
            return OTHER_USER_ERROR
        if row[0] is not None or row[2] is not None:
            return DELETED_ERROR
        return None

    async def _cycle_parent_error(
        self, session: AsyncSession, user: User, cycle_id: uuid.UUID
    ) -> str | None:
        row = (
            await session.execute(
                select(
                    CropCycle.deleted_at,
                    Plot.deleted_at,
                    Farm.owner_id,
                    Farm.deleted_at,
                )
                .join(Plot, CropCycle.plot_id == Plot.id)
                .join(Farm, Plot.farm_id == Farm.id)
                .where(CropCycle.id == cycle_id)
            )
        ).first()
        if row is None:
            return PARENT_ERROR
        if row[2] != user.id:
            return OTHER_USER_ERROR
        if row[0] is not None or row[1] is not None or row[3] is not None:
            return DELETED_ERROR
        return None

    async def _delete(
        self,
        session: AsyncSession,
        user: User,
        change: SyncChange,
    ) -> SyncResult:
        loaders = {
            "farm": self._delete_farm,
            "plot": self._delete_plot,
            "crop_cycle": self._delete_cycle,
            "farm_activity": self._delete_activity,
            "harvest": self._delete_harvest,
        }
        return await loaders[change.entity](session, user, change)

    async def _delete_farm(
        self, session: AsyncSession, user: User, change: SyncChange
    ) -> SyncResult:
        farm = await session.get(Farm, change.id)
        if farm is None:
            return self._applied(change, None)
        if farm.owner_id != user.id:
            return self._rejected(change, OTHER_USER_ERROR)
        if farm.deleted_at is not None:
            return self._applied(change, farm.updated_at)

        now = datetime.now(UTC)
        plot_ids = list(
            (
                await session.scalars(
                    select(Plot.id).where(
                        Plot.farm_id == farm.id, Plot.deleted_at.is_(None)
                    )
                )
            ).all()
        )
        if plot_ids:
            cycle_ids = list(
                (
                    await session.scalars(
                        select(CropCycle.id).where(
                            CropCycle.plot_id.in_(plot_ids),
                            CropCycle.deleted_at.is_(None),
                        )
                    )
                ).all()
            )
            if cycle_ids:
                await session.execute(
                    update(Harvest)
                    .where(
                        Harvest.crop_cycle_id.in_(cycle_ids),
                        Harvest.deleted_at.is_(None),
                    )
                    .values(deleted_at=now)
                )
                await session.execute(
                    update(FarmActivity)
                    .where(
                        FarmActivity.crop_cycle_id.in_(cycle_ids),
                        FarmActivity.deleted_at.is_(None),
                    )
                    .values(deleted_at=now)
                )
                await session.execute(
                    update(CropCycle)
                    .where(
                        CropCycle.id.in_(cycle_ids),
                        CropCycle.deleted_at.is_(None),
                    )
                    .values(deleted_at=now)
                )
            await session.execute(
                update(Plot)
                .where(Plot.id.in_(plot_ids), Plot.deleted_at.is_(None))
                .values(deleted_at=now)
            )
        farm.deleted_at = now
        await session.flush()
        await session.refresh(farm)
        return self._applied(change, farm.updated_at)

    async def _delete_plot(
        self, session: AsyncSession, user: User, change: SyncChange
    ) -> SyncResult:
        row = (
            await session.execute(
                select(Plot, Farm.owner_id).join(Farm, Plot.farm_id == Farm.id).where(
                    Plot.id == change.id
                )
            )
        ).first()
        if row is None:
            return self._applied(change, None)
        plot, owner_id = row
        if owner_id != user.id:
            return self._rejected(change, OTHER_USER_ERROR)
        if plot.deleted_at is not None:
            return self._applied(change, plot.updated_at)

        now = datetime.now(UTC)
        cycle_ids = list(
            (
                await session.scalars(
                    select(CropCycle.id).where(
                        CropCycle.plot_id == plot.id,
                        CropCycle.deleted_at.is_(None),
                    )
                )
            ).all()
        )
        if cycle_ids:
            await session.execute(
                update(Harvest)
                .where(
                    Harvest.crop_cycle_id.in_(cycle_ids),
                    Harvest.deleted_at.is_(None),
                )
                .values(deleted_at=now)
            )
            await session.execute(
                update(FarmActivity)
                .where(
                    FarmActivity.crop_cycle_id.in_(cycle_ids),
                    FarmActivity.deleted_at.is_(None),
                )
                .values(deleted_at=now)
            )
            await session.execute(
                update(CropCycle)
                .where(
                    CropCycle.id.in_(cycle_ids),
                    CropCycle.deleted_at.is_(None),
                )
                .values(deleted_at=now)
            )
        plot.deleted_at = now
        await session.flush()
        await session.refresh(plot)
        return self._applied(change, plot.updated_at)

    async def _delete_cycle(
        self, session: AsyncSession, user: User, change: SyncChange
    ) -> SyncResult:
        row = (
            await session.execute(
                select(CropCycle, Farm.owner_id)
                .join(Plot, CropCycle.plot_id == Plot.id)
                .join(Farm, Plot.farm_id == Farm.id)
                .where(CropCycle.id == change.id)
            )
        ).first()
        if row is None:
            return self._applied(change, None)
        cycle, owner_id = row
        if owner_id != user.id:
            return self._rejected(change, OTHER_USER_ERROR)
        if cycle.deleted_at is not None:
            return self._applied(change, cycle.updated_at)

        now = datetime.now(UTC)
        await session.execute(
            update(Harvest)
            .where(
                Harvest.crop_cycle_id == cycle.id,
                Harvest.deleted_at.is_(None),
            )
            .values(deleted_at=now)
        )
        await session.execute(
            update(FarmActivity)
            .where(
                FarmActivity.crop_cycle_id == cycle.id,
                FarmActivity.deleted_at.is_(None),
            )
            .values(deleted_at=now)
        )
        cycle.deleted_at = now
        await session.flush()
        await session.refresh(cycle)
        return self._applied(change, cycle.updated_at)

    async def _delete_activity(
        self, session: AsyncSession, user: User, change: SyncChange
    ) -> SyncResult:
        row = (
            await session.execute(
                select(FarmActivity, Farm.owner_id)
                .join(CropCycle, FarmActivity.crop_cycle_id == CropCycle.id)
                .join(Plot, CropCycle.plot_id == Plot.id)
                .join(Farm, Plot.farm_id == Farm.id)
                .where(FarmActivity.id == change.id)
            )
        ).first()
        if row is None:
            return self._applied(change, None)
        activity, owner_id = row
        if owner_id != user.id:
            return self._rejected(change, OTHER_USER_ERROR)
        if activity.deleted_at is not None:
            return self._applied(change, activity.updated_at)
        activity.deleted_at = datetime.now(UTC)
        await session.flush()
        await session.refresh(activity)
        return self._applied(change, activity.updated_at)

    async def _delete_harvest(
        self, session: AsyncSession, user: User, change: SyncChange
    ) -> SyncResult:
        row = (
            await session.execute(
                select(Harvest, Farm.owner_id)
                .join(CropCycle, Harvest.crop_cycle_id == CropCycle.id)
                .join(Plot, CropCycle.plot_id == Plot.id)
                .join(Farm, Plot.farm_id == Farm.id)
                .where(Harvest.id == change.id)
            )
        ).first()
        if row is None:
            return self._applied(change, None)
        harvest, owner_id = row
        if owner_id != user.id:
            return self._rejected(change, OTHER_USER_ERROR)
        if harvest.deleted_at is not None:
            return self._applied(change, harvest.updated_at)
        harvest.deleted_at = datetime.now(UTC)
        await session.flush()
        await session.refresh(harvest)
        return self._applied(change, harvest.updated_at)

    async def _owned_selects(self, user_id: uuid.UUID) -> list:
        return [
            select(
                literal("farm").label("entity"),
                Farm.id.label("id"),
                Farm.updated_at.label("updated_at"),
            ).where(Farm.owner_id == user_id),
            select(
                literal("plot").label("entity"),
                Plot.id.label("id"),
                Plot.updated_at.label("updated_at"),
            )
            .join(Farm, Plot.farm_id == Farm.id)
            .where(Farm.owner_id == user_id),
            select(
                literal("crop_cycle").label("entity"),
                CropCycle.id.label("id"),
                CropCycle.updated_at.label("updated_at"),
            )
            .join(Plot, CropCycle.plot_id == Plot.id)
            .join(Farm, Plot.farm_id == Farm.id)
            .where(Farm.owner_id == user_id),
            select(
                literal("farm_activity").label("entity"),
                FarmActivity.id.label("id"),
                FarmActivity.updated_at.label("updated_at"),
            )
            .join(CropCycle, FarmActivity.crop_cycle_id == CropCycle.id)
            .join(Plot, CropCycle.plot_id == Plot.id)
            .join(Farm, Plot.farm_id == Farm.id)
            .where(Farm.owner_id == user_id),
            select(
                literal("harvest").label("entity"),
                Harvest.id.label("id"),
                Harvest.updated_at.label("updated_at"),
            )
            .join(CropCycle, Harvest.crop_cycle_id == CropCycle.id)
            .join(Plot, CropCycle.plot_id == Plot.id)
            .join(Farm, Plot.farm_id == Farm.id)
            .where(Farm.owner_id == user_id),
        ]

    async def pull(
        self,
        session: AsyncSession,
        user_id: uuid.UUID,
        since: str | None = None,
        limit: int = 200,
    ) -> SyncPullResponse:
        combined = union_all(*await self._owned_selects(user_id)).subquery()
        stmt = select(
            combined.c.entity, combined.c.id, combined.c.updated_at
        )
        if since is not None:
            cursor_dt, cursor_id = decode_cursor(since)
            try:
                cursor_uuid = uuid.UUID(cursor_id)
            except (ValueError, TypeError):
                cursor_uuid = uuid.UUID(int=0)
            cursor_dt = _as_utc(cursor_dt)
            stmt = stmt.where(
                or_(
                    combined.c.updated_at > cursor_dt,
                    and_(
                        combined.c.updated_at == cursor_dt,
                        combined.c.id > cursor_uuid,
                    ),
                )
            )
        stmt = stmt.order_by(
            combined.c.updated_at.asc(), combined.c.id.asc()
        ).limit(limit + 1)

        rows = list((await session.execute(stmt)).all())
        has_more = len(rows) > limit
        page = rows[:limit]

        changes = await self._hydrate(session, page)
        next_cursor = None
        if page:
            next_cursor = encode_cursor(page[-1][2], page[-1][1])
        return SyncPullResponse(
            changes=changes, next_cursor=next_cursor, has_more=has_more
        )

    async def _hydrate(
        self,
        session: AsyncSession,
        page: list,
    ) -> list[SyncChangeItem]:
        by_entity: dict[str, list[uuid.UUID]] = {}
        for entity, row_id, _ in page:
            by_entity.setdefault(entity, []).append(row_id)

        farms: dict[uuid.UUID, Farm] = {}
        if ids := by_entity.get("farm"):
            farms = {
                row.id: row
                for row in (
                    await session.scalars(select(Farm).where(Farm.id.in_(ids)))
                ).all()
            }
        plots: dict[uuid.UUID, Plot] = {}
        if ids := by_entity.get("plot"):
            plots = {
                row.id: row
                for row in (
                    await session.scalars(select(Plot).where(Plot.id.in_(ids)))
                ).all()
            }
        cycles: dict[uuid.UUID, CropCycle] = {}
        if ids := by_entity.get("crop_cycle"):
            cycles = {
                row.id: row
                for row in (
                    await session.scalars(
                        select(CropCycle).where(CropCycle.id.in_(ids))
                    )
                ).all()
            }
        activities: dict[uuid.UUID, FarmActivity] = {}
        if ids := by_entity.get("farm_activity"):
            activities = {
                row.id: row
                for row in (
                    await session.scalars(
                        select(FarmActivity).where(FarmActivity.id.in_(ids))
                    )
                ).all()
            }
        harvests: dict[uuid.UUID, Harvest] = {}
        if ids := by_entity.get("harvest"):
            harvests = {
                row.id: row
                for row in (
                    await session.scalars(
                        select(Harvest).where(Harvest.id.in_(ids))
                    )
                ).all()
            }

        changes: list[SyncChangeItem] = []
        for entity, row_id, updated_at in page:
            if entity == "farm":
                row = farms[row_id]
                data = {
                    "name": row.name,
                    "village": row.village,
                    "admin_area_id": row.admin_area_id,
                    "organization_id": row.organization_id,
                    "location": postgis_to_geojson(row.location),
                    "created_at": row.created_at,
                }
                deleted_at = row.deleted_at
            elif entity == "plot":
                row = plots[row_id]
                data = {
                    "farm_id": row.farm_id,
                    "name": row.name,
                    "area_ha": row.area_ha,
                    "geom": postgis_to_geojson(row.geom),
                    "soil_type": row.soil_type,
                    "irrigation": row.irrigation,
                    "created_at": row.created_at,
                }
                deleted_at = row.deleted_at
            elif entity == "crop_cycle":
                row = cycles[row_id]
                data = {
                    "plot_id": row.plot_id,
                    "crop_id": row.crop_id,
                    "variety": row.variety,
                    "season": row.season,
                    "sowing_date": row.sowing_date,
                    "expected_harvest_date": row.expected_harvest_date,
                    "harvest_date": row.harvest_date,
                    "status": row.status,
                    "notes": row.notes,
                    "created_at": row.created_at,
                }
                deleted_at = row.deleted_at
            elif entity == "farm_activity":
                row = activities[row_id]
                data = {
                    "crop_cycle_id": row.crop_cycle_id,
                    "type": row.type,
                    "performed_on": row.performed_on,
                    "product_name": row.product_name,
                    "quantity": row.quantity,
                    "unit": row.unit,
                    "cost_xof": row.cost_xof,
                    "notes": row.notes,
                    "created_at": row.created_at,
                }
                deleted_at = row.deleted_at
            else:
                row = harvests[row_id]
                data = {
                    "crop_cycle_id": row.crop_cycle_id,
                    "harvested_on": row.harvested_on,
                    "quantity_kg": row.quantity_kg,
                    "quality": row.quality,
                    "sold_kg": row.sold_kg,
                    "avg_price_xof_per_kg": row.avg_price_xof_per_kg,
                    "created_at": row.created_at,
                }
                deleted_at = row.deleted_at
            changes.append(
                SyncChangeItem(
                    entity=entity,
                    id=row_id,
                    data=data,
                    updated_at=updated_at,
                    deleted_at=deleted_at,
                )
            )
        return changes


sync_service = SyncService()
