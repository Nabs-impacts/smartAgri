from celery import Celery

from app.core.config import settings

celery = Celery(
    "smartagri",
    broker=settings.CELERY_BROKER_URL,
    backend=settings.CELERY_RESULT_BACKEND,
)

celery.autodiscover_tasks(["app.workers"], related_name="tasks_media", force=True)
