import uuid
from datetime import datetime

from sqlalchemy import and_, or_, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.errors import NotFoundException, ValidationException
from app.core.pagination import decode_cursor, encode_cursor
from app.db.models.identity import User
from app.db.models.media_ai import (
    Diagnostic,
    Recommendation,
    RecommendationFeedback,
)
from app.schemas.recommendation import (
    RecommendationFeedbackRequest,
    RecommendationFeedbackResponse,
    RecommendationResponse,
)


def _recommendation_to_response(
    recommendation: Recommendation,
) -> RecommendationResponse:
    return RecommendationResponse(
        id=recommendation.id,
        diagnostic_id=recommendation.diagnostic_id,
        plot_id=recommendation.plot_id,
        crop_cycle_id=recommendation.crop_cycle_id,
        source=recommendation.source,
        language=recommendation.language,
        title=recommendation.title,
        body=recommendation.body,
        steps=recommendation.steps,
        citations=recommendation.citations,
        status=recommendation.status,
        validated_by=recommendation.validated_by,
        created_at=recommendation.created_at,
    )


def _feedback_to_response(
    feedback: RecommendationFeedback,
) -> RecommendationFeedbackResponse:
    return RecommendationFeedbackResponse(
        recommendation_id=feedback.recommendation_id,
        user_id=feedback.user_id,
        helpful=feedback.helpful,
        applied=feedback.applied,
        comment=feedback.comment,
        created_at=feedback.created_at,
    )


def _parse_uuid_cursor(cursor: str) -> tuple[datetime, uuid.UUID]:
    cursor_dt, cursor_id = decode_cursor(cursor)
    try:
        cursor_uuid = uuid.UUID(cursor_id)
    except (ValueError, TypeError) as err:
        raise ValidationException("Curseur de pagination invalide.") from err
    return cursor_dt, cursor_uuid


class RecommendationApiService:
    def _published_filter(self):
        return and_(
            Recommendation.status == "published",
            or_(
                Recommendation.diagnostic_id.is_(None),
                Diagnostic.deleted_at.is_(None),
            ),
        )

    async def list_recommendations(
        self,
        session: AsyncSession,
        user_id: uuid.UUID,
        plot_id: uuid.UUID | None = None,
        crop_cycle_id: uuid.UUID | None = None,
        limit: int = 20,
        cursor: str | None = None,
    ) -> tuple[list[RecommendationResponse], str | None]:
        stmt = (
            select(Recommendation)
            .outerjoin(
                Diagnostic,
                Recommendation.diagnostic_id == Diagnostic.id,
            )
            .where(
                Recommendation.user_id == user_id,
                self._published_filter(),
            )
        )
        if plot_id is not None:
            stmt = stmt.where(Recommendation.plot_id == plot_id)
        if crop_cycle_id is not None:
            stmt = stmt.where(Recommendation.crop_cycle_id == crop_cycle_id)

        if cursor:
            cursor_dt, cursor_uuid = _parse_uuid_cursor(cursor)
            stmt = stmt.where(
                or_(
                    Recommendation.created_at < cursor_dt,
                    and_(
                        Recommendation.created_at == cursor_dt,
                        Recommendation.id < cursor_uuid,
                    ),
                )
            )

        stmt = stmt.order_by(
            Recommendation.created_at.desc(), Recommendation.id.desc()
        ).limit(limit + 1)
        rows = list((await session.scalars(stmt)).all())
        if len(rows) > limit:
            items = rows[:limit]
            next_cursor = encode_cursor(items[-1].created_at, items[-1].id)
        else:
            items = rows
            next_cursor = None
        return [
            _recommendation_to_response(recommendation) for recommendation in items
        ], next_cursor

    async def _load_published_owned(
        self,
        session: AsyncSession,
        user_id: uuid.UUID,
        recommendation_id: uuid.UUID,
    ) -> Recommendation:
        recommendation = (
            await session.execute(
                select(Recommendation)
                .outerjoin(
                    Diagnostic,
                    Recommendation.diagnostic_id == Diagnostic.id,
                )
                .where(
                    Recommendation.id == recommendation_id,
                    Recommendation.user_id == user_id,
                    self._published_filter(),
                )
            )
        ).scalar_one_or_none()
        if recommendation is None:
            raise NotFoundException("Recommandation introuvable.")
        return recommendation

    async def get_recommendation(
        self,
        session: AsyncSession,
        user_id: uuid.UUID,
        recommendation_id: uuid.UUID,
    ) -> RecommendationResponse:
        recommendation = await self._load_published_owned(
            session, user_id, recommendation_id
        )
        return _recommendation_to_response(recommendation)

    async def submit_feedback(
        self,
        session: AsyncSession,
        user: User,
        recommendation_id: uuid.UUID,
        data: RecommendationFeedbackRequest,
    ) -> RecommendationFeedbackResponse:
        recommendation = await self._load_published_owned(
            session, user.id, recommendation_id
        )
        feedback = (
            await session.execute(
                select(RecommendationFeedback).where(
                    RecommendationFeedback.recommendation_id == recommendation.id,
                    RecommendationFeedback.user_id == user.id,
                )
            )
        ).scalar_one_or_none()
        if feedback is None:
            feedback = RecommendationFeedback(
                recommendation_id=recommendation.id,
                user_id=user.id,
                helpful=data.helpful,
                applied=data.applied,
                comment=data.comment,
            )
            session.add(feedback)
        else:
            feedback.helpful = data.helpful
            feedback.applied = data.applied
            feedback.comment = data.comment
        await session.commit()
        await session.refresh(feedback)
        return _feedback_to_response(feedback)


recommendation_api_service = RecommendationApiService()
