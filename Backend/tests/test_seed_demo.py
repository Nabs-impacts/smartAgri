from datetime import UTC, datetime

import pytest
from httpx import AsyncClient
from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.security import create_access_token
from app.db.models.farming import CropCycle, Farm, Harvest, Plot
from app.db.models.identity import User
from app.db.models.media_ai import Diagnostic
from scripts.seed_demo import _check_environment, seed_demo

DEMO_PHONES = [f"+2279000{index:04d}" for index in range(1, 31)]


async def _counts(session: AsyncSession) -> dict[str, int]:
    async def count(model, *joins) -> int:
        stmt = select(func.count(model.id))
        for target, condition in joins:
            stmt = stmt.join(target, condition)
        stmt = stmt.where(User.phone.in_(DEMO_PHONES))
        return int((await session.execute(stmt)).scalar_one())

    return {
        "users": int(
            (
                await session.execute(
                    select(func.count(User.id)).where(
                        User.phone.in_(DEMO_PHONES)
                    )
                )
            ).scalar_one()
        ),
        "farms": await count(
            Farm, (User, Farm.owner_id == User.id)
        ),
        "plots": await count(
            Plot,
            (Farm, Plot.farm_id == Farm.id),
            (User, Farm.owner_id == User.id),
        ),
        "cycles": await count(
            CropCycle,
            (Plot, CropCycle.plot_id == Plot.id),
            (Farm, Plot.farm_id == Farm.id),
            (User, Farm.owner_id == User.id),
        ),
        "harvests": await count(
            Harvest,
            (CropCycle, Harvest.crop_cycle_id == CropCycle.id),
            (Plot, CropCycle.plot_id == Plot.id),
            (Farm, Plot.farm_id == Farm.id),
            (User, Farm.owner_id == User.id),
        ),
        "diagnostics": await count(
            Diagnostic, (User, Diagnostic.user_id == User.id)
        ),
    }


async def test_seed_demo_is_idempotent_and_feeds_stats(
    client: AsyncClient,
    db_session: AsyncSession,
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    monkeypatch.setenv("DEMO_PASSWORD", "MotDePasseDemo123!")
    await seed_demo(db_session)
    first = await _counts(db_session)
    assert first == {
        "users": 30,
        "farms": 30,
        "plots": 60,
        "cycles": 66,
        "harvests": 66,
        "diagnostics": 6,
    }

    await seed_demo(db_session)
    second = await _counts(db_session)
    assert second == first

    admin = User(
        phone="+22797000001",
        full_name="Gouverneur Démo",
        role="gov_admin",
        is_active=True,
        phone_verified_at=datetime.now(UTC),
    )
    db_session.add(admin)
    await db_session.commit()
    headers = {
        "Authorization": f"Bearer {create_access_token(admin.id, admin.role)}"
    }

    response = await client.get("/api/v1/admin/stats/yields", headers=headers)
    assert response.status_code == 200
    items = response.json()["items"]
    assert any(cell["masked"] is False for cell in items)
    assert any(cell["masked"] is True for cell in items)

    overview = await client.get(
        "/api/v1/admin/stats/overview", headers=headers
    )
    assert overview.status_code == 200
    assert overview.json()["active_users_30d"] == 30


async def test_seed_demo_requires_password(
    db_session: AsyncSession, monkeypatch: pytest.MonkeyPatch
) -> None:
    monkeypatch.delenv("DEMO_PASSWORD", raising=False)
    with pytest.raises(RuntimeError, match="DEMO_PASSWORD"):
        await seed_demo(db_session)


def test_seed_demo_refuses_production(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    monkeypatch.setenv("ENVIRONMENT", "production")
    with pytest.raises(RuntimeError, match="production"):
        _check_environment()
