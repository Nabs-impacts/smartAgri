import re
import uuid
from datetime import UTC, datetime

from httpx import AsyncClient
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.db.models.farming import Crop
from app.db.models.media_ai import (
    Diagnostic,
    Recommendation,
    RecommendationFeedback,
)
from app.providers.sms.fake import FakeSmsProvider

PHONE_OWNER = "+22797000001"
PHONE_OTHER = "+22797000002"
OTP_PATTERN = re.compile(r"(\d{6})")


def _last_otp_code() -> str:
    message = FakeSmsProvider.sent_messages[-1]["message"]
    match = OTP_PATTERN.search(message)
    assert match is not None
    return match.group(1)


async def _register_verified(
    client: AsyncClient,
    phone: str,
) -> tuple[dict[str, str], uuid.UUID]:
    registered = await client.post(
        "/api/v1/auth/register",
        json={"phone": phone, "full_name": "Test Recommandation", "language": "fr"},
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


async def _add_diagnostic(
    session: AsyncSession,
    user_id: uuid.UUID,
    deleted: bool = False,
) -> Diagnostic:
    diagnostic = Diagnostic(
        user_id=user_id,
        status="done",
        deleted_at=datetime.now(UTC) if deleted else None,
    )
    session.add(diagnostic)
    await session.flush()
    return diagnostic


def _recommendation(
    user_id: uuid.UUID,
    title: str,
    status: str = "published",
    diagnostic_id: uuid.UUID | None = None,
    plot_id: uuid.UUID | None = None,
    crop_cycle_id: uuid.UUID | None = None,
    created_at: datetime | None = None,
) -> Recommendation:
    values = {
        "user_id": user_id,
        "diagnostic_id": diagnostic_id,
        "plot_id": plot_id,
        "crop_cycle_id": crop_cycle_id,
        "source": "rules",
        "language": "fr",
        "title": title,
        "body": "Corps de la recommandation",
        "status": status,
    }
    if created_at is not None:
        values["created_at"] = created_at
    return Recommendation(**values)


async def _crop_id(session: AsyncSession, code: str = "millet") -> int:
    crop = (await session.execute(select(Crop).where(Crop.code == code))).scalar_one()
    return crop.id


async def _create_plot_and_cycle(
    client: AsyncClient,
    headers: dict[str, str],
    session: AsyncSession,
) -> tuple[uuid.UUID, uuid.UUID]:
    farm = await client.post(
        "/api/v1/farms", json={"name": "Ferme Recommandation"}, headers=headers
    )
    assert farm.status_code == 201
    plot = await client.post(
        f"/api/v1/farms/{farm.json()['id']}/plots",
        json={"name": "Parcelle Recommandation", "area_ha": 1.0},
        headers=headers,
    )
    assert plot.status_code == 201
    cycle = await client.post(
        f"/api/v1/plots/{plot.json()['id']}/cycles",
        json={"crop_id": await _crop_id(session)},
        headers=headers,
    )
    assert cycle.status_code == 201
    return uuid.UUID(plot.json()["id"]), uuid.UUID(cycle.json()["id"])


async def test_draft_invisible_and_stranger_not_found(
    client: AsyncClient,
    db_session: AsyncSession,
) -> None:
    headers, user_id = await _register_verified(client, PHONE_OWNER)
    other_headers, _ = await _register_verified(client, PHONE_OTHER)
    diagnostic = await _add_diagnostic(db_session, user_id)
    published = _recommendation(
        user_id, "Publiée", diagnostic_id=diagnostic.id
    )
    draft = _recommendation(user_id, "Brouillon", status="draft")
    db_session.add_all([published, draft])
    await db_session.commit()

    listing = await client.get("/api/v1/recommendations", headers=headers)
    assert listing.status_code == 200
    assert [item["id"] for item in listing.json()["items"]] == [str(published.id)]

    draft_detail = await client.get(
        f"/api/v1/recommendations/{draft.id}", headers=headers
    )
    assert draft_detail.status_code == 404
    draft_feedback = await client.post(
        f"/api/v1/recommendations/{draft.id}/feedback",
        json={"helpful": True},
        headers=headers,
    )
    assert draft_feedback.status_code == 404

    own = await client.get(
        f"/api/v1/recommendations/{published.id}", headers=headers
    )
    assert own.status_code == 200
    assert own.json()["title"] == "Publiée"

    stranger = await client.get(
        f"/api/v1/recommendations/{published.id}", headers=other_headers
    )
    assert stranger.status_code == 404
    stranger_list = await client.get(
        "/api/v1/recommendations", headers=other_headers
    )
    assert stranger_list.json()["items"] == []


async def test_feedback_upsert_keeps_single_row(
    client: AsyncClient,
    db_session: AsyncSession,
) -> None:
    headers, user_id = await _register_verified(client, PHONE_OWNER)
    recommendation = _recommendation(user_id, "Feedback")
    db_session.add(recommendation)
    await db_session.commit()

    first = await client.post(
        f"/api/v1/recommendations/{recommendation.id}/feedback",
        json={"helpful": True, "applied": False, "comment": "Utile"},
        headers=headers,
    )
    assert first.status_code == 200, first.text
    second = await client.post(
        f"/api/v1/recommendations/{recommendation.id}/feedback",
        json={"helpful": False, "applied": None, "comment": None},
        headers=headers,
    )
    assert second.status_code == 200

    rows = list(
        (
            await db_session.execute(
                select(RecommendationFeedback).where(
                    RecommendationFeedback.recommendation_id == recommendation.id
                )
            )
        )
        .scalars()
        .all()
    )
    assert len(rows) == 1
    assert rows[0].helpful is False
    assert rows[0].applied is None
    assert rows[0].comment is None
    assert second.json()["helpful"] is False


async def test_filters_cursor_and_deleted_diagnostic(
    client: AsyncClient,
    db_session: AsyncSession,
) -> None:
    headers, user_id = await _register_verified(client, PHONE_OWNER)
    plot_id, cycle_id = await _create_plot_and_cycle(client, headers, db_session)
    other_plot_id, other_cycle_id = await _create_plot_and_cycle(
        client, headers, db_session
    )
    active = await _add_diagnostic(db_session, user_id)
    deleted = await _add_diagnostic(db_session, user_id, deleted=True)

    first = _recommendation(
        user_id,
        "Première",
        diagnostic_id=active.id,
        plot_id=plot_id,
        crop_cycle_id=cycle_id,
        created_at=datetime(2026, 4, 1, 12, tzinfo=UTC),
    )
    second = _recommendation(
        user_id,
        "Deuxième",
        plot_id=plot_id,
        crop_cycle_id=other_cycle_id,
        created_at=datetime(2026, 4, 2, 12, tzinfo=UTC),
    )
    third = _recommendation(
        user_id,
        "Troisième",
        plot_id=other_plot_id,
        created_at=datetime(2026, 4, 3, 12, tzinfo=UTC),
    )
    hidden = _recommendation(
        user_id,
        "Diagnostic supprimé",
        diagnostic_id=deleted.id,
        created_at=datetime(2026, 4, 4, 12, tzinfo=UTC),
    )
    db_session.add_all([first, second, third, hidden])
    await db_session.commit()

    listing = await client.get("/api/v1/recommendations", headers=headers)
    assert [item["id"] for item in listing.json()["items"]] == [
        str(third.id),
        str(second.id),
        str(first.id),
    ]

    page_one = await client.get(
        "/api/v1/recommendations?limit=2", headers=headers
    )
    page_one_body = page_one.json()
    assert [item["id"] for item in page_one_body["items"]] == [
        str(third.id),
        str(second.id),
    ]
    assert page_one_body["next_cursor"] is not None
    page_two = await client.get(
        f"/api/v1/recommendations?limit=2&cursor={page_one_body['next_cursor']}",
        headers=headers,
    )
    assert [item["id"] for item in page_two.json()["items"]] == [str(first.id)]

    by_plot = await client.get(
        f"/api/v1/recommendations?plot_id={plot_id}", headers=headers
    )
    assert [item["id"] for item in by_plot.json()["items"]] == [
        str(second.id),
        str(first.id),
    ]
    by_cycle = await client.get(
        f"/api/v1/recommendations?crop_cycle_id={other_cycle_id}",
        headers=headers,
    )
    assert [item["id"] for item in by_cycle.json()["items"]] == [str(second.id)]

    hidden_detail = await client.get(
        f"/api/v1/recommendations/{hidden.id}", headers=headers
    )
    assert hidden_detail.status_code == 404
