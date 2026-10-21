import re
from datetime import UTC, date, datetime

from httpx import AsyncClient
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.deps import get_current_user
from app.core.geo import geojson_to_postgis_point, geojson_to_postgis_polygon
from app.core.security import create_access_token
from app.db.models.audit import AuditLog
from app.db.models.billing import Payment, Subscription, UsageRecord
from app.db.models.farming import Crop, CropCycle, Farm, FarmActivity, Harvest, Plot
from app.db.models.field_data import Notification
from app.db.models.identity import (
    AdminArea,
    Device,
    OtpCode,
    RefreshToken,
    User,
)
from app.db.models.knowledge import ChatMessage, ChatSession
from app.db.models.media_ai import Diagnostic, MediaFile, Recommendation
from app.db.models.organizations import Organization, OrganizationMember
from app.main import app
from app.providers.sms.fake import FakeSmsProvider

PHONE = "+22791000001"
OTHER_PHONE = "+22791000002"
PASSWORD = "MotDePasse123!"
OTP_PATTERN = re.compile(r"(\d{6})")


def _iter_keys(value: object):
    if isinstance(value, dict):
        for key, item in value.items():
            yield key
            yield from _iter_keys(item)
    elif isinstance(value, list):
        for item in value:
            yield from _iter_keys(item)


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


async def test_get_me_plots_quota_counts_user_plots(
    client: AsyncClient, db_session: AsyncSession
) -> None:
    tokens = await _register_verified(client)
    user = (
        await db_session.execute(select(User).where(User.phone == PHONE))
    ).scalar_one()

    farm = Farm(owner_id=user.id, name="Ferme")
    db_session.add(farm)
    await db_session.commit()
    await db_session.refresh(farm)

    db_session.add_all(
        [
            Plot(farm_id=farm.id, name="Parcelle 1"),
            Plot(farm_id=farm.id, name="Parcelle 2"),
            Plot(
                farm_id=farm.id,
                name="Parcelle supprimée",
                deleted_at=datetime.now(UTC),
            ),
        ]
    )
    await db_session.commit()

    response = await client.get("/api/v1/users/me", headers=_auth_headers(tokens))

    assert response.status_code == 200
    quotas = {quota["metric"]: quota for quota in response.json()["quotas"]}
    assert quotas["plots"]["limit"] == 3
    assert quotas["plots"]["used"] == 2
    assert quotas["plots"]["remaining"] == 1


async def test_patch_me_email_normalized_and_case_insensitive_conflict(
    client: AsyncClient,
) -> None:
    first = await _register_verified(client, phone=PHONE)
    second = await _register_verified(client, phone=OTHER_PHONE)

    stored = await client.patch(
        "/api/v1/users/me",
        json={"email": "Amina@Example.COM"},
        headers=_auth_headers(first),
    )
    assert stored.status_code == 200
    assert stored.json()["email"] == "amina@example.com"

    conflict = await client.patch(
        "/api/v1/users/me",
        json={"email": "AMINA@example.com"},
        headers=_auth_headers(second),
    )
    assert conflict.status_code == 409
    assert conflict.json()["error"]["code"] == "CONFLICT"


async def test_update_password_rejects_invalid_length(client: AsyncClient) -> None:
    tokens = await _register_verified(client)
    headers = _auth_headers(tokens)

    too_short = await client.put(
        "/api/v1/users/me/password",
        json={"new_password": "court"},
        headers=headers,
    )
    assert too_short.status_code == 422
    assert too_short.json()["error"]["code"] == "VALIDATION_ERROR"

    too_long = await client.put(
        "/api/v1/users/me/password",
        json={"new_password": "a" * 129},
        headers=headers,
    )
    assert too_long.status_code == 422
    assert too_long.json()["error"]["code"] == "VALIDATION_ERROR"

    current_too_long = await client.put(
        "/api/v1/users/me/password",
        json={"current_password": "a" * 129, "new_password": PASSWORD},
        headers=headers,
    )
    assert current_too_long.status_code == 422
    assert current_too_long.json()["error"]["code"] == "VALIDATION_ERROR"


async def test_export_contains_only_own_data(
    client: AsyncClient, db_session: AsyncSession
) -> None:
    tokens = await _register_verified(client, phone=PHONE)
    await _register_verified(client, phone=OTHER_PHONE)
    user = (
        await db_session.execute(select(User).where(User.phone == PHONE))
    ).scalar_one()
    other = (
        await db_session.execute(select(User).where(User.phone == OTHER_PHONE))
    ).scalar_one()

    farm = Farm(owner_id=user.id, name="Ma ferme")
    other_farm = Farm(owner_id=other.id, name="Ferme d'un autre")
    db_session.add_all([farm, other_farm])
    await db_session.commit()
    await db_session.refresh(farm)

    plot = Plot(farm_id=farm.id, name="Ma parcelle")
    db_session.add(plot)
    await db_session.commit()
    await db_session.refresh(plot)

    crop = Crop(code="millet-test", name_fr="Mil", category="cereal")
    db_session.add(crop)
    await db_session.commit()
    await db_session.refresh(crop)

    cycle = CropCycle(plot_id=plot.id, crop_id=crop.id, status="growing")
    db_session.add(cycle)
    await db_session.commit()
    await db_session.refresh(cycle)

    activity = FarmActivity(
        crop_cycle_id=cycle.id, type="sowing", performed_on=date.today()
    )
    harvest = Harvest(
        crop_cycle_id=cycle.id,
        harvested_on=date.today(),
        quantity_kg=100,
    )
    diagnostic = Diagnostic(user_id=user.id, status="done")
    recommendation = Recommendation(
        user_id=user.id, source="rules", title="Conseil", body="Texte"
    )
    payment = Payment(
        user_id=user.id,
        provider="manual",
        idempotency_key="export-own",
        purpose="subscription",
        amount_xof=1000,
    )
    other_payment = Payment(
        user_id=other.id,
        provider="manual",
        idempotency_key="export-other",
        purpose="subscription",
        amount_xof=2000,
    )
    db_session.add_all(
        [activity, harvest, diagnostic, recommendation, payment, other_payment]
    )
    await db_session.commit()

    response = await client.get(
        "/api/v1/users/me/export", headers=_auth_headers(tokens)
    )

    assert response.status_code == 200
    body = response.json()
    assert body["user"]["phone"] == PHONE
    assert [item["name"] for item in body["farms"]] == ["Ma ferme"]
    assert [item["name"] for item in body["plots"]] == ["Ma parcelle"]
    assert len(body["crop_cycles"]) == 1
    assert len(body["activities"]) == 1
    assert len(body["harvests"]) == 1
    assert len(body["diagnostics"]) == 1
    assert len(body["recommendations"]) == 1
    assert [item["idempotency_key"] for item in body["payments"]] == ["export-own"]

    keys = list(_iter_keys(body))
    assert not any(
        "hash" in key.lower() or "password" in key.lower() for key in keys
    )


async def test_delete_account_anonymizes_and_blocks_login(
    client: AsyncClient, db_session: AsyncSession
) -> None:
    tokens = await _register_verified(client)
    headers = _auth_headers(tokens)
    user = (
        await db_session.execute(select(User).where(User.phone == PHONE))
    ).scalar_one()
    user_id = user.id

    created = await client.post(
        "/api/v1/users/me/devices",
        json={"platform": "android", "fcm_token": "token-delete"},
        headers=headers,
    )
    assert created.status_code == 201

    password_set = await client.put(
        "/api/v1/users/me/password",
        json={"new_password": PASSWORD},
        headers=headers,
    )
    assert password_set.status_code == 200

    login_before = await client.post(
        "/api/v1/auth/login", json={"phone": PHONE, "password": PASSWORD}
    )
    assert login_before.status_code == 200

    deleted = await client.request(
        "DELETE",
        "/api/v1/users/me",
        json={"confirmation": "SUPPRIMER MON COMPTE"},
        headers=headers,
    )
    assert deleted.status_code == 200

    login_after = await client.post(
        "/api/v1/auth/login", json={"phone": PHONE, "password": PASSWORD}
    )
    assert login_after.status_code == 401

    db_session.expire_all()
    anonymized = (
        await db_session.execute(select(User).where(User.id == user_id))
    ).scalar_one()
    assert anonymized.phone != PHONE
    assert anonymized.phone.startswith("deleted-")
    assert anonymized.full_name == ""
    assert anonymized.email is None
    assert anonymized.password_hash is None
    assert anonymized.is_active is False
    assert anonymized.deleted_at is not None

    devices = (
        await db_session.execute(
            select(Device).where(Device.user_id == user_id)
        )
    ).scalars().all()
    assert devices == []

    refresh_tokens = (
        await db_session.execute(
            select(RefreshToken).where(RefreshToken.user_id == user_id)
        )
    ).scalars().all()
    assert refresh_tokens == []

    audit_entries = (
        await db_session.execute(
            select(AuditLog).where(AuditLog.action == "account_deleted")
        )
    ).scalars().all()
    assert len(audit_entries) == 1
    assert audit_entries[0].entity_id == str(user_id)


async def test_delete_account_requires_confirmation(client: AsyncClient) -> None:
    tokens = await _register_verified(client)
    headers = _auth_headers(tokens)

    missing = await client.delete("/api/v1/users/me", headers=headers)
    assert missing.status_code == 422
    assert missing.json()["error"]["code"] == "VALIDATION_ERROR"

    wrong = await client.request(
        "DELETE",
        "/api/v1/users/me",
        json={"confirmation": "supprimer"},
        headers=headers,
    )
    assert wrong.status_code == 422
    assert wrong.json()["error"]["code"] == "VALIDATION_ERROR"

    profile = await client.get("/api/v1/users/me", headers=headers)
    assert profile.status_code == 200


async def test_access_token_rejected_after_account_deletion(
    client: AsyncClient,
) -> None:
    tokens = await _register_verified(client)
    headers = _auth_headers(tokens)

    deleted = await client.request(
        "DELETE",
        "/api/v1/users/me",
        json={"confirmation": "SUPPRIMER MON COMPTE"},
        headers=headers,
    )
    assert deleted.status_code == 200

    rejected = await client.get("/api/v1/users/me", headers=headers)
    assert rejected.status_code == 401
    assert rejected.json()["error"]["code"] == "UNAUTHORIZED"


async def test_delete_account_anonymizes_related_personal_data(
    client: AsyncClient, db_session: AsyncSession
) -> None:
    tokens = await _register_verified(client)
    headers = _auth_headers(tokens)
    user = (
        await db_session.execute(select(User).where(User.phone == PHONE))
    ).scalar_one()
    user_id = user.id

    farm = Farm(
        owner_id=user_id,
        name="Ferme d'origine",
        village="Village d'origine",
        location=geojson_to_postgis_point(
            {"type": "Point", "coordinates": [2.1, 13.5]}
        ),
    )
    db_session.add(farm)
    await db_session.commit()
    await db_session.refresh(farm)

    plot = Plot(
        farm_id=farm.id,
        name="Parcelle d'origine",
        area_ha=3.5,
        geom=geojson_to_postgis_polygon(
            {
                "type": "Polygon",
                "coordinates": [
                    [
                        [2.0, 13.0],
                        [2.01, 13.0],
                        [2.01, 13.01],
                        [2.0, 13.01],
                        [2.0, 13.0],
                    ]
                ],
            }
        ),
    )
    db_session.add(plot)
    await db_session.commit()
    await db_session.refresh(plot)

    crop = Crop(code="millet-delete", name_fr="Mil", category="cereal")
    db_session.add(crop)
    await db_session.commit()
    await db_session.refresh(crop)

    cycle = CropCycle(
        plot_id=plot.id,
        crop_id=crop.id,
        status="growing",
        notes="Note privée du cycle",
    )
    db_session.add(cycle)
    await db_session.commit()
    await db_session.refresh(cycle)

    activity = FarmActivity(
        crop_cycle_id=cycle.id,
        type="sowing",
        performed_on=date.today(),
        notes="Note privée de l'activité",
    )
    harvest = Harvest(
        crop_cycle_id=cycle.id,
        harvested_on=date.today(),
        quantity_kg=120,
    )
    diagnostic = Diagnostic(
        user_id=user_id,
        status="done",
        location=geojson_to_postgis_point(
            {"type": "Point", "coordinates": [2.2, 13.6]}
        ),
        user_note="Note privée du diagnostic",
    )
    payment = Payment(
        user_id=user_id,
        provider="manual",
        idempotency_key="delete-mask-payment",
        purpose="subscription",
        amount_xof=1500,
        payer_phone="+22790001122",
    )
    otp = OtpCode(
        phone=PHONE,
        code_hash="hash",
        purpose="login",
        expires_at=datetime.now(UTC),
    )
    chat_session = ChatSession(user_id=user_id, title="Conversation")
    notification = Notification(
        user_id=user_id,
        channel="in_app",
        title="Alerte",
        body="Message",
    )
    organization = Organization(name="Coopérative", type="cooperative")
    db_session.add_all(
        [activity, harvest, diagnostic, payment, otp, chat_session, notification]
    )
    db_session.add(organization)
    await db_session.commit()
    await db_session.refresh(chat_session)
    await db_session.refresh(organization)
    db_session.add(
        OrganizationMember(
            organization_id=organization.id,
            user_id=user_id,
            member_role="owner",
        )
    )
    db_session.add(
        ChatMessage(
            session_id=chat_session.id,
            role="user",
            content="Message privé",
        )
    )
    await db_session.commit()

    payment_id = payment.id
    farm_id = farm.id
    plot_id = plot.id
    cycle_id = cycle.id
    activity_id = activity.id
    harvest_id = harvest.id
    diagnostic_id = diagnostic.id
    chat_session_id = chat_session.id

    deleted = await client.request(
        "DELETE",
        "/api/v1/users/me",
        json={"confirmation": "SUPPRIMER MON COMPTE"},
        headers=headers,
    )
    assert deleted.status_code == 200

    db_session.expire_all()
    otp_count = len(
        (
            await db_session.execute(
                select(OtpCode).where(OtpCode.phone == PHONE)
            )
        ).scalars().all()
    )
    assert otp_count == 0

    masked_payment = await db_session.get(Payment, payment_id)
    assert masked_payment is not None
    assert masked_payment.payer_phone is not None
    assert masked_payment.payer_phone.endswith("22")
    assert masked_payment.payer_phone != "+22790001122"

    anonymized_farm = await db_session.get(Farm, farm_id)
    assert anonymized_farm is not None
    assert anonymized_farm.name == "Exploitation supprimée"
    assert anonymized_farm.village is None
    assert anonymized_farm.location is None

    anonymized_plot = await db_session.get(Plot, plot_id)
    assert anonymized_plot is not None
    assert anonymized_plot.name == "Parcelle supprimée"
    assert anonymized_plot.geom is None
    assert float(anonymized_plot.area_ha) == 3.5

    assert (await db_session.get(CropCycle, cycle_id)).notes is None
    assert (await db_session.get(FarmActivity, activity_id)).notes is None
    assert (await db_session.get(Harvest, harvest_id)) is not None

    anonymized_diagnostic = await db_session.get(Diagnostic, diagnostic_id)
    assert anonymized_diagnostic is not None
    assert anonymized_diagnostic.location is None
    assert anonymized_diagnostic.user_note is None

    chat_sessions = (
        await db_session.execute(
            select(ChatSession).where(ChatSession.user_id == user_id)
        )
    ).scalars().all()
    chat_messages = (
        await db_session.execute(
            select(ChatMessage).where(
                ChatMessage.session_id == chat_session_id
            )
        )
    ).scalars().all()
    notifications = (
        await db_session.execute(
            select(Notification).where(Notification.user_id == user_id)
        )
    ).scalars().all()
    memberships = (
        await db_session.execute(
            select(OrganizationMember).where(
                OrganizationMember.user_id == user_id
            )
        )
    ).scalars().all()
    assert chat_sessions == []
    assert chat_messages == []
    assert notifications == []
    assert memberships == []


async def test_delete_account_refused_for_sole_owner_with_other_members(
    client: AsyncClient, db_session: AsyncSession
) -> None:
    tokens = await _register_verified(client, phone=PHONE)
    await _register_verified(client, phone=OTHER_PHONE)
    user = (
        await db_session.execute(select(User).where(User.phone == PHONE))
    ).scalar_one()
    other = (
        await db_session.execute(select(User).where(User.phone == OTHER_PHONE))
    ).scalar_one()

    organization = Organization(name="Coopérative", type="cooperative")
    db_session.add(organization)
    await db_session.commit()
    await db_session.refresh(organization)
    db_session.add_all(
        [
            OrganizationMember(
                organization_id=organization.id,
                user_id=user.id,
                member_role="owner",
            ),
            OrganizationMember(
                organization_id=organization.id,
                user_id=other.id,
                member_role="member",
            ),
        ]
    )
    await db_session.commit()

    response = await client.request(
        "DELETE",
        "/api/v1/users/me",
        json={"confirmation": "SUPPRIMER MON COMPTE"},
        headers=_auth_headers(tokens),
    )

    assert response.status_code == 409
    assert response.json()["error"]["code"] == "CONFLICT"
    assert "seul propriétaire" in response.json()["error"]["message"]

    user_id = user.id
    db_session.expire_all()
    still_active = await db_session.get(User, user_id)
    assert still_active is not None
    assert still_active.is_active is True
    assert still_active.deleted_at is None
    memberships = (
        await db_session.execute(
            select(OrganizationMember).where(
                OrganizationMember.user_id == user_id
            )
        )
    ).scalars().all()
    assert len(memberships) == 1


async def test_anonymized_farm_and_plot_not_returned_by_read_routes(
    client: AsyncClient, db_session: AsyncSession
) -> None:
    tokens = await _register_verified(client)
    headers = _auth_headers(tokens)
    user = (
        await db_session.execute(select(User).where(User.phone == PHONE))
    ).scalar_one()
    user_id = user.id

    farm = Farm(
        owner_id=user_id,
        name="Ferme visible",
        village="Village",
        location=geojson_to_postgis_point(
            {"type": "Point", "coordinates": [2.1, 13.5]}
        ),
    )
    db_session.add(farm)
    await db_session.commit()
    await db_session.refresh(farm)

    plot = Plot(
        farm_id=farm.id,
        name="Parcelle visible",
        area_ha=2.0,
        geom=geojson_to_postgis_polygon(
            {
                "type": "Polygon",
                "coordinates": [
                    [
                        [2.0, 13.0],
                        [2.01, 13.0],
                        [2.01, 13.01],
                        [2.0, 13.01],
                        [2.0, 13.0],
                    ]
                ],
            }
        ),
    )
    db_session.add(plot)
    await db_session.commit()
    await db_session.refresh(plot)

    deleted = await client.request(
        "DELETE",
        "/api/v1/users/me",
        json={"confirmation": "SUPPRIMER MON COMPTE"},
        headers=headers,
    )
    assert deleted.status_code == 200

    farm_id = farm.id
    plot_id = plot.id
    db_session.expire_all()
    anonymized_user = await db_session.get(User, user_id)
    assert anonymized_user is not None
    app.dependency_overrides[get_current_user] = lambda: anonymized_user
    try:
        farm_response = await client.get(f"/api/v1/farms/{farm_id}")
        assert farm_response.status_code == 200
        farm_body = farm_response.json()
        assert farm_body["name"] == "Exploitation supprimée"
        assert farm_body["village"] is None
        assert farm_body["location"] is None

        plot_response = await client.get(f"/api/v1/plots/{plot_id}")
        assert plot_response.status_code == 200
        plot_body = plot_response.json()
        assert plot_body["name"] == "Parcelle supprimée"
        assert plot_body["geom"] is None
        assert float(plot_body["area_ha"]) == 2.0
    finally:
        app.dependency_overrides.pop(get_current_user, None)


async def test_export_includes_extended_data(
    client: AsyncClient, db_session: AsyncSession
) -> None:
    tokens = await _register_verified(client, phone=PHONE)
    await _register_verified(client, phone=OTHER_PHONE)
    user = (
        await db_session.execute(select(User).where(User.phone == PHONE))
    ).scalar_one()
    other = (
        await db_session.execute(select(User).where(User.phone == OTHER_PHONE))
    ).scalar_one()

    organization = Organization(name="Coopérative", type="cooperative")
    db_session.add(organization)
    await db_session.commit()
    await db_session.refresh(organization)
    db_session.add(
        OrganizationMember(
            organization_id=organization.id,
            user_id=user.id,
            member_role="owner",
        )
    )
    notification = Notification(
        user_id=user.id,
        channel="in_app",
        title="Mon alerte",
        body="Mon message",
    )
    other_notification = Notification(
        user_id=other.id,
        channel="in_app",
        title="Alerte d'un autre",
        body="Message d'un autre",
    )
    chat_session = ChatSession(user_id=user.id, title="Ma conversation")
    media = MediaFile(
        owner_id=user.id,
        kind="image",
        storage_key="private/own-key.jpg",
        mime_type="image/jpeg",
        size_bytes=1024,
        sha256="abc",
    )
    other_media = MediaFile(
        owner_id=other.id,
        kind="image",
        storage_key="private/other-key.jpg",
        mime_type="image/jpeg",
        size_bytes=2048,
        sha256="def",
    )
    db_session.add_all(
        [notification, other_notification, chat_session, media, other_media]
    )
    await db_session.commit()
    await db_session.refresh(chat_session)
    chat_message = ChatMessage(
        session_id=chat_session.id,
        role="user",
        content="Bonjour",
    )
    db_session.add(chat_message)
    await db_session.commit()

    response = await client.get(
        "/api/v1/users/me/export", headers=_auth_headers(tokens)
    )

    assert response.status_code == 200
    body = response.json()
    assert len(body["subscriptions"]) == 1
    assert [item["organization_id"] for item in body["organization_memberships"]] == [
        str(organization.id)
    ]
    assert [item["title"] for item in body["notifications"]] == ["Mon alerte"]
    assert [item["id"] for item in body["chat_sessions"]] == [
        str(chat_session.id)
    ]
    assert [item["id"] for item in body["chat_messages"]] == [
        chat_message.id
    ]
    assert [item["id"] for item in body["media_files"]] == [str(media.id)]

    keys = list(_iter_keys(body))
    assert not any("storage_key" in key.lower() for key in keys)
