import uuid
from datetime import datetime
from sqlalchemy import (
    Boolean,
    CheckConstraint,
    DateTime,
    ForeignKey,
    Integer,
    String,
    func,
    text,
)
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship
from app.db.base import Base, TimestampMixin, UUIDPrimaryKeyMixin
from app.db.models.identity import AdminArea, User


class Organization(Base, UUIDPrimaryKeyMixin, TimestampMixin):
    __tablename__ = "organizations"

    name: Mapped[str] = mapped_column(String, nullable=False)
    type: Mapped[str] = mapped_column(String, nullable=False)
    registration_no: Mapped[str | None] = mapped_column(String, nullable=True)
    admin_area_id: Mapped[int | None] = mapped_column(
        Integer, ForeignKey("admin_areas.id"), nullable=True
    )
    contact_phone: Mapped[str | None] = mapped_column(String, nullable=True)
    contact_email: Mapped[str | None] = mapped_column(String, nullable=True)
    is_active: Mapped[bool] = mapped_column(
        Boolean, default=True, server_default=text("true"), nullable=False
    )

    admin_area: Mapped[AdminArea | None] = relationship("AdminArea")
    members: Mapped[list["OrganizationMember"]] = relationship(
        "OrganizationMember", back_populates="organization", cascade="all, delete-orphan"
    )

    __table_args__ = (
        CheckConstraint(
            "type IN ('cooperative', 'ngo', 'agri_company', 'bank', 'insurer', 'government', 'other')",
            name="chk_organizations_type",
        ),
    )


class OrganizationMember(Base):
    __tablename__ = "organization_members"

    organization_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("organizations.id", ondelete="CASCADE"),
        primary_key=True,
    )
    user_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("users.id", ondelete="CASCADE"),
        primary_key=True,
    )
    member_role: Mapped[str] = mapped_column(
        String,
        server_default="member",
        default="member",
        nullable=False,
    )
    joined_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        server_default=func.now(),
        nullable=False,
    )

    organization: Mapped[Organization] = relationship(
        "Organization", back_populates="members"
    )
    user: Mapped[User] = relationship("User")

    __table_args__ = (
        CheckConstraint(
            "member_role IN ('owner', 'admin', 'agent', 'member')",
            name="chk_organization_members_role",
        ),
    )
