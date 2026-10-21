from sqlalchemy import select
from sqlalchemy.orm import Session

from app.db.models.media_ai import (
    DiagnosisLabel,
    Diagnostic,
    Recommendation,
)
from app.ml.rules_engine import build_recommendation


def create_recommendation(
    session: Session,
    diagnostic: Diagnostic,
    label: DiagnosisLabel,
    language: str,
    status: str,
) -> Recommendation:
    existing = (
        session.execute(
            select(Recommendation).where(
                Recommendation.diagnostic_id == diagnostic.id
            )
        )
    ).scalar_one_or_none()
    if existing is not None:
        return existing

    content = build_recommendation(label, language)
    recommendation = Recommendation(
        user_id=diagnostic.user_id,
        diagnostic_id=diagnostic.id,
        plot_id=diagnostic.plot_id,
        crop_cycle_id=diagnostic.crop_cycle_id,
        source="rules",
        language=language,
        title=content["title"],
        body=content["body"],
        steps=content["steps"],
        citations=content["citations"],
        model_id=None,
        status=status,
    )
    session.add(recommendation)
    session.flush()
    return recommendation
