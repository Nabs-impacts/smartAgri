import asyncio
import uuid
from datetime import UTC, datetime

from sqlalchemy import select

from app.db.models.media_ai import MediaFile
from app.db.session import SyncSessionLocal
from app.services.storage_service import storage_service
from app.workers.celery_app import celery


async def _delete_objects(keys: list[str]) -> None:
    for key in keys:
        await storage_service.delete(key)


@celery.task(
    name="tasks_media.purge_user_media",
    autoretry_for=(Exception,),
    retry_backoff=True,
    retry_backoff_max=600,
    max_retries=5,
)
def purge_user_media(user_id: str) -> int:
    owner_id = uuid.UUID(user_id)
    with SyncSessionLocal() as session:
        media_files = list(
            session.execute(
                select(MediaFile).where(MediaFile.owner_id == owner_id)
            )
            .scalars()
            .all()
        )
        asyncio.run(_delete_objects([media.storage_key for media in media_files]))
        now = datetime.now(UTC)
        for media in media_files:
            media.location = None
            if media.deleted_at is None:
                media.deleted_at = now
        session.commit()
        return len(media_files)
