import re
from datetime import date

from httpx import AsyncClient
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.security import create_access_token
from app.db.models.billing import Subscription, UsageRecord
from app.db.models.identity import AdminArea, User
from app.providers.sms.fake import FakeSmsProvider

PHONE = "+22791000001"
OTHER_PHONE = "+22791000002"
PASSWORD = "MotDePasse123!"
OTP_PATTERN = re.compile(r"(\d{6})")


def _last_otp_code() -> str:
    message = FakeSmsProvider.sent_messages[-1]["message"]
    match = OTP_PATTERN.search(message)
    assert match is not None
    return match.group(1)


async def _register_verified(
    client: AsyncClient, phone: str = PHONE
) -> dict[str, object]:
    registered = await client.post(
        "/api/v1/auth/register",
        json={"phone": phone, "full_name": "Amina", "language": "fr"},
    )
    assert registered.status_code == 201

    verified = await client.post(
        "/api/v1/auth/otp/verify",
        json={"phone": phone, "code": _last_otp_code(), "purpose": "verify_phone"},
    )
    assert verified.status_code == 200
    return verified.json()


def _auth_headers(tokens: dict[str, object]) -> dict[str, str]:
    return {"Authorization": f"Bearer {tokens['access_token']}"}


async def test_get_me_requires_auth(client: AsyncClient) -> None:
    response = await client.get("/api/v1/users/me")
    assert response.status_code == 401


async def test_get_me_returns_profile_and_quotas(
    client: AsyncClient, db_session: AsyncSession
) -> None:
    tokens = await _register_verified(client)
    user = (
        await db_session.execute(select(User).where(User.phone == PHONE))
    ).scalar_one()
    subscription = (
        await db_session.execute(
            select(Subscription).where(Subscription.user_id == user.id)
        )
    ).scalar_one()

    response = await client.get("/api/v1/users/me", headers=_auth_headers(tokens))

    assert response.status_code == 200
    body = response.json()
    assert body["user"]["phone"] == PHONE
    assert body["effective_plan"]["code"] == "free"

    quotas = {quota["metric"]: quota for quota in body["quotas"]}
    assert quotas["diagnostics_per_month"]["limit"] == 10
    assert quotas["diagnostics_per_month"]["used"] == 0
    assert quotas["diagnostics_per_month"]["remaining"] == 10

    db_session.add(
        UsageRecord(
            subscription_id=subscription.id,
            metric="diagnostic",
            quantity=3,
            period=date.today().replace(day=1),
        )
    )
    await db_session.commit()

    refreshed = await client.get("/api/v1/users/me", headers=_auth_headers(tokens))
    quotas = {quota["metric"]: quota for quota in refreshed.json()["quotas"]}
    assert quotas["diagnostics_per_month"]["used"] == 3
    assert quotas["diagnostics_per_month"]["remaining"] == 7


async def test_patch_me_updates_fields(client: AsyncClient) -> None:
    tokens = await _register_verified(client)

    response = await client.patch(
        "/api/v1/users/me",
        json={
            "full_name": "Amina Traoré",
            "language": "ha",
            "email": "amina@example.com",
        },
        headers=_auth_headers(tokens),
    )

    assert response.status_code == 200
    body = response.json()
    assert body["full_name"] == "Amina Traoré"
    assert body["language"] == "ha"
    assert body["email"] == "amina@example.com"


async def test_patch_me_email_conflict(client: AsyncClient) -> None:
    first = await _register_verified(client, phone=PHONE)
    second = await _register_verified(client, phone=OTHER_PHONE)

    reserved = await client.patch(
        "/api/v1/users/me",
        json={"email": "collision@example.com"},
        headers=_auth_headers(second),
    )
    assert reserved.status_code == 200

    conflict = await client.patch(
        "/api/v1/users/me",
        json={"email": "collision@example.com"},
        headers=_auth_headers(first),
    )
    assert conflict.status_code == 409
    assert conflict.json()["error"]["code"] == "CONFLICT"


async def test_patch_me_email_null_clears(client: AsyncClient) -> None:
    tokens = await _register_verified(client)
    headers = _auth_headers(tokens)

    await client.patch(
        "/api/v1/users/me",
        json={"email": "clear@example.com"},
        headers=headers,
    )
    cleared = await client.patch(
        "/api/v1/users/me",
        json={"email": None},
        headers=headers,
    )

    assert cleared.status_code == 200
    assert cleared.json()["email"] is None


async def test_patch_me_admin_area(
    client: AsyncClient, db_session: AsyncSession
) -> None:
    tokens = await _register_verified(client)
    area = AdminArea(level="region", name="Niamey", code="NE-NIA")
    db_session.add(area)
    await db_session.commit()
    await db_session.refresh(area)

    updated = await client.patch(
        "/api/v1/users/me",
        json={"admin_area_id": area.id},
        headers=_auth_headers(tokens),
    )
    assert updated.status_code == 200
    assert updated.json()["admin_area_id"] == area.id

    missing = await client.patch(
        "/api/v1/users/me",
        json={"admin_area_id": 999999},
        headers=_auth_headers(tokens),
    )
    assert missing.status_code == 404
    assert missing.json()["error"]["code"] == "NOT_FOUND"


async def test_update_password_without_existing_password(client: AsyncClient) -> None:
    tokens = await _register_verified(client)
    headers = _auth_headers(tokens)

    response = await client.put(
        "/api/v1/users/me/password",
        json={"new_password": PASSWORD},
        headers=headers,
    )
    assert response.status_code == 200

    login = await client.post(
        "/api/v1/auth/login",
        json={"phone": PHONE, "password": PASSWORD},
    )
    assert login.status_code == 200

    reused = await client.post(
        "/api/v1/auth/refresh",
        json={"refresh_token": tokens["refresh_token"]},
    )
    assert reused.status_code == 401


async def test_update_password_requires_current_password(client: AsyncClient) -> None:
    tokens = await _register_verified(client)
    headers = _auth_headers(tokens)

    first = await client.put(
        "/api/v1/users/me/password",
        json={"new_password": PASSWORD},
        headers=headers,
    )
    assert first.status_code == 200

    missing = await client.put(
        "/api/v1/users/me/password",
        json={"new_password": "DeuxiemeMotDePasse2!"},
        headers=headers,
    )
    assert missing.status_code == 422

    wrong = await client.put(
        "/api/v1/users/me/password",
        json={"current_password": "MauvaisMotDePasse", "new_password": "DeuxiemeMotDePasse2!"},
        headers=headers,
    )
    assert wrong.status_code == 401

    good = await client.put(
        "/api/v1/users/me/password",
        json={"current_password": PASSWORD, "new_password": "DeuxiemeMotDePasse2!"},
        headers=headers,
    )
    assert good.status_code == 200

    login = await client.post(
        "/api/v1/auth/login",
        json={"phone": PHONE, "password": "DeuxiemeMotDePasse2!"},
    )
    assert login.status_code == 200


async def test_update_password_refused_when_phone_not_verified(
    client: AsyncClient, db_session: AsyncSession
) -> None:
    user = User(phone=PHONE, full_name="Non Vérifié")
    db_session.add(user)
    await db_session.commit()
    await db_session.refresh(user)

    token = create_access_token(user.id, user.role)
    response = await client.put(
        "/api/v1/users/me/password",
        json={"new_password": PASSWORD},
        headers={"Authorization": f"Bearer {token}"},
    )

    assert response.status_code == 403
    assert response.json()["error"]["code"] == "FORBIDDEN"


async def test_devices_upsert_and_delete(client: AsyncClient) -> None:
    tokens = await _register_verified(client)
    headers = _auth_headers(tokens)

    created = await client.post(
        "/api/v1/users/me/devices",
        json={"platform": "android", "fcm_token": "token-abc", "app_version": "1.0.0"},
        headers=headers,
    )
    assert created.status_code == 201
    device_id = created.json()["id"]

    updated = await client.post(
        "/api/v1/users/me/devices",
        json={"platform": "android", "fcm_token": "token-abc", "app_version": "1.1.0"},
        headers=headers,
    )
    assert updated.status_code == 201
    assert updated.json()["id"] == device_id
    assert updated.json()["app_version"] == "1.1.0"

    deleted = await client.delete(
        f"/api/v1/users/me/devices/{device_id}", headers=headers
    )
    assert deleted.status_code == 200

    missing = await client.delete(
        f"/api/v1/users/me/devices/{device_id}", headers=headers
    )
    assert missing.status_code == 404


async def test_delete_other_users_device_returns_404(client: AsyncClient) -> None:
    first = await _register_verified(client, phone=PHONE)
    second = await _register_verified(client, phone=OTHER_PHONE)

    created = await client.post(
        "/api/v1/users/me/devices",
        json={"platform": "ios", "fcm_token": "token-other"},
        headers=_auth_headers(first),
    )
    device_id = created.json()["id"]

    response = await client.delete(
        f"/api/v1/users/me/devices/{device_id}",
        headers=_auth_headers(second),
    )
    assert response.status_code == 404


async def test_consents_latest_state_per_type(client: AsyncClient) -> None:
    tokens = await _register_verified(client)
    headers = _auth_headers(tokens)

    await client.post(
        "/api/v1/users/me/consents",
        json={"type": "terms", "version": "1.0", "accepted": True},
        headers=headers,
    )
    await client.post(
        "/api/v1/users/me/consents",
        json={"type": "terms", "version": "2.0", "accepted": False},
        headers=headers,
    )
    await client.post(
        "/api/v1/users/me/consents",
        json={"type": "privacy", "version": "1.0", "accepted": True},
        headers=headers,
    )

    response = await client.get("/api/v1/users/me/consents", headers=headers)
    assert response.status_code == 200

    consents = {consent["type"]: consent for consent in response.json()}
    assert consents["terms"]["version"] == "2.0"
    assert consents["terms"]["accepted"] is False
    assert consents["privacy"]["version"] == "1.0"
    assert consents["privacy"]["accepted"] is True
