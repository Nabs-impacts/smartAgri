import uuid
from datetime import UTC, datetime

from sqlalchemy import and_, or_, select, update
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.core.errors import ConflictException, NotFoundException, ValidationException
from app.core.geo import (
    compute_area_ha,
    geojson_to_postgis_point,
    geojson_to_postgis_polygon,
    postgis_to_geojson,
)
from app.core.pagination import decode_cursor, encode_cursor
from app.db.models.farming import CropCycle, Farm, FarmActivity, Harvest, Plot
from app.db.models.identity import AdminArea, User
from app.schemas.farm import (
    FarmCreateRequest,
    FarmResponse,
    FarmUpdateRequest,
    PlotCreateRequest,
    PlotResponse,
    PlotUpdateRequest,
)
from app.services.quota_service import ensure_quota


def farm_to_response(farm: Farm) -> FarmResponse:
    return FarmResponse(
        id=farm.id,
        owner_id=farm.owner_id,
        organization_id=farm.organization_id,
        name=farm.name,
        village=farm.village,
        admin_area_id=farm.admin_area_id,
        location=postgis_to_geojson(farm.location),
        created_at=farm.created_at,
        updated_at=farm.updated_at,
    )


def plot_to_response(plot: Plot) -> PlotResponse:
    return PlotResponse(
        id=plot.id,
        farm_id=plot.farm_id,
        name=plot.name,
        area_ha=plot.area_ha,
        geom=postgis_to_geojson(plot.geom),
        soil_type=plot.soil_type,
        irrigation=plot.irrigation,
        created_at=plot.created_at,
        updated_at=plot.updated_at,
    )


class FarmService:
    async def list_farms(
        self,
        session: AsyncSession,
        user_id: uuid.UUID,
        limit: int = 20,
        cursor: str | None = None,
    ) -> tuple[list[FarmResponse], str | None]:
        stmt = select(Farm).where(
            Farm.owner_id == user_id,
            Farm.deleted_at.is_(None),
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
        result = await session.execute(stmt)
        rows = list(result.scalars().all())

        if len(rows) > limit:
            items = rows[:limit]
            next_cursor = encode_cursor(items[-1].created_at, items[-1].id)
        else:
            items = rows
            next_cursor = None

        return [farm_to_response(farm) for farm in items], next_cursor

    async def create_farm(
        self,
        session: AsyncSession,
        user: User,
        data: FarmCreateRequest,
    ) -> tuple[FarmResponse, bool]:
        user_id = user.id
        if data.id is not None:
            existing = (
                await session.execute(select(Farm).where(Farm.id == data.id))
            ).scalar_one_or_none()
            if existing is not None:
                if existing.deleted_at is not None:
                    raise ConflictException("Cette ressource a été supprimée.")
                if existing.owner_id == user_id:
                    return farm_to_response(existing), False
                raise ConflictException("Une ressource avec cet identifiant existe déjà.")

        if data.admin_area_id is not None:
            area_exists = (
                await session.execute(
                    select(AdminArea.id).where(AdminArea.id == data.admin_area_id)
                )
            ).scalar_one_or_none()
            if not area_exists:
                raise NotFoundException("Zone administrative introuvable.")

        loc_geom = (
            geojson_to_postgis_point(data.location) if data.location else None
        )
        farm = Farm(
            id=data.id or uuid.uuid4(),
            owner_id=user_id,
            name=data.name,
            village=data.village,
            admin_area_id=data.admin_area_id,
            location=loc_geom,
        )
        session.add(farm)
        try:
            await session.commit()
        except IntegrityError:
            await session.rollback()
            if data.id is not None:
                existing = (
                    await session.execute(select(Farm).where(Farm.id == data.id))
                ).scalar_one_or_none()
                if existing is not None:
                    if existing.deleted_at is not None:
                        raise ConflictException(
                            "Cette ressource a été supprimée."
                        ) from None
                    if existing.owner_id == user_id:
                        return farm_to_response(existing), False
                    raise ConflictException(
                        "Une ressource avec cet identifiant existe déjà."
                    ) from None
            raise
        await session.refresh(farm)
        return farm_to_response(farm), True

    async def get_farm(
        self,
        session: AsyncSession,
        user_id: uuid.UUID,
        farm_id: uuid.UUID,
    ) -> FarmResponse:
        farm = (
            await session.execute(
                select(Farm).where(
                    Farm.id == farm_id,
                    Farm.deleted_at.is_(None),
                )
            )
        ).scalar_one_or_none()

        if farm is None or farm.owner_id != user_id:
            raise NotFoundException("Ferme introuvable.")

        return farm_to_response(farm)

    async def update_farm(
        self,
        session: AsyncSession,
        user_id: uuid.UUID,
        farm_id: uuid.UUID,
        data: FarmUpdateRequest,
    ) -> FarmResponse:
        farm = (
            await session.execute(
                select(Farm).where(
                    Farm.id == farm_id,
                    Farm.deleted_at.is_(None),
                )
            )
        ).scalar_one_or_none()

        if farm is None or farm.owner_id != user_id:
            raise NotFoundException("Ferme introuvable.")

        if data.name is not None:
            farm.name = data.name
        if data.village is not None:
            farm.village = data.village
        if data.admin_area_id is not None:
            area_exists = (
                await session.execute(
                    select(AdminArea.id).where(AdminArea.id == data.admin_area_id)
                )
            ).scalar_one_or_none()
            if not area_exists:
                raise NotFoundException("Zone administrative introuvable.")
            farm.admin_area_id = data.admin_area_id
        if data.location is not None:
            farm.location = geojson_to_postgis_point(data.location)

        await session.commit()
        await session.refresh(farm)
        return farm_to_response(farm)

    async def delete_farm(
        self,
        session: AsyncSession,
        user_id: uuid.UUID,
        farm_id: uuid.UUID,
    ) -> None:
        farm = (
            await session.execute(
                select(Farm).where(
                    Farm.id == farm_id,
                    Farm.deleted_at.is_(None),
                )
            )
        ).scalar_one_or_none()

        if farm is None or farm.owner_id != user_id:
            raise NotFoundException("Ferme introuvable.")

        now = datetime.now(UTC)
        plot_ids_stmt = select(Plot.id).where(
            Plot.farm_id == farm_id,
            Plot.deleted_at.is_(None),
        )
        plot_ids = list((await session.scalars(plot_ids_stmt)).all())

        if plot_ids:
            cycle_ids_stmt = select(CropCycle.id).where(
                CropCycle.plot_id.in_(plot_ids),
                CropCycle.deleted_at.is_(None),
            )
            cycle_ids = list((await session.scalars(cycle_ids_stmt)).all())

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
        await session.commit()

    async def list_plots(
        self,
        session: AsyncSession,
        user_id: uuid.UUID,
        farm_id: uuid.UUID,
        limit: int = 20,
        cursor: str | None = None,
    ) -> tuple[list[PlotResponse], str | None]:
        farm = (
            await session.execute(
                select(Farm).where(
                    Farm.id == farm_id,
                    Farm.deleted_at.is_(None),
                )
            )
        ).scalar_one_or_none()

        if farm is None or farm.owner_id != user_id:
            raise NotFoundException("Ferme introuvable.")

        stmt = select(Plot).where(
            Plot.farm_id == farm_id,
            Plot.deleted_at.is_(None),
        )

        if cursor:
            cursor_dt, cursor_id = decode_cursor(cursor)
            try:
                cursor_uuid = uuid.UUID(cursor_id)
            except (ValueError, TypeError) as err:
                raise ValidationException("Curseur de pagination invalide.") from err
            stmt = stmt.where(
                or_(
                    Plot.created_at < cursor_dt,
                    and_(
                        Plot.created_at == cursor_dt,
                        Plot.id < cursor_uuid,
                    ),
                )
            )

        stmt = stmt.order_by(Plot.created_at.desc(), Plot.id.desc()).limit(limit + 1)
        result = await session.execute(stmt)
        rows = list(result.scalars().all())

        if len(rows) > limit:
            items = rows[:limit]
            next_cursor = encode_cursor(items[-1].created_at, items[-1].id)
        else:
            items = rows
            next_cursor = None

        return [plot_to_response(plot) for plot in items], next_cursor

    async def create_plot(
        self,
        session: AsyncSession,
        user: User,
        farm_id: uuid.UUID,
        data: PlotCreateRequest,
    ) -> tuple[PlotResponse, bool]:
        user_id = user.id
        farm = (
            await session.execute(
                select(Farm).where(
                    Farm.id == farm_id,
                    Farm.deleted_at.is_(None),
                )
            )
        ).scalar_one_or_none()

        if farm is None or farm.owner_id != user_id:
            raise NotFoundException("Ferme introuvable.")

        if data.id is not None:
            stmt = (
                select(Plot, Farm.owner_id)
                .join(Farm, Plot.farm_id == Farm.id)
                .where(Plot.id == data.id)
            )
            row = (await session.execute(stmt)).first()
            if row is not None:
                existing_plot, farm_owner_id = row
                if existing_plot.deleted_at is not None:
                    raise ConflictException("Cette ressource a été supprimée.")
                if farm_owner_id == user_id:
                    return plot_to_response(existing_plot), False
                raise ConflictException("Une ressource avec cet identifiant existe déjà.")

        await ensure_quota(session, user, "plots")

        if data.geom is not None:
            wkb_geom = geojson_to_postgis_polygon(data.geom)
            area_ha = await compute_area_ha(session, wkb_geom)
        else:
            wkb_geom = None
            area_ha = data.area_ha

        plot = Plot(
            id=data.id or uuid.uuid4(),
            farm_id=farm.id,
            name=data.name,
            area_ha=area_ha,
            geom=wkb_geom,
            soil_type=data.soil_type,
            irrigation=data.irrigation,
        )
        session.add(plot)
        try:
            await session.commit()
        except IntegrityError:
            await session.rollback()
            if data.id is not None:
                stmt = (
                    select(Plot, Farm.owner_id)
                    .join(Farm, Plot.farm_id == Farm.id)
                    .where(Plot.id == data.id)
                )
                row = (await session.execute(stmt)).first()
                if row is not None:
                    existing_plot, farm_owner_id = row
                    if existing_plot.deleted_at is not None:
                        raise ConflictException(
                            "Cette ressource a été supprimée."
                        ) from None
                    if farm_owner_id == user_id:
                        return plot_to_response(existing_plot), False
                    raise ConflictException(
                        "Une ressource avec cet identifiant existe déjà."
                    ) from None
            raise
        await session.refresh(plot)
        return plot_to_response(plot), True

    async def get_plot(
        self,
        session: AsyncSession,
        user_id: uuid.UUID,
        plot_id: uuid.UUID,
    ) -> PlotResponse:
        stmt = (
            select(Plot)
            .join(Farm, Plot.farm_id == Farm.id)
            .options(selectinload(Plot.farm))
            .where(
                Plot.id == plot_id,
                Plot.deleted_at.is_(None),
                Farm.deleted_at.is_(None),
            )
        )
        plot = (await session.execute(stmt)).scalar_one_or_none()

        if plot is None or plot.farm.owner_id != user_id:
            raise NotFoundException("Parcelle introuvable.")

        return plot_to_response(plot)

    async def update_plot(
        self,
        session: AsyncSession,
        user_id: uuid.UUID,
        plot_id: uuid.UUID,
        data: PlotUpdateRequest,
    ) -> PlotResponse:
        stmt = (
            select(Plot)
            .join(Farm, Plot.farm_id == Farm.id)
            .options(selectinload(Plot.farm))
            .where(
                Plot.id == plot_id,
                Plot.deleted_at.is_(None),
                Farm.deleted_at.is_(None),
            )
        )
        plot = (await session.execute(stmt)).scalar_one_or_none()

        if plot is None or plot.farm.owner_id != user_id:
            raise NotFoundException("Parcelle introuvable.")

        if data.name is not None:
            plot.name = data.name
        if data.geom is not None:
            if data.area_ha is not None:
                raise ValidationException("La surface est calculée à partir de la géométrie.")
            wkb_geom = geojson_to_postgis_polygon(data.geom)
            plot.area_ha = await compute_area_ha(session, wkb_geom)
            plot.geom = wkb_geom
        elif data.area_ha is not None:
            if plot.geom is not None:
                raise ValidationException("La surface est calculée à partir de la géométrie.")
            plot.area_ha = data.area_ha
        if data.soil_type is not None:
            plot.soil_type = data.soil_type
        if data.irrigation is not None:
            plot.irrigation = data.irrigation

        await session.commit()
        await session.refresh(plot)
        return plot_to_response(plot)

    async def delete_plot(
        self,
        session: AsyncSession,
        user_id: uuid.UUID,
        plot_id: uuid.UUID,
    ) -> None:
        stmt = (
            select(Plot)
            .join(Farm, Plot.farm_id == Farm.id)
            .options(selectinload(Plot.farm))
            .where(
                Plot.id == plot_id,
                Plot.deleted_at.is_(None),
                Farm.deleted_at.is_(None),
            )
        )
        plot = (await session.execute(stmt)).scalar_one_or_none()

        if plot is None or plot.farm.owner_id != user_id:
            raise NotFoundException("Parcelle introuvable.")

        now = datetime.now(UTC)
        cycle_ids_stmt = select(CropCycle.id).where(
            CropCycle.plot_id == plot.id,
            CropCycle.deleted_at.is_(None),
        )
        cycle_ids = list((await session.scalars(cycle_ids_stmt)).all())

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
        await session.commit()


farm_service = FarmService()
