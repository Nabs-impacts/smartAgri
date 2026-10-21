import uuid
from datetime import UTC, datetime

from celery import Task

from app.core.logging import get_logger
from app.db.models.media_ai import Diagnostic
from app.db.session import SyncSessionLocal
from app.services.diagnostic_service import run_pipeline
from app.workers.celery_app import celery

logger = get_logger("tasks_diagnostic")

_FAILED_MESSAGE = "Le diagnostic a échoué. Réessayez plus tard."


def _mark_failed(diagnostic_id: str, message: str) -> None:
    with SyncSessionLocal() as session:
        diagnostic = session.get(Diagnostic, uuid.UUID(diagnostic_id))
        if diagnostic is None:
            return
        if diagnostic.status in ("done", "needs_review"):
            return
        diagnostic.status = "failed"
        diagnostic.error = message
        diagnostic.completed_at = datetime.now(UTC)
        session.commit()


@celery.task(
    bind=True,
    name="tasks_diagnostic.run_diagnostic",
    max_retries=3,
)
def run_diagnostic(self: Task, diagnostic_id: str) -> None:
    try:
        with SyncSessionLocal() as session:
            run_pipeline(session, uuid.UUID(diagnostic_id))
    except Exception as exc:
        if self.request.retries >= self.max_retries:
            logger.exception(
                "diagnostic_run_failed",
                diagnostic_id=diagnostic_id,
            )
            _mark_failed(diagnostic_id, _FAILED_MESSAGE)
            return
        raise self.retry(
            exc=exc,
            countdown=2 ** (self.request.retries + 1),
        ) from exc
