import uuid
from typing import Any

from sqlalchemy.ext.asyncio import AsyncSession

from app.db.models.audit import AuditLog


class AuditService:
    def record(
        self,
        session: AsyncSession,
        action: str,
        user_id: uuid.UUID | None = None,
        entity: str | None = None,
        entity_id: str | None = None,
        ip: str | None = None,
        meta: dict[str, Any] | None = None,
    ) -> AuditLog:
        entry = AuditLog(
            user_id=user_id,
            action=action,
            entity=entity,
            entity_id=entity_id,
            ip=ip,
            meta=meta,
        )
        session.add(entry)
        return entry


audit_service = AuditService()
