import re
import uuid
from datetime import UTC, datetime, timedelta

from httpx import AsyncClient
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import settings
from app.db.models.farming import (
    Crop,
    CropCycle,
    Farm,
    FarmActivity,
    Harvest,
    Plot,
)
from app.providers.sms.fake import FakeSmsProvider
from app.services.sync_service import OTHER_USER_ERROR

PHONE_USER1 = "+22792000001"
PHONE_USER2 = "+22792000002"
PHONE_OWNER = "+22792000003"
OTP_PATTERN = re.compile(r"(\d{6})")


def _last_otp_code() -> str:
    message = FakeSmsProvider.sent_messages[-1]["message"]
    match = OTP_PATTERN.search(message)
    assert match is not None
    return match.group(1)


async def _register_verified(
    client: AsyncClient, phone: str
) -> tuple[dict[str, str], str]:
    registered = await client.post(
        "/api/v1/auth/register",
        json={"phone": phone, "full_name": "Sync User", "language": "fr"},
    )
    assert registered.status_code == 201
    verified = await client.post(
        "/api/v1/auth/otp/verify",
        json={"phone": phone, "code": _last_otp_code(), "purpose": "verify_phone"},
    )
    assert verified.status_code == 200
    body = verified.json()
    return (
        {"Authorization": f"Bearer {body['access_token']}"},
        body["user"]["id"],
    )


async def _crop_id(session: AsyncSession, code: str = "millet") -> int:
    crop = (
        await session.execute(select(Crop).where(Crop.code == code))
    ).scalar_one()
    return crop.id


def _iso(value: datetime) -> str:
    return value.isoformat()


def _now() -> datetime:
    return datetime.now(UTC)


async def _push(
    client: AsyncClient, headers: dict[str, str], changes: list[dict]
) -> list[dict]:
    response = await client.post(
        "/api/v1/sync/push", json={"changes": changes}, headers=headers
    )
    assert response.status_code == 200
    return response.json()["results"]


def _farm_change(
    farm_id: uuid.UUID, name: str, updated_at: datetime
) -> dict:
    return {
        "entity": "farm",
        "op": "upsert",
        "id": str(farm_id),
        "data": {"name": name},
        "updated_at": _iso(updated_at),
    }


def _plot_change(
    plot_id: uuid.UUID,
    farm_id: uuid.UUID,
    name: str,
    updated_at: datetime,
) -> dict:
    return {
        "entity": "plot",
        "op": "upsert",
        "id": str(plot_id),
        "data": {"farm_id": str(farm_id), "name": name, "area_ha": 2.0},
        "updated_at": _iso(updated_at),
    }


def _cycle_change(
    cycle_id: uuid.UUID, plot_id: uuid.UUID, crop_id: int, updated_at: datetime
) -> dict:
    return {
        "entity": "crop_cycle",
        "op": "upsert",
        "id": str(cycle_id),
        "data": {"plot_id": str(plot_id), "crop_id": crop_id},
        "updated_at": _iso(updated_at),
    }


def _activity_change(
    activity_id: uuid.UUID, cycle_id: uuid.UUID, updated_at: datetime
) -> dict:
    return {
        "entity": "farm_activity",
        "op": "upsert",
        "id": str(activity_id),
        "data": {
            "crop_cycle_id": str(cycle_id),
            "type": "sowing",
            "performed_on": "2026-05-01",
        },
        "updated_at": _iso(updated_at),
    }


def _harvest_change(
    harvest_id: uuid.UUID, cycle_id: uuid.UUID, updated_at: datetime
) -> dict:
    return {
        "entity": "harvest",
        "op": "upsert",
        "id": str(harvest_id),
        "data": {
            "crop_cycle_id": str(cycle_id),
            "harvested_on": "2026-08-01",
            "quantity_kg": 1000,
        },
        "updated_at": _iso(updated_at),
    }


async def _pull(
    client: AsyncClient,
    headers: dict[str, str],
    since: str | None = None,
    limit: int | None = None,
) -> dict:
    params: dict[str, object] = {}
    if since is not None:
        params["since"] = since
    if limit is not None:
        params["limit"] = limit
    response = await client.get(
        "/api/v1/sync/pull", params=params, headers=headers
    )
    assert response.status_code == 200
    return response.json()


def _entity_ids(pull_body: dict, entity: str) -> set[str]:
    return {
        change["id"]
        for change in pull_body["changes"]
        if change["entity"] == entity
    }


async def test_push_creates_five_entities_in_order(
    client: AsyncClient, db_session: AsyncSession
) -> None:
    headers, _ = await _register_verified(client, PHONE_USER1)
    crop_id = await _crop_id(db_session)
    now = _now()
    farm_id = uuid.uuid4()
    plot_id = uuid.uuid4()
    cycle_id = uuid.uuid4()
    activity_id = uuid.uuid4()
    harvest_id = uuid.uuid4()

    results = await _push(
        client,
        headers,
        [
            _farm_change(farm_id, "Ferme Sync", now),
            _plot_change(plot_id, farm_id, "Parcelle Sync", now),
            _cycle_change(cycle_id, plot_id, crop_id, now),
            _activity_change(activity_id, cycle_id, now),
            _harvest_change(harvest_id, cycle_id, now),
        ],
    )
    assert [result["status"] for result in results] == ["applied"] * 5

    pull_body = await _pull(client, headers)
    assert _entity_ids(pull_body, "farm") == {str(farm_id)}
    assert _entity_ids(pull_body, "plot") == {str(plot_id)}
    assert _entity_ids(pull_body, "crop_cycle") == {str(cycle_id)}
    assert _entity_ids(pull_body, "farm_activity") == {str(activity_id)}
    assert _entity_ids(pull_body, "harvest") == {str(harvest_id)}


async def test_push_is_idempotent(
    client: AsyncClient, db_session: AsyncSession
) -> None:
    headers, _ = await _register_verified(client, PHONE_USER1)
    crop_id = await _crop_id(db_session)
    now = _now()
    farm_id = uuid.uuid4()
    plot_id = uuid.uuid4()
    cycle_id = uuid.uuid4()
    changes = [
        _farm_change(farm_id, "Ferme Idem", now),
        _plot_change(plot_id, farm_id, "Parcelle Idem", now),
        _cycle_change(cycle_id, plot_id, crop_id, now),
    ]

    first = await _push(client, headers, changes)
    assert [result["status"] for result in first] == ["applied"] * 3
    second = await _push(client, headers, changes)
    assert all(result["status"] != "rejected" for result in second)

    pull_body = await _pull(client, headers)
    assert len(_entity_ids(pull_body, "farm")) == 1
    assert len(_entity_ids(pull_body, "plot")) == 1
    assert len(_entity_ids(pull_body, "crop_cycle")) == 1


async def test_push_conflict_keeps_server_value(client: AsyncClient) -> None:
    headers, _ = await _register_verified(client, PHONE_USER1)
    farm_id = uuid.uuid4()
    now = _now()
    await _push(client, headers, [_farm_change(farm_id, "Origine", now)])

    older = now - timedelta(hours=1)
    results = await _push(
        client, headers, [_farm_change(farm_id, "Renommée", older)]
    )
    assert results[0]["status"] == "conflict"

    fetched = await client.get(f"/api/v1/farms/{farm_id}", headers=headers)
    assert fetched.status_code == 200
    assert fetched.json()["name"] == "Origine"


async def test_push_delete_and_redelete(
    client: AsyncClient, db_session: AsyncSession
) -> None:
    headers, _ = await _register_verified(client, PHONE_USER1)
    crop_id = await _crop_id(db_session)
    now = _now()
    farm_id = uuid.uuid4()
    plot_id = uuid.uuid4()
    cycle_id = uuid.uuid4()
    await _push(
        client,
        headers,
        [
            _farm_change(farm_id, "Ferme Delete", now),
            _plot_change(plot_id, farm_id, "Parcelle Delete", now),
            _cycle_change(cycle_id, plot_id, crop_id, now),
        ],
    )

    delete_change = {
        "entity": "farm",
        "op": "delete",
        "id": str(farm_id),
        "data": {},
        "updated_at": _iso(_now()),
    }
    first = await _push(client, headers, [delete_change])
    assert first[0]["status"] == "applied"
    second = await _push(client, headers, [delete_change])
    assert second[0]["status"] == "applied"

    failed = await client.get(
        f"/api/v1/farms/{farm_id}", headers=headers
    )
    assert failed.status_code == 404


async def test_upsert_on_deleted_resource_rejected(
    client: AsyncClient, db_session: AsyncSession
) -> None:
    headers, _ = await _register_verified(client, PHONE_USER1)
    crop_id = await _crop_id(db_session)
    now = _now()
    farm_id = uuid.uuid4()
    plot_id = uuid.uuid4()
    cycle_id = uuid.uuid4()
    await _push(
        client,
        headers,
        [
            _farm_change(farm_id, "Ferme Suppr", now),
            _plot_change(plot_id, farm_id, "Parcelle Suppr", now),
            _cycle_change(cycle_id, plot_id, crop_id, now),
        ],
    )
    await _push(
        client,
        headers,
        [
            {
                "entity": "farm",
                "op": "delete",
                "id": str(farm_id),
                "data": {},
                "updated_at": _iso(_now()),
            }
        ],
    )

    results = await _push(
        client,
        headers,
        [_farm_change(farm_id, "Ressuscitée", _now() + timedelta(minutes=1))],
    )
    assert results[0]["status"] == "rejected"
    assert results[0]["error"] == "Cette ressource a été supprimée."


async def test_future_updated_at_is_clamped(client: AsyncClient) -> None:
    headers, _ = await _register_verified(client, PHONE_USER1)
    farm_id = uuid.uuid4()
    future = _now() + timedelta(hours=2)
    results = await _push(
        client, headers, [_farm_change(farm_id, "Ferme Futur", future)]
    )
    assert results[0]["status"] == "applied"
    server_updated_at = datetime.fromisoformat(results[0]["server_updated_at"])
    assert server_updated_at < _now() + timedelta(minutes=1)


async def test_other_user_resource_rejected_without_failing_batch(
    client: AsyncClient,
) -> None:
    headers_one, _ = await _register_verified(client, PHONE_USER1)
    headers_two, _ = await _register_verified(client, PHONE_USER2)
    foreign_id = uuid.uuid4()
    await _push(
        client, headers_one, [_farm_change(foreign_id, "Ferme Un", _now())]
    )

    own_id = uuid.uuid4()
    results = await _push(
        client,
        headers_two,
        [
            _farm_change(foreign_id, "Vol", _now() + timedelta(minutes=1)),
            _farm_change(own_id, "Ferme Deux", _now()),
        ],
    )
    assert results[0]["status"] == "rejected"
    assert results[0]["error"] == "Cette ressource appartient à un autre utilisateur."
    assert results[1]["status"] == "applied"


async def test_push_more_than_200_changes_is_422(client: AsyncClient) -> None:
    headers, _ = await _register_verified(client, PHONE_USER1)
    changes = [
        {
            "entity": "farm",
            "op": "delete",
            "id": str(uuid.uuid4()),
            "data": {},
            "updated_at": _iso(_now()),
        }
        for _ in range(201)
    ]
    response = await client.post(
        "/api/v1/sync/push", json={"changes": changes}, headers=headers
    )
    assert response.status_code == 422


async def test_pull_full_then_incremental(
    client: AsyncClient, db_session: AsyncSession
) -> None:
    headers, _ = await _register_verified(client, PHONE_USER1)
    crop_id = await _crop_id(db_session)
    now = _now()
    farm_id = uuid.uuid4()
    plot_id = uuid.uuid4()
    cycle_id = uuid.uuid4()
    await _push(
        client,
        headers,
        [
            _farm_change(farm_id, "Ferme Pull", now),
            _plot_change(plot_id, farm_id, "Parcelle Pull", now),
            _cycle_change(cycle_id, plot_id, crop_id, now),
        ],
    )

    full = await _pull(client, headers)
    assert _entity_ids(full, "farm") == {str(farm_id)}
    assert full["next_cursor"] is not None

    activity_id = uuid.uuid4()
    await _push(
        client, headers, [_activity_change(activity_id, cycle_id, _now())]
    )

    incremental = await _pull(client, headers, since=full["next_cursor"])
    assert _entity_ids(incremental, "farm_activity") == {str(activity_id)}
    assert _entity_ids(incremental, "farm") == set()


async def test_pull_includes_cascaded_deletions(
    client: AsyncClient, db_session: AsyncSession
) -> None:
    headers, _ = await _register_verified(client, PHONE_USER1)
    crop_id = await _crop_id(db_session)
    now = _now()
    farm_id = uuid.uuid4()
    plot_id = uuid.uuid4()
    cycle_id = uuid.uuid4()
    activity_id = uuid.uuid4()
    harvest_id = uuid.uuid4()
    await _push(
        client,
        headers,
        [
            _farm_change(farm_id, "Ferme Cascade", now),
            _plot_change(plot_id, farm_id, "Parcelle Cascade", now),
            _cycle_change(cycle_id, plot_id, crop_id, now),
            _activity_change(activity_id, cycle_id, now),
            _harvest_change(harvest_id, cycle_id, now),
        ],
    )
    await _push(
        client,
        headers,
        [
            {
                "entity": "farm",
                "op": "delete",
                "id": str(farm_id),
                "data": {},
                "updated_at": _iso(_now()),
            }
        ],
    )

    pull_body = await _pull(client, headers)
    deleted = {
        change["entity"]: change
        for change in pull_body["changes"]
        if change["deleted_at"] is not None
    }
    assert deleted["farm"]["id"] == str(farm_id)
    assert deleted["plot"]["id"] == str(plot_id)
    assert deleted["crop_cycle"]["id"] == str(cycle_id)
    assert deleted["farm_activity"]["id"] == str(activity_id)
    assert deleted["harvest"]["id"] == str(harvest_id)


async def test_pull_pagination(client: AsyncClient) -> None:
    headers, _ = await _register_verified(client, PHONE_USER1)
    now = _now()
    farm_ids = [uuid.uuid4() for _ in range(3)]
    await _push(
        client,
        headers,
        [
            _farm_change(farm_id, f"Ferme {index}", now)
            for index, farm_id in enumerate(farm_ids)
        ],
    )

    first_page = await _pull(client, headers, limit=2)
    assert len(first_page["changes"]) == 2
    assert first_page["has_more"] is True
    assert first_page["next_cursor"] is not None

    second_page = await _pull(
        client, headers, since=first_page["next_cursor"], limit=2
    )
    assert len(second_page["changes"]) == 1
    assert second_page["has_more"] is False

    seen = {
        change["id"]
        for change in first_page["changes"] + second_page["changes"]
    }
    assert seen == {str(farm_id) for farm_id in farm_ids}


async def test_pull_invalid_cursor_is_422(client: AsyncClient) -> None:
    headers, _ = await _register_verified(client, PHONE_USER1)
    response = await client.get(
        "/api/v1/sync/pull", params={"since": "!!!invalid!!!"}, headers=headers
    )
    assert response.status_code == 422


async def test_pull_isolation_between_users(client: AsyncClient) -> None:
    headers_one, _ = await _register_verified(client, PHONE_USER1)
    headers_two, _ = await _register_verified(client, PHONE_USER2)
    farm_id = uuid.uuid4()
    await _push(
        client, headers_one, [_farm_change(farm_id, "Ferme Iso", _now())]
    )

    pull_body = await _pull(client, headers_two)
    assert _entity_ids(pull_body, "farm") == set()


async def test_pull_excludes_organization_resources(
    client: AsyncClient,
) -> None:
    owner_headers, _ = await _register_verified(client, PHONE_OWNER)
    agent_headers, _ = await _register_verified(client, PHONE_USER1)

    farm = await client.post(
        "/api/v1/farms", json={"name": "Ferme Org"}, headers=owner_headers
    )
    assert farm.status_code == 201
    organization = await client.post(
        "/api/v1/organizations",
        json={"name": "Coop Sync", "type": "cooperative"},
        headers=owner_headers,
    )
    organization_id = organization.json()["id"]
    added = await client.post(
        f"/api/v1/organizations/{organization_id}/members",
        json={"phone": PHONE_USER1, "member_role": "agent"},
        headers=owner_headers,
    )
    assert added.status_code == 201

    pull_body = await _pull(client, agent_headers)
    assert pull_body["changes"] == []


async def test_push_enforces_plot_quota(
    client: AsyncClient, monkeypatch
) -> None:
    monkeypatch.setattr(settings, "REGISTER_REQUESTS_PER_IP_WINDOW", 50)
    headers, _ = await _register_verified(client, PHONE_USER1)
    now = _now()
    farm_id = uuid.uuid4()
    await _push(client, headers, [_farm_change(farm_id, "Ferme Quota", now)])

    results = await _push(
        client,
        headers,
        [
            _plot_change(uuid.uuid4(), farm_id, f"Parcelle {index}", now)
            for index in range(4)
        ],
    )
    assert [result["status"] for result in results] == [
        "applied",
        "applied",
        "applied",
        "rejected",
    ]
    assert "Quota" in results[3]["error"]


def _delete_change(entity: str, row_id: uuid.UUID) -> dict:
    return {
        "entity": entity,
        "op": "delete",
        "id": str(row_id),
        "data": {},
        "updated_at": _iso(_now()),
    }


def _change_by_id(pull_body: dict, entity: str, row_id: uuid.UUID) -> dict:
    return next(
        change
        for change in pull_body["changes"]
        if change["entity"] == entity and change["id"] == str(row_id)
    )


async def _create_chain(
    client: AsyncClient,
    headers: dict[str, str],
    crop_id: int,
    updated_at: datetime,
) -> tuple[uuid.UUID, uuid.UUID, uuid.UUID, uuid.UUID, uuid.UUID]:
    farm_id = uuid.uuid4()
    plot_id = uuid.uuid4()
    cycle_id = uuid.uuid4()
    activity_id = uuid.uuid4()
    harvest_id = uuid.uuid4()
    results = await _push(
        client,
        headers,
        [
            _farm_change(farm_id, "Ferme", updated_at),
            _plot_change(plot_id, farm_id, "Parcelle", updated_at),
            _cycle_change(cycle_id, plot_id, crop_id, updated_at),
            _activity_change(activity_id, cycle_id, updated_at),
            _harvest_change(harvest_id, cycle_id, updated_at),
        ],
    )
    assert [result["status"] for result in results] == ["applied"] * 5
    return farm_id, plot_id, cycle_id, activity_id, harvest_id


async def test_cannot_upsert_other_user_entity_with_own_parent(
    client: AsyncClient, db_session: AsyncSession
) -> None:
    headers_a, _ = await _register_verified(client, PHONE_USER1)
    headers_b, _ = await _register_verified(client, PHONE_USER2)
    crop_id = await _crop_id(db_session)
    now = _now()
    farm_a, plot_a, cycle_a, activity_a, harvest_a = await _create_chain(
        client, headers_a, crop_id, now
    )
    farm_b, plot_b, cycle_b, _, _ = await _create_chain(
        client, headers_b, crop_id, now
    )

    later = now + timedelta(minutes=1)
    results = await _push(
        client,
        headers_b,
        [
            _plot_change(plot_a, farm_b, "Parcelle volée", later),
            _cycle_change(cycle_a, plot_b, crop_id, later),
            _activity_change(activity_a, cycle_b, later),
            _harvest_change(harvest_a, cycle_b, later),
        ],
    )

    assert [result["status"] for result in results] == ["rejected"] * 4
    assert [result["error"] for result in results] == [OTHER_USER_ERROR] * 4

    db_session.expire_all()
    plot_row = await db_session.get(Plot, plot_a)
    cycle_row = await db_session.get(CropCycle, cycle_a)
    activity_row = await db_session.get(FarmActivity, activity_a)
    harvest_row = await db_session.get(Harvest, harvest_a)
    assert plot_row is not None and plot_row.farm_id == farm_a
    assert cycle_row is not None and cycle_row.plot_id == plot_a
    assert activity_row is not None and activity_row.crop_cycle_id == cycle_a
    assert harvest_row is not None and harvest_row.crop_cycle_id == cycle_a

    pull_a = await _pull(client, headers_a)
    assert _change_by_id(pull_a, "plot", plot_a)["data"]["farm_id"] == str(
        farm_a
    )
    assert _change_by_id(pull_a, "crop_cycle", cycle_a)["data"][
        "plot_id"
    ] == str(plot_a)
    assert _change_by_id(pull_a, "farm_activity", activity_a)["data"][
        "crop_cycle_id"
    ] == str(cycle_a)
    assert _change_by_id(pull_a, "harvest", harvest_a)["data"][
        "crop_cycle_id"
    ] == str(cycle_a)


async def test_cannot_delete_other_user_entities(
    client: AsyncClient, db_session: AsyncSession
) -> None:
    headers_a, _ = await _register_verified(client, PHONE_USER1)
    headers_b, _ = await _register_verified(client, PHONE_USER2)
    crop_id = await _crop_id(db_session)
    now = _now()
    farm_id, plot_id, cycle_id, activity_id, harvest_id = await _create_chain(
        client, headers_a, crop_id, now
    )

    results = await _push(
        client,
        headers_b,
        [
            _delete_change("farm", farm_id),
            _delete_change("plot", plot_id),
            _delete_change("crop_cycle", cycle_id),
            _delete_change("farm_activity", activity_id),
            _delete_change("harvest", harvest_id),
        ],
    )

    assert [result["status"] for result in results] == ["rejected"] * 5
    assert [result["error"] for result in results] == [OTHER_USER_ERROR] * 5

    pull_a = await _pull(client, headers_a)
    for entity, row_id in (
        ("farm", farm_id),
        ("plot", plot_id),
        ("crop_cycle", cycle_id),
        ("farm_activity", activity_id),
        ("harvest", harvest_id),
    ):
        assert _change_by_id(pull_a, entity, row_id)["deleted_at"] is None

    db_session.expire_all()
    farm_row = await db_session.get(Farm, farm_id)
    plot_row = await db_session.get(Plot, plot_id)
    cycle_row = await db_session.get(CropCycle, cycle_id)
    activity_row = await db_session.get(FarmActivity, activity_id)
    harvest_row = await db_session.get(Harvest, harvest_id)
    assert farm_row is not None and farm_row.deleted_at is None
    assert plot_row is not None and plot_row.deleted_at is None
    assert cycle_row is not None and cycle_row.deleted_at is None
    assert activity_row is not None and activity_row.deleted_at is None
    assert harvest_row is not None and harvest_row.deleted_at is None
