import uuid
from datetime import UTC, datetime

from sqlalchemy import delete, or_, select
from sqlalchemy.orm import Session

from app.core.config import settings
from app.db.models.identity import User
from app.db.models.media_ai import (
    DiagnosisLabel,
    Diagnostic,
    DiagnosticMedia,
    DiagnosticPrediction,
    LabelCrop,
    MediaFile,
)
from app.ml.inference import predict_stub
from app.services.recommendation_service import create_recommendation

_INFERENCE_UNAVAILABLE = "Mode d'inférence non disponible."
_NO_LABEL_ERROR = "Aucun label disponible pour cette culture."


def compute_severity(confidence: float, label_kind: str) -> str | None:
    if label_kind == "healthy":
        return None
    if confidence >= settings.DIAGNOSTIC_SEVERITY_HIGH_MIN:
        return "high"
    if confidence >= settings.DIAGNOSTIC_SEVERITY_MEDIUM_MIN:
        return "medium"
    return "low"


def _load_labels(session: Session, crop_id: int | None) -> list[DiagnosisLabel]:
    statement = select(DiagnosisLabel)
    if crop_id is not None:
        statement = statement.join(
            LabelCrop,
            LabelCrop.label_id == DiagnosisLabel.id,
        ).where(LabelCrop.crop_id == crop_id)
    statement = statement.order_by(DiagnosisLabel.id)
    return list(session.execute(statement).scalars().all())


def _load_sha256(session: Session, diagnostic_id: uuid.UUID) -> list[str]:
    statement = (
        select(MediaFile.sha256)
        .join(DiagnosticMedia, DiagnosticMedia.media_id == MediaFile.id)
        .where(DiagnosticMedia.diagnostic_id == diagnostic_id)
    )
    return list(session.execute(statement).scalars().all())


def run_pipeline(session: Session, diagnostic_id: uuid.UUID) -> None:
    diagnostic = (
        session.execute(
            select(Diagnostic)
            .where(
                Diagnostic.id == diagnostic_id,
                Diagnostic.deleted_at.is_(None),
            )
            .with_for_update(skip_locked=True)
        )
    ).scalar_one_or_none()
    if diagnostic is None or diagnostic.status != "pending":
        return

    diagnostic.status = "processing"
    session.flush()

    if settings.INFERENCE_MODE != "stub":
        diagnostic.status = "failed"
        diagnostic.error = _INFERENCE_UNAVAILABLE
        diagnostic.completed_at = datetime.now(UTC)
        session.commit()
        return

    labels = _load_labels(session, diagnostic.crop_id)
    sha256s = _load_sha256(session, diagnostic.id)
    predictions = predict_stub(
        sha256s,
        diagnostic.crop_id,
        [(label.id, label.code) for label in labels],
    )

    if not predictions:
        diagnostic.status = "failed"
        diagnostic.error = _NO_LABEL_ERROR
        diagnostic.completed_at = datetime.now(UTC)
        session.commit()
        return

    session.execute(
        delete(DiagnosticPrediction).where(
            DiagnosticPrediction.diagnostic_id == diagnostic.id,
            or_(
                DiagnosticPrediction.bbox.is_(None),
                DiagnosticPrediction.bbox["source"].astext.is_distinct_from(
                    "on_device"
                ),
            ),
        )
    )
    labels_by_id = {label.id: label for label in labels}
    for prediction in predictions:
        session.add(
            DiagnosticPrediction(
                diagnostic_id=diagnostic.id,
                label_id=prediction["label_id"],
                confidence=prediction["confidence"],
                rank=prediction["rank"],
            )
        )

    top_prediction = predictions[0]
    top_label = labels_by_id[top_prediction["label_id"]]
    confidence = top_prediction["confidence"]
    diagnostic.top_label_id = top_label.id
    diagnostic.confidence = confidence
    diagnostic.severity = compute_severity(confidence, top_label.kind)
    diagnostic.status = (
        "done"
        if confidence >= settings.DIAGNOSTIC_CONFIDENCE_THRESHOLD
        else "needs_review"
    )
    diagnostic.error = None
    diagnostic.model_id = None

    user = session.get(User, diagnostic.user_id)
    language = user.language if user is not None else "fr"
    create_recommendation(
        session=session,
        diagnostic=diagnostic,
        label=top_label,
        language=language,
        status="published" if diagnostic.status == "done" else "draft",
    )

    diagnostic.completed_at = datetime.now(UTC)
    session.commit()
