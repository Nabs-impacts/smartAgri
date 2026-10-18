import asyncio
import re
from datetime import UTC, datetime, timedelta

import pytest
from httpx import AsyncClient
from sqlalchemy import select, update
from sqlalchemy.ext.asyncio import AsyncSession

import app.services.auth_service as auth_service_module
from app.core.config import settings
from app.core.rate_limit import get_redis_client
from app.db.models.identity import OtpCode, User
from app.providers.sms.fake import FakeSmsProvider

PHONE = "+22790000001"
OTHER_PHONE = "+22790000002"
PASSWORD = "MotDePasse123!"
NEW_PASSWORD = "NouveauMotDePasse456!"
OTP_PATTERN = re.compile(r"(\d{6})")


def _last_otp_code() -> str:
    message = FakeSmsProvider.sent_messages[-1]["message"]
    match = OTP_PATTERN.search(message)
    assert match is not None
    return match.group(1)


async def _register(
    client: AsyncClient, password: str | None = None, phone: str = PHONE
):
    payload: dict[str, str] = {
        "phone": phone,
        "full_name": "Amina",
        "language": "fr",
    }
    if password is not None:
        payload["password"] = password
    return await client.post("/api/v1/auth/register", json=payload)


async def _login_password(
    client: AsyncClient, password: str = PASSWORD, phone: str = PHONE
):
    return await client.post(
        "/api/v1/auth/login",
        json={"phone": phone, "password": password},
    )


async def _verify_otp(client: AsyncClient, code: str, phone: str = PHONE):
    return await client.post(
        "/api/v1/auth/otp/verify",
        json={"phone": phone, "code": code, "purpose": "verify_phone"},
    )


async def _register_verified(
    client: AsyncClient, password: str = PASSWORD, phone: str = PHONE
) -> None:
    await _register(client, phone=phone)
    verified = await _verify_otp(client, _last_otp_code(), phone)
    assert verified.status_code == 200

    requested = await client.post(
        "/api/v1/auth/otp/request",
        json={"phone": phone, "purpose": "reset_password"},
    )
    assert requested.status_code == 202

    reset = await client.post(
        "/api/v1/auth/password/reset",
        json={
            "phone": phone,
            "code": _last_otp_code(),
            "new_password": password,
        },
    )
    assert reset.status_code == 200


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

    verified = await _verify_otp(client, _last_otp_code())
    assert verified.status_code == 200

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
    await _register_verified(client)

    response = await _login_password(client)

    assert response.status_code == 200
    body = response.json()
    assert body["access_token"]
    assert body["refresh_token"]
    assert body["user"]["phone"] == PHONE

    wrong = await _login_password(client, password="MauvaisMotDePasse")
    assert wrong.status_code == 401


async def test_refresh_rotates_token(client: AsyncClient) -> None:
    await _register_verified(client)
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
    await _register_verified(client)
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


async def test_otp_request_unknown_phone_sends_no_sms(client: AsyncClient) -> None:
    response = await client.post(
        "/api/v1/auth/otp/request",
        json={"phone": "+22799999999", "purpose": "login"},
    )

    assert response.status_code == 202
    assert FakeSmsProvider.sent_messages == []


async def test_otp_request_known_phone_sends_sms(client: AsyncClient) -> None:
    await _register(client)
    FakeSmsProvider.clear()

    response = await client.post(
        "/api/v1/auth/otp/request",
        json={"phone": PHONE, "purpose": "login"},
    )

    assert response.status_code == 202
    assert len(FakeSmsProvider.sent_messages) == 1


async def test_otp_request_per_ip_rate_limit(
    client: AsyncClient, monkeypatch: pytest.MonkeyPatch
) -> None:
    monkeypatch.setattr(settings, "OTP_REQUESTS_PER_IP_WINDOW", 2)
    payload = {"phone": "+22799999999", "purpose": "login"}

    first = await client.post("/api/v1/auth/otp/request", json=payload)
    second = await client.post("/api/v1/auth/otp/request", json=payload)
    third = await client.post("/api/v1/auth/otp/request", json=payload)

    assert first.status_code == 202
    assert second.status_code == 202
    assert third.status_code == 429


async def test_otp_attempts_capped_under_concurrency(
    client: AsyncClient, db_session: AsyncSession
) -> None:
    await _register(client)
    code = _last_otp_code()
    wrong_code = "000000" if code != "000000" else "000001"

    responses = await asyncio.gather(
        *[
            _verify_otp(client, wrong_code)
            for _ in range(settings.OTP_MAX_ATTEMPTS + 2)
        ]
    )

    assert all(response.status_code == 401 for response in responses)

    otp = (
        await db_session.execute(
            select(OtpCode).where(OtpCode.phone == PHONE)
        )
    ).scalar_one()
    assert otp.attempts <= settings.OTP_MAX_ATTEMPTS


async def test_otp_verify_rejects_reset_password_purpose(
    client: AsyncClient,
) -> None:
    await _register(client)
    code = _last_otp_code()

    response = await client.post(
        "/api/v1/auth/otp/verify",
        json={"phone": PHONE, "code": code, "purpose": "reset_password"},
    )

    assert response.status_code == 422


async def test_refresh_grace_accepts_revoked_token_once(
    client: AsyncClient, monkeypatch: pytest.MonkeyPatch
) -> None:
    monkeypatch.setattr(settings, "REFRESH_REUSE_GRACE_SECONDS", 45)
    await _register_verified(client)
    login_body = (await _login_password(client)).json()
    first_refresh = login_body["refresh_token"]

    rotation = await client.post(
        "/api/v1/auth/refresh",
        json={"refresh_token": first_refresh},
    )
    assert rotation.status_code == 200
    second_refresh = rotation.json()["refresh_token"]

    grace = await client.post(
        "/api/v1/auth/refresh",
        json={"refresh_token": first_refresh},
    )
    assert grace.status_code == 200
    third_refresh = grace.json()["refresh_token"]

    replay = await client.post(
        "/api/v1/auth/refresh",
        json={"refresh_token": first_refresh},
    )
    assert replay.status_code == 401

    revoked_second = await client.post(
        "/api/v1/auth/refresh",
        json={"refresh_token": second_refresh},
    )
    assert revoked_second.status_code == 401

    revoked_third = await client.post(
        "/api/v1/auth/refresh",
        json={"refresh_token": third_refresh},
    )
    assert revoked_third.status_code == 401


async def test_refresh_concurrent_only_one_succeeds(client: AsyncClient) -> None:
    await _register_verified(client)
    login_body = (await _login_password(client)).json()
    refresh_token = login_body["refresh_token"]

    responses = await asyncio.gather(
        client.post(
            "/api/v1/auth/refresh",
            json={"refresh_token": refresh_token},
        ),
        client.post(
            "/api/v1/auth/refresh",
            json={"refresh_token": refresh_token},
        ),
    )

    assert sorted(response.status_code for response in responses) == [200, 401]


async def test_logout_revokes_refresh_token(client: AsyncClient) -> None:
    await _register_verified(client)
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


async def test_otp_cannot_be_reused_after_success(client: AsyncClient) -> None:
    await _register(client)
    code = _last_otp_code()

    first = await _verify_otp(client, code)
    assert first.status_code == 200

    second = await _verify_otp(client, code)
    assert second.status_code == 401


async def test_password_reset_then_login_with_new_password(
    client: AsyncClient,
) -> None:
    await _register_verified(client)
    login_body = (await _login_password(client)).json()
    old_refresh = login_body["refresh_token"]

    await client.post(
        "/api/v1/auth/otp/request",
        json={"phone": PHONE, "purpose": "reset_password"},
    )
    code = _last_otp_code()

    reset = await client.post(
        "/api/v1/auth/password/reset",
        json={"phone": PHONE, "code": code, "new_password": NEW_PASSWORD},
    )
    assert reset.status_code == 200

    old_password_login = await _login_password(client, password=PASSWORD)
    assert old_password_login.status_code == 401

    new_password_login = await _login_password(client, password=NEW_PASSWORD)
    assert new_password_login.status_code == 200

    old_refresh_reuse = await client.post(
        "/api/v1/auth/refresh",
        json={"refresh_token": old_refresh},
    )
    assert old_refresh_reuse.status_code == 401


async def test_refresh_with_invalid_token_returns_401(client: AsyncClient) -> None:
    response = await client.post(
        "/api/v1/auth/refresh",
        json={"refresh_token": "jeton-invalide"},
    )
    assert response.status_code == 401
    assert response.json()["error"]["code"] == "UNAUTHORIZED"


async def test_logout_without_access_token_returns_401(client: AsyncClient) -> None:
    await _register_verified(client)
    login_body = (await _login_password(client)).json()

    response = await client.post(
        "/api/v1/auth/logout",
        json={"refresh_token": login_body["refresh_token"]},
    )
    assert response.status_code == 401


async def test_logout_rejects_other_users_refresh_token(client: AsyncClient) -> None:
    await _register_verified(client, phone=PHONE)
    await _register_verified(client, phone=OTHER_PHONE)

    first_login = (await _login_password(client)).json()
    second_login = (await _login_password(client, phone=OTHER_PHONE)).json()

    response = await client.post(
        "/api/v1/auth/logout",
        json={"refresh_token": second_login["refresh_token"]},
        headers={"Authorization": f"Bearer {first_login['access_token']}"},
    )
    assert response.status_code == 403
    assert response.json()["error"]["code"] == "FORBIDDEN"


async def test_otp_request_phone_rate_limit_identical_known_and_unknown(
    client: AsyncClient, monkeypatch: pytest.MonkeyPatch
) -> None:
    await _register(client)
    FakeSmsProvider.clear()
    await get_redis_client().flushdb()
    monkeypatch.setattr(settings, "OTP_REQUESTS_PER_IP_WINDOW", 100)
    monkeypatch.setattr(settings, "OTP_REQUESTS_PER_WINDOW", 2)

    unknown_phone = "+22799999999"
    known_statuses = []
    unknown_statuses = []
    for _ in range(3):
        known = await client.post(
            "/api/v1/auth/otp/request",
            json={"phone": PHONE, "purpose": "login"},
        )
        unknown = await client.post(
            "/api/v1/auth/otp/request",
            json={"phone": unknown_phone, "purpose": "login"},
        )
        known_statuses.append(known.status_code)
        unknown_statuses.append(unknown.status_code)

    assert known_statuses == [202, 202, 429]
    assert unknown_statuses == [202, 202, 429]


async def test_register_per_ip_rate_limit(
    client: AsyncClient, monkeypatch: pytest.MonkeyPatch
) -> None:
    monkeypatch.setattr(settings, "REGISTER_REQUESTS_PER_IP_WINDOW", 2)

    first = await _register(client, phone="+22790000011")
    second = await _register(client, phone="+22790000012")
    third = await _register(client, phone="+22790000013")

    assert first.status_code == 201
    assert second.status_code == 201
    assert third.status_code == 429
    assert third.json()["error"]["code"] == "RATE_LIMITED"


async def test_login_rate_limited(
    client: AsyncClient, monkeypatch: pytest.MonkeyPatch
) -> None:
    await _register_verified(client)
    monkeypatch.setattr(settings, "RATE_LIMIT_LOGIN_PER_MINUTE", 2)

    first = await _login_password(client, password="MauvaisMotDePasse")
    second = await _login_password(client, password="MauvaisMotDePasse")
    third = await _login_password(client, password="MauvaisMotDePasse")

    assert first.status_code == 401
    assert second.status_code == 401
    assert third.status_code == 429
    assert third.json()["error"]["code"] == "RATE_LIMITED"


async def test_login_unknown_phone_verifies_dummy_hash(
    client: AsyncClient, monkeypatch: pytest.MonkeyPatch
) -> None:
    calls: list[str] = []

    def spy(password: str, hash_str: str) -> bool:
        calls.append(hash_str)
        return False

    monkeypatch.setattr(auth_service_module, "verify_password", spy)

    response = await _login_password(client, phone="+22799999998")

    assert response.status_code == 401
    assert calls == [auth_service_module._DUMMY_PASSWORD_HASH]


async def test_login_account_without_password_verifies_dummy_hash(
    client: AsyncClient, monkeypatch: pytest.MonkeyPatch
) -> None:
    await _register(client)

    calls: list[str] = []

    def spy(password: str, hash_str: str) -> bool:
        calls.append(hash_str)
        return False

    monkeypatch.setattr(auth_service_module, "verify_password", spy)

    response = await _login_password(client)

    assert response.status_code == 401
    assert calls == [auth_service_module._DUMMY_PASSWORD_HASH]


async def test_otp_request_not_blocked_by_sms_delivery_failure(
    client: AsyncClient, db_session: AsyncSession, monkeypatch: pytest.MonkeyPatch
) -> None:
    await _register(client)
    FakeSmsProvider.clear()

    async def failing_send_sms(self, phone: str, message: str) -> bool:
        raise RuntimeError("sms provider unavailable")

    monkeypatch.setattr(FakeSmsProvider, "send_sms", failing_send_sms)

    response = await client.post(
        "/api/v1/auth/otp/request",
        json={"phone": PHONE, "purpose": "login"},
    )

    assert response.status_code == 202
    otp = (
        await db_session.execute(
            select(OtpCode).where(
                OtpCode.phone == PHONE,
                OtpCode.purpose == "login",
            )
        )
    ).scalar_one_or_none()
    assert otp is not None


async def test_login_refused_until_phone_verified(client: AsyncClient) -> None:
    await _register(client, password=PASSWORD)

    response = await _login_password(client)

    assert response.status_code == 401
    assert response.json()["error"]["code"] == "UNAUTHORIZED"
    assert response.json()["error"]["message"] == "Identifiants incorrects."


async def test_pre_registration_takeover_password_invalidated_after_verification(
    client: AsyncClient, db_session: AsyncSession
) -> None:
    attacker_password = "MotDePasseAttaquant1!"
    await _register(client, password=attacker_password)

    verified = await _verify_otp(client, _last_otp_code())
    assert verified.status_code == 200

    user = (
        await db_session.execute(select(User).where(User.phone == PHONE))
    ).scalar_one()
    assert user.phone_verified_at is not None
    assert user.password_hash is None

    response = await _login_password(client, password=attacker_password)
    assert response.status_code == 401
    assert response.json()["error"]["message"] == "Identifiants incorrects."


async def test_register_unverified_phone_replaces_account(
    client: AsyncClient, db_session: AsyncSession
) -> None:
    first = await _register(client, password="AncienMotDePasse1!")
    assert first.status_code == 201
    old_code = _last_otp_code()

    second = await _register(client, password=PASSWORD)
    assert second.status_code == 201
    assert second.json()["phone"] == PHONE

    new_code = _last_otp_code()
    assert new_code != old_code

    pending = (
        await db_session.execute(
            select(OtpCode).where(
                OtpCode.phone == PHONE,
                OtpCode.consumed_at.is_(None),
            )
        )
    ).scalars().all()
    assert len(pending) == 1

    stale = await _verify_otp(client, old_code)
    assert stale.status_code == 401

    fresh = await _verify_otp(client, new_code)
    assert fresh.status_code == 200


async def test_otp_verify_failures_share_same_message(
    client: AsyncClient, db_session: AsyncSession
) -> None:
    await _register(client)
    code = _last_otp_code()
    wrong_code = "000000" if code != "000000" else "000001"
    expected_message = "Code invalide ou expiré."

    wrong = await _verify_otp(client, wrong_code)
    assert wrong.status_code == 401
    assert wrong.json()["error"]["code"] == "UNAUTHORIZED"
    assert wrong.json()["error"]["message"] == expected_message

    await db_session.execute(
        update(OtpCode)
        .where(OtpCode.phone == PHONE, OtpCode.consumed_at.is_(None))
        .values(expires_at=datetime.now(UTC) - timedelta(seconds=1))
    )
    await db_session.commit()

    expired = await _verify_otp(client, code)
    assert expired.status_code == 401
    assert expired.json()["error"]["message"] == expected_message

    absent = await client.post(
        "/api/v1/auth/otp/verify",
        json={"phone": "+22799999999", "code": code, "purpose": "login"},
    )
    assert absent.status_code == 401
    assert absent.json()["error"]["message"] == expected_message
