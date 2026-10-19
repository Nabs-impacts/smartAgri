import asyncio
import re
import uuid
from datetime import UTC, datetime

from httpx import AsyncClient
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import settings
from app.db.models.farming import Crop, CropCycle
from app.db.models.identity import AdminArea
from app.providers.sms.fake import FakeSmsProvider

PHONE_USER1 = "+22793000001"
PHONE_USER2 = "+22793000002"
OTP_PATTERN = re.compile(r"(\d{6})")


def _last_otp_code() -> str:
    message = FakeSmsProvider.sent_messages[-1]["message"]
    match = OTP_PATTERN.search(message)
    assert match is not None
    return match.group(1)


async def _register_verified(client: AsyncClient, phone: str) -> dict[str, str]:
    registered = await client.post(
        "/api/v1/auth/register",
        json={"phone": phone, "full_name": "Test User", "language": "fr"},
    )
    assert registered.status_code == 201

    verified = await client.post(
        "/api/v1/auth/otp/verify",
        json={"phone": phone, "code": _last_otp_code(), "purpose": "verify_phone"},
    )
    assert verified.status_code == 200
    data = verified.json()
    return {"Authorization": f"Bearer {data['access_token']}"}


async def _crop_id(session: AsyncSession, code: str = "millet") -> int:
    crop = (
        await session.execute(select(Crop).where(Crop.code == code))
    ).scalar_one()
    return crop.id


async def _niamey_area_id(session: AsyncSession) -> int:
    area = (
        await session.execute(
            select(AdminArea).where(AdminArea.code == "NER-NIAMEY")
        )
    ).scalar_one()
    return area.id


async def _create_plot(
    client: AsyncClient,
    headers: dict[str, str],
    area_ha: float = 2.0,
    admin_area_id: int | None = None,
) -> dict:
    farm_payload = {"name": "Ferme Cycle"}
    if admin_area_id is not None:
        farm_payload["admin_area_id"] = admin_area_id
    farm = await client.post("/api/v1/farms", json=farm_payload, headers=headers)
    assert farm.status_code == 201
    plot = await client.post(
        f"/api/v1/farms/{farm.json()['id']}/plots",
        json={"name": "Parcelle Cycle", "area_ha": area_ha},
        headers=headers,
    )
    assert plot.status_code == 201
    return plot.json()


async def test_cycle_lifecycle_and_forbidden_transitions(
    client: AsyncClient, db_session: AsyncSession
) -> None:
    headers = await _register_verified(client, PHONE_USER1)
    plot = await _create_plot(client, headers)
    crop_id = await _crop_id(db_session)

    create_res = await client.post(
        f"/api/v1/plots/{plot['id']}/cycles",
        json={
            "crop_id": crop_id,
            "variety": "HKP",
            "season": "2026",
            "sowing_date": "2026-05-01",
        },
        headers=headers,
    )
    assert create_res.status_code == 201
    cycle = create_res.json()
    cycle_id = cycle["id"]
    assert cycle["status"] == "planned"
    assert cycle["expected_harvest_date"] == "2026-07-30"

    listed = await client.get(
        f"/api/v1/plots/{plot['id']}/cycles", headers=headers
    )
    assert listed.status_code == 200
    assert [item["id"] for item in listed.json()["items"]] == [cycle_id]

    get_res = await client.get(f"/api/v1/cycles/{cycle_id}", headers=headers)
    assert get_res.status_code == 200
    assert get_res.json()["variety"] == "HKP"

    forbidden_harvest = await client.patch(
        f"/api/v1/cycles/{cycle_id}",
        json={"status": "harvested"},
        headers=headers,
    )
    assert forbidden_harvest.status_code == 409
    assert forbidden_harvest.json()["error"]["code"] == "CONFLICT"

    growing = await client.patch(
        f"/api/v1/cycles/{cycle_id}",
        json={"status": "growing"},
        headers=headers,
    )
    assert growing.status_code == 200
    assert growing.json()["status"] == "growing"

    backward = await client.patch(
        f"/api/v1/cycles/{cycle_id}",
        json={"status": "planned"},
        headers=headers,
    )
    assert backward.status_code == 409

    harvested = await client.patch(
        f"/api/v1/cycles/{cycle_id}",
        json={"status": "harvested", "harvest_date": "2026-08-10"},
        headers=headers,
    )
    assert harvested.status_code == 200
    assert harvested.json()["status"] == "harvested"
    assert harvested.json()["harvest_date"] == "2026-08-10"

    terminal = await client.patch(
        f"/api/v1/cycles/{cycle_id}",
        json={"status": "growing"},
        headers=headers,
    )
    assert terminal.status_code == 409

    second = await client.post(
        f"/api/v1/plots/{plot['id']}/cycles",
        json={"crop_id": crop_id},
        headers=headers,
    )
    second_id = second.json()["id"]
    assert second.json()["expected_harvest_date"] is None
    assert (
        await client.patch(
            f"/api/v1/cycles/{second_id}",
            json={"status": "growing"},
            headers=headers,
        )
    ).status_code == 200
    failed = await client.patch(
        f"/api/v1/cycles/{second_id}",
        json={"status": "failed"},
        headers=headers,
    )
    assert failed.status_code == 200
    assert failed.json()["status"] == "failed"


async def test_cycle_idempotence_conflicts_and_deleted_id(
    client: AsyncClient, db_session: AsyncSession
) -> None:
    headers1 = await _register_verified(client, PHONE_USER1)
    headers2 = await _register_verified(client, PHONE_USER2)
    plot1 = await _create_plot(client, headers1)
    plot2 = await _create_plot(client, headers2)
    crop_id = await _crop_id(db_session)

    fixed_id = str(uuid.uuid4())
    payload = {"id": fixed_id, "crop_id": crop_id, "sowing_date": "2026-04-01"}

    first = await client.post(
        f"/api/v1/plots/{plot1['id']}/cycles", json=payload, headers=headers1
    )
    assert first.status_code == 201
    second = await client.post(
        f"/api/v1/plots/{plot1['id']}/cycles", json=payload, headers=headers1
    )
    assert second.status_code == 200
    assert second.json()["id"] == fixed_id

    conflict = await client.post(
        f"/api/v1/plots/{plot2['id']}/cycles", json=payload, headers=headers2
    )
    assert conflict.status_code == 409
    assert conflict.json()["error"]["code"] == "CONFLICT"

    concurrent_id = str(uuid.uuid4())
    concurrent_payload = {"id": concurrent_id, "crop_id": crop_id}
    res1, res2 = await asyncio.gather(
        client.post(
            f"/api/v1/plots/{plot1['id']}/cycles",
            json=concurrent_payload,
            headers=headers1,
        ),
        client.post(
            f"/api/v1/plots/{plot1['id']}/cycles",
            json=concurrent_payload,
            headers=headers1,
        ),
    )
    assert {res1.status_code, res2.status_code} == {200, 201}
    assert res1.json()["id"] == concurrent_id
    assert res2.json()["id"] == concurrent_id

    cycle = (
        await db_session.execute(
            select(CropCycle).where(CropCycle.id == uuid.UUID(fixed_id))
        )
    ).scalar_one()
    cycle.deleted_at = datetime.now(UTC)
    await db_session.commit()

    deleted_conflict = await client.post(
        f"/api/v1/plots/{plot1['id']}/cycles", json=payload, headers=headers1
    )
    assert deleted_conflict.status_code == 409
    assert (
        deleted_conflict.json()["error"]["message"]
        == "Cette ressource a été supprimée."
    )


async def test_activities_crud_and_harvest_close_cycle(
    client: AsyncClient, db_session: AsyncSession
) -> None:
    headers = await _register_verified(client, PHONE_USER1)
    plot = await _create_plot(client, headers)
    crop_id = await _crop_id(db_session)
    cycle = (
        await client.post(
            f"/api/v1/plots/{plot['id']}/cycles",
            json={"crop_id": crop_id, "sowing_date": "2026-05-01"},
            headers=headers,
        )
    ).json()
    cycle_id = cycle["id"]

    activity_id = str(uuid.uuid4())
    activity_payload = {
        "id": activity_id,
        "type": "fertilizing",
        "performed_on": "2026-05-10",
        "product_name": "NPK",
        "quantity": 50,
        "unit": "kg",
        "cost_xof": 30000,
    }
    created = await client.post(
        f"/api/v1/cycles/{cycle_id}/activities",
        json=activity_payload,
        headers=headers,
    )
    assert created.status_code == 201
    assert created.json()["cost_xof"] == 30000

    repeated = await client.post(
        f"/api/v1/cycles/{cycle_id}/activities",
        json=activity_payload,
        headers=headers,
    )
    assert repeated.status_code == 200
    assert repeated.json()["id"] == activity_id

    second = await client.post(
        f"/api/v1/cycles/{cycle_id}/activities",
        json={
            "type": "weeding",
            "performed_on": "2026-05-12",
            "cost_xof": 20000,
        },
        headers=headers,
    )
    assert second.status_code == 201

    listed = await client.get(
        f"/api/v1/cycles/{cycle_id}/activities", headers=headers
    )
    assert listed.status_code == 200
    assert len(listed.json()["items"]) == 2

    patched = await client.patch(
        f"/api/v1/activities/{activity_id}",
        json={"cost_xof": 35000, "notes": "Ajusté"},
        headers=headers,
    )
    assert patched.status_code == 200
    assert patched.json()["cost_xof"] == 35000
    assert patched.json()["notes"] == "Ajusté"

    deleted = await client.delete(
        f"/api/v1/activities/{activity_id}", headers=headers
    )
    assert deleted.status_code == 204
    after_delete = await client.get(
        f"/api/v1/cycles/{cycle_id}/activities", headers=headers
    )
    assert len(after_delete.json()["items"]) == 1
    assert (
        await client.patch(
            f"/api/v1/activities/{activity_id}", json={"cost_xof": 1}, headers=headers
        )
    ).status_code == 404

    harvest = await client.post(
        f"/api/v1/cycles/{cycle_id}/harvests",
        json={
            "harvested_on": "2026-07-30",
            "quantity_kg": 1000,
            "quality": "A",
            "sold_kg": 800,
            "avg_price_xof_per_kg": 250,
            "close_cycle": True,
        },
        headers=headers,
    )
    assert harvest.status_code == 201
    assert float(harvest.json()["quantity_kg"]) == 1000

    refreshed = await client.get(f"/api/v1/cycles/{cycle_id}", headers=headers)
    assert refreshed.json()["status"] == "harvested"
    assert refreshed.json()["harvest_date"] == "2026-07-30"


async def _other_cycle_with_yield(
    client: AsyncClient,
    phone: str,
    crop_id: int,
    admin_area_id: int,
    quantity_kg: float,
) -> None:
    headers = await _register_verified(client, phone)
    plot = await _create_plot(
        client, headers, area_ha=1.0, admin_area_id=admin_area_id
    )
    cycle = await client.post(
        f"/api/v1/plots/{plot['id']}/cycles",
        json={"crop_id": crop_id},
        headers=headers,
    )
    assert cycle.status_code == 201
    harvest = await client.post(
        f"/api/v1/cycles/{cycle.json()['id']}/harvests",
        json={"harvested_on": "2026-08-01", "quantity_kg": quantity_kg},
        headers=headers,
    )
    assert harvest.status_code == 201


async def test_summary_manual_numbers_and_comparison_threshold(
    client: AsyncClient, db_session: AsyncSession, monkeypatch
) -> None:
    monkeypatch.setattr(settings, "REGISTER_REQUESTS_PER_IP_WINDOW", 50)
    headers = await _register_verified(client, PHONE_USER1)
    admin_area_id = await _niamey_area_id(db_session)
    crop_id = await _crop_id(db_session)
    plot = await _create_plot(
        client, headers, area_ha=2.0, admin_area_id=admin_area_id
    )
    cycle = (
        await client.post(
            f"/api/v1/plots/{plot['id']}/cycles",
            json={"crop_id": crop_id},
            headers=headers,
        )
    ).json()
    cycle_id = cycle["id"]

    for cost, activity_type in ((30000, "fertilizing"), (20000, "weeding")):
        res = await client.post(
            f"/api/v1/cycles/{cycle_id}/activities",
            json={
                "type": activity_type,
                "performed_on": "2026-05-10",
                "cost_xof": cost,
            },
            headers=headers,
        )
        assert res.status_code == 201

    harvest = await client.post(
        f"/api/v1/cycles/{cycle_id}/harvests",
        json={
            "harvested_on": "2026-08-01",
            "quantity_kg": 1000,
            "sold_kg": 800,
            "avg_price_xof_per_kg": 250,
        },
        headers=headers,
    )
    assert harvest.status_code == 201

    summary = await client.get(
        f"/api/v1/cycles/{cycle_id}/summary", headers=headers
    )
    assert summary.status_code == 200
    body = summary.json()
    assert float(body["area_ha"]) == 2.0
    assert float(body["total_kg"]) == 1000.0
    assert float(body["yield_kg_per_ha"]) == 500.0
    assert body["total_cost_xof"] == 50000
    assert float(body["revenue_xof"]) == 200000.0
    assert float(body["margin_xof"]) == 150000.0
    assert body["comparison"] is None

    for index in range(4):
        await _other_cycle_with_yield(
            client,
            f"+2279400000{index}",
            crop_id,
            admin_area_id,
            400.0,
        )

    below_threshold = await client.get(
        f"/api/v1/cycles/{cycle_id}/summary", headers=headers
    )
    assert below_threshold.json()["comparison"] is None

    await _other_cycle_with_yield(
        client, "+22794000009", crop_id, admin_area_id, 400.0
    )

    above_threshold = await client.get(
        f"/api/v1/cycles/{cycle_id}/summary", headers=headers
    )
    comparison = above_threshold.json()["comparison"]
    assert comparison is not None
    assert comparison["sample_size"] == 5
    assert float(comparison["average_yield_kg_per_ha"]) == 400.0


async def test_timeline_merges_and_paginates(
    client: AsyncClient, db_session: AsyncSession
) -> None:
    headers = await _register_verified(client, PHONE_USER1)
    plot = await _create_plot(client, headers)
    crop_id = await _crop_id(db_session)
    cycle = (
        await client.post(
            f"/api/v1/plots/{plot['id']}/cycles",
            json={"crop_id": crop_id},
            headers=headers,
        )
    ).json()
    cycle_id = cycle["id"]

    for performed_on in ("2026-05-01", "2026-05-03"):
        res = await client.post(
            f"/api/v1/cycles/{cycle_id}/activities",
            json={"type": "weeding", "performed_on": performed_on},
            headers=headers,
        )
        assert res.status_code == 201

    for harvested_on in ("2026-05-02", "2026-05-05"):
        res = await client.post(
            f"/api/v1/cycles/{cycle_id}/harvests",
            json={"harvested_on": harvested_on, "quantity_kg": 10},
            headers=headers,
        )
        assert res.status_code == 201

    page1 = await client.get(
        f"/api/v1/plots/{plot['id']}/timeline?limit=2", headers=headers
    )
    assert page1.status_code == 200
    first_page = page1.json()
    assert len(first_page["items"]) == 2
    assert [item["occurred_on"] for item in first_page["items"]] == [
        "2026-05-05",
        "2026-05-03",
    ]
    assert [item["type"] for item in first_page["items"]] == [
        "harvest",
        "activity",
    ]
    assert first_page["next_cursor"] is not None

    page2 = await client.get(
        f"/api/v1/plots/{plot['id']}/timeline?limit=2"
        f"&cursor={first_page['next_cursor']}",
        headers=headers,
    )
    assert page2.status_code == 200
    second_page = page2.json()
    assert [item["occurred_on"] for item in second_page["items"]] == [
        "2026-05-02",
        "2026-05-01",
    ]
    assert [item["type"] for item in second_page["items"]] == [
        "harvest",
        "activity",
    ]
    assert second_page["next_cursor"] is None


async def test_inter_user_resources_return_404(
    client: AsyncClient, db_session: AsyncSession
) -> None:
    headers1 = await _register_verified(client, PHONE_USER1)
    headers2 = await _register_verified(client, PHONE_USER2)
    plot = await _create_plot(client, headers1)
    crop_id = await _crop_id(db_session)

    cycle = (
        await client.post(
            f"/api/v1/plots/{plot['id']}/cycles",
            json={"crop_id": crop_id},
            headers=headers1,
        )
    ).json()
    cycle_id = cycle["id"]
    activity = (
        await client.post(
            f"/api/v1/cycles/{cycle_id}/activities",
            json={"type": "sowing", "performed_on": "2026-05-01"},
            headers=headers1,
        )
    ).json()

    assert (
        await client.get(
            f"/api/v1/plots/{plot['id']}/cycles", headers=headers2
        )
    ).status_code == 404
    assert (
        await client.post(
            f"/api/v1/plots/{plot['id']}/cycles",
            json={"crop_id": crop_id},
            headers=headers2,
        )
    ).status_code == 404
    assert (
        await client.get(f"/api/v1/cycles/{cycle_id}", headers=headers2)
    ).status_code == 404
    assert (
        await client.patch(
            f"/api/v1/cycles/{cycle_id}",
            json={"status": "growing"},
            headers=headers2,
        )
    ).status_code == 404
    assert (
        await client.get(
            f"/api/v1/cycles/{cycle_id}/activities", headers=headers2
        )
    ).status_code == 404
    assert (
        await client.post(
            f"/api/v1/cycles/{cycle_id}/activities",
            json={"type": "sowing", "performed_on": "2026-05-01"},
            headers=headers2,
        )
    ).status_code == 404
    assert (
        await client.patch(
            f"/api/v1/activities/{activity['id']}",
            json={"cost_xof": 1},
            headers=headers2,
        )
    ).status_code == 404
    assert (
        await client.delete(
            f"/api/v1/activities/{activity['id']}", headers=headers2
        )
    ).status_code == 404
    assert (
        await client.post(
            f"/api/v1/cycles/{cycle_id}/harvests",
            json={"harvested_on": "2026-08-01", "quantity_kg": 10},
            headers=headers2,
        )
    ).status_code == 404
    assert (
        await client.get(
            f"/api/v1/cycles/{cycle_id}/summary", headers=headers2
        )
    ).status_code == 404
    assert (
        await client.get(
            f"/api/v1/plots/{plot['id']}/timeline", headers=headers2
        )
    ).status_code == 404
