import asyncio
import re
import uuid
from datetime import date

from httpx import AsyncClient
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.db.models.farming import Crop, CropCycle, Farm, FarmActivity, Harvest, Plot
from app.providers.sms.fake import FakeSmsProvider

PHONE_USER1 = "+22792000001"
PHONE_USER2 = "+22792000002"
OTP_PATTERN = re.compile(r"(\d{6})")


def _last_otp_code() -> str:
    message = FakeSmsProvider.sent_messages[-1]["message"]
    match = OTP_PATTERN.search(message)
    assert match is not None
    return match.group(1)


async def _register_verified(
    client: AsyncClient, phone: str
) -> dict[str, str]:
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


async def test_farm_crud(client: AsyncClient) -> None:
    headers = await _register_verified(client, PHONE_USER1)

    farm_payload = {
        "name": "Ferme du Sahel",
        "village": "Karma",
        "location": {"type": "Point", "coordinates": [2.1098, 13.5116]},
    }
    create_res = await client.post("/api/v1/farms", json=farm_payload, headers=headers)
    assert create_res.status_code == 201
    farm_data = create_res.json()
    farm_id = farm_data["id"]
    assert farm_data["name"] == "Ferme du Sahel"
    assert farm_data["village"] == "Karma"
    assert farm_data["location"]["type"] == "Point"

    get_res = await client.get(f"/api/v1/farms/{farm_id}", headers=headers)
    assert get_res.status_code == 200
    assert get_res.json()["name"] == "Ferme du Sahel"

    patch_res = await client.patch(
        f"/api/v1/farms/{farm_id}",
        json={"name": "Ferme Sahel Modifiée", "village": "Hamdallaye"},
        headers=headers,
    )
    assert patch_res.status_code == 200
    assert patch_res.json()["name"] == "Ferme Sahel Modifiée"
    assert patch_res.json()["village"] == "Hamdallaye"

    del_res = await client.delete(f"/api/v1/farms/{farm_id}", headers=headers)
    assert del_res.status_code == 204

    get_after_del = await client.get(f"/api/v1/farms/{farm_id}", headers=headers)
    assert get_after_del.status_code == 404


async def test_farm_idempotence_and_other_user_conflict(client: AsyncClient) -> None:
    headers1 = await _register_verified(client, PHONE_USER1)
    headers2 = await _register_verified(client, PHONE_USER2)

    fixed_id = str(uuid.uuid4())
    payload = {"id": fixed_id, "name": "Ferme Unique"}

    first_res = await client.post("/api/v1/farms", json=payload, headers=headers1)
    assert first_res.status_code == 201
    assert first_res.json()["id"] == fixed_id

    second_res = await client.post("/api/v1/farms", json=payload, headers=headers1)
    assert second_res.status_code == 200
    assert second_res.json()["id"] == fixed_id

    conflict_res = await client.post("/api/v1/farms", json=payload, headers=headers2)
    assert conflict_res.status_code == 409
    assert conflict_res.json()["error"]["code"] == "CONFLICT"


async def test_inter_user_404_isolation(client: AsyncClient) -> None:
    headers1 = await _register_verified(client, PHONE_USER1)
    headers2 = await _register_verified(client, PHONE_USER2)

    farm_res = await client.post(
        "/api/v1/farms", json={"name": "Ferme Privée"}, headers=headers1
    )
    assert farm_res.status_code == 201
    farm_id = farm_res.json()["id"]

    plot_res = await client.post(
        f"/api/v1/farms/{farm_id}/plots",
        json={"name": "Parcelle Privée", "area_ha": 1.5},
        headers=headers1,
    )
    assert plot_res.status_code == 201
    plot_id = plot_res.json()["id"]

    assert (await client.get(f"/api/v1/farms/{farm_id}", headers=headers2)).status_code == 404
    assert (
        await client.patch(
            f"/api/v1/farms/{farm_id}", json={"name": "Piratage"}, headers=headers2
        )
    ).status_code == 404
    assert (
        await client.delete(f"/api/v1/farms/{farm_id}", headers=headers2)
    ).status_code == 404

    assert (
        await client.get(f"/api/v1/farms/{farm_id}/plots", headers=headers2)
    ).status_code == 404
    assert (
        await client.post(
            f"/api/v1/farms/{farm_id}/plots", json={"name": "Intrusion"}, headers=headers2
        )
    ).status_code == 404

    assert (await client.get(f"/api/v1/plots/{plot_id}", headers=headers2)).status_code == 404
    assert (
        await client.patch(
            f"/api/v1/plots/{plot_id}", json={"name": "Piratage"}, headers=headers2
        )
    ).status_code == 404
    assert (
        await client.delete(f"/api/v1/plots/{plot_id}", headers=headers2)
    ).status_code == 404


async def test_plot_surface_recalculated_niamey_and_invalid_polygon(
    client: AsyncClient,
) -> None:
    headers = await _register_verified(client, PHONE_USER1)

    farm_res = await client.post(
        "/api/v1/farms", json={"name": "Ferme Surface"}, headers=headers
    )
    farm_id = farm_res.json()["id"]

    delta_lat = 0.0009009
    delta_lng = 0.0009265
    lng0 = 2.1098
    lat0 = 13.5116

    one_ha_polygon = {
        "type": "Polygon",
        "coordinates": [
            [
                [lng0, lat0],
                [round(lng0 + delta_lng, 7), lat0],
                [round(lng0 + delta_lng, 7), round(lat0 + delta_lat, 7)],
                [lng0, round(lat0 + delta_lat, 7)],
                [lng0, lat0],
            ]
        ],
    }

    plot_res = await client.post(
        f"/api/v1/farms/{farm_id}/plots",
        json={
            "name": "Parcelle 1ha Niamey",
            "geom": one_ha_polygon,
            "area_ha": 99.0,
        },
        headers=headers,
    )
    assert plot_res.status_code == 201
    created_plot = plot_res.json()
    calculated_area = float(created_plot["area_ha"])
    assert 0.98 <= calculated_area <= 1.02
    assert created_plot["geom"]["type"] == "Polygon"

    invalid_bowtie = {
        "type": "Polygon",
        "coordinates": [
            [
                [0.0, 0.0],
                [0.0, 1.0],
                [1.0, 0.0],
                [1.0, 1.0],
                [0.0, 0.0],
            ]
        ],
    }
    err_res = await client.post(
        f"/api/v1/farms/{farm_id}/plots",
        json={"name": "Parcelle Papillon", "geom": invalid_bowtie},
        headers=headers,
    )
    assert err_res.status_code == 422
    assert err_res.json()["error"]["code"] == "VALIDATION_ERROR"

    point_geom = {"type": "Point", "coordinates": [2.1098, 13.5116]}
    err_point = await client.post(
        f"/api/v1/farms/{farm_id}/plots",
        json={"name": "Parcelle Point", "geom": point_geom},
        headers=headers,
    )
    assert err_point.status_code == 422


async def test_plot_idempotence_and_other_user_conflict(client: AsyncClient) -> None:
    headers1 = await _register_verified(client, PHONE_USER1)
    headers2 = await _register_verified(client, PHONE_USER2)

    farm1 = (
        await client.post("/api/v1/farms", json={"name": "F1"}, headers=headers1)
    ).json()
    farm2 = (
        await client.post("/api/v1/farms", json={"name": "F2"}, headers=headers2)
    ).json()

    plot_uuid = str(uuid.uuid4())
    payload = {"id": plot_uuid, "name": "Parcelle Fixe", "area_ha": 1.2}

    res1 = await client.post(
        f"/api/v1/farms/{farm1['id']}/plots", json=payload, headers=headers1
    )
    assert res1.status_code == 201

    res2 = await client.post(
        f"/api/v1/farms/{farm1['id']}/plots", json=payload, headers=headers1
    )
    assert res2.status_code == 200
    assert res2.json()["id"] == plot_uuid

    res3 = await client.post(
        f"/api/v1/farms/{farm2['id']}/plots", json=payload, headers=headers2
    )
    assert res3.status_code == 409
    assert res3.json()["error"]["code"] == "CONFLICT"


async def test_quota_exceeded_fourth_plot_on_free_plan(client: AsyncClient) -> None:
    headers = await _register_verified(client, PHONE_USER1)

    farm_res = await client.post(
        "/api/v1/farms", json={"name": "Ferme Quota"}, headers=headers
    )
    farm_id = farm_res.json()["id"]

    for i in range(1, 4):
        res = await client.post(
            f"/api/v1/farms/{farm_id}/plots",
            json={"name": f"Parcelle {i}", "area_ha": 1.0},
            headers=headers,
        )
        assert res.status_code == 201

    res_fourth = await client.post(
        f"/api/v1/farms/{farm_id}/plots",
        json={"name": "Parcelle 4", "area_ha": 1.0},
        headers=headers,
    )
    assert res_fourth.status_code == 403
    error_body = res_fourth.json()["error"]
    assert error_body["code"] == "QUOTA_EXCEEDED"
    assert error_body["details"]["metric"] == "plots"
    assert error_body["details"]["limit"] == 3
    assert error_body["details"]["used"] == 3


async def test_cascade_soft_delete(
    client: AsyncClient, db_session: AsyncSession
) -> None:
    headers = await _register_verified(client, PHONE_USER1)

    farm_res = await client.post(
        "/api/v1/farms", json={"name": "Ferme Cascade"}, headers=headers
    )
    farm_id = uuid.UUID(farm_res.json()["id"])

    plot_res = await client.post(
        f"/api/v1/farms/{farm_id}/plots",
        json={"name": "Parcelle Cascade", "area_ha": 2.0},
        headers=headers,
    )
    plot_id = uuid.UUID(plot_res.json()["id"])

    crop = (await db_session.execute(select(Crop).limit(1))).scalar_one()

    cycle = CropCycle(
        plot_id=plot_id,
        crop_id=crop.id,
        variety="HKP",
        season="2026",
        status="growing",
    )
    db_session.add(cycle)
    await db_session.flush()

    activity = FarmActivity(
        crop_cycle_id=cycle.id,
        type="sowing",
        performed_on=date.today(),
        product_name="Semences",
    )
    db_session.add(activity)

    harvest = Harvest(
        crop_cycle_id=cycle.id,
        harvested_on=date.today(),
        quantity_kg=150.0,
    )
    db_session.add(harvest)
    await db_session.commit()

    del_farm = await client.delete(f"/api/v1/farms/{farm_id}", headers=headers)
    assert del_farm.status_code == 204

    f_db = (
        await db_session.execute(select(Farm).where(Farm.id == farm_id))
    ).scalar_one()
    p_db = (
        await db_session.execute(select(Plot).where(Plot.id == plot_id))
    ).scalar_one()
    c_db = (
        await db_session.execute(select(CropCycle).where(CropCycle.id == cycle.id))
    ).scalar_one()
    a_db = (
        await db_session.execute(
            select(FarmActivity).where(FarmActivity.id == activity.id)
        )
    ).scalar_one()
    h_db = (
        await db_session.execute(select(Harvest).where(Harvest.id == harvest.id))
    ).scalar_one()

    assert f_db.deleted_at is not None
    assert p_db.deleted_at is not None
    assert c_db.deleted_at is not None
    assert a_db.deleted_at is not None
    assert h_db.deleted_at is not None


async def test_farms_and_plots_cursor_pagination(client: AsyncClient) -> None:
    headers = await _register_verified(client, PHONE_USER1)

    farm_ids: list[str] = []
    for i in range(5):
        res = await client.post(
            "/api/v1/farms", json={"name": f"Ferme Paginée {i}"}, headers=headers
        )
        assert res.status_code == 201
        farm_ids.append(res.json()["id"])

    page1 = await client.get("/api/v1/farms?limit=2", headers=headers)
    assert page1.status_code == 200
    p1_data = page1.json()
    assert len(p1_data["items"]) == 2
    assert p1_data["next_cursor"] is not None

    page2 = await client.get(
        f"/api/v1/farms?limit=2&cursor={p1_data['next_cursor']}",
        headers=headers,
    )
    assert page2.status_code == 200
    p2_data = page2.json()
    assert len(p2_data["items"]) == 2
    assert p2_data["next_cursor"] is not None

    page3 = await client.get(
        f"/api/v1/farms?limit=2&cursor={p2_data['next_cursor']}",
        headers=headers,
    )
    assert page3.status_code == 200
    p3_data = page3.json()
    assert len(p3_data["items"]) == 1
    assert p3_data["next_cursor"] is None

    collected_ids = [
        item["id"]
        for item in p1_data["items"] + p2_data["items"] + p3_data["items"]
    ]
    assert len(collected_ids) == 5
    assert set(collected_ids) == set(farm_ids)


async def test_farm_and_plot_concurrent_same_id_idempotent(client: AsyncClient) -> None:
    headers = await _register_verified(client, PHONE_USER1)
    farm_id = str(uuid.uuid4())
    farm_payload = {"id": farm_id, "name": "Ferme Concurrente"}
    res1, res2 = await asyncio.gather(
        client.post("/api/v1/farms", json=farm_payload, headers=headers),
        client.post("/api/v1/farms", json=farm_payload, headers=headers),
    )
    assert {res1.status_code, res2.status_code} == {200, 201}
    assert res1.json()["id"] == farm_id
    assert res2.json()["id"] == farm_id

    plot_id = str(uuid.uuid4())
    plot_payload = {"id": plot_id, "name": "Parcelle Concurrente", "area_ha": 1.5}
    p_res1, p_res2 = await asyncio.gather(
        client.post(f"/api/v1/farms/{farm_id}/plots", json=plot_payload, headers=headers),
        client.post(f"/api/v1/farms/{farm_id}/plots", json=plot_payload, headers=headers),
    )
    assert {p_res1.status_code, p_res2.status_code} == {200, 201}
    assert p_res1.json()["id"] == plot_id
    assert p_res2.json()["id"] == plot_id


async def test_farm_and_plot_deleted_id_conflict_409(client: AsyncClient) -> None:
    headers = await _register_verified(client, PHONE_USER1)
    farm_id = str(uuid.uuid4())
    create_farm = await client.post(
        "/api/v1/farms", json={"id": farm_id, "name": "Ferme Supprimable"}, headers=headers
    )
    assert create_farm.status_code == 201

    del_farm = await client.delete(f"/api/v1/farms/{farm_id}", headers=headers)
    assert del_farm.status_code == 204

    recreate_farm = await client.post(
        "/api/v1/farms", json={"id": farm_id, "name": "Ferme Supprimable"}, headers=headers
    )
    assert recreate_farm.status_code == 409
    assert recreate_farm.json()["error"]["code"] == "CONFLICT"
    assert recreate_farm.json()["error"]["message"] == "Cette ressource a été supprimée."

    farm2_res = await client.post(
        "/api/v1/farms", json={"name": "Ferme Active"}, headers=headers
    )
    farm2_id = farm2_res.json()["id"]

    plot_id = str(uuid.uuid4())
    create_plot = await client.post(
        f"/api/v1/farms/{farm2_id}/plots",
        json={"id": plot_id, "name": "Parcelle Supprimable", "area_ha": 1.0},
        headers=headers,
    )
    assert create_plot.status_code == 201

    del_plot = await client.delete(f"/api/v1/plots/{plot_id}", headers=headers)
    assert del_plot.status_code == 204

    recreate_plot = await client.post(
        f"/api/v1/farms/{farm2_id}/plots",
        json={"id": plot_id, "name": "Parcelle Supprimable", "area_ha": 1.0},
        headers=headers,
    )
    assert recreate_plot.status_code == 409
    assert recreate_plot.json()["error"]["code"] == "CONFLICT"
    assert recreate_plot.json()["error"]["message"] == "Cette ressource a été supprimée."


async def test_plot_area_ha_bounds_and_geometry_conflict(client: AsyncClient) -> None:
    headers = await _register_verified(client, PHONE_USER1)
    farm_res = await client.post(
        "/api/v1/farms", json={"name": "Ferme Test Area"}, headers=headers
    )
    farm_id = farm_res.json()["id"]

    err_zero = await client.post(
        f"/api/v1/farms/{farm_id}/plots",
        json={"name": "P0", "area_ha": 0},
        headers=headers,
    )
    assert err_zero.status_code == 422

    err_neg = await client.post(
        f"/api/v1/farms/{farm_id}/plots",
        json={"name": "Pneg", "area_ha": -2.0},
        headers=headers,
    )
    assert err_neg.status_code == 422

    err_large = await client.post(
        f"/api/v1/farms/{farm_id}/plots",
        json={"name": "Plarge", "area_ha": 10000.5},
        headers=headers,
    )
    assert err_large.status_code == 422

    poly = {
        "type": "Polygon",
        "coordinates": [
            [
                [2.1098, 13.5116],
                [2.1107, 13.5116],
                [2.1107, 13.5125],
                [2.1098, 13.5125],
                [2.1098, 13.5116],
            ]
        ],
    }
    plot_geom = await client.post(
        f"/api/v1/farms/{farm_id}/plots",
        json={"name": "PGeom", "geom": poly},
        headers=headers,
    )
    assert plot_geom.status_code == 201
    geom_plot_id = plot_geom.json()["id"]

    patch_manual_area = await client.patch(
        f"/api/v1/plots/{geom_plot_id}",
        json={"area_ha": 5.0},
        headers=headers,
    )
    assert patch_manual_area.status_code == 422
    assert patch_manual_area.json()["error"]["code"] == "VALIDATION_ERROR"

    plot_no_geom = await client.post(
        f"/api/v1/farms/{farm_id}/plots",
        json={"name": "PNoGeom", "area_ha": 2.0},
        headers=headers,
    )
    assert plot_no_geom.status_code == 201
    no_geom_plot_id = plot_no_geom.json()["id"]

    patch_ok = await client.patch(
        f"/api/v1/plots/{no_geom_plot_id}",
        json={"area_ha": 4.5},
        headers=headers,
    )
    assert patch_ok.status_code == 200
    assert float(patch_ok.json()["area_ha"]) == 4.5

    patch_bounds = await client.patch(
        f"/api/v1/plots/{no_geom_plot_id}",
        json={"area_ha": 0},
        headers=headers,
    )
    assert patch_bounds.status_code == 422


async def test_geo_point_non_numeric_and_invalid_cursor_422(
    client: AsyncClient,
) -> None:
    headers = await _register_verified(client, PHONE_USER1)

    bad_point1 = await client.post(
        "/api/v1/farms",
        json={"name": "BadPt1", "location": {"type": "Point", "coordinates": ["abc", "def"]}},
        headers=headers,
    )
    assert bad_point1.status_code == 422
    assert bad_point1.json()["error"]["code"] == "VALIDATION_ERROR"

    bad_point2 = await client.post(
        "/api/v1/farms",
        json={"name": "BadPt2", "location": {"type": "Point", "coordinates": [None, 13.5]}},
        headers=headers,
    )
    assert bad_point2.status_code == 422

    cur_res1 = await client.get("/api/v1/farms?cursor=not-a-valid-cursor", headers=headers)
    assert cur_res1.status_code == 422
    assert cur_res1.json()["error"]["code"] == "VALIDATION_ERROR"

    cur_res2 = await client.get("/api/v1/farms?cursor=eyJ0IjoiYmFkIiwiaWQiOiJub3QtdXVpZCJ9", headers=headers)
    assert cur_res2.status_code == 422

    cur_res3 = await client.get(
        f"/api/v1/farms/{uuid.uuid4()}/plots?cursor=invalid-cursor", headers=headers
    )
    assert cur_res3.status_code == 422
