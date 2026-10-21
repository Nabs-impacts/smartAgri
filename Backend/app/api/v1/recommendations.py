import uuid

from fastapi import APIRouter, Depends, Query
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.deps import get_current_user
from app.core.pagination import PaginatedResponse, PaginationParams
from app.db.models.identity import User
from app.db.session import get_db
from app.schemas.recommendation import (
    RecommendationFeedbackRequest,
    RecommendationFeedbackResponse,
    RecommendationResponse,
)
from app.services.recommendation_api_service import recommendation_api_service

router = APIRouter()


@router.get("", response_model=PaginatedResponse[RecommendationResponse])
async def list_recommendations(
    pagination: PaginationParams = Depends(),
    plot_id: uuid.UUID | None = Query(default=None),
    crop_cycle_id: uuid.UUID | None = Query(default=None),
    session: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
) -> PaginatedResponse[RecommendationResponse]:
    items, next_cursor = await recommendation_api_service.list_recommendations(
        session=session,
        user_id=current_user.id,
        plot_id=plot_id,
        crop_cycle_id=crop_cycle_id,
        limit=pagination.limit,
        cursor=pagination.cursor,
    )
    return PaginatedResponse[RecommendationResponse](
        items=items, next_cursor=next_cursor
    )


@router.get("/{id}", response_model=RecommendationResponse)
async def get_recommendation(
    id: uuid.UUID,
    session: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
) -> RecommendationResponse:
    return await recommendation_api_service.get_recommendation(
        session=session,
        user_id=current_user.id,
        recommendation_id=id,
    )


@router.post("/{id}/feedback", response_model=RecommendationFeedbackResponse)
async def submit_feedback(
    id: uuid.UUID,
    data: RecommendationFeedbackRequest,
    session: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
) -> RecommendationFeedbackResponse:
    return await recommendation_api_service.submit_feedback(
        session=session,
        user=current_user,
        recommendation_id=id,
        data=data,
    )
