import uuid
from datetime import date, datetime
from decimal import Decimal
from typing import Any
from geoalchemy2 import Geography
from sqlalchemy import (
    BigInteger,
    Boolean,
    CheckConstraint,
    Date,
    DateTime,
    ForeignKey,
    Index,
    Integer,
    Numeric,
    String,
    Text,
    UniqueConstraint,
    desc,
    func,
    text,
)
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship
from app.db.base import Base, CreatedAtMixin, UUIDPrimaryKeyMixin
from app.db.models.farming import Crop, Plot
from app.db.models.identity import AdminArea, User
from app.db.models.media_ai import DiagnosisLabel, Diagnostic


class WeatherData(Base, CreatedAtMixin):
    __tablename__ = "weather_data"

    id: Mapped[int] = mapped_column(BigInteger, primary_key=True, autoincrement=True)
    admin_area_id: Mapped[int] = mapped_column(
        Integer, ForeignKey("admin_areas.id"), nullable=False
    )
    obs_date: Mapped[date] = mapped_column(Date, nullable=False)
    kind: Mapped[str] = mapped_column(String, nullable=False)
    temp_min_c: Mapped[Decimal | None] = mapped_column(
        Numeric(4, 1), nullable=True
    )
    temp_max_c: Mapped[Decimal | None] = mapped_column(
        Numeric(4, 1), nullable=True
    )
    rain_mm: Mapped[Decimal | None] = mapped_column(
        Numeric(6, 1), nullable=True
    )
    humidity_pct: Mapped[Decimal | None] = mapped_column(
        Numeric(4, 1), nullable=True
    )
    wind_kmh: Mapped[Decimal | None] = mapped_column(
        Numeric(5, 1), nullable=True
    )
    source: Mapped[str] = mapped_column(String, nullable=False)

    admin_area: Mapped[AdminArea] = relationship("AdminArea")

    __table_args__ = (
        CheckConstraint(
            "kind IN ('observed', 'forecast')",
            name="chk_weather_data_kind",
        ),
        UniqueConstraint(
            "admin_area_id",
            "obs_date",
            "kind",
            "source",
            name="uq_weather_data_area_date_kind_source",
        ),
    )


class SatelliteIndex(Base):
    __tablename__ = "satellite_indices"

    id: Mapped[int] = mapped_column(BigInteger, primary_key=True, autoincrement=True)
    plot_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("plots.id"), nullable=False
    )
    obs_date: Mapped[date] = mapped_column(Date, nullable=False)
    ndvi: Mapped[Decimal | None] = mapped_column(Numeric(5, 4), nullable=True)
    evi: Mapped[Decimal | None] = mapped_column(Numeric(5, 4), nullable=True)
    cloud_cover_pct: Mapped[Decimal | None] = mapped_column(
        Numeric(4, 1), nullable=True
    )
    source: Mapped[str] = mapped_column(
        String, server_default="sentinel-2", default="sentinel-2", nullable=False
    )

    plot: Mapped[Plot] = relationship("Plot")

    __table_args__ = (
        UniqueConstraint("plot_id", "obs_date", name="uq_satellite_indices_plot_date"),
    )


class Market(Base):
    __tablename__ = "markets"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    name: Mapped[str] = mapped_column(String, nullable=False)
    admin_area_id: Mapped[int | None] = mapped_column(
        Integer, ForeignKey("admin_areas.id"), nullable=True
    )
    location: Mapped[Any | None] = mapped_column(
        Geography(geometry_type="POINT", srid=4326), nullable=True
    )

    admin_area: Mapped[AdminArea | None] = relationship("AdminArea")


class MarketPrice(Base):
    __tablename__ = "market_prices"

    id: Mapped[int] = mapped_column(BigInteger, primary_key=True, autoincrement=True)
    market_id: Mapped[int] = mapped_column(
        Integer, ForeignKey("markets.id"), nullable=False
    )
    crop_id: Mapped[int] = mapped_column(
        Integer, ForeignKey("crops.id"), nullable=False
    )
    price_date: Mapped[date] = mapped_column(Date, nullable=False)
    price_xof_per_kg: Mapped[Decimal] = mapped_column(
        Numeric(10, 2), nullable=False
    )
    source: Mapped[str | None] = mapped_column(String, nullable=True)

    market: Mapped[Market] = relationship("Market")
    crop: Mapped[Crop] = relationship("Crop")

    __table_args__ = (
        UniqueConstraint(
            "market_id", "crop_id", "price_date", name="uq_market_prices_market_crop_date"
        ),
    )


class OutbreakReport(Base, UUIDPrimaryKeyMixin):
    __tablename__ = "outbreak_reports"

    diagnostic_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("diagnostics.id", ondelete="CASCADE"),
        unique=True,
        nullable=False,
    )
    label_id: Mapped[int] = mapped_column(
        Integer, ForeignKey("diagnosis_labels.id"), nullable=False
    )
    crop_id: Mapped[int | None] = mapped_column(
        Integer, ForeignKey("crops.id"), nullable=True
    )
    admin_area_id: Mapped[int | None] = mapped_column(
        Integer, ForeignKey("admin_areas.id"), nullable=True
    )
    location: Mapped[Any | None] = mapped_column(
        Geography(geometry_type="POINT", srid=4326), nullable=True
    )
    severity: Mapped[str | None] = mapped_column(String, nullable=True)
    verified: Mapped[bool] = mapped_column(
        Boolean, default=False, server_default=text("false"), nullable=False
    )
    reported_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        server_default=func.now(),
        nullable=False,
    )

    diagnostic: Mapped[Diagnostic] = relationship("Diagnostic")
    label: Mapped[DiagnosisLabel] = relationship("DiagnosisLabel")
    crop: Mapped[Crop | None] = relationship("Crop")
    admin_area: Mapped[AdminArea | None] = relationship("AdminArea")

    __table_args__ = (
        CheckConstraint(
            "severity IS NULL OR severity IN ('low', 'medium', 'high')",
            name="chk_outbreak_reports_severity",
        ),
        Index("ix_outbreak_reports_location", "location", postgresql_using="gist"),
        Index("ix_outbreak_reports_label_reported", "label_id", desc("reported_at")),
    )


class Alert(Base, UUIDPrimaryKeyMixin, CreatedAtMixin):
    __tablename__ = "alerts"

    type: Mapped[str] = mapped_column(String, nullable=False)
    severity: Mapped[str] = mapped_column(
        String,
        server_default="info",
        default="info",
        nullable=False,
    )
    title: Mapped[str] = mapped_column(String, nullable=False)
    body: Mapped[str] = mapped_column(Text, nullable=False)
    admin_area_id: Mapped[int | None] = mapped_column(
        Integer, ForeignKey("admin_areas.id"), nullable=True
    )
    crop_id: Mapped[int | None] = mapped_column(
        Integer, ForeignKey("crops.id"), nullable=True
    )
    starts_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        server_default=func.now(),
        nullable=False,
    )
    ends_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True), nullable=True
    )
    created_by: Mapped[uuid.UUID | None] = mapped_column(
        UUID(as_uuid=True), ForeignKey("users.id"), nullable=True
    )

    admin_area: Mapped[AdminArea | None] = relationship("AdminArea")
    crop: Mapped[Crop | None] = relationship("Crop")
    creator: Mapped[User | None] = relationship("User")

    __table_args__ = (
        CheckConstraint(
            "type IN ('weather', 'pest', 'disease', 'market', 'advisory', 'system')",
            name="chk_alerts_type",
        ),
        CheckConstraint(
            "severity IN ('info', 'warning', 'critical')",
            name="chk_alerts_severity",
        ),
    )


class Notification(Base, UUIDPrimaryKeyMixin, CreatedAtMixin):
    __tablename__ = "notifications"

    user_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("users.id", ondelete="CASCADE"),
        nullable=False,
    )
    alert_id: Mapped[uuid.UUID | None] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("alerts.id", ondelete="SET NULL"),
        nullable=True,
    )
    channel: Mapped[str] = mapped_column(String, nullable=False)
    title: Mapped[str] = mapped_column(String, nullable=False)
    body: Mapped[str] = mapped_column(Text, nullable=False)
    status: Mapped[str] = mapped_column(
        String,
        server_default="queued",
        default="queued",
        nullable=False,
    )
    sent_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True), nullable=True
    )
    read_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True), nullable=True
    )

    user: Mapped[User] = relationship("User")
    alert: Mapped[Alert | None] = relationship("Alert")

    __table_args__ = (
        CheckConstraint(
            "channel IN ('push', 'sms', 'whatsapp', 'in_app')",
            name="chk_notifications_channel",
        ),
        CheckConstraint(
            "status IN ('queued', 'sent', 'failed', 'read')",
            name="chk_notifications_status",
        ),
        Index("ix_notifications_user_created_at_desc", "user_id", desc("created_at")),
    )
