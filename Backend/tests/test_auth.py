import re
from datetime import UTC, datetime, timedelta

from httpx import AsyncClient
from sqlalchemy import select, update
from sqlalchemy.ext.asyncio import AsyncSession

from app.db.models.identity import OtpCode, User
from app.providers.sms.fake import FakeSmsProvider

PHONE = "+22790000001"
PASSWORD = "MotDePasse123!"
OTP_PATTERN = re.compile(r"(\d{6})")


def _last_otp_code() -> str:
    message = FakeSmsProvider.sent_messages[-1]["message"]
    match = OTP_PATTERN.search(message)
    assert match is not None
    return match.group(1)


async def _register(client: AsyncClient, password: str | None = None):
    payload: dict[str, str] = {
        "phone": PHONE,
        "full_name": "Amina",
        "language": "fr",
    }
    if password is not None:
        payload["password"] = password
    return await client.post("/api/v1/auth/register", json=payload)


async def _login_password(client: AsyncClient, password: str = PASSWORD):
    return await client.post(
        "/api/v1/auth/login",
        json={"phone": PHONE, "password": password},
    )


async def _verify_otp(client: AsyncClient, code: str):
    return await client.post(
        "/api/v1/auth/otp/verify",
        json={"phone": PHONE, "code": code, "purpose": "verify_phone"},
    )


async def test_register_creates_user_and_sends_otp(
    client: AsyncClient, db_session: AsyncSession
) -> None:
    response = await _register(client)

    assert response.status_code == 201
    assert response.json()["phone"] == PHONE

    user = (
        await db_session.execute(select(User).where(User.phone == PHONE))
    ).scalar_one()
    assert user.role == "farmer"
    assert user.password_hash is None
    assert user.phone_verified_at is None
    assert len(FakeSmsProvider.sent_messages) == 1
    assert FakeSmsProvider.sent_messages[0]["phone"] == PHONE


async def test_register_duplicate_phone_returns_conflict(client: AsyncClient) -> None:
    first = await _register(client)
    assert first.status_code == 201

    second = await _register(client)

    assert second.status_code == 409
    assert second.json()["error"]["code"] == "CONFLICT"


async def test_otp_verify_valid_returns_tokens(client: AsyncClient) -> None:
    await _register(client)
    code = _last_otp_code()

    response = await _verify_otp(client, code)

    assert response.status_code == 200
    body = response.json()
    assert body["access_token"]
    assert body["refresh_token"]
    assert body["token_type"] == "bearer"
    assert body["expires_in"] > 0
    assert body["user"]["phone"] == PHONE


async def test_otp_verify_wrong_code(client: AsyncClient) -> None:
    await _register(client)
    code = _last_otp_code()
    wrong_code = "000000" if code != "000000" else "000001"

    response = await _verify_otp(client, wrong_code)

    assert response.status_code == 401
    assert response.json()["error"]["code"] == "UNAUTHORIZED"


async def test_otp_verify_expired_code(
    client: AsyncClient, db_session: AsyncSession
) -> None:
    await _register(client)
    code = _last_otp_code()

    await db_session.execute(
        update(OtpCode)
        .where(OtpCode.phone == PHONE)
        .values(expires_at=datetime.now(UTC) - timedelta(seconds=1))
    )
    await db_session.commit()

    response = await _verify_otp(client, code)

    assert response.status_code == 401
    assert response.json()["error"]["code"] == "UNAUTHORIZED"


async def test_login_with_password(client: AsyncClient) -> None:
    await _register(client, password=PASSWORD)

    response = await _login_password(client)

    assert response.status_code == 200
    body = response.json()
    assert body["access_token"]
    assert body["refresh_token"]
    assert body["user"]["phone"] == PHONE

    wrong = await _login_password(client, password="MauvaisMotDePasse")
    assert wrong.status_code == 401


async def test_refresh_rotates_token(client: AsyncClient) -> None:
    await _register(client, password=PASSWORD)
    first_login = (await _login_password(client)).json()
    first_refresh = first_login["refresh_token"]

    first_rotation = await client.post(
        "/api/v1/auth/refresh",
        json={"refresh_token": first_refresh},
    )
    assert first_rotation.status_code == 200
    second_refresh = first_rotation.json()["refresh_token"]
    assert second_refresh != first_refresh

    second_rotation = await client.post(
        "/api/v1/auth/refresh",
        json={"refresh_token": second_refresh},
    )
    assert second_rotation.status_code == 200
    assert second_rotation.json()["refresh_token"] != second_refresh


async def test_refresh_replay_revokes_all_tokens(client: AsyncClient) -> None:
    await _register(client, password=PASSWORD)
    first_login = (await _login_password(client)).json()
    first_refresh = first_login["refresh_token"]

    rotation = await client.post(
        "/api/v1/auth/refresh",
        json={"refresh_token": first_refresh},
    )
    assert rotation.status_code == 200
    second_refresh = rotation.json()["refresh_token"]

    replay = await client.post(
        "/api/v1/auth/refresh",
        json={"refresh_token": first_refresh},
    )
    assert replay.status_code == 401

    after_replay = await client.post(
        "/api/v1/auth/refresh",
        json={"refresh_token": second_refresh},
    )
    assert after_replay.status_code == 401


async def test_logout_revokes_refresh_token(client: AsyncClient) -> None:
    await _register(client, password=PASSWORD)
    login_body = (await _login_password(client)).json()
    access_token = login_body["access_token"]
    refresh_token = login_body["refresh_token"]

    response = await client.post(
        "/api/v1/auth/logout",
        json={"refresh_token": refresh_token},
        headers={"Authorization": f"Bearer {access_token}"},
    )
    assert response.status_code == 200

    refresh = await client.post(
        "/api/v1/auth/refresh",
        json={"refresh_token": refresh_token},
    )
    assert refresh.status_code == 401
