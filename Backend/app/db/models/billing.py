import uuid
from datetime import date, datetime
from typing import Any
from sqlalchemy import (
    BigInteger,
    Boolean,
    CheckConstraint,
    Date,
    DateTime,
    ForeignKey,
    Index,
    Integer,
    String,
    UniqueConstraint,
    desc,
    func,
    text,
)
from sqlalchemy.dialects.postgresql import JSONB, UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship
from app.db.base import Base, CreatedAtMixin, TimestampMixin, UUIDPrimaryKeyMixin
from app.db.models.identity import User
from app.db.models.organizations import Organization


class Plan(Base):
    __tablename__ = "plans"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    code: Mapped[str] = mapped_column(String, unique=True, nullable=False)
    name: Mapped[str] = mapped_column(String, nullable=False)
    audience: Mapped[str] = mapped_column(String, nullable=False)
    billing_model: Mapped[str] = mapped_column(String, nullable=False)
    interval: Mapped[str | None] = mapped_column(String, nullable=True)
    price_xof: Mapped[int] = mapped_column(
        Integer, default=0, server_default=text("0"), nullable=False
    )
    quotas: Mapped[dict[str, Any]] = mapped_column(
        JSONB, default=dict, server_default=text("'{}'::jsonb"), nullable=False
    )
    features: Mapped[dict[str, Any]] = mapped_column(
        JSONB, default=dict, server_default=text("'{}'::jsonb"), nullable=False
    )
    is_active: Mapped[bool] = mapped_column(
        Boolean, default=True, server_default=text("true"), nullable=False
    )

    __table_args__ = (
        CheckConstraint(
            "audience IN ('farmer', 'organization', 'government')",
            name="chk_plans_audience",
        ),
        CheckConstraint(
            "billing_model IN ('free', 'subscription', 'pay_per_use', 'license')",
            name="chk_plans_billing_model",
        ),
        CheckConstraint(
            "interval IS NULL OR interval IN ('month', 'quarter', 'year')",
            name="chk_plans_interval",
        ),
    )


class Subscription(Base, UUIDPrimaryKeyMixin, TimestampMixin):
    __tablename__ = "subscriptions"

    user_id: Mapped[uuid.UUID | None] = mapped_column(
        UUID(as_uuid=True), ForeignKey("users.id"), nullable=True
    )
    organization_id: Mapped[uuid.UUID | None] = mapped_column(
        UUID(as_uuid=True), ForeignKey("organizations.id"), nullable=True
    )
    plan_id: Mapped[int] = mapped_column(
        Integer, ForeignKey("plans.id"), nullable=False
    )
    status: Mapped[str] = mapped_column(String, nullable=False)
    current_period_start: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), nullable=False
    )
    current_period_end: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True), nullable=True
    )
    auto_renew: Mapped[bool] = mapped_column(
        Boolean, default=False, server_default=text("false"), nullable=False
    )
    canceled_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True), nullable=True
    )

    user: Mapped[User | None] = relationship("User")
    organization: Mapped[Organization | None] = relationship("Organization")
    plan: Mapped[Plan] = relationship("Plan")

    __table_args__ = (
        CheckConstraint(
            "status IN ('trialing', 'active', 'past_due', 'canceled', 'expired')",
            name="chk_subscriptions_status",
        ),
        CheckConstraint(
            "num_nonnulls(user_id, organization_id) = 1",
            name="chk_subscriptions_owner",
        ),
        Index("ix_subscriptions_user_status", "user_id", "status"),
        Index("ix_subscriptions_org_status", "organization_id", "status"),
    )


class Payment(Base, UUIDPrimaryKeyMixin, CreatedAtMixin):
    __tablename__ = "payments"

    user_id: Mapped[uuid.UUID | None] = mapped_column(
        UUID(as_uuid=True), ForeignKey("users.id"), nullable=True
    )
    organization_id: Mapped[uuid.UUID | None] = mapped_column(
        UUID(as_uuid=True), ForeignKey("organizations.id"), nullable=True
    )
    subscription_id: Mapped[uuid.UUID | None] = mapped_column(
        UUID(as_uuid=True), ForeignKey("subscriptions.id"), nullable=True
    )
    plan_id: Mapped[int | None] = mapped_column(
        Integer, ForeignKey("plans.id"), nullable=True
    )
    provider: Mapped[str] = mapped_column(String, nullable=False)
    provider_ref: Mapped[str | None] = mapped_column(String, nullable=True)
    idempotency_key: Mapped[str] = mapped_column(String, unique=True, nullable=False)
    purpose: Mapped[str] = mapped_column(String, nullable=False)
    amount_xof: Mapped[int] = mapped_column(Integer, nullable=False)
    currency: Mapped[str] = mapped_column(
        String, server_default="XOF", default="XOF", nullable=False
    )
    payer_phone: Mapped[str | None] = mapped_column(String, nullable=True)
    status: Mapped[str] = mapped_column(
        String,
        server_default="pending",
        default="pending",
        nullable=False,
    )
    raw: Mapped[dict[str, Any] | None] = mapped_column(JSONB, nullable=True)
    paid_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True), nullable=True
    )

    user: Mapped[User | None] = relationship("User")
    organization: Mapped[Organization | None] = relationship("Organization")
    subscription: Mapped[Subscription | None] = relationship("Subscription")
    plan: Mapped[Plan | None] = relationship("Plan")

    __table_args__ = (
        CheckConstraint(
            "provider IN ('orange_money', 'airtel_money', 'moov_money', 'mynita', 'aggregator', 'manual')",
            name="chk_payments_provider",
        ),
        CheckConstraint(
            "purpose IN ('subscription', 'top_up', 'license')",
            name="chk_payments_purpose",
        ),
        CheckConstraint(
            "amount_xof > 0",
            name="chk_payments_amount_xof_positive",
        ),
        CheckConstraint(
            "status IN ('pending', 'succeeded', 'failed', 'refunded')",
            name="chk_payments_status",
        ),
        UniqueConstraint("provider", "provider_ref", name="uq_payments_provider_provider_ref"),
        Index("ix_payments_user_created_at_desc", "user_id", desc("created_at")),
        Index("ix_payments_status_created_at", "status", "created_at"),
    )


class PaymentEvent(Base, CreatedAtMixin):
    __tablename__ = "payment_events"

    id: Mapped[int] = mapped_column(BigInteger, primary_key=True, autoincrement=True)
    provider: Mapped[str] = mapped_column(String, nullable=False)
    event_id: Mapped[str] = mapped_column(String, nullable=False)
    payload: Mapped[dict[str, Any]] = mapped_column(JSONB, nullable=False)
    signature_valid: Mapped[bool] = mapped_column(Boolean, nullable=False)
    processed_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True), nullable=True
    )

    __table_args__ = (
        UniqueConstraint("provider", "event_id", name="uq_payment_events_provider_event"),
    )


class UsageRecord(Base, CreatedAtMixin):
    __tablename__ = "usage_records"

    id: Mapped[int] = mapped_column(BigInteger, primary_key=True, autoincrement=True)
    subscription_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("subscriptions.id", ondelete="CASCADE"),
        nullable=False,
    )
    metric: Mapped[str] = mapped_column(String, nullable=False)
    quantity: Mapped[int] = mapped_column(
        Integer, default=1, server_default=text("1"), nullable=False
    )
    period: Mapped[date] = mapped_column(Date, nullable=False)

    subscription: Mapped[Subscription] = relationship("Subscription")

    __table_args__ = (
        CheckConstraint(
            "metric IN ('diagnostic', 'llm_message', 'video_analysis', 'storage_mb')",
            name="chk_usage_records_metric",
        ),
        Index("ix_usage_records_sub_metric_period", "subscription_id", "metric", "period"),
    )


class LicenseKey(Base, UUIDPrimaryKeyMixin, CreatedAtMixin):
    __tablename__ = "license_keys"

    organization_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("organizations.id"), nullable=False
    )
    plan_id: Mapped[int] = mapped_column(
        Integer, ForeignKey("plans.id"), nullable=False
    )
    key_hash: Mapped[str] = mapped_column(String, unique=True, nullable=False)
    max_activations: Mapped[int] = mapped_column(
        Integer, default=1, server_default=text("1"), nullable=False
    )
    expires_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True), nullable=True
    )
    status: Mapped[str] = mapped_column(
        String,
        server_default="active",
        default="active",
        nullable=False,
    )

    organization: Mapped[Organization] = relationship("Organization")
    plan: Mapped[Plan] = relationship("Plan")
    activations: Mapped[list["LicenseActivation"]] = relationship(
        "LicenseActivation", back_populates="license", cascade="all, delete-orphan"
    )

    __table_args__ = (
        CheckConstraint(
            "status IN ('active', 'revoked', 'expired')",
            name="chk_license_keys_status",
        ),
    )


class LicenseActivation(Base, UUIDPrimaryKeyMixin):
    __tablename__ = "license_activations"

    license_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("license_keys.id", ondelete="CASCADE"),
        nullable=False,
    )
    device_fingerprint: Mapped[str] = mapped_column(String, nullable=False)
    activated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        server_default=func.now(),
        nullable=False,
    )
    revoked_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True), nullable=True
    )

    license: Mapped[LicenseKey] = relationship(
        "LicenseKey", back_populates="activations"
    )

    __table_args__ = (
        UniqueConstraint(
            "license_id", "device_fingerprint", name="uq_license_activations_license_device"
        ),
    )
