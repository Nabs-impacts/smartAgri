import uuid
from datetime import datetime
from typing import Any

from geoalchemy2 import Geometry
from sqlalchemy import (
    Boolean,
    CheckConstraint,
    DateTime,
    ForeignKey,
    Index,
    Integer,
    String,
    UniqueConstraint,
    desc,
    text,
)
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db.base import Base, CreatedAtMixin, SoftDeleteMixin, TimestampMixin, UUIDPrimaryKeyMixin


class AdminArea(Base):
    __tablename__ = "admin_areas"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    parent_id: Mapped[int | None] = mapped_column(
        Integer, ForeignKey("admin_areas.id"), nullable=True
    )
    level: Mapped[str] = mapped_column(String, nullable=False)
    name: Mapped[str] = mapped_column(String, nullable=False)
    code: Mapped[str] = mapped_column(String, unique=True, nullable=False)
    geom: Mapped[Any | None] = mapped_column(
        Geometry(geometry_type="MULTIPOLYGON", srid=4326), nullable=True
    )

    parent: Mapped["AdminArea | None"] = relationship(
        "AdminArea", remote_side=[id], back_populates="children"
    )
    children: Mapped[list["AdminArea"]] = relationship(
        "AdminArea", back_populates="parent"
    )

    __table_args__ = (
        CheckConstraint(
            "level IN ('region', 'departement', 'commune')",
            name="chk_admin_areas_level",
        ),
        Index("ix_admin_areas_geom", "geom", postgresql_using="gist"),
    )


class User(Base, UUIDPrimaryKeyMixin, TimestampMixin, SoftDeleteMixin):
    __tablename__ = "users"

    phone: Mapped[str] = mapped_column(String, unique=True, nullable=False)
    email: Mapped[str | None] = mapped_column(String, unique=True, nullable=True)
    password_hash: Mapped[str | None] = mapped_column(String, nullable=True)
    full_name: Mapped[str] = mapped_column(String, nullable=False)
    role: Mapped[str] = mapped_column(
        String,
        server_default="farmer",
        default="farmer",
        nullable=False,
    )
    language: Mapped[str] = mapped_column(
        String,
        server_default="fr",
        default="fr",
        nullable=False,
    )
    admin_area_id: Mapped[int | None] = mapped_column(
        Integer, ForeignKey("admin_areas.id"), nullable=True
    )
    is_active: Mapped[bool] = mapped_column(
        Boolean, default=True, server_default=text("true"), nullable=False
    )
    phone_verified_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True), nullable=True
    )
    last_login_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True), nullable=True
    )

    admin_area: Mapped[AdminArea | None] = relationship("AdminArea")
    devices: Mapped[list["Device"]] = relationship(
        "Device", back_populates="user", cascade="all, delete-orphan"
    )
    refresh_tokens: Mapped[list["RefreshToken"]] = relationship(
        "RefreshToken", back_populates="user", cascade="all, delete-orphan"
    )
    consents: Mapped[list["Consent"]] = relationship(
        "Consent", back_populates="user", cascade="all, delete-orphan"
    )

    __table_args__ = (
        CheckConstraint(
            "role IN ('farmer', 'field_agent', 'agronomist', 'org_admin', "
            "'gov_admin', 'super_admin')",
            name="chk_users_role",
        ),
        CheckConstraint(
            "language IN ('fr', 'ha', 'dje', 'en')",
            name="chk_users_language",
        ),
    )


class OtpCode(Base, UUIDPrimaryKeyMixin, CreatedAtMixin):
    __tablename__ = "otp_codes"

    phone: Mapped[str] = mapped_column(String, nullable=False)
    code_hash: Mapped[str] = mapped_column(String, nullable=False)
    purpose: Mapped[str] = mapped_column(String, nullable=False)
    attempts: Mapped[int] = mapped_column(
        Integer, default=0, server_default=text("0"), nullable=False
    )
    expires_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), nullable=False
    )
    consumed_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True), nullable=True
    )

    __table_args__ = (
        CheckConstraint(
            "purpose IN ('login', 'verify_phone', 'reset_password')",
            name="chk_otp_codes_purpose",
        ),
        Index("ix_otp_codes_phone_created_at_desc", "phone", desc("created_at")),
    )


class Device(Base, UUIDPrimaryKeyMixin, CreatedAtMixin):
    __tablename__ = "devices"

    user_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("users.id", ondelete="CASCADE"),
        nullable=False,
    )
    platform: Mapped[str] = mapped_column(String, nullable=False)
    fcm_token: Mapped[str] = mapped_column(String, nullable=False)
    app_version: Mapped[str | None] = mapped_column(String, nullable=True)
    last_seen_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True), nullable=True
    )

    user: Mapped[User] = relationship("User", back_populates="devices")

    __table_args__ = (
        CheckConstraint(
            "platform IN ('android', 'ios')",
            name="chk_devices_platform",
        ),
        UniqueConstraint("user_id", "fcm_token", name="uq_devices_user_fcm"),
    )


class RefreshToken(Base, UUIDPrimaryKeyMixin, CreatedAtMixin):
    __tablename__ = "refresh_tokens"

    user_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("users.id", ondelete="CASCADE"),
        nullable=False,
    )
    device_id: Mapped[uuid.UUID | None] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("devices.id", ondelete="SET NULL"),
        nullable=True,
    )
    token_hash: Mapped[str] = mapped_column(String, unique=True, nullable=False)
    expires_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), nullable=False
    )
    revoked_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True), nullable=True
    )

    user: Mapped[User] = relationship("User", back_populates="refresh_tokens")
    device: Mapped[Device | None] = relationship("Device")


class Consent(Base, UUIDPrimaryKeyMixin, CreatedAtMixin):
    __tablename__ = "consents"

    user_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("users.id", ondelete="CASCADE"),
        nullable=False,
    )
    type: Mapped[str] = mapped_column(String, nullable=False)
    version: Mapped[str] = mapped_column(String, nullable=False)
    accepted: Mapped[bool] = mapped_column(Boolean, nullable=False)

    user: Mapped[User] = relationship("User", back_populates="consents")

    __table_args__ = (
        CheckConstraint(
            "type IN ('terms', 'privacy', 'data_sharing_gov', 'research')",
            name="chk_consents_type",
        ),
    )
