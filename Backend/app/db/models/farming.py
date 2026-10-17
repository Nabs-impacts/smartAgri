import uuid
from datetime import date
from decimal import Decimal
from typing import Any

from geoalchemy2 import Geography, Geometry
from sqlalchemy import (
    CheckConstraint,
    Date,
    ForeignKey,
    Index,
    Integer,
    Numeric,
    String,
    Text,
    text,
)
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db.base import Base, SoftDeleteMixin, TimestampMixin, UUIDPrimaryKeyMixin
from app.db.models.identity import AdminArea, User
from app.db.models.organizations import Organization


class Farm(Base, UUIDPrimaryKeyMixin, TimestampMixin, SoftDeleteMixin):
    __tablename__ = "farms"

    owner_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("users.id"), nullable=False
    )
    organization_id: Mapped[uuid.UUID | None] = mapped_column(
        UUID(as_uuid=True), ForeignKey("organizations.id"), nullable=True
    )
    name: Mapped[str] = mapped_column(String, nullable=False)
    village: Mapped[str | None] = mapped_column(String, nullable=True)
    admin_area_id: Mapped[int | None] = mapped_column(
        Integer, ForeignKey("admin_areas.id"), nullable=True
    )
    location: Mapped[Any | None] = mapped_column(
        Geography(geometry_type="POINT", srid=4326), nullable=True
    )

    owner: Mapped[User] = relationship("User")
    organization: Mapped[Organization | None] = relationship("Organization")
    admin_area: Mapped[AdminArea | None] = relationship("AdminArea")
    plots: Mapped[list["Plot"]] = relationship(
        "Plot", back_populates="farm", cascade="all, delete-orphan"
    )

    __table_args__ = (Index("ix_farms_owner_id", "owner_id"),)


class Plot(Base, UUIDPrimaryKeyMixin, TimestampMixin, SoftDeleteMixin):
    __tablename__ = "plots"

    farm_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("farms.id"), nullable=False
    )
    name: Mapped[str] = mapped_column(String, nullable=False)
    area_ha: Mapped[Decimal | None] = mapped_column(
        Numeric(10, 3), nullable=True
    )
    geom: Mapped[Any | None] = mapped_column(
        Geometry(geometry_type="POLYGON", srid=4326), nullable=True
    )
    soil_type: Mapped[str | None] = mapped_column(String, nullable=True)
    irrigation: Mapped[str | None] = mapped_column(String, nullable=True)

    farm: Mapped[Farm] = relationship("Farm", back_populates="plots")
    crop_cycles: Mapped[list["CropCycle"]] = relationship(
        "CropCycle", back_populates="plot", cascade="all, delete-orphan"
    )

    __table_args__ = (
        CheckConstraint(
            "soil_type IS NULL OR soil_type IN ('sandy', 'loam', 'clay', 'laterite', 'other')",
            name="chk_plots_soil_type",
        ),
        CheckConstraint(
            "irrigation IS NULL OR irrigation IN ('rainfed', 'drip', 'gravity', 'well', 'other')",
            name="chk_plots_irrigation",
        ),
        Index("ix_plots_farm_id", "farm_id"),
    )


class Crop(Base):
    __tablename__ = "crops"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    code: Mapped[str] = mapped_column(String, unique=True, nullable=False)
    name_fr: Mapped[str] = mapped_column(String, nullable=False)
    name_ha: Mapped[str | None] = mapped_column(String, nullable=True)
    name_dje: Mapped[str | None] = mapped_column(String, nullable=True)
    category: Mapped[str] = mapped_column(String, nullable=False)
    cycle_days: Mapped[int | None] = mapped_column(Integer, nullable=True)

    __table_args__ = (
        CheckConstraint(
            "category IN ('cereal', 'legume', 'vegetable', 'fruit', 'tuber', 'cash_crop', 'other')",
            name="chk_crops_category",
        ),
    )


class CropCycle(Base, UUIDPrimaryKeyMixin, TimestampMixin, SoftDeleteMixin):
    __tablename__ = "crop_cycles"

    plot_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("plots.id"), nullable=False
    )
    crop_id: Mapped[int] = mapped_column(
        Integer, ForeignKey("crops.id"), nullable=False
    )
    variety: Mapped[str | None] = mapped_column(String, nullable=True)
    season: Mapped[str | None] = mapped_column(String, nullable=True)
    sowing_date: Mapped[date | None] = mapped_column(Date, nullable=True)
    expected_harvest_date: Mapped[date | None] = mapped_column(Date, nullable=True)
    harvest_date: Mapped[date | None] = mapped_column(Date, nullable=True)
    status: Mapped[str] = mapped_column(
        String,
        server_default="planned",
        default="planned",
        nullable=False,
    )
    notes: Mapped[str | None] = mapped_column(Text, nullable=True)

    plot: Mapped[Plot] = relationship("Plot", back_populates="crop_cycles")
    crop: Mapped[Crop] = relationship("Crop")
    activities: Mapped[list["FarmActivity"]] = relationship(
        "FarmActivity", back_populates="crop_cycle", cascade="all, delete-orphan"
    )
    harvests: Mapped[list["Harvest"]] = relationship(
        "Harvest", back_populates="crop_cycle", cascade="all, delete-orphan"
    )

    __table_args__ = (
        CheckConstraint(
            "status IN ('planned', 'growing', 'harvested', 'failed')",
            name="chk_crop_cycles_status",
        ),
        Index("ix_crop_cycles_plot_status", "plot_id", "status"),
    )


class FarmActivity(Base, UUIDPrimaryKeyMixin, TimestampMixin, SoftDeleteMixin):
    __tablename__ = "farm_activities"

    crop_cycle_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("crop_cycles.id"), nullable=False
    )
    type: Mapped[str] = mapped_column(String, nullable=False)
    performed_on: Mapped[date] = mapped_column(Date, nullable=False)
    product_name: Mapped[str | None] = mapped_column(String, nullable=True)
    quantity: Mapped[Decimal | None] = mapped_column(
        Numeric(12, 2), nullable=True
    )
    unit: Mapped[str | None] = mapped_column(String, nullable=True)
    cost_xof: Mapped[int | None] = mapped_column(Integer, nullable=True)
    notes: Mapped[str | None] = mapped_column(Text, nullable=True)

    crop_cycle: Mapped[CropCycle] = relationship(
        "CropCycle", back_populates="activities"
    )

    __table_args__ = (
        CheckConstraint(
            "type IN ('sowing', 'fertilizing', 'irrigation', 'weeding', "
            "'pesticide', 'harvest', 'other')",
            name="chk_farm_activities_type",
        ),
        Index("ix_farm_activities_cycle_date", "crop_cycle_id", "performed_on"),
    )


class Harvest(Base, UUIDPrimaryKeyMixin, TimestampMixin, SoftDeleteMixin):
    __tablename__ = "harvests"

    crop_cycle_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("crop_cycles.id"), nullable=False
    )
    harvested_on: Mapped[date] = mapped_column(Date, nullable=False)
    quantity_kg: Mapped[Decimal] = mapped_column(Numeric(12, 2), nullable=False)
    quality: Mapped[str | None] = mapped_column(String, nullable=True)
    sold_kg: Mapped[Decimal] = mapped_column(
        Numeric(12, 2), default=Decimal("0"), server_default=text("0"), nullable=False
    )
    avg_price_xof_per_kg: Mapped[Decimal | None] = mapped_column(
        Numeric(10, 2), nullable=True
    )

    crop_cycle: Mapped[CropCycle] = relationship(
        "CropCycle", back_populates="harvests"
    )

    __table_args__ = (
        CheckConstraint(
            "quality IS NULL OR quality IN ('A', 'B', 'C')",
            name="chk_harvests_quality",
        ),
        Index("ix_harvests_crop_cycle_id", "crop_cycle_id"),
    )
