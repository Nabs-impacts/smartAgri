import asyncio
import hashlib
import uuid
from datetime import UTC, datetime
from decimal import Decimal

import pytest
from sqlalchemy import delete, func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import settings
from app.db.models.farming import Crop
from app.db.models.identity import User
from app.db.models.media_ai import (
    DiagnosisLabel,
    Diagnostic,
    DiagnosticMedia,
    DiagnosticPrediction,
    LabelCrop,
    MediaFile,
    Recommendation,
)
from app.db.session import SyncSessionLocal
from app.ml.inference import predict_stub
from app.ml.rules_engine import build_recommendation
from app.services import diagnostic_service
from app.services.diagnostic_service import compute_severity, run_pipeline
from app.workers import tasks_diagnostic
from app.workers.tasks_diagnostic import run_diagnostic

PHONE = "+22794000001"
TECHNICIAN_STEP = "Consultez un technicien agricole avant tout traitement."


def _run_pipeline_sync(diagnostic_id: uuid.UUID) -> None:
    with SyncSessionLocal() as session:
        run_pipeline(session, diagnostic_id)


async def _run(diagnostic_id: uuid.UUID) -> None:
    await asyncio.to_thread(_run_pipeline_sync, diagnostic_id)


def _run_task_final_attempt(diagnostic_id: uuid.UUID) -> None:
    run_diagnostic.push_request(retries=run_diagnostic.max_retries)
    try:
        run_diagnostic.run(str(diagnostic_id))
    finally:
        run_diagnostic.pop_request()


async def _run_task(diagnostic_id: uuid.UUID) -> None:
    await asyncio.to_thread(_run_task_final_attempt, diagnostic_id)


async def _create_user(session: AsyncSession, language: str = "fr") -> User:
    user = User(
        phone=PHONE,
        full_name="Test Diagnostic",
        language=language,
        phone_verified_at=datetime.now(UTC),
    )
    session.add(user)
    await session.flush()
    return user


async def _crop(session: AsyncSession, code: str = "millet") -> Crop:
    return (
        await session.execute(select(Crop).where(Crop.code == code))
    ).scalar_one()


async def _create_diagnostic(
    session: AsyncSession,
    user: User,
    crop: Crop,
    sha256: str,
    status: str = "pending",
) -> Diagnostic:
    media = MediaFile(
        owner_id=user.id,
        kind="image",
        storage_key=f"users/{user.id}/{uuid.uuid4()}.jpg",
        mime_type="image/jpeg",
        size_bytes=128,
        sha256=sha256,
        upload_status="uploaded",
    )
    session.add(media)
    await session.flush()
    diagnostic = Diagnostic(
        user_id=user.id,
        crop_id=crop.id,
        status=status,
    )
    session.add(diagnostic)
    await session.flush()
    session.add(
        DiagnosticMedia(
            diagnostic_id=diagnostic.id,
            media_id=media.id,
        )
    )
    await session.commit()
    return diagnostic


async def _predictions(
    session: AsyncSession,
    diagnostic_id: uuid.UUID,
) -> list[DiagnosticPrediction]:
    return list(
        (
            await session.execute(
                select(DiagnosticPrediction)
                .where(DiagnosticPrediction.diagnostic_id == diagnostic_id)
                .order_by(DiagnosticPrediction.rank)
                .execution_options(populate_existing=True)
            )
        )
        .scalars()
        .all()
    )


async def _diagnostic(
    session: AsyncSession,
    diagnostic_id: uuid.UUID,
) -> Diagnostic:
    return (
        await session.execute(
            select(Diagnostic)
            .where(Diagnostic.id == diagnostic_id)
            .execution_options(populate_existing=True)
        )
    ).scalar_one()


async def test_pipeline_is_deterministic_and_returns_top_three(
    db_session: AsyncSession,
) -> None:
    user = await _create_user(db_session)
    crop = await _crop(db_session)
    sha256 = hashlib.sha256(b"media-deterministe").hexdigest()
    first = await _create_diagnostic(db_session, user, crop, sha256)
    second = await _create_diagnostic(db_session, user, crop, sha256)

    await _run(first.id)
    await _run(second.id)

    first_predictions = await _predictions(db_session, first.id)
    second_predictions = await _predictions(db_session, second.id)
    first_result = [
        (row.label_id, float(row.confidence), row.rank)
        for row in first_predictions
    ]
    second_result = [
        (row.label_id, float(row.confidence), row.rank)
        for row in second_predictions
    ]
    assert first_result == second_result
    assert len(first_result) == 3
    assert [row[2] for row in first_result] == [1, 2, 3]
    confidences = [row[1] for row in first_result]
    assert confidences == sorted(confidences, reverse=True)
    assert sum(confidences) <= 1

    linked = set(
        (
            await db_session.execute(
                select(LabelCrop.label_id).where(LabelCrop.crop_id == crop.id)
            )
        ).scalars()
    )
    assert {row[0] for row in first_result} <= linked


async def test_only_labels_linked_to_crop_are_proposed(
    db_session: AsyncSession,
) -> None:
    user = await _create_user(db_session)
    crop = await _crop(db_session, "cabbage")
    healthy = (
        await db_session.execute(
            select(DiagnosisLabel).where(DiagnosisLabel.code == "healthy")
        )
    ).scalar_one()
    await db_session.execute(
        delete(LabelCrop).where(
            LabelCrop.crop_id == crop.id,
            LabelCrop.label_id != healthy.id,
        )
    )
    await db_session.commit()
    diagnostic = await _create_diagnostic(
        db_session,
        user,
        crop,
        hashlib.sha256(b"chou").hexdigest(),
    )

    await _run(diagnostic.id)

    predictions = await _predictions(db_session, diagnostic.id)
    assert len(predictions) == 1
    assert predictions[0].label_id == healthy.id
    refreshed = await _diagnostic(db_session, diagnostic.id)
    assert refreshed.severity is None


async def test_status_done_or_needs_review_depends_on_threshold(
    db_session: AsyncSession,
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    user = await _create_user(db_session)
    crop = await _crop(db_session)
    sha256 = hashlib.sha256(b"seuil").hexdigest()

    monkeypatch.setattr(settings, "DIAGNOSTIC_CONFIDENCE_THRESHOLD", 0.0)
    done = await _create_diagnostic(db_session, user, crop, sha256)
    await _run(done.id)
    done_refreshed = await _diagnostic(db_session, done.id)
    assert done_refreshed.status == "done"
    done_recommendation = (
        await db_session.execute(
            select(Recommendation).where(
                Recommendation.diagnostic_id == done.id
            )
        )
    ).scalar_one()
    assert done_recommendation.status == "published"

    monkeypatch.setattr(settings, "DIAGNOSTIC_CONFIDENCE_THRESHOLD", 0.999)
    review = await _create_diagnostic(db_session, user, crop, sha256)
    await _run(review.id)
    review_refreshed = await _diagnostic(db_session, review.id)
    assert review_refreshed.status == "needs_review"
    review_recommendation = (
        await db_session.execute(
            select(Recommendation).where(
                Recommendation.diagnostic_id == review.id
            )
        )
    ).scalar_one()
    assert review_recommendation.status == "draft"


def test_compute_severity_boundaries() -> None:
    assert compute_severity(0.85, "disease") == "high"
    assert compute_severity(0.849, "disease") == "medium"
    assert compute_severity(0.70, "disease") == "medium"
    assert compute_severity(0.699, "disease") == "low"
    assert compute_severity(0.99, "healthy") is None


def test_recommendation_without_validated_guideline_has_no_chemical_step() -> None:
    label = DiagnosisLabel(
        id=1,
        code="test_non_valide",
        kind="disease",
        name_fr="Mildiou test",
        name_ha="Kunkuma",
        name_dje=None,
        description="Maladie de test",
        guideline={
            "validated": False,
            "cultural": ["Retirer et brûler les plants malades."],
            "biological": [],
            "chemical": ["Appliquer un fongicide de synthèse."],
            "prevention": ["Utiliser des semences saines."],
        },
    )

    result = build_recommendation(label, "fr")

    categories = [step["category"] for step in result["steps"]]
    texts = [step["text"] for step in result["steps"]]
    assert "chemical" not in categories
    assert "Appliquer un fongicide de synthèse." not in texts
    assert result["steps"][-1]["text"] == TECHNICIAN_STEP
    assert "Retirer et brûler les plants malades." in texts
    assert "Utiliser des semences saines." in texts
    assert result["citations"] is None


def test_recommendation_with_validated_guideline_includes_chemical_step() -> None:
    label = DiagnosisLabel(
        id=2,
        code="test_valide",
        kind="pest",
        name_fr="Ravageur test",
        name_ha=None,
        name_dje=None,
        description=None,
        guideline={
            "validated": True,
            "cultural": ["Inspecter les plants."],
            "biological": ["Introduire des auxiliaires."],
            "chemical": ["Appliquer le produit homologué indiqué."],
            "prevention": ["Pratiquer la rotation des cultures."],
        },
    )

    result = build_recommendation(label, "fr")

    categories = {step["category"] for step in result["steps"]}
    texts = [step["text"] for step in result["steps"]]
    assert {"cultural", "biological", "chemical", "prevention"} <= categories
    assert "Appliquer le produit homologué indiqué." in texts


def test_healthy_label_recommendation_has_no_treatment_step() -> None:
    label = DiagnosisLabel(
        id=3,
        code="healthy_test",
        kind="healthy",
        name_fr="Sain",
        name_ha="Lafiyayye",
        name_dje=None,
        description=None,
        guideline=None,
    )

    result = build_recommendation(label, "ha")

    assert result["title"] == "Culture en bonne santé"
    assert result["steps"] == []


async def test_rerun_on_processed_diagnostic_changes_nothing(
    db_session: AsyncSession,
) -> None:
    user = await _create_user(db_session)
    crop = await _crop(db_session)
    diagnostic = await _create_diagnostic(
        db_session,
        user,
        crop,
        hashlib.sha256(b"relance").hexdigest(),
    )

    await _run(diagnostic.id)
    first = await _diagnostic(db_session, diagnostic.id)
    first_status = first.status
    first_confidence = float(first.confidence)
    first_completed_at = first.completed_at
    first_predictions = [
        (row.label_id, float(row.confidence), row.rank)
        for row in await _predictions(db_session, diagnostic.id)
    ]
    first_recommendation = (
        await db_session.execute(
            select(Recommendation).where(
                Recommendation.diagnostic_id == diagnostic.id
            )
        )
    ).scalar_one()
    first_recommendation_id = first_recommendation.id

    await _run(diagnostic.id)

    second = await _diagnostic(db_session, diagnostic.id)
    second_status = second.status
    second_confidence = float(second.confidence)
    second_completed_at = second.completed_at
    second_predictions = [
        (row.label_id, float(row.confidence), row.rank)
        for row in await _predictions(db_session, diagnostic.id)
    ]
    recommendations = list(
        (
            await db_session.execute(
                select(Recommendation).where(
                    Recommendation.diagnostic_id == diagnostic.id
                )
            )
        )
        .scalars()
        .all()
    )
    assert second_status == first_status
    assert second_confidence == first_confidence
    assert second_completed_at == first_completed_at
    assert second_predictions == first_predictions
    assert len(recommendations) == 1
    assert recommendations[0].id == first_recommendation_id


async def test_non_pending_diagnostic_is_ignored(
    db_session: AsyncSession,
) -> None:
    user = await _create_user(db_session)
    crop = await _crop(db_session)
    diagnostic = await _create_diagnostic(
        db_session,
        user,
        crop,
        hashlib.sha256(b"ignore").hexdigest(),
        status="done",
    )

    await _run(diagnostic.id)

    refreshed = await _diagnostic(db_session, diagnostic.id)
    assert refreshed.status == "done"
    assert refreshed.completed_at is None
    assert refreshed.error is None
    assert await _predictions(db_session, diagnostic.id) == []
    count = (
        await db_session.execute(
            select(func.count(Recommendation.id)).where(
                Recommendation.diagnostic_id == diagnostic.id
            )
        )
    ).scalar_one()
    assert count == 0


async def test_inference_failure_marks_diagnostic_failed_after_retries(
    db_session: AsyncSession,
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    user = await _create_user(db_session)
    crop = await _crop(db_session)
    diagnostic = await _create_diagnostic(
        db_session,
        user,
        crop,
        hashlib.sha256(b"echec").hexdigest(),
    )

    def _raise(*args, **kwargs):
        raise RuntimeError("Échec simulé de l'inférence.")

    class _Logger:
        def __init__(self) -> None:
            self.calls: list[tuple[str, dict]] = []

        def exception(self, event: str, **kwargs) -> None:
            self.calls.append((event, kwargs))

    logger = _Logger()
    monkeypatch.setattr(tasks_diagnostic, "logger", logger)
    monkeypatch.setattr(diagnostic_service, "predict_stub", _raise)
    await _run_task(diagnostic.id)

    refreshed = await _diagnostic(db_session, diagnostic.id)
    assert refreshed.status == "failed"
    assert refreshed.error == "Le diagnostic a échoué. Réessayez plus tard."
    assert "Échec simulé de l'inférence." not in refreshed.error
    assert len(logger.calls) == 1
    assert logger.calls[0][1]["diagnostic_id"] == str(diagnostic.id)


async def test_onnx_mode_marks_diagnostic_failed(
    db_session: AsyncSession,
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    user = await _create_user(db_session)
    crop = await _crop(db_session)
    diagnostic = await _create_diagnostic(
        db_session,
        user,
        crop,
        hashlib.sha256(b"onnx").hexdigest(),
    )
    monkeypatch.setattr(settings, "INFERENCE_MODE", "onnx")

    await _run_task(diagnostic.id)

    refreshed = await _diagnostic(db_session, diagnostic.id)
    assert refreshed.status == "failed"
    assert refreshed.error == "Mode d'inférence non disponible."


def test_predict_stub_returns_nothing_without_labels() -> None:
    assert predict_stub(["a" * 64], 1, []) == []


async def test_on_device_prediction_is_preserved_and_not_in_server_top_three(
    db_session: AsyncSession,
) -> None:
    user = await _create_user(db_session)
    crop = await _crop(db_session)
    diagnostic = await _create_diagnostic(
        db_session,
        user,
        crop,
        hashlib.sha256(b"embarque").hexdigest(),
    )
    label = (
        await db_session.execute(
            select(DiagnosisLabel)
            .join(LabelCrop, LabelCrop.label_id == DiagnosisLabel.id)
            .where(LabelCrop.crop_id == crop.id)
            .order_by(DiagnosisLabel.id)
            .limit(1)
        )
    ).scalar_one()
    db_session.add(
        DiagnosticPrediction(
            diagnostic_id=diagnostic.id,
            label_id=label.id,
            confidence=Decimal("0.900"),
            rank=9,
            bbox={"source": "on_device"},
        )
    )
    await db_session.commit()

    await _run(diagnostic.id)

    predictions = await _predictions(db_session, diagnostic.id)
    on_device = [row for row in predictions if row.rank == 9]
    server = [row for row in predictions if row.rank != 9]
    assert len(on_device) == 1
    assert on_device[0].bbox == {"source": "on_device"}
    assert [row.rank for row in server] == [1, 2, 3]
    assert all(row.bbox is None for row in server)
