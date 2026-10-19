from fastapi import APIRouter, Depends, Query
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.deps import get_current_user
from app.db.models.identity import User
from app.db.session import get_db
from app.schemas.sync import (
    SyncPullResponse,
    SyncPushRequest,
    SyncPushResponse,
)
from app.services.sync_service import sync_service

router = APIRouter()


@router.post("/push", response_model=SyncPushResponse)
async def push_changes(
    data: SyncPushRequest,
    session: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
) -> SyncPushResponse:
    return await sync_service.push(session, current_user, data.changes)


@router.get("/pull", response_model=SyncPullResponse)
async def pull_changes(
    since: str | None = Query(default=None),
    limit: int = Query(default=200, ge=1, le=200),
    session: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
) -> SyncPullResponse:
    return await sync_service.pull(
        session,
        current_user.id,
        since=since,
        limit=limit,
    )
