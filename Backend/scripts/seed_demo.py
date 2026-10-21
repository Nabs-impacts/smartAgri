import asyncio
import os
import sys
import uuid
from datetime import UTC, date, datetime, timedelta
from decimal import Decimal

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.security import hash_password
from app.db.models.farming import Crop, CropCycle, Farm, Harvest, Plot
from app.db.models.identity import AdminArea, User
from app.db.models.media_ai import DiagnosisLabel, Diagnostic
from app.db.session import AsyncSessionLocal

NAMESPACE = uuid.UUID("59683f6c-8d69-4f14-9f6c-34f7bd8a3d6f")
PHONE_PREFIX = "+2279000"
FARMER_COUNT = 30
REGION_CODES = ["NER-NIAMEY", "NER-DOSSO", "NER-MARADI"]
SEASON_CROPS = [
    {"rainy": "millet", "dry": "sorghum"},
    {"rainy": "sorghum", "dry": "cowpea"},
    {"rainy": "cowpea", "dry": "millet"},
]
MASKED_EXTRA = [
    {"indices": [20, 21], "crop": "onion", "season": "rainy", "key": "onion"},
    {"indices": [0, 1, 2, 3], "crop": "tomato", "season": "dry", "key": "tomato"},
]
DIAGNOSTIC_COUNT = 6


def _demo_id(*parts: object) -> uuid.UUID:
    return uuid.uuid5(NAMESPACE, ":".join(str(part) for part in parts))


def _phone(index: int) -> str:
    return f"{PHONE_PREFIX}{index:04d}"


def _read_password(password: str | None) -> str:
    value = password or os.environ.get("DEMO_PASSWORD")
    if not value:
        raise RuntimeError(
            "La variable d'environnement DEMO_PASSWORD est obligatoire "
            "pour créer les données de démonstration."
        )
    return value


def _check_environment() -> None:
    environment = os.environ.get("ENVIRONMENT", "").strip().lower()
    if environment == "production":
        raise RuntimeError(
            "Le script de démonstration refuse de s'exécuter en production."
        )


async def _upsert_plot(
    session: AsyncSession,
    plot_id: uuid.UUID,
    farm_id: uuid.UUID,
    name: str,
    area: Decimal,
) -> None:
    plot = await session.get(Plot, plot_id)
    if plot is None:
        session.add(
            Plot(
                id=plot_id,
                farm_id=farm_id,
                name=name,
                area_ha=area,
                soil_type="loam",
                irrigation="rainfed",
            )
        )
    else:
        plot.farm_id = farm_id
        plot.name = name
        plot.area_ha = area
        plot.deleted_at = None
    await session.flush()


async def _upsert_cycle(
    session: AsyncSession,
    cycle_id: uuid.UUID,
    harvest_id: uuid.UUID,
    plot_id: uuid.UUID,
    crop_id: int,
    sowing_date: date,
    area: Decimal,
    yield_kg_per_ha: int,
) -> None:
    cycle = await session.get(CropCycle, cycle_id)
    if cycle is None:
        cycle = CropCycle(id=cycle_id, plot_id=plot_id, crop_id=crop_id)
        session.add(cycle)
    cycle.plot_id = plot_id
    cycle.crop_id = crop_id
    cycle.season = "2026"
    cycle.sowing_date = sowing_date
    cycle.harvest_date = sowing_date + timedelta(days=90)
    cycle.expected_harvest_date = cycle.harvest_date
    cycle.status = "harvested"
    cycle.notes = "Cycle de démonstration"
    cycle.deleted_at = None
    await session.flush()

    harvest = await session.get(Harvest, harvest_id)
    if harvest is None:
        harvest = Harvest(id=harvest_id, crop_cycle_id=cycle_id)
        session.add(harvest)
    quantity = (area * Decimal(yield_kg_per_ha)).quantize(Decimal("0.01"))
    harvest.crop_cycle_id = cycle_id
    harvest.harvested_on = cycle.harvest_date
    harvest.quantity_kg = quantity
    harvest.quality = "A"
    harvest.sold_kg = (quantity / 2).quantize(Decimal("0.01"))
    harvest.avg_price_xof_per_kg = Decimal("250.00")
    harvest.deleted_at = None
    await session.flush()


async def seed_demo(
    session: AsyncSession,
    password: str | None = None,
) -> None:
    demo_password = _read_password(password)
    password_hash = hash_password(demo_password)
    now = datetime.now(UTC)

    regions: list[AdminArea] = []
    for code in REGION_CODES:
        region = (
            await session.execute(
                select(AdminArea).where(AdminArea.code == code)
            )
        ).scalar_one()
        regions.append(region)

    crops = {
        crop.code: crop
        for crop in (
            await session.execute(
                select(Crop).where(
                    Crop.code.in_(
                        [
                            "millet",
                            "sorghum",
                            "cowpea",
                            "onion",
                            "tomato",
                        ]
                    )
                )
            )
        ).scalars()
    }
    labels = {
        label.code: label
        for label in (
            await session.execute(
                select(DiagnosisLabel).where(
                    DiagnosisLabel.code.in_(["healthy", "fall_armyworm"])
                )
            )
        ).scalars()
    }

    for index in range(1, FARMER_COUNT + 1):
        region_index = (index - 1) // 10
        region = regions[region_index]
        phone = _phone(index)
        user_id = _demo_id("user", index)
        user = (
            await session.execute(select(User).where(User.phone == phone))
        ).scalar_one_or_none()
        if user is None:
            user = User(id=user_id, phone=phone, full_name=f"Démo {index:02d}")
            session.add(user)
        user.full_name = f"Démo {index:02d}"
        user.role = "farmer"
        user.language = "fr"
        user.password_hash = password_hash
        user.admin_area_id = region.id
        user.is_active = True
        user.phone_verified_at = now
        user.last_login_at = now - timedelta(days=index % 20)
        user.deleted_at = None
        await session.flush()

        farm_id = _demo_id("farm", index)
        farm = await session.get(Farm, farm_id)
        if farm is None:
            farm = Farm(id=farm_id, owner_id=user.id, name=f"Ferme Démo {index:02d}")
            session.add(farm)
        farm.owner_id = user.id
        farm.name = f"Ferme Démo {index:02d}"
        farm.village = "Village Démo"
        farm.admin_area_id = region.id
        farm.deleted_at = None
        await session.flush()

        plot_count = 1 + (index % 3)
        plot_areas: list[Decimal] = []
        for plot_index in range(plot_count):
            area = Decimal(str(0.5 + ((index + plot_index) % 4) * 0.5))
            plot_areas.append(area)
            await _upsert_plot(
                session,
                _demo_id("plot", index, plot_index),
                farm.id,
                f"Parcelle Démo {index:02d}-{plot_index + 1}",
                area,
            )

        season_crops = SEASON_CROPS[region_index]
        for season_index, season in enumerate(("rainy", "dry")):
            crop = crops[season_crops[season]]
            if season == "rainy":
                sowing_date = date(2026, 6 + (index % 3), 1 + (index % 25))
            else:
                sowing_date = date(2026, 1 + (index % 2), 1 + (index % 25))
            yield_kg_per_ha = 800 + ((index * 37 + season_index * 113) % 400)
            await _upsert_cycle(
                session,
                _demo_id("cycle", index, season),
                _demo_id("harvest", index, season),
                _demo_id("plot", index, season_index % plot_count),
                crop.id,
                sowing_date,
                plot_areas[season_index % plot_count],
                yield_kg_per_ha,
            )

        for extra in MASKED_EXTRA:
            if index - 1 not in extra["indices"]:
                continue
            crop = crops[extra["crop"]]
            if extra["season"] == "rainy":
                sowing_date = date(2026, 7, 1 + (index % 25))
            else:
                sowing_date = date(2026, 2, 1 + (index % 25))
            await _upsert_cycle(
                session,
                _demo_id("cycle", index, extra["key"]),
                _demo_id("harvest", index, extra["key"]),
                _demo_id("plot", index, 0),
                crop.id,
                sowing_date,
                plot_areas[0],
                700 + (index % 5) * 40,
            )

        if index <= DIAGNOSTIC_COUNT:
            label_code = "healthy" if index % 2 == 0 else "fall_armyworm"
            label = labels.get(label_code)
            status = "done" if index % 2 == 0 else "needs_review"
            diagnostic_id = _demo_id("diagnostic", index)
            diagnostic = await session.get(Diagnostic, diagnostic_id)
            if diagnostic is None:
                diagnostic = Diagnostic(id=diagnostic_id, user_id=user.id)
                session.add(diagnostic)
            diagnostic.user_id = user.id
            diagnostic.plot_id = _demo_id("plot", index, 0)
            diagnostic.crop_cycle_id = _demo_id("cycle", index, "rainy")
            diagnostic.crop_id = crops[season_crops["rainy"]].id
            diagnostic.source = "server"
            diagnostic.status = status
            diagnostic.top_label_id = label.id if label is not None else None
            diagnostic.confidence = Decimal("0.820")
            diagnostic.severity = (
                "high" if label_code == "fall_armyworm" else None
            )
            diagnostic.user_note = "Diagnostic fictif de démonstration"
            diagnostic.error = None
            diagnostic.completed_at = now - timedelta(days=index)
            diagnostic.created_at = now - timedelta(days=index)
            diagnostic.deleted_at = None
            await session.flush()

    await session.commit()


async def main() -> None:
    _check_environment()
    password = _read_password(None)
    async with AsyncSessionLocal() as session:
        await seed_demo(session, password)


if __name__ == "__main__":
    try:
        asyncio.run(main())
    except RuntimeError as error:
        sys.exit(str(error))
