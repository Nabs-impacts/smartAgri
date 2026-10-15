import uuid
from datetime import datetime
from typing import Any
from sqlalchemy import (
    BigInteger,
    DateTime,
    ForeignKey,
    Index,
    String,
    desc,
    text,
)
from sqlalchemy.dialects.postgresql import ARRAY, INET, JSONB, UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship
from app.db.base import Base, CreatedAtMixin, UUIDPrimaryKeyMixin
from app.db.models.identity import User
from app.db.models.organizations import Organization


class AuditLog(Base, CreatedAtMixin):
    __tablename__ = "audit_logs"

    id: Mapped[int] = mapped_column(BigInteger, primary_key=True, autoincrement=True)
    user_id: Mapped[uuid.UUID | None] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("users.id", ondelete="SET NULL"),
        nullable=True,
    )
    action: Mapped[str] = mapped_column(String, nullable=False)
    entity: Mapped[str | None] = mapped_column(String, nullable=True)
    entity_id: Mapped[str | None] = mapped_column(String, nullable=True)
    ip: Mapped[str | None] = mapped_column(INET, nullable=True)
    meta: Mapped[dict[str, Any] | None] = mapped_column(JSONB, nullable=True)

    user: Mapped[User | None] = relationship("User")

    __table_args__ = (
        Index("ix_audit_logs_user_created_at_desc", "user_id", desc("created_at")),
        Index("ix_audit_logs_entity_entity_id", "entity", "entity_id"),
    )


class ApiKey(Base, UUIDPrimaryKeyMixin, CreatedAtMixin):
    __tablename__ = "api_keys"

    organization_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("organizations.id", ondelete="CASCADE"),
        nullable=False,
    )
    name: Mapped[str] = mapped_column(String, nullable=False)
    key_hash: Mapped[str] = mapped_column(String, unique=True, nullable=False)
    scopes: Mapped[list[str]] = mapped_column(
        ARRAY(String),
        server_default=text("'{}'"),
        default=list,
        nullable=False,
    )
    last_used_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True), nullable=True
    )
    revoked_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True), nullable=True
    )

    organization: Mapped[Organization] = relationship("Organization")
