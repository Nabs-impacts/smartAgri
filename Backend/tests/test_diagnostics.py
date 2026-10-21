import asyncio
import hashlib
import re
import uuid
from datetime import UTC, datetime

import pytest
from httpx import AsyncClient
from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import settings
from app.db.models.billing import Plan, Subscription, UsageRecord
from app.db.models.farming import Crop
from app.db.models.identity import User
from app.db.models.media_ai import (
    Diagnostic,
    DiagnosticMedia,
    DiagnosticPrediction,
    MediaFile,
)
from app.db.session import SyncSessionLocal
from app.providers.sms.fake import FakeSmsProvider
from app.services.diagnostic_service import run_pipeline
from app.workers.tasks_diagnostic import run_diagnostic

PHONE_OWNER = "+22795000001"
PHONE_OTHER = "+22795000002"
PHONE_AGRONOMIST = "+22795000003"
PHONE_AGENT = "+22795000004"
OTP_PATTERN = re.compile(r"(\d{6})")


@pytest.fixture(autouse=True)
def worker_calls(monkeypatch: pytest.MonkeyPatch) -> list[tuple]:
    calls: list[tuple] = []

    def _delay(*args, **kwargs) -> None:
        calls.append(args)

    monkeypatch.setattr(run_diagnostic, "delay", _delay)
    return calls


def _last_otp_code() -> str:
    message = FakeSmsProvider.sent_messages[-1]["message"]
    match = OTP_PATTERN.search(message)
    assert match is not None
    return match.group(1)


async def _register_verified(
    client: AsyncClient,
    phone: str,
    language: str = "fr",
) -> tuple[dict[str, str], uuid.UUID]:
    registered = await client.post(
        "/api/v1/auth/register",
        json={"phone": phone, "full_name": "Test Diagnostic", "language": language},
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
        uuid.UUID(body["user"]["id"]),
    )


async def _create_plot(client: AsyncClient, headers: dict[str, str]) -> dict:
    farm = await client.post(
        "/api/v1/farms", json={"name": "Ferme Diagnostic"}, headers=headers
    )
    assert farm.status_code == 201
    plot = await client.post(
        f"/api/v1/farms/{farm.json()['id']}/plots",
        json={"name": "Parcelle Diagnostic", "area_ha": 2.0},
        headers=headers,
    )
    assert plot.status_code == 201
    return plot.json()


async def _create_cycle(
    client: AsyncClient,
    headers: dict[str, str],
    plot_id: str,
    crop_id: int,
) -> dict:
    cycle = await client.post(
        f"/api/v1/plots/{plot_id}/cycles",
        json={"crop_id": crop_id},
        headers=headers,
    )
    assert cycle.status_code == 201
    return cycle.json()


async def _crop_id(session: AsyncSession, code: str = "millet") -> int:
    crop = (await session.execute(select(Crop).where(Crop.code == code))).scalar_one()
    return crop.id


async def _add_media(
    session: AsyncSession,
    owner_id: uuid.UUID,
    kind: str = "image",
    upload_status: str = "uploaded",
    deleted_at: datetime | None = None,
    plot_id: uuid.UUID | None = None,
    crop_cycle_id: uuid.UUID | None = None,
) -> MediaFile:
    mime_types = {
        "image": "image/jpeg",
        "video": "video/mp4",
        "audio": "audio/mpeg",
    }
    media = MediaFile(
        owner_id=owner_id,
        kind=kind,
        storage_key=f"users/{owner_id}/{uuid.uuid4()}.bin",
        mime_type=mime_types[kind],
        size_bytes=128,
        sha256=hashlib.sha256(uuid.uuid4().bytes).hexdigest(),
        upload_status=upload_status,
        deleted_at=deleted_at,
        plot_id=plot_id,
        crop_cycle_id=crop_cycle_id,
    )
    session.add(media)
    await session.flush()
    return media


async def _add_diagnostic(
    session: AsyncSession,
    user_id: uuid.UUID,
    status: str = "pending",
    plot_id: uuid.UUID | None = None,
    crop_id: int | None = None,
    crop_cycle_id: uuid.UUID | None = None,
    created_at: datetime | None = None,
    source: str = "server",
) -> Diagnostic:
    values = {
        "user_id": user_id,
        "status": status,
        "plot_id": plot_id,
        "crop_id": crop_id,
        "crop_cycle_id": crop_cycle_id,
        "source": source,
    }
    if created_at is not None:
        values["created_at"] = created_at
    diagnostic = Diagnostic(**values)
    session.add(diagnostic)
    await session.flush()
    await session.commit()
    return diagnostic


async def _link_media(
    session: AsyncSession,
    diagnostic_id: uuid.UUID,
    media_id: uuid.UUID,
) -> None:
    session.add(
        DiagnosticMedia(diagnostic_id=diagnostic_id, media_id=media_id)
    )
    await session.commit()


async def _set_free_quotas(session: AsyncSession, quotas: dict) -> None:
    plan = (
        await session.execute(select(Plan).where(Plan.code == "free"))
    ).scalar_one()
    plan.quotas = quotas
    await session.commit()


def _run_pipeline_sync(diagnostic_id: uuid.UUID) -> None:
    with SyncSessionLocal() as session:
        run_pipeline(session, diagnostic_id)


async def _run_pipeline(diagnostic_id: uuid.UUID) -> None:
    await asyncio.to_thread(_run_pipeline_sync, diagnostic_id)


async def _usage_count(
    session: AsyncSession,
    metric: str | None = None,
) -> int:
    stmt = select(func.count(UsageRecord.id))
    if metric is not None:
        stmt = stmt.where(UsageRecord.metric == metric)
    return int((await session.execute(stmt)).scalar_one())


def _iter_keys(value: object):
    if isinstance(value, dict):
        for key, item in value.items():
            yield key
            yield from _iter_keys(item)
    elif isinstance(value, list):
        for item in value:
            yield from _iter_keys(item)


async def test_create_diagnostic_records_usage_and_enqueues(
    client: AsyncClient,
    db_session: AsyncSession,
    worker_calls: list[tuple],
) -> None:
    headers, user_id = await _register_verified(client, PHONE_OWNER)
    crop_id = await _crop_id(db_session)
    media = await _add_media(db_session, user_id)
    await db_session.commit()
    diagnostic_id = uuid.uuid4()

    response = await client.post(
        "/api/v1/diagnostics",
        json={
            "id": str(diagnostic_id),
            "media_ids": [str(media.id)],
            "crop_id": crop_id,
            "user_note": "Feuilles jaunes",
            "lat": 13.5,
            "lng": 2.1,
        },
        headers=headers,
    )

    assert response.status_code == 202, response.text
    body = response.json()
    assert body["id"] == str(diagnostic_id)
    assert body["status"] == "pending"
    assert body["crop_id"] == crop_id
    assert "storage_key" not in set(_iter_keys(body))

    records = list(
        (
            await db_session.execute(
                select(UsageRecord).where(UsageRecord.metric == "diagnostic")
            )
        )
        .scalars()
        .all()
    )
    assert len(records) == 1
    assert records[0].quantity == 1
    assert records[0].period == datetime.now(UTC).date().replace(day=1)
    subscription = (
        await db_session.execute(
            select(Subscription).where(Subscription.user_id == user_id)
        )
    ).scalar_one()
    assert records[0].subscription_id == subscription.id
    assert worker_calls == [(str(diagnostic_id),)]


async def test_roundtrip_pipeline_then_detail(
    client: AsyncClient,
    db_session: AsyncSession,
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    headers, user_id = await _register_verified(client, PHONE_OWNER)
    crop_id = await _crop_id(db_session)
    media = await _add_media(db_session, user_id)
    await db_session.commit()

    created = await client.post(
        "/api/v1/diagnostics",
        json={"media_ids": [str(media.id)], "crop_id": crop_id},
        headers=headers,
    )
    assert created.status_code == 202
    diagnostic_id = created.json()["id"]

    monkeypatch.setattr(settings, "DIAGNOSTIC_CONFIDENCE_THRESHOLD", 0.0)
    await _run_pipeline(uuid.UUID(diagnostic_id))

    detail = await client.get(
        f"/api/v1/diagnostics/{diagnostic_id}", headers=headers
    )
    assert detail.status_code == 200, detail.text
    body = detail.json()
    assert body["status"] == "done"
    assert [item["rank"] for item in body["predictions"]] == [1, 2, 3]
    assert body["predictions"][0]["label"]["name"]
    assert body["recommendation"] is not None
    assert body["recommendation"]["status"] == "published"
    assert body["on_device_prediction"] is None
    assert body["media"][0]["url"]
    assert "storage_key" not in set(_iter_keys(body))


async def test_client_id_idempotency_and_conflicts(
    client: AsyncClient,
    db_session: AsyncSession,
) -> None:
    headers, user_id = await _register_verified(client, PHONE_OWNER)
    other_headers, other_id = await _register_verified(client, PHONE_OTHER)
    media = await _add_media(db_session, user_id)
    other_media = await _add_media(db_session, other_id)
    await db_session.commit()
    diagnostic_id = uuid.uuid4()

    payload = {"id": str(diagnostic_id), "media_ids": [str(media.id)]}
    first = await client.post("/api/v1/diagnostics", json=payload, headers=headers)
    assert first.status_code == 202
    second = await client.post("/api/v1/diagnostics", json=payload, headers=headers)
    assert second.status_code == 200
    assert second.json()["id"] == str(diagnostic_id)

    conflict = await client.post(
        "/api/v1/diagnostics",
        json={"id": str(diagnostic_id), "media_ids": [str(other_media.id)]},
        headers=other_headers,
    )
    assert conflict.status_code == 409
    assert conflict.json()["error"]["message"] == (
        "Une ressource avec cet identifiant existe déjà."
    )

    diagnostic = await db_session.get(Diagnostic, diagnostic_id)
    diagnostic.deleted_at = datetime.now(UTC)
    await db_session.commit()
    deleted = await client.post(
        "/api/v1/diagnostics",
        json={"id": str(diagnostic_id), "media_ids": [str(media.id)]},
        headers=headers,
    )
    assert deleted.status_code == 409
    assert deleted.json()["error"]["message"] == "Cette ressource a été supprimée."


async def test_media_validation_errors(
    client: AsyncClient,
    db_session: AsyncSession,
) -> None:
    headers, user_id = await _register_verified(client, PHONE_OWNER)
    other_headers, other_id = await _register_verified(client, PHONE_OTHER)
    other_media = await _add_media(db_session, other_id)
    pending_media = await _add_media(db_session, user_id, upload_status="pending")
    audio_media = await _add_media(db_session, user_id, kind="audio")
    await db_session.commit()

    foreign = await client.post(
        "/api/v1/diagnostics",
        json={"media_ids": [str(other_media.id)]},
        headers=headers,
    )
    assert foreign.status_code == 404
    assert foreign.json()["error"]["message"] == "Média introuvable."

    pending = await client.post(
        "/api/v1/diagnostics",
        json={"media_ids": [str(pending_media.id)]},
        headers=headers,
    )
    assert pending.status_code == 409
    assert pending.json()["error"]["message"] == (
        "Le média n'a pas fini d'être téléversé."
    )

    audio = await client.post(
        "/api/v1/diagnostics",
        json={"media_ids": [str(audio_media.id)]},
        headers=headers,
    )
    assert audio.status_code == 422

    empty = await client.post(
        "/api/v1/diagnostics", json={"media_ids": []}, headers=headers
    )
    assert empty.status_code == 422

    too_many = await client.post(
        "/api/v1/diagnostics",
        json={"media_ids": [str(uuid.uuid4()) for _ in range(7)]},
        headers=headers,
    )
    assert too_many.status_code == 422


async def test_foreign_plot_and_cycle_return_404(
    client: AsyncClient,
    db_session: AsyncSession,
) -> None:
    headers, user_id = await _register_verified(client, PHONE_OWNER)
    other_headers, _ = await _register_verified(client, PHONE_OTHER)
    crop_id = await _crop_id(db_session)
    other_plot = await _create_plot(client, other_headers)
    other_cycle = await _create_cycle(
        client, other_headers, other_plot["id"], crop_id
    )
    media = await _add_media(db_session, user_id)
    await db_session.commit()

    plot_response = await client.post(
        "/api/v1/diagnostics",
        json={"media_ids": [str(media.id)], "plot_id": other_plot["id"]},
        headers=headers,
    )
    assert plot_response.status_code == 404
    assert plot_response.json()["error"]["message"] == "Parcelle introuvable."

    cycle_response = await client.post(
        "/api/v1/diagnostics",
        json={
            "media_ids": [str(media.id)],
            "crop_cycle_id": other_cycle["id"],
        },
        headers=headers,
    )
    assert cycle_response.status_code == 404
    assert cycle_response.json()["error"]["message"] == (
        "Cycle de culture introuvable."
    )


async def test_cycle_must_belong_to_given_plot(
    client: AsyncClient,
    db_session: AsyncSession,
) -> None:
    headers, user_id = await _register_verified(client, PHONE_OWNER)
    crop_id = await _crop_id(db_session)
    plot_with_cycle = await _create_plot(client, headers)
    other_plot = await _create_plot(client, headers)
    cycle = await _create_cycle(
        client, headers, plot_with_cycle["id"], crop_id
    )
    media = await _add_media(db_session, user_id)
    await db_session.commit()

    response = await client.post(
        "/api/v1/diagnostics",
        json={
            "media_ids": [str(media.id)],
            "plot_id": other_plot["id"],
            "crop_cycle_id": cycle["id"],
        },
        headers=headers,
    )
    assert response.status_code == 422
    assert response.json()["error"]["message"] == (
        "Le cycle de culture ne correspond pas à la parcelle."
    )


async def test_crop_derived_from_cycle(
    client: AsyncClient,
    db_session: AsyncSession,
) -> None:
    headers, user_id = await _register_verified(client, PHONE_OWNER)
    plot = await _create_plot(client, headers)
    crop_id = await _crop_id(db_session, "sorghum")
    cycle = await _create_cycle(client, headers, plot["id"], crop_id)
    media = await _add_media(db_session, user_id)
    await db_session.commit()

    response = await client.post(
        "/api/v1/diagnostics",
        json={
            "media_ids": [str(media.id)],
            "crop_cycle_id": cycle["id"],
        },
        headers=headers,
    )
    assert response.status_code == 202
    assert response.json()["crop_id"] == crop_id
    assert response.json()["crop_cycle_id"] == cycle["id"]


async def test_monthly_quotas(
    client: AsyncClient,
    db_session: AsyncSession,
) -> None:
    headers, user_id = await _register_verified(client, PHONE_OWNER)
    image = await _add_media(db_session, user_id)
    video = await _add_media(db_session, user_id, kind="video")
    await _set_free_quotas(
        db_session,
        {
            "diagnostics_per_month": 1,
            "video_analyses_per_month": 10,
            "plots": 3,
            "storage_mb": 100,
        },
    )

    first = await client.post(
        "/api/v1/diagnostics",
        json={"media_ids": [str(image.id)]},
        headers=headers,
    )
    assert first.status_code == 202
    exceeded = await client.post(
        "/api/v1/diagnostics",
        json={"media_ids": [str(image.id)]},
        headers=headers,
    )
    assert exceeded.status_code == 403
    error = exceeded.json()["error"]
    assert error["code"] == "QUOTA_EXCEEDED"
    assert error["details"] == {"metric": "diagnostic", "limit": 1, "used": 1}

    await _set_free_quotas(
        db_session,
        {
            "diagnostics_per_month": -1,
            "video_analyses_per_month": 0,
            "plots": 3,
            "storage_mb": 100,
        },
    )
    video_response = await client.post(
        "/api/v1/diagnostics",
        json={"media_ids": [str(video.id)]},
        headers=headers,
    )
    assert video_response.status_code == 403
    video_error = video_response.json()["error"]
    assert video_error["code"] == "QUOTA_EXCEEDED"
    assert video_error["details"] == {
        "metric": "video_analysis",
        "limit": 0,
        "used": 0,
    }


async def test_retry_only_when_failed_and_without_new_usage(
    client: AsyncClient,
    db_session: AsyncSession,
    worker_calls: list[tuple],
) -> None:
    headers, user_id = await _register_verified(client, PHONE_OWNER)
    media = await _add_media(db_session, user_id)
    await db_session.commit()

    created = await client.post(
        "/api/v1/diagnostics",
        json={"media_ids": [str(media.id)]},
        headers=headers,
    )
    assert created.status_code == 202
    diagnostic_id = created.json()["id"]

    not_failed = await client.post(
        f"/api/v1/diagnostics/{diagnostic_id}/retry",
        headers=headers,
    )
    assert not_failed.status_code == 409
    assert not_failed.json()["error"]["message"] == (
        "Seul un diagnostic en échec peut être relancé."
    )

    diagnostic = await db_session.get(Diagnostic, uuid.UUID(diagnostic_id))
    diagnostic.status = "failed"
    diagnostic.error = "Erreur interne"
    diagnostic.completed_at = datetime.now(UTC)
    await db_session.commit()
    usage_before = await _usage_count(db_session, "diagnostic")

    retried = await client.post(
        f"/api/v1/diagnostics/{diagnostic_id}/retry",
        headers=headers,
    )
    assert retried.status_code == 200, retried.text
    body = retried.json()
    assert body["status"] == "pending"
    assert body["error"] is None
    assert body["completed_at"] is None
    assert await _usage_count(db_session, "diagnostic") == usage_before
    assert worker_calls[-1] == (diagnostic_id,)


async def test_delete_then_not_found(
    client: AsyncClient,
    db_session: AsyncSession,
) -> None:
    headers, user_id = await _register_verified(client, PHONE_OWNER)
    media = await _add_media(db_session, user_id)
    await db_session.commit()
    created = await client.post(
        "/api/v1/diagnostics",
        json={"media_ids": [str(media.id)]},
        headers=headers,
    )
    diagnostic_id = created.json()["id"]

    deleted = await client.delete(
        f"/api/v1/diagnostics/{diagnostic_id}", headers=headers
    )
    assert deleted.status_code == 204
    fetched = await client.get(
        f"/api/v1/diagnostics/{diagnostic_id}", headers=headers
    )
    assert fetched.status_code == 404
    listed = await client.get("/api/v1/diagnostics", headers=headers)
    assert listed.json()["items"] == []


async def test_foreign_diagnostic_returns_404(
    client: AsyncClient,
    db_session: AsyncSession,
) -> None:
    headers, user_id = await _register_verified(client, PHONE_OWNER)
    other_headers, _ = await _register_verified(client, PHONE_OTHER)
    diagnostic = await _add_diagnostic(db_session, user_id)

    for method, path in (
        ("get", f"/api/v1/diagnostics/{diagnostic.id}"),
        ("post", f"/api/v1/diagnostics/{diagnostic.id}/retry"),
        ("delete", f"/api/v1/diagnostics/{diagnostic.id}"),
    ):
        response = await getattr(client, method)(path, headers=other_headers)
        assert response.status_code == 404


async def test_agronomist_reads_only_needs_review(
    client: AsyncClient,
    db_session: AsyncSession,
) -> None:
    owner_headers, owner_id = await _register_verified(client, PHONE_OWNER)
    agronomist_headers, agronomist_id = await _register_verified(
        client, PHONE_AGRONOMIST
    )
    review = await _add_diagnostic(db_session, owner_id, status="needs_review")
    done = await _add_diagnostic(db_session, owner_id, status="done")
    review_media = await _add_media(db_session, owner_id)
    done_media = await _add_media(db_session, owner_id)
    await _link_media(db_session, review.id, review_media.id)
    await _link_media(db_session, done.id, done_media.id)
    agronomist = await db_session.get(User, agronomist_id)
    agronomist.role = "agronomist"
    await db_session.commit()

    allowed = await client.get(
        f"/api/v1/diagnostics/{review.id}", headers=agronomist_headers
    )
    assert allowed.status_code == 200
    denied = await client.get(
        f"/api/v1/diagnostics/{done.id}", headers=agronomist_headers
    )
    assert denied.status_code == 404

    allowed_media = await client.get(
        f"/api/v1/media/{review_media.id}", headers=agronomist_headers
    )
    assert allowed_media.status_code == 200
    denied_media = await client.get(
        f"/api/v1/media/{done_media.id}", headers=agronomist_headers
    )
    assert denied_media.status_code == 404

    write_denied = await client.delete(
        f"/api/v1/diagnostics/{review.id}", headers=agronomist_headers
    )
    assert write_denied.status_code == 404
    owner_read = await client.get(
        f"/api/v1/diagnostics/{review.id}", headers=owner_headers
    )
    assert owner_read.status_code == 200


async def test_organization_agent_reads_plot_diagnostic_only(
    client: AsyncClient,
    db_session: AsyncSession,
) -> None:
    owner_headers, owner_id = await _register_verified(client, PHONE_OWNER)
    agent_headers, agent_id = await _register_verified(client, PHONE_AGENT)
    organization = await client.post(
        "/api/v1/organizations",
        json={"name": "Coop Diagnostic", "type": "cooperative"},
        headers=owner_headers,
    )
    assert organization.status_code == 201
    member = await client.post(
        f"/api/v1/organizations/{organization.json()['id']}/members",
        json={"phone": PHONE_AGENT, "member_role": "agent"},
        headers=owner_headers,
    )
    assert member.status_code == 201

    plot = await _create_plot(client, owner_headers)
    with_plot = await _add_diagnostic(
        db_session, owner_id, plot_id=uuid.UUID(plot["id"])
    )
    without_plot = await _add_diagnostic(db_session, owner_id)

    allowed = await client.get(
        f"/api/v1/diagnostics/{with_plot.id}", headers=agent_headers
    )
    assert allowed.status_code == 200
    denied = await client.get(
        f"/api/v1/diagnostics/{without_plot.id}", headers=agent_headers
    )
    assert denied.status_code == 404
    write_denied = await client.delete(
        f"/api/v1/diagnostics/{with_plot.id}", headers=agent_headers
    )
    assert write_denied.status_code == 404

    agent = await db_session.get(User, agent_id)
    assert agent is not None


async def test_on_device_result_stored_and_preserved(
    client: AsyncClient,
    db_session: AsyncSession,
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    headers, user_id = await _register_verified(client, PHONE_OWNER)
    crop_id = await _crop_id(db_session)
    media = await _add_media(db_session, user_id)
    await db_session.commit()

    created = await client.post(
        "/api/v1/diagnostics",
        json={
            "media_ids": [str(media.id)],
            "crop_id": crop_id,
            "source": "on_device",
            "on_device_result": {"label_code": "healthy", "confidence": 0.9},
        },
        headers=headers,
    )
    assert created.status_code == 202, created.text
    diagnostic_id = uuid.UUID(created.json()["id"])

    rows = list(
        (
            await db_session.execute(
                select(DiagnosticPrediction).where(
                    DiagnosticPrediction.diagnostic_id == diagnostic_id
                )
            )
        )
        .scalars()
        .all()
    )
    assert len(rows) == 1
    assert rows[0].rank == 9
    assert rows[0].bbox == {"source": "on_device"}

    monkeypatch.setattr(settings, "DIAGNOSTIC_CONFIDENCE_THRESHOLD", 0.0)
    await _run_pipeline(diagnostic_id)

    detail = await client.get(
        f"/api/v1/diagnostics/{diagnostic_id}", headers=headers
    )
    assert detail.status_code == 200
    body = detail.json()
    assert body["on_device_prediction"]["label"]["code"] == "healthy"
    assert body["on_device_prediction"]["rank"] == 9
    assert [item["rank"] for item in body["predictions"]] == [1, 2, 3]
    stored = list(
        (
            await db_session.execute(
                select(DiagnosticPrediction)
                .where(DiagnosticPrediction.diagnostic_id == diagnostic_id)
                .execution_options(populate_existing=True)
            )
        )
        .scalars()
        .all()
    )
    assert len(stored) == 4
    assert len([row for row in stored if row.rank == 9]) == 1


async def test_list_filters_and_pagination(
    client: AsyncClient,
    db_session: AsyncSession,
) -> None:
    headers, user_id = await _register_verified(client, PHONE_OWNER)
    other_headers, other_id = await _register_verified(client, PHONE_OTHER)
    plot = await _create_plot(client, headers)
    plot_id = uuid.UUID(plot["id"])
    millet = await _crop_id(db_session, "millet")
    sorghum = await _crop_id(db_session, "sorghum")

    first = await _add_diagnostic(
        db_session,
        user_id,
        status="done",
        plot_id=plot_id,
        crop_id=millet,
        created_at=datetime(2026, 1, 10, 12, tzinfo=UTC),
    )
    second = await _add_diagnostic(
        db_session,
        user_id,
        status="needs_review",
        crop_id=sorghum,
        created_at=datetime(2026, 2, 10, 12, tzinfo=UTC),
    )
    third = await _add_diagnostic(
        db_session,
        user_id,
        status="done",
        plot_id=plot_id,
        crop_id=millet,
        created_at=datetime(2026, 3, 10, 12, tzinfo=UTC),
    )
    await _add_diagnostic(
        db_session,
        other_id,
        status="done",
        created_at=datetime(2026, 3, 11, 12, tzinfo=UTC),
    )

    listing = await client.get("/api/v1/diagnostics", headers=headers)
    assert listing.status_code == 200
    body = listing.json()
    assert [item["id"] for item in body["items"]] == [
        str(third.id),
        str(second.id),
        str(first.id),
    ]

    page_one = await client.get(
        "/api/v1/diagnostics?limit=2", headers=headers
    )
    page_one_body = page_one.json()
    assert len(page_one_body["items"]) == 2
    assert page_one_body["next_cursor"] is not None
    page_two = await client.get(
        "/api/v1/diagnostics?limit=2&cursor="
        f"{page_one_body['next_cursor']}",
        headers=headers,
    )
    assert [item["id"] for item in page_two.json()["items"]] == [str(first.id)]

    by_plot = await client.get(
        f"/api/v1/diagnostics?plot_id={plot_id}", headers=headers
    )
    assert [item["id"] for item in by_plot.json()["items"]] == [
        str(third.id),
        str(first.id),
    ]
    by_crop = await client.get(
        f"/api/v1/diagnostics?crop_id={millet}", headers=headers
    )
    assert [item["id"] for item in by_crop.json()["items"]] == [
        str(third.id),
        str(first.id),
    ]
    by_status = await client.get(
        "/api/v1/diagnostics?status=needs_review", headers=headers
    )
    assert [item["id"] for item in by_status.json()["items"]] == [str(second.id)]
    by_dates = await client.get(
        "/api/v1/diagnostics?from=2026-02-01&to=2026-03-31", headers=headers
    )
    assert [item["id"] for item in by_dates.json()["items"]] == [
        str(third.id),
        str(second.id),
    ]
    invalid_cursor = await client.get(
        "/api/v1/diagnostics?cursor=invalide", headers=headers
    )
    assert invalid_cursor.status_code == 422
