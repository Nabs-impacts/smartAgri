import uuid
from datetime import datetime
from decimal import Decimal
from typing import Any

from geoalchemy2 import Geography
from sqlalchemy import (
    BigInteger,
    Boolean,
    CheckConstraint,
    DateTime,
    ForeignKey,
    Index,
    Integer,
    Numeric,
    SmallInteger,
    String,
    Text,
    UniqueConstraint,
    desc,
    text,
)
from sqlalchemy.dialects.postgresql import JSONB, UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db.base import Base, CreatedAtMixin, SoftDeleteMixin, TimestampMixin, UUIDPrimaryKeyMixin
from app.db.models.farming import Crop, CropCycle, Plot
from app.db.models.identity import User


class MediaFile(Base, UUIDPrimaryKeyMixin, CreatedAtMixin, SoftDeleteMixin):
    __tablename__ = "media_files"

    owner_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("users.id"), nullable=False
    )
    plot_id: Mapped[uuid.UUID | None] = mapped_column(
        UUID(as_uuid=True), ForeignKey("plots.id"), nullable=True
    )
    crop_cycle_id: Mapped[uuid.UUID | None] = mapped_column(
        UUID(as_uuid=True), ForeignKey("crop_cycles.id"), nullable=True
    )
    kind: Mapped[str] = mapped_column(String, nullable=False)
    storage_key: Mapped[str] = mapped_column(String, nullable=False)
    mime_type: Mapped[str] = mapped_column(String, nullable=False)
    size_bytes: Mapped[int] = mapped_column(BigInteger, nullable=False)
    width: Mapped[int | None] = mapped_column(Integer, nullable=True)
    height: Mapped[int | None] = mapped_column(Integer, nullable=True)
    duration_s: Mapped[Decimal | None] = mapped_column(
        Numeric(6, 1), nullable=True
    )
    sha256: Mapped[str] = mapped_column(String, nullable=False)
    location: Mapped[Any | None] = mapped_column(
        Geography(geometry_type="POINT", srid=4326), nullable=True
    )
    captured_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True), nullable=True
    )
    upload_status: Mapped[str] = mapped_column(
        String,
        server_default="pending",
        default="pending",
        nullable=False,
    )

    owner: Mapped[User] = relationship("User")
    plot: Mapped[Plot | None] = relationship("Plot")
    crop_cycle: Mapped[CropCycle | None] = relationship("CropCycle")

    __table_args__ = (
        CheckConstraint(
            "kind IN ('image', 'video', 'audio')",
            name="chk_media_files_kind",
        ),
        CheckConstraint(
            "upload_status IN ('pending', 'uploaded', 'failed')",
            name="chk_media_files_upload_status",
        ),
        Index("ix_media_files_owner_created_at_desc", "owner_id", desc("created_at")),
        Index("ix_media_files_sha256", "sha256"),
    )


class AiModel(Base, CreatedAtMixin):
    __tablename__ = "ai_models"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    name: Mapped[str] = mapped_column(String, nullable=False)
    version: Mapped[str] = mapped_column(String, nullable=False)
    task: Mapped[str] = mapped_column(String, nullable=False)
    format: Mapped[str] = mapped_column(String, nullable=False)
    artifact_url: Mapped[str | None] = mapped_column(String, nullable=True)
    metrics: Mapped[dict[str, Any] | None] = mapped_column(JSONB, nullable=True)
    is_active: Mapped[bool] = mapped_column(
        Boolean, default=False, server_default=text("false"), nullable=False
    )
    deployed_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True), nullable=True
    )

    __table_args__ = (
        CheckConstraint(
            "task IN ('disease_classification', 'pest_detection', "
            "'deficiency', 'yield_prediction', 'llm_advisor')",
            name="chk_ai_models_task",
        ),
        CheckConstraint(
            "format IN ('tflite', 'onnx', 'api', 'other')",
            name="chk_ai_models_format",
        ),
        UniqueConstraint("name", "version", name="uq_ai_models_name_version"),
        Index(
            "uq_ai_models_task_active",
            "task",
            unique=True,
            postgresql_where=text("is_active = true"),
        ),
    )


class DiagnosisLabel(Base):
    __tablename__ = "diagnosis_labels"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    code: Mapped[str] = mapped_column(String, unique=True, nullable=False)
    kind: Mapped[str] = mapped_column(String, nullable=False)
    name_fr: Mapped[str] = mapped_column(String, nullable=False)
    name_ha: Mapped[str | None] = mapped_column(String, nullable=True)
    name_dje: Mapped[str | None] = mapped_column(String, nullable=True)
    description: Mapped[str | None] = mapped_column(Text, nullable=True)
    guideline: Mapped[dict[str, Any] | None] = mapped_column(JSONB, nullable=True)

    crops: Mapped[list[Crop]] = relationship(
        "Crop", secondary="label_crops", backref="diagnosis_labels"
    )

    __table_args__ = (
        CheckConstraint(
            "kind IN ('disease', 'pest', 'deficiency', 'weed', 'healthy')",
            name="chk_diagnosis_labels_kind",
        ),
    )


class LabelCrop(Base):
    __tablename__ = "label_crops"

    label_id: Mapped[int] = mapped_column(
        Integer,
        ForeignKey("diagnosis_labels.id", ondelete="CASCADE"),
        primary_key=True,
    )
    crop_id: Mapped[int] = mapped_column(
        Integer,
        ForeignKey("crops.id", ondelete="CASCADE"),
        primary_key=True,
    )


class Diagnostic(Base, UUIDPrimaryKeyMixin, TimestampMixin, SoftDeleteMixin):
    __tablename__ = "diagnostics"

    user_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("users.id"), nullable=False
    )
    plot_id: Mapped[uuid.UUID | None] = mapped_column(
        UUID(as_uuid=True), ForeignKey("plots.id"), nullable=True
    )
    crop_cycle_id: Mapped[uuid.UUID | None] = mapped_column(
        UUID(as_uuid=True), ForeignKey("crop_cycles.id"), nullable=True
    )
    crop_id: Mapped[int | None] = mapped_column(
        Integer, ForeignKey("crops.id"), nullable=True
    )
    model_id: Mapped[int | None] = mapped_column(
        Integer, ForeignKey("ai_models.id"), nullable=True
    )
    source: Mapped[str] = mapped_column(
        String,
        server_default="server",
        default="server",
        nullable=False,
    )
    status: Mapped[str] = mapped_column(
        String,
        server_default="pending",
        default="pending",
        nullable=False,
    )
    top_label_id: Mapped[int | None] = mapped_column(
        Integer, ForeignKey("diagnosis_labels.id"), nullable=True
    )
    confidence: Mapped[Decimal | None] = mapped_column(
        Numeric(4, 3), nullable=True
    )
    severity: Mapped[str | None] = mapped_column(String, nullable=True)
    user_note: Mapped[str | None] = mapped_column(Text, nullable=True)
    location: Mapped[Any | None] = mapped_column(
        Geography(geometry_type="POINT", srid=4326), nullable=True
    )
    error: Mapped[str | None] = mapped_column(Text, nullable=True)
    completed_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True), nullable=True
    )

    user: Mapped[User] = relationship("User")
    plot: Mapped[Plot | None] = relationship("Plot")
    crop_cycle: Mapped[CropCycle | None] = relationship("CropCycle")
    crop: Mapped[Crop | None] = relationship("Crop")
    model: Mapped[AiModel | None] = relationship("AiModel")
    top_label: Mapped[DiagnosisLabel | None] = relationship("DiagnosisLabel")
    media_files: Mapped[list[MediaFile]] = relationship(
        "MediaFile", secondary="diagnostic_media"
    )
    predictions: Mapped[list["DiagnosticPrediction"]] = relationship(
        "DiagnosticPrediction",
        back_populates="diagnostic",
        cascade="all, delete-orphan",
    )
    reviews: Mapped[list["ExpertReview"]] = relationship(
        "ExpertReview", back_populates="diagnostic", cascade="all, delete-orphan"
    )

    __table_args__ = (
        CheckConstraint(
            "source IN ('on_device', 'server')",
            name="chk_diagnostics_source",
        ),
        CheckConstraint(
            "status IN ('pending', 'processing', 'done', 'needs_review', 'failed')",
            name="chk_diagnostics_status",
        ),
        CheckConstraint(
            "severity IS NULL OR severity IN ('low', 'medium', 'high')",
            name="chk_diagnostics_severity",
        ),
        Index("ix_diagnostics_user_created_at_desc", "user_id", desc("created_at")),
        Index("ix_diagnostics_status", "status"),
    )


class DiagnosticMedia(Base):
    __tablename__ = "diagnostic_media"

    diagnostic_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("diagnostics.id", ondelete="CASCADE"),
        primary_key=True,
    )
    media_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("media_files.id"),
        primary_key=True,
    )


class DiagnosticPrediction(Base):
    __tablename__ = "diagnostic_predictions"

    id: Mapped[int] = mapped_column(BigInteger, primary_key=True, autoincrement=True)
    diagnostic_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("diagnostics.id", ondelete="CASCADE"),
        nullable=False,
    )
    label_id: Mapped[int] = mapped_column(
        Integer, ForeignKey("diagnosis_labels.id"), nullable=False
    )
    confidence: Mapped[Decimal] = mapped_column(Numeric(4, 3), nullable=False)
    rank: Mapped[int] = mapped_column(SmallInteger, nullable=False)
    bbox: Mapped[dict[str, Any] | None] = mapped_column(JSONB, nullable=True)

    diagnostic: Mapped[Diagnostic] = relationship(
        "Diagnostic", back_populates="predictions"
    )
    label: Mapped[DiagnosisLabel] = relationship("DiagnosisLabel")

    __table_args__ = (
        Index("ix_diagnostic_predictions_diagnostic_id", "diagnostic_id"),
    )


class ExpertReview(Base, UUIDPrimaryKeyMixin, CreatedAtMixin):
    __tablename__ = "expert_reviews"

    diagnostic_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("diagnostics.id", ondelete="CASCADE"),
        nullable=False,
    )
    reviewer_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("users.id"), nullable=False
    )
    verdict: Mapped[str] = mapped_column(String, nullable=False)
    corrected_label_id: Mapped[int | None] = mapped_column(
        Integer, ForeignKey("diagnosis_labels.id"), nullable=True
    )
    notes: Mapped[str | None] = mapped_column(Text, nullable=True)

    diagnostic: Mapped[Diagnostic] = relationship(
        "Diagnostic", back_populates="reviews"
    )
    reviewer: Mapped[User] = relationship("User")
    corrected_label: Mapped[DiagnosisLabel | None] = relationship("DiagnosisLabel")

    __table_args__ = (
        CheckConstraint(
            "verdict IN ('confirmed', 'corrected', 'unusable')",
            name="chk_expert_reviews_verdict",
        ),
    )


class Recommendation(Base, UUIDPrimaryKeyMixin, CreatedAtMixin):
    __tablename__ = "recommendations"

    user_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("users.id"), nullable=False
    )
    diagnostic_id: Mapped[uuid.UUID | None] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("diagnostics.id", ondelete="SET NULL"),
        nullable=True,
    )
    plot_id: Mapped[uuid.UUID | None] = mapped_column(
        UUID(as_uuid=True), ForeignKey("plots.id"), nullable=True
    )
    crop_cycle_id: Mapped[uuid.UUID | None] = mapped_column(
        UUID(as_uuid=True), ForeignKey("crop_cycles.id"), nullable=True
    )
    source: Mapped[str] = mapped_column(String, nullable=False)
    language: Mapped[str] = mapped_column(
        String, server_default="fr", default="fr", nullable=False
    )
    title: Mapped[str] = mapped_column(String, nullable=False)
    body: Mapped[str] = mapped_column(Text, nullable=False)
    steps: Mapped[list[Any] | None] = mapped_column(JSONB, nullable=True)
    citations: Mapped[list[Any] | None] = mapped_column(JSONB, nullable=True)
    model_id: Mapped[int | None] = mapped_column(
        Integer, ForeignKey("ai_models.id"), nullable=True
    )
    status: Mapped[str] = mapped_column(
        String,
        server_default="published",
        default="published",
        nullable=False,
    )
    validated_by: Mapped[uuid.UUID | None] = mapped_column(
        UUID(as_uuid=True), ForeignKey("users.id"), nullable=True
    )

    user: Mapped[User] = relationship("User", foreign_keys=[user_id])
    validator: Mapped[User | None] = relationship("User", foreign_keys=[validated_by])
    diagnostic: Mapped[Diagnostic | None] = relationship("Diagnostic")
    plot: Mapped[Plot | None] = relationship("Plot")
    crop_cycle: Mapped[CropCycle | None] = relationship("CropCycle")
    feedbacks: Mapped[list["RecommendationFeedback"]] = relationship(
        "RecommendationFeedback",
        back_populates="recommendation",
        cascade="all, delete-orphan",
    )

    __table_args__ = (
        CheckConstraint(
            "source IN ('rules', 'llm', 'expert')",
            name="chk_recommendations_source",
        ),
        CheckConstraint(
            "status IN ('draft', 'published', 'withdrawn')",
            name="chk_recommendations_status",
        ),
        Index("ix_recommendations_user_created_at_desc", "user_id", desc("created_at")),
    )


class RecommendationFeedback(Base, CreatedAtMixin):
    __tablename__ = "recommendation_feedback"

    recommendation_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("recommendations.id", ondelete="CASCADE"),
        primary_key=True,
    )
    user_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("users.id", ondelete="CASCADE"),
        primary_key=True,
    )
    helpful: Mapped[bool | None] = mapped_column(Boolean, nullable=True)
    applied: Mapped[bool | None] = mapped_column(Boolean, nullable=True)
    comment: Mapped[str | None] = mapped_column(Text, nullable=True)

    recommendation: Mapped[Recommendation] = relationship(
        "Recommendation", back_populates="feedbacks"
    )
    user: Mapped[User] = relationship("User")


class TrainingSample(Base, UUIDPrimaryKeyMixin, CreatedAtMixin):
    __tablename__ = "training_samples"

    media_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("media_files.id"), nullable=False
    )
    label_id: Mapped[int] = mapped_column(
        Integer, ForeignKey("diagnosis_labels.id"), nullable=False
    )
    crop_id: Mapped[int | None] = mapped_column(
        Integer, ForeignKey("crops.id"), nullable=True
    )
    source: Mapped[str] = mapped_column(String, nullable=False)
    split: Mapped[str | None] = mapped_column(String, nullable=True)
    quality_ok: Mapped[bool] = mapped_column(
        Boolean, default=True, server_default=text("true"), nullable=False
    )

    media: Mapped[MediaFile] = relationship("MediaFile")
    label: Mapped[DiagnosisLabel] = relationship("DiagnosisLabel")
    crop: Mapped[Crop | None] = relationship("Crop")

    __table_args__ = (
        CheckConstraint(
            "source IN ('expert_review', 'field_collection', 'public_dataset')",
            name="chk_training_samples_source",
        ),
        CheckConstraint(
            "split IS NULL OR split IN ('train', 'val', 'test')",
            name="chk_training_samples_split",
        ),
    )
