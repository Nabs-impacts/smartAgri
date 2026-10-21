import uuid
from datetime import UTC, date, datetime, timedelta
from decimal import Decimal

from httpx import AsyncClient
from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.security import create_access_token
from app.db.models.farming import Crop, CropCycle, Farm, Harvest, Plot
from app.db.models.identity import AdminArea, User
from app.db.models.media_ai import Diagnostic
from scripts.create_superuser import create_or_update_superuser

FORBIDDEN_ROLES = ["farmer", "agronomist", "org_admin"]
ALLOWED_ROLES = ["gov_admin", "super_admin"]


def _iter_keys(value: object):
    if isinstance(value, dict):
        for key, item in value.items():
            yield key
            yield from _iter_keys(item)
    elif isinstance(value, list):
        for item in value:
            yield from _iter_keys(item)


def _headers(user: User) -> dict[str, str]:
    return {
        "Authorization": f"Bearer {create_access_token(user.id, user.role)}"
    }


async def _create_user(
    session: AsyncSession,
    phone: str,
    role: str = "farmer",
    last_login_at: datetime | None = None,
    deleted: bool = False,
) -> User:
    user = User(
        phone=phone,
        full_name=f"Utilisateur {phone[-4:]}",
        role=role,
        is_active=True,
        phone_verified_at=datetime.now(UTC),
        last_login_at=last_login_at,
        deleted_at=datetime.now(UTC) if deleted else None,
    )
    session.add(user)
    await session.flush()
    return user


async def _region(session: AsyncSession, code: str) -> AdminArea:
    return (
        await session.execute(
            select(AdminArea).where(AdminArea.code == code)
        )
    ).scalar_one()


async def _crop(session: AsyncSession, code: str) -> Crop:
    return (
        await session.execute(select(Crop).where(Crop.code == code))
    ).scalar_one()


async def _farm_plot(
    session: AsyncSession,
    owner_id: uuid.UUID,
    admin_area_id: int,
    area_ha: str,
    name: str,
    farm_deleted: bool = False,
    plot_deleted: bool = False,
) -> Plot:
    farm = Farm(
        owner_id=owner_id,
        name=name,
        admin_area_id=admin_area_id,
        deleted_at=datetime.now(UTC) if farm_deleted else None,
    )
    session.add(farm)
    await session.flush()
    plot = Plot(
        farm_id=farm.id,
        name=name,
        area_ha=Decimal(area_ha),
        deleted_at=datetime.now(UTC) if plot_deleted else None,
    )
    session.add(plot)
    await session.flush()
    return plot


async def _cycle_with_harvest(
    session: AsyncSession,
    plot_id: uuid.UUID,
    crop_id: int,
    sowing_date: date,
    quantity_kg: str,
    harvested_on: date = date(2026, 10, 1),
    cycle_deleted: bool = False,
    harvest_deleted: bool = False,
) -> CropCycle:
    cycle = CropCycle(
        plot_id=plot_id,
        crop_id=crop_id,
        sowing_date=sowing_date,
        status="harvested",
        deleted_at=datetime.now(UTC) if cycle_deleted else None,
    )
    session.add(cycle)
    await session.flush()
    session.add(
        Harvest(
            crop_cycle_id=cycle.id,
            harvested_on=harvested_on,
            quantity_kg=Decimal(quantity_kg),
            deleted_at=datetime.now(UTC) if harvest_deleted else None,
        )
    )
    await session.flush()
    return cycle


async def _cycle_without_harvest(
    session: AsyncSession,
    plot_id: uuid.UUID,
    crop_id: int,
    sowing_date: date,
) -> CropCycle:
    cycle = CropCycle(
        plot_id=plot_id,
        crop_id=crop_id,
        sowing_date=sowing_date,
        status="growing",
    )
    session.add(cycle)
    await session.flush()
    return cycle


async def _yields(client: AsyncClient, headers: dict[str, str], query: str = ""):
    return await client.get(f"/api/v1/admin/stats/yields{query}", headers=headers)


async def _build_visible_cell(
    session: AsyncSession,
    users: list[User],
    region_area_id: int,
    crop_id: int,
    prefix: str,
) -> None:
    plot_a1 = await _farm_plot(
        session, users[0].id, region_area_id, "1.000", f"{prefix} A1"
    )
    plot_a2 = await _farm_plot(
        session, users[0].id, region_area_id, "2.000", f"{prefix} A2"
    )
    await _cycle_with_harvest(
        session,
        plot_a1.id,
        crop_id,
        date(2026, 6, 1),
        "1000",
    )
    await _cycle_with_harvest(
        session,
        plot_a2.id,
        crop_id,
        date(2026, 6, 2),
        "2400",
    )
    plot_b1 = await _farm_plot(
        session, users[1].id, region_area_id, "1.000", f"{prefix} B1"
    )
    plot_b2 = await _farm_plot(
        session, users[1].id, region_area_id, "2.000", f"{prefix} B2"
    )
    await _cycle_with_harvest(
        session,
        plot_b1.id,
        crop_id,
        date(2026, 6, 3),
        "800",
    )
    await _cycle_with_harvest(
        session,
        plot_b2.id,
        crop_id,
        date(2026, 6, 4),
        "2800",
    )
    plot_c1 = await _farm_plot(
        session, users[2].id, region_area_id, "1.000", f"{prefix} C1"
    )
    await _cycle_with_harvest(
        session,
        plot_c1.id,
        crop_id,
        date(2026, 6, 5),
        "1000",
    )
    await _cycle_without_harvest(
        session, plot_c1.id, crop_id, date(2026, 6, 6)
    )
    await _cycle_with_harvest(
        session,
        plot_c1.id,
        crop_id,
        date(2026, 6, 7),
        "5000",
        cycle_deleted=True,
    )
    await _cycle_with_harvest(
        session,
        plot_c1.id,
        crop_id,
        date(2026, 6, 8),
        "6000",
        harvest_deleted=True,
    )


async def test_admin_stats_permissions(client: AsyncClient, db_session: AsyncSession) -> None:
    phone_index = 0
    for role in FORBIDDEN_ROLES:
        phone_index += 1
        user = await _create_user(
            db_session, f"+2279600{phone_index:04d}", role
        )
        await db_session.commit()
        headers = _headers(user)
        for path in ("/yields", "/overview"):
            response = await client.get(
                f"/api/v1/admin/stats{path}", headers=headers
            )
            assert response.status_code == 403, (role, path)
            assert response.json()["error"]["code"] == "FORBIDDEN"

    for role in ALLOWED_ROLES:
        phone_index += 1
        user = await _create_user(
            db_session, f"+2279600{phone_index:04d}", role
        )
        await db_session.commit()
        headers = _headers(user)
        for path in ("/yields", "/overview"):
            response = await client.get(
                f"/api/v1/admin/stats{path}", headers=headers
            )
            assert response.status_code == 200, (role, path)

    for path in ("/yields", "/overview"):
        response = await client.get(f"/api/v1/admin/stats{path}")
        assert response.status_code == 401
        assert response.json()["error"]["code"] == "UNAUTHORIZED"


async def test_yields_visible_and_masked_cells(
    client: AsyncClient, db_session: AsyncSession
) -> None:
    admin = await _create_user(db_session, "+22796010001", "gov_admin")
    niamey = await _region(db_session, "NER-NIAMEY")
    dosso = await _region(db_session, "NER-DOSSO")
    maradi = await _region(db_session, "NER-MARADI")
    tahoua = await _region(db_session, "NER-TAHOUA")
    child = AdminArea(
        parent_id=niamey.id,
        level="departement",
        name="Niamey Département",
        code="NER-NIAMEY-DEPT-STATS",
    )
    db_session.add(child)
    await db_session.flush()

    millet = await _crop(db_session, "millet")
    sorghum = await _crop(db_session, "sorghum")
    cowpea = await _crop(db_session, "cowpea")

    visible_users = [
        await _create_user(db_session, f"+2279610{i:04d}")
        for i in range(3)
    ]
    await _build_visible_cell(
        db_session, visible_users, child.id, millet.id, "Visible"
    )

    four_users = [
        await _create_user(db_session, f"+2279620{i:04d}")
        for i in range(4)
    ]
    for user in four_users:
        plot = await _farm_plot(
            db_session, user.id, dosso.id, "1.000", "Quatre"
        )
        await _cycle_with_harvest(
            db_session, plot.id, sorghum.id, date(2026, 7, 1), "700"
        )

    single_owner = await _create_user(db_session, "+22796300001")
    for index in range(6):
        plot = await _farm_plot(
            db_session, single_owner.id, maradi.id, "1.000", f"Seul {index}"
        )
        await _cycle_with_harvest(
            db_session, plot.id, cowpea.id, date(2026, 6, 10), "900"
        )

    two_users = [
        await _create_user(db_session, f"+2279640{i:04d}")
        for i in range(2)
    ]
    for user_index, user in enumerate(two_users):
        for cycle_index in range(3 if user_index == 0 else 2):
            plot = await _farm_plot(
                db_session,
                user.id,
                tahoua.id,
                "1.000",
                f"Deux {user_index}-{cycle_index}",
            )
            await _cycle_with_harvest(
                db_session, plot.id, millet.id, date(2026, 2, 1), "600"
            )

    await db_session.commit()
    headers = _headers(admin)

    response = await _yields(client, headers)
    assert response.status_code == 200
    body = response.json()
    assert len(body["items"]) == 4

    visible = next(
        cell
        for cell in body["items"]
        if cell["crop"]["code"] == "millet" and cell["region"]["id"] == niamey.id
    )
    assert visible["masked"] is False
    assert visible["cycles"] == 5
    assert visible["farmers"] == 3
    assert visible["season_year"] == 2026
    assert visible["season_type"] == "rainy"
    assert visible["avg_yield_kg_per_ha"] == 1080.0
    assert visible["min_yield_kg_per_ha"] == 800.0
    assert visible["max_yield_kg_per_ha"] == 1400.0

    masked_cycles = next(
        cell
        for cell in body["items"]
        if cell["crop"]["code"] == "sorghum" and cell["region"]["id"] == dosso.id
    )
    assert masked_cycles["masked"] is True
    assert set(masked_cycles) == {
        "crop",
        "region",
        "season_year",
        "season_type",
        "masked",
    }

    masked_farmers = next(
        cell
        for cell in body["items"]
        if cell["crop"]["code"] == "cowpea" and cell["region"]["id"] == maradi.id
    )
    assert masked_farmers["masked"] is True

    masked_five_two = next(
        cell
        for cell in body["items"]
        if cell["crop"]["code"] == "millet" and cell["region"]["id"] == tahoua.id
    )
    assert masked_five_two["masked"] is True
    assert masked_five_two["season_type"] == "dry"

    for cell in body["items"]:
        assert not any(
            key in {"user_id", "farm_id", "plot_id", "crop_cycle_id", "cycle_id"}
            for key in _iter_keys(cell)
        )

    filtered = await _yields(
        client,
        headers,
        (
            f"?crop_id={millet.id}&region_id={child.id}"
            "&season_year=2026&season_type=rainy"
        ),
    )
    assert filtered.status_code == 200
    filtered_items = filtered.json()["items"]
    assert len(filtered_items) == 1
    assert filtered_items[0]["region"]["id"] == niamey.id
    assert filtered_items[0]["masked"] is False

    dry_only = await _yields(client, headers, "?season_type=dry")
    assert dry_only.status_code == 200
    assert [cell["season_type"] for cell in dry_only.json()["items"]] == [
        "dry"
    ]


async def test_overview_counts_and_masked_region(
    client: AsyncClient, db_session: AsyncSession
) -> None:
    admin = await _create_user(db_session, "+22796020001", "gov_admin")
    niamey = await _region(db_session, "NER-NIAMEY")
    dosso = await _region(db_session, "NER-DOSSO")
    crop = await _crop(db_session, "millet")
    now = datetime.now(UTC)

    niamey_users: list[User] = []
    for index in range(6):
        user = await _create_user(
            db_session,
            f"+2279650{index:04d}",
            last_login_at=now - timedelta(days=index),
        )
        niamey_users.append(user)
        plot = await _farm_plot(
            db_session, user.id, niamey.id, "1.500", f"Niamey {index}"
        )
        await _cycle_with_harvest(
            db_session, plot.id, crop.id, date(2026, 6, 1), "1500"
        )

    dosso_users: list[User] = []
    for index in range(2):
        user = await _create_user(
            db_session,
            f"+2279660{index:04d}",
            last_login_at=now - timedelta(days=index),
        )
        dosso_users.append(user)
        plot = await _farm_plot(
            db_session, user.id, dosso.id, "2.000", f"Dosso {index}"
        )
        await _cycle_with_harvest(
            db_session, plot.id, crop.id, date(2026, 6, 2), "2000"
        )

    inactive = await _create_user(
        db_session,
        "+22796700001",
        last_login_at=now - timedelta(days=40),
    )
    await _farm_plot(
        db_session, inactive.id, niamey.id, "3.000", "Inactif"
    )
    deleted = await _create_user(
        db_session,
        "+22796700002",
        last_login_at=now - timedelta(days=1),
        deleted=True,
    )
    await _farm_plot(
        db_session, deleted.id, niamey.id, "4.000", "Supprimé"
    )
    await _farm_plot(
        db_session,
        niamey_users[0].id,
        niamey.id,
        "5.000",
        "Parcelle supprimée",
        plot_deleted=True,
    )
    await _farm_plot(
        db_session,
        niamey_users[1].id,
        niamey.id,
        "6.000",
        "Ferme supprimée",
        farm_deleted=True,
    )

    db_session.add(
        Diagnostic(
            user_id=niamey_users[0].id,
            crop_id=crop.id,
            status="done",
            created_at=now - timedelta(days=2),
        )
    )
    db_session.add(
        Diagnostic(
            user_id=dosso_users[0].id,
            crop_id=crop.id,
            status="needs_review",
            created_at=now - timedelta(days=10),
        )
    )
    db_session.add(
        Diagnostic(
            user_id=niamey_users[1].id,
            crop_id=crop.id,
            status="done",
            created_at=now - timedelta(days=45),
        )
    )
    db_session.add(
        Diagnostic(
            user_id=niamey_users[2].id,
            crop_id=crop.id,
            status="done",
            created_at=now - timedelta(days=1),
            deleted_at=now,
        )
    )
    await db_session.commit()
    headers = _headers(admin)

    response = await client.get(
        "/api/v1/admin/stats/overview", headers=headers
    )
    assert response.status_code == 200
    body = response.json()
    assert body["active_users_30d"] == 8
    assert body["diagnostics_30d"] == 2
    assert body["tracked_area_ha"] == 13.0

    adoption = {entry["region"]["id"]: entry for entry in body["adoption"]}
    assert adoption[niamey.id]["masked"] is False
    assert adoption[niamey.id]["users"] == 6
    assert adoption[niamey.id]["plots"] == 6
    assert adoption[dosso.id] == {
        "region": {"id": dosso.id, "name_fr": "Dosso"},
        "masked": True,
    }

    assert not any(
        key in {"user_id", "farm_id", "plot_id", "crop_cycle_id", "cycle_id"}
        for key in _iter_keys(body)
    )


async def test_create_superuser_with_gov_admin_role(
    db_session: AsyncSession,
) -> None:
    phone = "+22796800001"
    await create_or_update_superuser(
        db_session, phone, "Compte Démo", "MotDePasse123!", "gov_admin"
    )
    user = (
        await db_session.execute(select(User).where(User.phone == phone))
    ).scalar_one()
    assert user.role == "gov_admin"
    assert user.is_active is True
    assert user.phone_verified_at is not None

    await create_or_update_superuser(
        db_session, phone, "Compte Démo", "MotDePasse456!", "gov_admin"
    )
    refreshed = (
        await db_session.execute(select(User).where(User.phone == phone))
    ).scalar_one()
    assert refreshed.role == "gov_admin"
    count = (
        await db_session.execute(
            select(func.count(User.id)).where(User.phone == phone)
        )
    ).scalar_one()
    assert count == 1
