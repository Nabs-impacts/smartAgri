import re

from httpx import AsyncClient
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.db.models.farming import Crop
from app.providers.sms.fake import FakeSmsProvider

PHONE_OWNER = "+22796000001"
PHONE_ADMIN = "+22796000002"
PHONE_AGENT = "+22796000003"
PHONE_MEMBER = "+22796000004"
PHONE_OUTSIDER = "+22796000005"
OTP_PATTERN = re.compile(r"(\d{6})")


def _last_otp_code() -> str:
    message = FakeSmsProvider.sent_messages[-1]["message"]
    match = OTP_PATTERN.search(message)
    assert match is not None
    return match.group(1)


async def _register_verified(
    client: AsyncClient, phone: str, full_name: str = "Test User"
) -> tuple[dict[str, str], str]:
    registered = await client.post(
        "/api/v1/auth/register",
        json={"phone": phone, "full_name": full_name, "language": "fr"},
    )
    assert registered.status_code == 201
    verified = await client.post(
        "/api/v1/auth/otp/verify",
        json={
            "phone": phone,
            "code": _last_otp_code(),
            "purpose": "verify_phone",
        },
    )
    assert verified.status_code == 200
    body = verified.json()
    return (
        {"Authorization": f"Bearer {body['access_token']}"},
        body["user"]["id"],
    )


async def _create_organization(
    client: AsyncClient,
    headers: dict[str, str],
    name: str = "Coopérative du Sahel",
) -> dict:
    response = await client.post(
        "/api/v1/organizations",
        json={
            "name": name,
            "type": "cooperative",
            "contact_phone": "+22796000000",
        },
        headers=headers,
    )
    assert response.status_code == 201
    return response.json()


async def _add_member(
    client: AsyncClient,
    headers: dict[str, str],
    organization_id: str,
    phone: str,
    member_role: str,
) -> dict:
    response = await client.post(
        f"/api/v1/organizations/{organization_id}/members",
        json={"phone": phone, "member_role": member_role},
        headers=headers,
    )
    assert response.status_code == 201
    return response.json()


async def _create_farm_with_plot(
    client: AsyncClient,
    headers: dict[str, str],
    area_ha: float,
    name: str,
) -> tuple[dict, dict]:
    farm = await client.post(
        "/api/v1/farms", json={"name": f"Ferme {name}"}, headers=headers
    )
    assert farm.status_code == 201
    plot = await client.post(
        f"/api/v1/farms/{farm.json()['id']}/plots",
        json={"name": f"Parcelle {name}", "area_ha": area_ha},
        headers=headers,
    )
    assert plot.status_code == 201
    return farm.json(), plot.json()


async def _crop_id(session: AsyncSession, code: str = "millet") -> int:
    crop = (
        await session.execute(select(Crop).where(Crop.code == code))
    ).scalar_one()
    return crop.id


async def test_create_list_and_role_rights(client: AsyncClient) -> None:
    owner_headers, owner_id = await _register_verified(client, PHONE_OWNER)
    admin_headers, admin_id = await _register_verified(client, PHONE_ADMIN)
    agent_headers, _ = await _register_verified(client, PHONE_AGENT)
    member_headers, member_id = await _register_verified(client, PHONE_MEMBER)

    organization = await _create_organization(client, owner_headers)
    organization_id = organization["id"]
    assert organization["member_role"] == "owner"

    listed = await client.get("/api/v1/organizations", headers=owner_headers)
    assert listed.status_code == 200
    assert len(listed.json()["items"]) == 1
    assert listed.json()["items"][0]["id"] == organization_id
    assert listed.json()["items"][0]["member_role"] == "owner"

    fetched = await client.get(
        f"/api/v1/organizations/{organization_id}", headers=owner_headers
    )
    assert fetched.status_code == 200
    assert fetched.json()["name"] == "Coopérative du Sahel"

    patched = await client.patch(
        f"/api/v1/organizations/{organization_id}",
        json={"name": "Coopérative Modifiée", "contact_phone": "+22796000111"},
        headers=owner_headers,
    )
    assert patched.status_code == 200
    assert patched.json()["name"] == "Coopérative Modifiée"
    assert patched.json()["contact_phone"] == "+22796000111"

    await _add_member(
        client, owner_headers, organization_id, PHONE_ADMIN, "admin"
    )
    await _add_member(
        client, owner_headers, organization_id, PHONE_AGENT, "agent"
    )
    await _add_member(
        client, owner_headers, organization_id, PHONE_MEMBER, "member"
    )

    members = await client.get(
        f"/api/v1/organizations/{organization_id}/members",
        headers=owner_headers,
    )
    assert members.status_code == 200
    roles = {item["user_id"]: item["member_role"] for item in members.json()}
    assert roles[owner_id] == "owner"
    assert roles[admin_id] == "admin"
    assert roles[member_id] == "member"
    assert len(roles) == 4

    admin_patch = await client.patch(
        f"/api/v1/organizations/{organization_id}",
        json={"name": "Coopérative Admin"},
        headers=admin_headers,
    )
    assert admin_patch.status_code == 200

    agent_members = await client.get(
        f"/api/v1/organizations/{organization_id}/members",
        headers=agent_headers,
    )
    assert agent_members.status_code == 200
    assert (
        await client.patch(
            f"/api/v1/organizations/{organization_id}",
            json={"name": "Interdit"},
            headers=agent_headers,
        )
    ).status_code == 403
    assert (
        await client.get(
            f"/api/v1/organizations/{organization_id}/dashboard",
            headers=agent_headers,
        )
    ).status_code == 403
    assert (
        await client.post(
            f"/api/v1/organizations/{organization_id}/members",
            json={"phone": PHONE_OUTSIDER, "member_role": "member"},
            headers=agent_headers,
        )
    ).status_code == 403

    assert (
        await client.get(
            f"/api/v1/organizations/{organization_id}", headers=member_headers
        )
    ).status_code == 200
    assert (
        await client.get(
            f"/api/v1/organizations/{organization_id}/members",
            headers=member_headers,
        )
    ).status_code == 403
    assert (
        await client.get(
            f"/api/v1/organizations/{organization_id}/farms",
            headers=member_headers,
        )
    ).status_code == 403
    assert (
        await client.get(
            f"/api/v1/organizations/{organization_id}/dashboard",
            headers=member_headers,
        )
    ).status_code == 403
    assert (
        await client.patch(
            f"/api/v1/organizations/{organization_id}",
            json={"name": "Interdit"},
            headers=member_headers,
        )
    ).status_code == 403


async def test_add_unknown_member_then_register_and_verify(
    client: AsyncClient,
) -> None:
    owner_headers, _ = await _register_verified(client, PHONE_OWNER)
    organization = await _create_organization(client, owner_headers)
    organization_id = organization["id"]
    unknown_phone = "+22796000999"

    created = await _add_member(
        client, owner_headers, organization_id, unknown_phone, "agent"
    )
    assert created["phone"] == unknown_phone
    assert created["member_role"] == "agent"
    assert created["plot_count"] == 0

    registered = await client.post(
        "/api/v1/auth/register",
        json={
            "phone": unknown_phone,
            "full_name": "Nouveau Membre",
            "language": "fr",
        },
    )
    assert registered.status_code == 201
    verified = await client.post(
        "/api/v1/auth/otp/verify",
        json={
            "phone": unknown_phone,
            "code": _last_otp_code(),
            "purpose": "verify_phone",
        },
    )
    assert verified.status_code == 200
    new_headers = {
        "Authorization": f"Bearer {verified.json()['access_token']}"
    }

    organizations = await client.get(
        "/api/v1/organizations", headers=new_headers
    )
    assert organizations.status_code == 200
    items = organizations.json()["items"]
    assert len(items) == 1
    assert items[0]["id"] == organization_id
    assert items[0]["member_role"] == "agent"
    assert verified.json()["user"]["phone_verified_at"] is not None


async def test_last_owner_cannot_be_removed(client: AsyncClient) -> None:
    owner_headers, owner_id = await _register_verified(client, PHONE_OWNER)
    second_headers, second_id = await _register_verified(client, PHONE_ADMIN)
    organization = await _create_organization(client, owner_headers)
    organization_id = organization["id"]

    last_owner = await client.delete(
        f"/api/v1/organizations/{organization_id}/members/{owner_id}",
        headers=owner_headers,
    )
    assert last_owner.status_code == 409
    assert (
        last_owner.json()["error"]["message"]
        == "Le dernier propriétaire ne peut pas être retiré."
    )

    await _add_member(
        client, owner_headers, organization_id, PHONE_ADMIN, "owner"
    )
    remove_first = await client.delete(
        f"/api/v1/organizations/{organization_id}/members/{owner_id}",
        headers=second_headers,
    )
    assert remove_first.status_code == 204

    remove_last = await client.delete(
        f"/api/v1/organizations/{organization_id}/members/{second_id}",
        headers=second_headers,
    )
    assert remove_last.status_code == 409


async def test_agent_read_access_and_write_refusal(
    client: AsyncClient, db_session: AsyncSession
) -> None:
    owner_headers, _ = await _register_verified(client, PHONE_OWNER)
    agent_headers, _ = await _register_verified(client, PHONE_AGENT)
    outsider_headers, _ = await _register_verified(client, PHONE_OUTSIDER)
    crop_id = await _crop_id(db_session)

    organization = await _create_organization(client, owner_headers)
    await _add_member(
        client, owner_headers, organization["id"], PHONE_AGENT, "agent"
    )

    farm, plot = await _create_farm_with_plot(
        client, owner_headers, 2.0, "Accès"
    )
    cycle = (
        await client.post(
            f"/api/v1/plots/{plot['id']}/cycles",
            json={"crop_id": crop_id, "status": "growing"},
            headers=owner_headers,
        )
    ).json()
    activity = (
        await client.post(
            f"/api/v1/cycles/{cycle['id']}/activities",
            json={"type": "sowing", "performed_on": "2026-05-01"},
            headers=owner_headers,
        )
    ).json()
    assert (
        await client.post(
            f"/api/v1/cycles/{cycle['id']}/harvests",
            json={"harvested_on": "2026-08-01", "quantity_kg": 1000},
            headers=owner_headers,
        )
    ).status_code == 201

    agent_farms = await client.get("/api/v1/farms", headers=agent_headers)
    assert agent_farms.status_code == 200
    assert [item["id"] for item in agent_farms.json()["items"]] == [farm["id"]]

    assert (
        await client.get(f"/api/v1/farms/{farm['id']}", headers=agent_headers)
    ).status_code == 200
    assert (
        await client.get(
            f"/api/v1/farms/{farm['id']}/plots", headers=agent_headers
        )
    ).status_code == 200
    assert (
        await client.get(f"/api/v1/plots/{plot['id']}", headers=agent_headers)
    ).status_code == 200
    assert (
        await client.get(
            f"/api/v1/plots/{plot['id']}/cycles", headers=agent_headers
        )
    ).status_code == 200
    assert (
        await client.get(
            f"/api/v1/cycles/{cycle['id']}", headers=agent_headers
        )
    ).status_code == 200
    assert (
        await client.get(
            f"/api/v1/cycles/{cycle['id']}/activities", headers=agent_headers
        )
    ).status_code == 200
    assert (
        await client.get(
            f"/api/v1/cycles/{cycle['id']}/summary", headers=agent_headers
        )
    ).status_code == 200
    assert (
        await client.get(
            f"/api/v1/plots/{plot['id']}/timeline", headers=agent_headers
        )
    ).status_code == 200

    assert (
        await client.patch(
            f"/api/v1/farms/{farm['id']}",
            json={"name": "Interdit"},
            headers=agent_headers,
        )
    ).status_code == 404
    assert (
        await client.delete(
            f"/api/v1/farms/{farm['id']}", headers=agent_headers
        )
    ).status_code == 404
    assert (
        await client.post(
            f"/api/v1/farms/{farm['id']}/plots",
            json={"name": "Interdite", "area_ha": 1.0},
            headers=agent_headers,
        )
    ).status_code == 404
    assert (
        await client.patch(
            f"/api/v1/plots/{plot['id']}",
            json={"name": "Interdite"},
            headers=agent_headers,
        )
    ).status_code == 404
    assert (
        await client.delete(
            f"/api/v1/plots/{plot['id']}", headers=agent_headers
        )
    ).status_code == 404
    assert (
        await client.post(
            f"/api/v1/plots/{plot['id']}/cycles",
            json={"crop_id": crop_id},
            headers=agent_headers,
        )
    ).status_code == 404
    assert (
        await client.patch(
            f"/api/v1/cycles/{cycle['id']}",
            json={"status": "harvested"},
            headers=agent_headers,
        )
    ).status_code == 404
    assert (
        await client.post(
            f"/api/v1/cycles/{cycle['id']}/activities",
            json={"type": "weeding", "performed_on": "2026-05-02"},
            headers=agent_headers,
        )
    ).status_code == 404
    assert (
        await client.patch(
            f"/api/v1/activities/{activity['id']}",
            json={"cost_xof": 1},
            headers=agent_headers,
        )
    ).status_code == 404
    assert (
        await client.delete(
            f"/api/v1/activities/{activity['id']}", headers=agent_headers
        )
    ).status_code == 404
    assert (
        await client.post(
            f"/api/v1/cycles/{cycle['id']}/harvests",
            json={"harvested_on": "2026-08-02", "quantity_kg": 10},
            headers=agent_headers,
        )
    ).status_code == 404

    outsider_farms = await client.get(
        "/api/v1/farms", headers=outsider_headers
    )
    assert outsider_farms.status_code == 200
    assert outsider_farms.json()["items"] == []
    assert (
        await client.get(
            f"/api/v1/farms/{farm['id']}", headers=outsider_headers
        )
    ).status_code == 404
    assert (
        await client.get(
            f"/api/v1/plots/{plot['id']}", headers=outsider_headers
        )
    ).status_code == 404
    assert (
        await client.get(
            f"/api/v1/cycles/{cycle['id']}", headers=outsider_headers
        )
    ).status_code == 404
    assert (
        await client.get(
            f"/api/v1/plots/{plot['id']}/timeline", headers=outsider_headers
        )
    ).status_code == 404


async def test_organization_dashboard_numbers(
    client: AsyncClient, db_session: AsyncSession
) -> None:
    owner_headers, owner_id = await _register_verified(client, PHONE_OWNER)
    member_headers, member_id = await _register_verified(client, PHONE_MEMBER)
    crop_id = await _crop_id(db_session)

    organization = await _create_organization(client, owner_headers)
    organization_id = organization["id"]
    await _add_member(
        client, owner_headers, organization_id, PHONE_MEMBER, "member"
    )

    _, plot_one = await _create_farm_with_plot(
        client, owner_headers, 2.0, "Une"
    )
    _, plot_two = await _create_farm_with_plot(
        client, owner_headers, 4.0, "Deux"
    )
    _, plot_three = await _create_farm_with_plot(
        client, member_headers, 1.0, "Trois"
    )

    for plot, quantity in (
        (plot_one, 1000),
        (plot_two, 2000),
        (plot_three, 400),
    ):
        cycle = (
            await client.post(
                f"/api/v1/plots/{plot['id']}/cycles",
                json={"crop_id": crop_id},
                headers=owner_headers if plot is not plot_three else member_headers,
            )
        ).json()
        harvest = await client.post(
            f"/api/v1/cycles/{cycle['id']}/harvests",
            json={"harvested_on": "2026-08-01", "quantity_kg": quantity},
            headers=owner_headers if plot is not plot_three else member_headers,
        )
        assert harvest.status_code == 201

    members = await client.get(
        f"/api/v1/organizations/{organization_id}/members",
        headers=owner_headers,
    )
    assert members.status_code == 200
    member_rows = {row["user_id"]: row for row in members.json()}
    assert member_rows[owner_id]["plot_count"] == 2
    assert float(member_rows[owner_id]["area_ha"]) == 6.0
    assert member_rows[member_id]["plot_count"] == 1
    assert float(member_rows[member_id]["area_ha"]) == 1.0

    dashboard = await client.get(
        f"/api/v1/organizations/{organization_id}/dashboard",
        headers=owner_headers,
    )
    assert dashboard.status_code == 200
    body = dashboard.json()
    assert body["member_count"] == 2
    assert body["plot_count"] == 3
    assert float(body["total_area_ha"]) == 7.0
    assert body["diagnostics_this_month"] == 0
    assert body["active_alerts"] == 0
    assert len(body["average_yield_by_crop"]) == 1
    yield_row = body["average_yield_by_crop"][0]
    assert yield_row["crop_id"] == crop_id
    assert yield_row["sample_size"] == 3
    assert float(yield_row["average_yield_kg_per_ha"]) == 466.7
