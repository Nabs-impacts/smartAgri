from typing import Sequence, Union
from alembic import op
import geoalchemy2
from pgvector.sqlalchemy import Vector
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql

revision: str = "0001_initial"
down_revision: Union[str, None] = None
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.execute("CREATE EXTENSION IF NOT EXISTS postgis;")
    op.execute("CREATE EXTENSION IF NOT EXISTS vector;")
    op.execute("CREATE EXTENSION IF NOT EXISTS pg_trgm;")

    op.execute(
        "CREATE OR REPLACE FUNCTION set_updated_at() "
        "RETURNS TRIGGER AS $$ "
        "BEGIN "
        "NEW.updated_at = NOW(); "
        "RETURN NEW; "
        "END; "
        "$$ LANGUAGE plpgsql;"
    )

    op.create_table(
        "admin_areas",
        sa.Column("id", sa.Integer(), autoincrement=True, nullable=False),
        sa.Column("parent_id", sa.Integer(), nullable=True),
        sa.Column("level", sa.String(), nullable=False),
        sa.Column("name", sa.String(), nullable=False),
        sa.Column("code", sa.String(), nullable=False),
        sa.Column(
            "geom",
            geoalchemy2.Geometry(
                geometry_type="MULTIPOLYGON",
                srid=4326,
                from_text="ST_GeomFromEWKT",
                name="geometry",
            ),
            nullable=True,
        ),
        sa.CheckConstraint(
            "level IN ('region', 'departement', 'commune')",
            name="chk_admin_areas_level",
        ),
        sa.ForeignKeyConstraint(["parent_id"], ["admin_areas.id"]),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint("code"),
    )
    op.create_index(
        "ix_admin_areas_geom",
        "admin_areas",
        ["geom"],
        unique=False,
        postgresql_using="gist",
    )

    op.create_table(
        "users",
        sa.Column(
            "id",
            postgresql.UUID(as_uuid=True),
            server_default=sa.text("gen_random_uuid()"),
            nullable=False,
        ),
        sa.Column("phone", sa.String(), nullable=False),
        sa.Column("email", sa.String(), nullable=True),
        sa.Column("password_hash", sa.String(), nullable=True),
        sa.Column("full_name", sa.String(), nullable=False),
        sa.Column(
            "role",
            sa.String(),
            server_default="farmer",
            nullable=False,
        ),
        sa.Column(
            "language",
            sa.String(),
            server_default="fr",
            nullable=False,
        ),
        sa.Column("admin_area_id", sa.Integer(), nullable=True),
        sa.Column(
            "is_active",
            sa.Boolean(),
            server_default=sa.text("true"),
            nullable=False,
        ),
        sa.Column("phone_verified_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("last_login_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            server_default=sa.func.now(),
            nullable=False,
        ),
        sa.Column(
            "updated_at",
            sa.DateTime(timezone=True),
            server_default=sa.func.now(),
            nullable=False,
        ),
        sa.Column("deleted_at", sa.DateTime(timezone=True), nullable=True),
        sa.CheckConstraint(
            "role IN ('farmer', 'field_agent', 'agronomist', 'org_admin', 'gov_admin', 'super_admin')",
            name="chk_users_role",
        ),
        sa.CheckConstraint(
            "language IN ('fr', 'ha', 'dje', 'en')",
            name="chk_users_language",
        ),
        sa.ForeignKeyConstraint(["admin_area_id"], ["admin_areas.id"]),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint("phone"),
        sa.UniqueConstraint("email"),
    )

    op.create_table(
        "otp_codes",
        sa.Column(
            "id",
            postgresql.UUID(as_uuid=True),
            server_default=sa.text("gen_random_uuid()"),
            nullable=False,
        ),
        sa.Column("phone", sa.String(), nullable=False),
        sa.Column("code_hash", sa.String(), nullable=False),
        sa.Column("purpose", sa.String(), nullable=False),
        sa.Column("attempts", sa.Integer(), server_default=sa.text("0"), nullable=False),
        sa.Column("expires_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("consumed_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            server_default=sa.func.now(),
            nullable=False,
        ),
        sa.CheckConstraint(
            "purpose IN ('login', 'verify_phone', 'reset_password')",
            name="chk_otp_codes_purpose",
        ),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index(
        "ix_otp_codes_phone_created_at_desc",
        "otp_codes",
        ["phone", sa.text("created_at DESC")],
        unique=False,
    )

    op.create_table(
        "devices",
        sa.Column(
            "id",
            postgresql.UUID(as_uuid=True),
            server_default=sa.text("gen_random_uuid()"),
            nullable=False,
        ),
        sa.Column("user_id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("platform", sa.String(), nullable=False),
        sa.Column("fcm_token", sa.String(), nullable=False),
        sa.Column("app_version", sa.String(), nullable=True),
        sa.Column("last_seen_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            server_default=sa.func.now(),
            nullable=False,
        ),
        sa.CheckConstraint(
            "platform IN ('android', 'ios')",
            name="chk_devices_platform",
        ),
        sa.ForeignKeyConstraint(["user_id"], ["users.id"], ondelete="CASCADE"),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint("user_id", "fcm_token", name="uq_devices_user_fcm"),
    )

    op.create_table(
        "refresh_tokens",
        sa.Column(
            "id",
            postgresql.UUID(as_uuid=True),
            server_default=sa.text("gen_random_uuid()"),
            nullable=False,
        ),
        sa.Column("user_id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("device_id", postgresql.UUID(as_uuid=True), nullable=True),
        sa.Column("token_hash", sa.String(), nullable=False),
        sa.Column("expires_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("revoked_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            server_default=sa.func.now(),
            nullable=False,
        ),
        sa.ForeignKeyConstraint(["device_id"], ["devices.id"], ondelete="SET NULL"),
        sa.ForeignKeyConstraint(["user_id"], ["users.id"], ondelete="CASCADE"),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint("token_hash"),
    )

    op.create_table(
        "consents",
        sa.Column(
            "id",
            postgresql.UUID(as_uuid=True),
            server_default=sa.text("gen_random_uuid()"),
            nullable=False,
        ),
        sa.Column("user_id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("type", sa.String(), nullable=False),
        sa.Column("version", sa.String(), nullable=False),
        sa.Column("accepted", sa.Boolean(), nullable=False),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            server_default=sa.func.now(),
            nullable=False,
        ),
        sa.CheckConstraint(
            "type IN ('terms', 'privacy', 'data_sharing_gov', 'research')",
            name="chk_consents_type",
        ),
        sa.ForeignKeyConstraint(["user_id"], ["users.id"], ondelete="CASCADE"),
        sa.PrimaryKeyConstraint("id"),
    )

    op.create_table(
        "organizations",
        sa.Column(
            "id",
            postgresql.UUID(as_uuid=True),
            server_default=sa.text("gen_random_uuid()"),
            nullable=False,
        ),
        sa.Column("name", sa.String(), nullable=False),
        sa.Column("type", sa.String(), nullable=False),
        sa.Column("registration_no", sa.String(), nullable=True),
        sa.Column("admin_area_id", sa.Integer(), nullable=True),
        sa.Column("contact_phone", sa.String(), nullable=True),
        sa.Column("contact_email", sa.String(), nullable=True),
        sa.Column(
            "is_active",
            sa.Boolean(),
            server_default=sa.text("true"),
            nullable=False,
        ),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            server_default=sa.func.now(),
            nullable=False,
        ),
        sa.Column(
            "updated_at",
            sa.DateTime(timezone=True),
            server_default=sa.func.now(),
            nullable=False,
        ),
        sa.CheckConstraint(
            "type IN ('cooperative', 'ngo', 'agri_company', 'bank', 'insurer', 'government', 'other')",
            name="chk_organizations_type",
        ),
        sa.ForeignKeyConstraint(["admin_area_id"], ["admin_areas.id"]),
        sa.PrimaryKeyConstraint("id"),
    )

    op.create_table(
        "organization_members",
        sa.Column("organization_id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("user_id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column(
            "member_role",
            sa.String(),
            server_default="member",
            nullable=False,
        ),
        sa.Column(
            "joined_at",
            sa.DateTime(timezone=True),
            server_default=sa.func.now(),
            nullable=False,
        ),
        sa.CheckConstraint(
            "member_role IN ('owner', 'admin', 'agent', 'member')",
            name="chk_organization_members_role",
        ),
        sa.ForeignKeyConstraint(["organization_id"], ["organizations.id"], ondelete="CASCADE"),
        sa.ForeignKeyConstraint(["user_id"], ["users.id"], ondelete="CASCADE"),
        sa.PrimaryKeyConstraint("organization_id", "user_id"),
    )

    op.create_table(
        "farms",
        sa.Column(
            "id",
            postgresql.UUID(as_uuid=True),
            server_default=sa.text("gen_random_uuid()"),
            nullable=False,
        ),
        sa.Column("owner_id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("organization_id", postgresql.UUID(as_uuid=True), nullable=True),
        sa.Column("name", sa.String(), nullable=False),
        sa.Column("village", sa.String(), nullable=True),
        sa.Column("admin_area_id", sa.Integer(), nullable=True),
        sa.Column(
            "location",
            geoalchemy2.Geography(
                geometry_type="POINT",
                srid=4326,
                from_text="ST_GeogFromText",
                name="geography",
            ),
            nullable=True,
        ),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            server_default=sa.func.now(),
            nullable=False,
        ),
        sa.Column(
            "updated_at",
            sa.DateTime(timezone=True),
            server_default=sa.func.now(),
            nullable=False,
        ),
        sa.Column("deleted_at", sa.DateTime(timezone=True), nullable=True),
        sa.ForeignKeyConstraint(["admin_area_id"], ["admin_areas.id"]),
        sa.ForeignKeyConstraint(["organization_id"], ["organizations.id"]),
        sa.ForeignKeyConstraint(["owner_id"], ["users.id"]),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index("ix_farms_owner_id", "farms", ["owner_id"], unique=False)
    op.create_index(
        "ix_farms_location",
        "farms",
        ["location"],
        unique=False,
        postgresql_using="gist",
    )

    op.create_table(
        "plots",
        sa.Column(
            "id",
            postgresql.UUID(as_uuid=True),
            server_default=sa.text("gen_random_uuid()"),
            nullable=False,
        ),
        sa.Column("farm_id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("name", sa.String(), nullable=False),
        sa.Column("area_ha", sa.Numeric(precision=10, scale=3), nullable=True),
        sa.Column(
            "geom",
            geoalchemy2.Geometry(
                geometry_type="POLYGON",
                srid=4326,
                from_text="ST_GeomFromEWKT",
                name="geometry",
            ),
            nullable=True,
        ),
        sa.Column("soil_type", sa.String(), nullable=True),
        sa.Column("irrigation", sa.String(), nullable=True),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            server_default=sa.func.now(),
            nullable=False,
        ),
        sa.Column(
            "updated_at",
            sa.DateTime(timezone=True),
            server_default=sa.func.now(),
            nullable=False,
        ),
        sa.Column("deleted_at", sa.DateTime(timezone=True), nullable=True),
        sa.CheckConstraint(
            "soil_type IS NULL OR soil_type IN ('sandy', 'loam', 'clay', 'laterite', 'other')",
            name="chk_plots_soil_type",
        ),
        sa.CheckConstraint(
            "irrigation IS NULL OR irrigation IN ('rainfed', 'drip', 'gravity', 'well', 'other')",
            name="chk_plots_irrigation",
        ),
        sa.ForeignKeyConstraint(["farm_id"], ["farms.id"]),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index("ix_plots_farm_id", "plots", ["farm_id"], unique=False)
    op.create_index(
        "ix_plots_geom",
        "plots",
        ["geom"],
        unique=False,
        postgresql_using="gist",
    )

    op.create_table(
        "crops",
        sa.Column("id", sa.Integer(), autoincrement=True, nullable=False),
        sa.Column("code", sa.String(), nullable=False),
        sa.Column("name_fr", sa.String(), nullable=False),
        sa.Column("name_ha", sa.String(), nullable=True),
        sa.Column("name_dje", sa.String(), nullable=True),
        sa.Column("category", sa.String(), nullable=False),
        sa.Column("cycle_days", sa.Integer(), nullable=True),
        sa.CheckConstraint(
            "category IN ('cereal', 'legume', 'vegetable', 'fruit', 'tuber', 'cash_crop', 'other')",
            name="chk_crops_category",
        ),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint("code"),
    )

    op.create_table(
        "crop_cycles",
        sa.Column(
            "id",
            postgresql.UUID(as_uuid=True),
            server_default=sa.text("gen_random_uuid()"),
            nullable=False,
        ),
        sa.Column("plot_id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("crop_id", sa.Integer(), nullable=False),
        sa.Column("variety", sa.String(), nullable=True),
        sa.Column("season", sa.String(), nullable=True),
        sa.Column("sowing_date", sa.Date(), nullable=True),
        sa.Column("expected_harvest_date", sa.Date(), nullable=True),
        sa.Column("harvest_date", sa.Date(), nullable=True),
        sa.Column(
            "status",
            sa.String(),
            server_default="planned",
            nullable=False,
        ),
        sa.Column("notes", sa.Text(), nullable=True),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            server_default=sa.func.now(),
            nullable=False,
        ),
        sa.Column(
            "updated_at",
            sa.DateTime(timezone=True),
            server_default=sa.func.now(),
            nullable=False,
        ),
        sa.Column("deleted_at", sa.DateTime(timezone=True), nullable=True),
        sa.CheckConstraint(
            "status IN ('planned', 'growing', 'harvested', 'failed')",
            name="chk_crop_cycles_status",
        ),
        sa.ForeignKeyConstraint(["crop_id"], ["crops.id"]),
        sa.ForeignKeyConstraint(["plot_id"], ["plots.id"]),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index(
        "ix_crop_cycles_plot_status",
        "crop_cycles",
        ["plot_id", "status"],
        unique=False,
    )

    op.create_table(
        "farm_activities",
        sa.Column(
            "id",
            postgresql.UUID(as_uuid=True),
            server_default=sa.text("gen_random_uuid()"),
            nullable=False,
        ),
        sa.Column("crop_cycle_id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("type", sa.String(), nullable=False),
        sa.Column("performed_on", sa.Date(), nullable=False),
        sa.Column("product_name", sa.String(), nullable=True),
        sa.Column("quantity", sa.Numeric(precision=12, scale=2), nullable=True),
        sa.Column("unit", sa.String(), nullable=True),
        sa.Column("cost_xof", sa.Integer(), nullable=True),
        sa.Column("notes", sa.Text(), nullable=True),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            server_default=sa.func.now(),
            nullable=False,
        ),
        sa.Column(
            "updated_at",
            sa.DateTime(timezone=True),
            server_default=sa.func.now(),
            nullable=False,
        ),
        sa.Column("deleted_at", sa.DateTime(timezone=True), nullable=True),
        sa.CheckConstraint(
            "type IN ('sowing', 'fertilizing', 'irrigation', 'weeding', 'pesticide', 'harvest', 'other')",
            name="chk_farm_activities_type",
        ),
        sa.ForeignKeyConstraint(["crop_cycle_id"], ["crop_cycles.id"]),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index(
        "ix_farm_activities_cycle_date",
        "farm_activities",
        ["crop_cycle_id", "performed_on"],
        unique=False,
    )

    op.create_table(
        "harvests",
        sa.Column(
            "id",
            postgresql.UUID(as_uuid=True),
            server_default=sa.text("gen_random_uuid()"),
            nullable=False,
        ),
        sa.Column("crop_cycle_id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("harvested_on", sa.Date(), nullable=False),
        sa.Column("quantity_kg", sa.Numeric(precision=12, scale=2), nullable=False),
        sa.Column("quality", sa.String(), nullable=True),
        sa.Column(
            "sold_kg",
            sa.Numeric(precision=12, scale=2),
            server_default=sa.text("0"),
            nullable=False,
        ),
        sa.Column("avg_price_xof_per_kg", sa.Numeric(precision=10, scale=2), nullable=True),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            server_default=sa.func.now(),
            nullable=False,
        ),
        sa.Column(
            "updated_at",
            sa.DateTime(timezone=True),
            server_default=sa.func.now(),
            nullable=False,
        ),
        sa.Column("deleted_at", sa.DateTime(timezone=True), nullable=True),
        sa.CheckConstraint(
            "quality IS NULL OR quality IN ('A', 'B', 'C')",
            name="chk_harvests_quality",
        ),
        sa.ForeignKeyConstraint(["crop_cycle_id"], ["crop_cycles.id"]),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index(
        "ix_harvests_crop_cycle_id",
        "harvests",
        ["crop_cycle_id"],
        unique=False,
    )

    op.create_table(
        "media_files",
        sa.Column(
            "id",
            postgresql.UUID(as_uuid=True),
            server_default=sa.text("gen_random_uuid()"),
            nullable=False,
        ),
        sa.Column("owner_id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("plot_id", postgresql.UUID(as_uuid=True), nullable=True),
        sa.Column("crop_cycle_id", postgresql.UUID(as_uuid=True), nullable=True),
        sa.Column("kind", sa.String(), nullable=False),
        sa.Column("storage_key", sa.String(), nullable=False),
        sa.Column("mime_type", sa.String(), nullable=False),
        sa.Column("size_bytes", sa.BigInteger(), nullable=False),
        sa.Column("width", sa.Integer(), nullable=True),
        sa.Column("height", sa.Integer(), nullable=True),
        sa.Column("duration_s", sa.Numeric(precision=6, scale=1), nullable=True),
        sa.Column("sha256", sa.String(), nullable=False),
        sa.Column(
            "location",
            geoalchemy2.Geography(
                geometry_type="POINT",
                srid=4326,
                from_text="ST_GeogFromText",
                name="geography",
            ),
            nullable=True,
        ),
        sa.Column("captured_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column(
            "upload_status",
            sa.String(),
            server_default="pending",
            nullable=False,
        ),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            server_default=sa.func.now(),
            nullable=False,
        ),
        sa.Column("deleted_at", sa.DateTime(timezone=True), nullable=True),
        sa.CheckConstraint(
            "kind IN ('image', 'video', 'audio')",
            name="chk_media_files_kind",
        ),
        sa.CheckConstraint(
            "upload_status IN ('pending', 'uploaded', 'failed')",
            name="chk_media_files_upload_status",
        ),
        sa.ForeignKeyConstraint(["crop_cycle_id"], ["crop_cycles.id"]),
        sa.ForeignKeyConstraint(["owner_id"], ["users.id"]),
        sa.ForeignKeyConstraint(["plot_id"], ["plots.id"]),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index(
        "ix_media_files_owner_created_at_desc",
        "media_files",
        ["owner_id", sa.text("created_at DESC")],
        unique=False,
    )
    op.create_index("ix_media_files_sha256", "media_files", ["sha256"], unique=False)

    op.create_table(
        "ai_models",
        sa.Column("id", sa.Integer(), autoincrement=True, nullable=False),
        sa.Column("name", sa.String(), nullable=False),
        sa.Column("version", sa.String(), nullable=False),
        sa.Column("task", sa.String(), nullable=False),
        sa.Column("format", sa.String(), nullable=False),
        sa.Column("artifact_url", sa.String(), nullable=True),
        sa.Column("metrics", postgresql.JSONB(astext_type=sa.Text()), nullable=True),
        sa.Column(
            "is_active",
            sa.Boolean(),
            server_default=sa.text("false"),
            nullable=False,
        ),
        sa.Column("deployed_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            server_default=sa.func.now(),
            nullable=False,
        ),
        sa.CheckConstraint(
            "task IN ('disease_classification', 'pest_detection', 'deficiency', 'yield_prediction', 'llm_advisor')",
            name="chk_ai_models_task",
        ),
        sa.CheckConstraint(
            "format IN ('tflite', 'onnx', 'api', 'other')",
            name="chk_ai_models_format",
        ),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint("name", "version", name="uq_ai_models_name_version"),
    )
    op.create_index(
        "uq_ai_models_task_active",
        "ai_models",
        ["task"],
        unique=True,
        postgresql_where=sa.text("is_active = true"),
    )

    op.create_table(
        "diagnosis_labels",
        sa.Column("id", sa.Integer(), autoincrement=True, nullable=False),
        sa.Column("code", sa.String(), nullable=False),
        sa.Column("kind", sa.String(), nullable=False),
        sa.Column("name_fr", sa.String(), nullable=False),
        sa.Column("name_ha", sa.String(), nullable=True),
        sa.Column("name_dje", sa.String(), nullable=True),
        sa.Column("description", sa.Text(), nullable=True),
        sa.Column("guideline", postgresql.JSONB(astext_type=sa.Text()), nullable=True),
        sa.CheckConstraint(
            "kind IN ('disease', 'pest', 'deficiency', 'weed', 'healthy')",
            name="chk_diagnosis_labels_kind",
        ),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint("code"),
    )

    op.create_table(
        "label_crops",
        sa.Column("label_id", sa.Integer(), nullable=False),
        sa.Column("crop_id", sa.Integer(), nullable=False),
        sa.ForeignKeyConstraint(["crop_id"], ["crops.id"], ondelete="CASCADE"),
        sa.ForeignKeyConstraint(["label_id"], ["diagnosis_labels.id"], ondelete="CASCADE"),
        sa.PrimaryKeyConstraint("label_id", "crop_id"),
    )

    op.create_table(
        "diagnostics",
        sa.Column(
            "id",
            postgresql.UUID(as_uuid=True),
            server_default=sa.text("gen_random_uuid()"),
            nullable=False,
        ),
        sa.Column("user_id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("plot_id", postgresql.UUID(as_uuid=True), nullable=True),
        sa.Column("crop_cycle_id", postgresql.UUID(as_uuid=True), nullable=True),
        sa.Column("crop_id", sa.Integer(), nullable=True),
        sa.Column("model_id", sa.Integer(), nullable=True),
        sa.Column(
            "source",
            sa.String(),
            server_default="server",
            nullable=False,
        ),
        sa.Column(
            "status",
            sa.String(),
            server_default="pending",
            nullable=False,
        ),
        sa.Column("top_label_id", sa.Integer(), nullable=True),
        sa.Column("confidence", sa.Numeric(precision=4, scale=3), nullable=True),
        sa.Column("severity", sa.String(), nullable=True),
        sa.Column("user_note", sa.Text(), nullable=True),
        sa.Column(
            "location",
            geoalchemy2.Geography(
                geometry_type="POINT",
                srid=4326,
                from_text="ST_GeogFromText",
                name="geography",
            ),
            nullable=True,
        ),
        sa.Column("error", sa.Text(), nullable=True),
        sa.Column("completed_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            server_default=sa.func.now(),
            nullable=False,
        ),
        sa.Column(
            "updated_at",
            sa.DateTime(timezone=True),
            server_default=sa.func.now(),
            nullable=False,
        ),
        sa.Column("deleted_at", sa.DateTime(timezone=True), nullable=True),
        sa.CheckConstraint(
            "source IN ('on_device', 'server')",
            name="chk_diagnostics_source",
        ),
        sa.CheckConstraint(
            "status IN ('pending', 'processing', 'done', 'needs_review', 'failed')",
            name="chk_diagnostics_status",
        ),
        sa.CheckConstraint(
            "severity IS NULL OR severity IN ('low', 'medium', 'high')",
            name="chk_diagnostics_severity",
        ),
        sa.ForeignKeyConstraint(["crop_cycle_id"], ["crop_cycles.id"]),
        sa.ForeignKeyConstraint(["crop_id"], ["crops.id"]),
        sa.ForeignKeyConstraint(["model_id"], ["ai_models.id"]),
        sa.ForeignKeyConstraint(["plot_id"], ["plots.id"]),
        sa.ForeignKeyConstraint(["top_label_id"], ["diagnosis_labels.id"]),
        sa.ForeignKeyConstraint(["user_id"], ["users.id"]),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index(
        "ix_diagnostics_user_created_at_desc",
        "diagnostics",
        ["user_id", sa.text("created_at DESC")],
        unique=False,
    )
    op.create_index("ix_diagnostics_status", "diagnostics", ["status"], unique=False)
    op.create_index(
        "ix_diagnostics_location",
        "diagnostics",
        ["location"],
        unique=False,
        postgresql_using="gist",
    )

    op.create_table(
        "diagnostic_media",
        sa.Column("diagnostic_id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("media_id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.ForeignKeyConstraint(["diagnostic_id"], ["diagnostics.id"], ondelete="CASCADE"),
        sa.ForeignKeyConstraint(["media_id"], ["media_files.id"]),
        sa.PrimaryKeyConstraint("diagnostic_id", "media_id"),
    )

    op.create_table(
        "diagnostic_predictions",
        sa.Column("id", sa.BigInteger(), autoincrement=True, nullable=False),
        sa.Column("diagnostic_id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("label_id", sa.Integer(), nullable=False),
        sa.Column("confidence", sa.Numeric(precision=4, scale=3), nullable=False),
        sa.Column("rank", sa.SmallInteger(), nullable=False),
        sa.Column("bbox", postgresql.JSONB(astext_type=sa.Text()), nullable=True),
        sa.ForeignKeyConstraint(["diagnostic_id"], ["diagnostics.id"], ondelete="CASCADE"),
        sa.ForeignKeyConstraint(["label_id"], ["diagnosis_labels.id"]),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index(
        "ix_diagnostic_predictions_diagnostic_id",
        "diagnostic_predictions",
        ["diagnostic_id"],
        unique=False,
    )

    op.create_table(
        "expert_reviews",
        sa.Column(
            "id",
            postgresql.UUID(as_uuid=True),
            server_default=sa.text("gen_random_uuid()"),
            nullable=False,
        ),
        sa.Column("diagnostic_id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("reviewer_id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("verdict", sa.String(), nullable=False),
        sa.Column("corrected_label_id", sa.Integer(), nullable=True),
        sa.Column("notes", sa.Text(), nullable=True),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            server_default=sa.func.now(),
            nullable=False,
        ),
        sa.CheckConstraint(
            "verdict IN ('confirmed', 'corrected', 'unusable')",
            name="chk_expert_reviews_verdict",
        ),
        sa.ForeignKeyConstraint(["corrected_label_id"], ["diagnosis_labels.id"]),
        sa.ForeignKeyConstraint(["diagnostic_id"], ["diagnostics.id"], ondelete="CASCADE"),
        sa.ForeignKeyConstraint(["reviewer_id"], ["users.id"]),
        sa.PrimaryKeyConstraint("id"),
    )

    op.create_table(
        "recommendations",
        sa.Column(
            "id",
            postgresql.UUID(as_uuid=True),
            server_default=sa.text("gen_random_uuid()"),
            nullable=False,
        ),
        sa.Column("user_id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("diagnostic_id", postgresql.UUID(as_uuid=True), nullable=True),
        sa.Column("plot_id", postgresql.UUID(as_uuid=True), nullable=True),
        sa.Column("crop_cycle_id", postgresql.UUID(as_uuid=True), nullable=True),
        sa.Column("source", sa.String(), nullable=False),
        sa.Column(
            "language",
            sa.String(),
            server_default="fr",
            nullable=False,
        ),
        sa.Column("title", sa.String(), nullable=False),
        sa.Column("body", sa.Text(), nullable=False),
        sa.Column("steps", postgresql.JSONB(astext_type=sa.Text()), nullable=True),
        sa.Column("citations", postgresql.JSONB(astext_type=sa.Text()), nullable=True),
        sa.Column("model_id", sa.Integer(), nullable=True),
        sa.Column(
            "status",
            sa.String(),
            server_default="published",
            nullable=False,
        ),
        sa.Column("validated_by", postgresql.UUID(as_uuid=True), nullable=True),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            server_default=sa.func.now(),
            nullable=False,
        ),
        sa.CheckConstraint(
            "source IN ('rules', 'llm', 'expert')",
            name="chk_recommendations_source",
        ),
        sa.CheckConstraint(
            "status IN ('draft', 'published', 'withdrawn')",
            name="chk_recommendations_status",
        ),
        sa.ForeignKeyConstraint(["crop_cycle_id"], ["crop_cycles.id"]),
        sa.ForeignKeyConstraint(["diagnostic_id"], ["diagnostics.id"], ondelete="SET NULL"),
        sa.ForeignKeyConstraint(["model_id"], ["ai_models.id"]),
        sa.ForeignKeyConstraint(["plot_id"], ["plots.id"]),
        sa.ForeignKeyConstraint(["user_id"], ["users.id"]),
        sa.ForeignKeyConstraint(["validated_by"], ["users.id"]),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index(
        "ix_recommendations_user_created_at_desc",
        "recommendations",
        ["user_id", sa.text("created_at DESC")],
        unique=False,
    )

    op.create_table(
        "recommendation_feedback",
        sa.Column("recommendation_id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("user_id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("helpful", sa.Boolean(), nullable=True),
        sa.Column("applied", sa.Boolean(), nullable=True),
        sa.Column("comment", sa.Text(), nullable=True),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            server_default=sa.func.now(),
            nullable=False,
        ),
        sa.ForeignKeyConstraint(["recommendation_id"], ["recommendations.id"], ondelete="CASCADE"),
        sa.ForeignKeyConstraint(["user_id"], ["users.id"], ondelete="CASCADE"),
        sa.PrimaryKeyConstraint("recommendation_id", "user_id"),
    )

    op.create_table(
        "training_samples",
        sa.Column(
            "id",
            postgresql.UUID(as_uuid=True),
            server_default=sa.text("gen_random_uuid()"),
            nullable=False,
        ),
        sa.Column("media_id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("label_id", sa.Integer(), nullable=False),
        sa.Column("crop_id", sa.Integer(), nullable=True),
        sa.Column("source", sa.String(), nullable=False),
        sa.Column("split", sa.String(), nullable=True),
        sa.Column(
            "quality_ok",
            sa.Boolean(),
            server_default=sa.text("true"),
            nullable=False,
        ),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            server_default=sa.func.now(),
            nullable=False,
        ),
        sa.CheckConstraint(
            "source IN ('expert_review', 'field_collection', 'public_dataset')",
            name="chk_training_samples_source",
        ),
        sa.CheckConstraint(
            "split IS NULL OR split IN ('train', 'val', 'test')",
            name="chk_training_samples_split",
        ),
        sa.ForeignKeyConstraint(["crop_id"], ["crops.id"]),
        sa.ForeignKeyConstraint(["label_id"], ["diagnosis_labels.id"]),
        sa.ForeignKeyConstraint(["media_id"], ["media_files.id"]),
        sa.PrimaryKeyConstraint("id"),
    )

    op.create_table(
        "knowledge_documents",
        sa.Column(
            "id",
            postgresql.UUID(as_uuid=True),
            server_default=sa.text("gen_random_uuid()"),
            nullable=False,
        ),
        sa.Column("title", sa.String(), nullable=False),
        sa.Column("source_org", sa.String(), nullable=True),
        sa.Column("url", sa.String(), nullable=True),
        sa.Column("storage_key", sa.String(), nullable=True),
        sa.Column(
            "language",
            sa.String(),
            server_default="fr",
            nullable=False,
        ),
        sa.Column("crop_id", sa.Integer(), nullable=True),
        sa.Column("published_year", sa.Integer(), nullable=True),
        sa.Column(
            "ingest_status",
            sa.String(),
            server_default="pending",
            nullable=False,
        ),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            server_default=sa.func.now(),
            nullable=False,
        ),
        sa.CheckConstraint(
            "ingest_status IN ('pending', 'processing', 'done', 'failed')",
            name="chk_knowledge_documents_status",
        ),
        sa.ForeignKeyConstraint(["crop_id"], ["crops.id"]),
        sa.PrimaryKeyConstraint("id"),
    )

    op.create_table(
        "knowledge_chunks",
        sa.Column("id", sa.BigInteger(), autoincrement=True, nullable=False),
        sa.Column("document_id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("chunk_index", sa.Integer(), nullable=False),
        sa.Column("content", sa.Text(), nullable=False),
        sa.Column("embedding", Vector(1024), nullable=False),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            server_default=sa.func.now(),
            nullable=False,
        ),
        sa.ForeignKeyConstraint(["document_id"], ["knowledge_documents.id"], ondelete="CASCADE"),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index(
        "ix_knowledge_chunks_embedding",
        "knowledge_chunks",
        ["embedding"],
        unique=False,
        postgresql_using="hnsw",
        postgresql_with={"m": 16, "ef_construction": 64},
        postgresql_ops={"embedding": "vector_cosine_ops"},
    )

    op.create_table(
        "chat_sessions",
        sa.Column(
            "id",
            postgresql.UUID(as_uuid=True),
            server_default=sa.text("gen_random_uuid()"),
            nullable=False,
        ),
        sa.Column("user_id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("plot_id", postgresql.UUID(as_uuid=True), nullable=True),
        sa.Column("title", sa.String(), nullable=True),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            server_default=sa.func.now(),
            nullable=False,
        ),
        sa.ForeignKeyConstraint(["plot_id"], ["plots.id"]),
        sa.ForeignKeyConstraint(["user_id"], ["users.id"], ondelete="CASCADE"),
        sa.PrimaryKeyConstraint("id"),
    )

    op.create_table(
        "chat_messages",
        sa.Column("id", sa.BigInteger(), autoincrement=True, nullable=False),
        sa.Column("session_id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("role", sa.String(), nullable=False),
        sa.Column("content", sa.Text(), nullable=False),
        sa.Column("media_id", postgresql.UUID(as_uuid=True), nullable=True),
        sa.Column("citations", postgresql.JSONB(astext_type=sa.Text()), nullable=True),
        sa.Column("tokens_in", sa.Integer(), nullable=True),
        sa.Column("tokens_out", sa.Integer(), nullable=True),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            server_default=sa.func.now(),
            nullable=False,
        ),
        sa.CheckConstraint(
            "role IN ('user', 'assistant', 'system')",
            name="chk_chat_messages_role",
        ),
        sa.ForeignKeyConstraint(["media_id"], ["media_files.id"]),
        sa.ForeignKeyConstraint(["session_id"], ["chat_sessions.id"], ondelete="CASCADE"),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index(
        "ix_chat_messages_session_id_id",
        "chat_messages",
        ["session_id", "id"],
        unique=False,
    )

    op.create_table(
        "weather_data",
        sa.Column("id", sa.BigInteger(), autoincrement=True, nullable=False),
        sa.Column("admin_area_id", sa.Integer(), nullable=False),
        sa.Column("obs_date", sa.Date(), nullable=False),
        sa.Column("kind", sa.String(), nullable=False),
        sa.Column("temp_min_c", sa.Numeric(precision=4, scale=1), nullable=True),
        sa.Column("temp_max_c", sa.Numeric(precision=4, scale=1), nullable=True),
        sa.Column("rain_mm", sa.Numeric(precision=6, scale=1), nullable=True),
        sa.Column("humidity_pct", sa.Numeric(precision=4, scale=1), nullable=True),
        sa.Column("wind_kmh", sa.Numeric(precision=5, scale=1), nullable=True),
        sa.Column("source", sa.String(), nullable=False),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            server_default=sa.func.now(),
            nullable=False,
        ),
        sa.CheckConstraint(
            "kind IN ('observed', 'forecast')",
            name="chk_weather_data_kind",
        ),
        sa.ForeignKeyConstraint(["admin_area_id"], ["admin_areas.id"]),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint(
            "admin_area_id",
            "obs_date",
            "kind",
            "source",
            name="uq_weather_data_area_date_kind_source",
        ),
    )

    op.create_table(
        "satellite_indices",
        sa.Column("id", sa.BigInteger(), autoincrement=True, nullable=False),
        sa.Column("plot_id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("obs_date", sa.Date(), nullable=False),
        sa.Column("ndvi", sa.Numeric(precision=5, scale=4), nullable=True),
        sa.Column("evi", sa.Numeric(precision=5, scale=4), nullable=True),
        sa.Column("cloud_cover_pct", sa.Numeric(precision=4, scale=1), nullable=True),
        sa.Column(
            "source",
            sa.String(),
            server_default="sentinel-2",
            nullable=False,
        ),
        sa.ForeignKeyConstraint(["plot_id"], ["plots.id"]),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint("plot_id", "obs_date", name="uq_satellite_indices_plot_date"),
    )

    op.create_table(
        "markets",
        sa.Column("id", sa.Integer(), autoincrement=True, nullable=False),
        sa.Column("name", sa.String(), nullable=False),
        sa.Column("admin_area_id", sa.Integer(), nullable=True),
        sa.Column(
            "location",
            geoalchemy2.Geography(
                geometry_type="POINT",
                srid=4326,
                from_text="ST_GeogFromText",
                name="geography",
            ),
            nullable=True,
        ),
        sa.ForeignKeyConstraint(["admin_area_id"], ["admin_areas.id"]),
        sa.PrimaryKeyConstraint("id"),
    )

    op.create_table(
        "market_prices",
        sa.Column("id", sa.BigInteger(), autoincrement=True, nullable=False),
        sa.Column("market_id", sa.Integer(), nullable=False),
        sa.Column("crop_id", sa.Integer(), nullable=False),
        sa.Column("price_date", sa.Date(), nullable=False),
        sa.Column("price_xof_per_kg", sa.Numeric(precision=10, scale=2), nullable=False),
        sa.Column("source", sa.String(), nullable=True),
        sa.ForeignKeyConstraint(["crop_id"], ["crops.id"]),
        sa.ForeignKeyConstraint(["market_id"], ["markets.id"]),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint("market_id", "crop_id", "price_date", name="uq_market_prices_market_crop_date"),
    )

    op.create_table(
        "outbreak_reports",
        sa.Column(
            "id",
            postgresql.UUID(as_uuid=True),
            server_default=sa.text("gen_random_uuid()"),
            nullable=False,
        ),
        sa.Column("diagnostic_id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("label_id", sa.Integer(), nullable=False),
        sa.Column("crop_id", sa.Integer(), nullable=True),
        sa.Column("admin_area_id", sa.Integer(), nullable=True),
        sa.Column(
            "location",
            geoalchemy2.Geography(
                geometry_type="POINT",
                srid=4326,
                from_text="ST_GeogFromText",
                name="geography",
            ),
            nullable=True,
        ),
        sa.Column("severity", sa.String(), nullable=True),
        sa.Column(
            "verified",
            sa.Boolean(),
            server_default=sa.text("false"),
            nullable=False,
        ),
        sa.Column(
            "reported_at",
            sa.DateTime(timezone=True),
            server_default=sa.func.now(),
            nullable=False,
        ),
        sa.CheckConstraint(
            "severity IS NULL OR severity IN ('low', 'medium', 'high')",
            name="chk_outbreak_reports_severity",
        ),
        sa.ForeignKeyConstraint(["admin_area_id"], ["admin_areas.id"]),
        sa.ForeignKeyConstraint(["crop_id"], ["crops.id"]),
        sa.ForeignKeyConstraint(["diagnostic_id"], ["diagnostics.id"], ondelete="CASCADE"),
        sa.ForeignKeyConstraint(["label_id"], ["diagnosis_labels.id"]),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint("diagnostic_id"),
    )
    op.create_index(
        "ix_outbreak_reports_location",
        "outbreak_reports",
        ["location"],
        unique=False,
        postgresql_using="gist",
    )
    op.create_index(
        "ix_outbreak_reports_label_reported",
        "outbreak_reports",
        ["label_id", sa.text("reported_at DESC")],
        unique=False,
    )

    op.create_table(
        "alerts",
        sa.Column(
            "id",
            postgresql.UUID(as_uuid=True),
            server_default=sa.text("gen_random_uuid()"),
            nullable=False,
        ),
        sa.Column("type", sa.String(), nullable=False),
        sa.Column(
            "severity",
            sa.String(),
            server_default="info",
            nullable=False,
        ),
        sa.Column("title", sa.String(), nullable=False),
        sa.Column("body", sa.Text(), nullable=False),
        sa.Column("admin_area_id", sa.Integer(), nullable=True),
        sa.Column("crop_id", sa.Integer(), nullable=True),
        sa.Column(
            "starts_at",
            sa.DateTime(timezone=True),
            server_default=sa.func.now(),
            nullable=False,
        ),
        sa.Column("ends_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("created_by", postgresql.UUID(as_uuid=True), nullable=True),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            server_default=sa.func.now(),
            nullable=False,
        ),
        sa.CheckConstraint(
            "type IN ('weather', 'pest', 'disease', 'market', 'advisory', 'system')",
            name="chk_alerts_type",
        ),
        sa.CheckConstraint(
            "severity IN ('info', 'warning', 'critical')",
            name="chk_alerts_severity",
        ),
        sa.ForeignKeyConstraint(["admin_area_id"], ["admin_areas.id"]),
        sa.ForeignKeyConstraint(["created_by"], ["users.id"]),
        sa.ForeignKeyConstraint(["crop_id"], ["crops.id"]),
        sa.PrimaryKeyConstraint("id"),
    )

    op.create_table(
        "notifications",
        sa.Column(
            "id",
            postgresql.UUID(as_uuid=True),
            server_default=sa.text("gen_random_uuid()"),
            nullable=False,
        ),
        sa.Column("user_id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("alert_id", postgresql.UUID(as_uuid=True), nullable=True),
        sa.Column("channel", sa.String(), nullable=False),
        sa.Column("title", sa.String(), nullable=False),
        sa.Column("body", sa.Text(), nullable=False),
        sa.Column(
            "status",
            sa.String(),
            server_default="queued",
            nullable=False,
        ),
        sa.Column("sent_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("read_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            server_default=sa.func.now(),
            nullable=False,
        ),
        sa.CheckConstraint(
            "channel IN ('push', 'sms', 'whatsapp', 'in_app')",
            name="chk_notifications_channel",
        ),
        sa.CheckConstraint(
            "status IN ('queued', 'sent', 'failed', 'read')",
            name="chk_notifications_status",
        ),
        sa.ForeignKeyConstraint(["alert_id"], ["alerts.id"], ondelete="SET NULL"),
        sa.ForeignKeyConstraint(["user_id"], ["users.id"], ondelete="CASCADE"),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index(
        "ix_notifications_user_created_at_desc",
        "notifications",
        ["user_id", sa.text("created_at DESC")],
        unique=False,
    )

    op.create_table(
        "plans",
        sa.Column("id", sa.Integer(), autoincrement=True, nullable=False),
        sa.Column("code", sa.String(), nullable=False),
        sa.Column("name", sa.String(), nullable=False),
        sa.Column("audience", sa.String(), nullable=False),
        sa.Column("billing_model", sa.String(), nullable=False),
        sa.Column("interval", sa.String(), nullable=True),
        sa.Column("price_xof", sa.Integer(), server_default=sa.text("0"), nullable=False),
        sa.Column(
            "quotas",
            postgresql.JSONB(astext_type=sa.Text()),
            server_default=sa.text("'{}'::jsonb"),
            nullable=False,
        ),
        sa.Column(
            "features",
            postgresql.JSONB(astext_type=sa.Text()),
            server_default=sa.text("'{}'::jsonb"),
            nullable=False,
        ),
        sa.Column(
            "is_active",
            sa.Boolean(),
            server_default=sa.text("true"),
            nullable=False,
        ),
        sa.CheckConstraint(
            "audience IN ('farmer', 'organization', 'government')",
            name="chk_plans_audience",
        ),
        sa.CheckConstraint(
            "billing_model IN ('free', 'subscription', 'pay_per_use', 'license')",
            name="chk_plans_billing_model",
        ),
        sa.CheckConstraint(
            "interval IS NULL OR interval IN ('month', 'quarter', 'year')",
            name="chk_plans_interval",
        ),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint("code"),
    )

    op.create_table(
        "subscriptions",
        sa.Column(
            "id",
            postgresql.UUID(as_uuid=True),
            server_default=sa.text("gen_random_uuid()"),
            nullable=False,
        ),
        sa.Column("user_id", postgresql.UUID(as_uuid=True), nullable=True),
        sa.Column("organization_id", postgresql.UUID(as_uuid=True), nullable=True),
        sa.Column("plan_id", sa.Integer(), nullable=False),
        sa.Column("status", sa.String(), nullable=False),
        sa.Column("current_period_start", sa.DateTime(timezone=True), nullable=False),
        sa.Column("current_period_end", sa.DateTime(timezone=True), nullable=True),
        sa.Column(
            "auto_renew",
            sa.Boolean(),
            server_default=sa.text("false"),
            nullable=False,
        ),
        sa.Column("canceled_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            server_default=sa.func.now(),
            nullable=False,
        ),
        sa.Column(
            "updated_at",
            sa.DateTime(timezone=True),
            server_default=sa.func.now(),
            nullable=False,
        ),
        sa.CheckConstraint(
            "status IN ('trialing', 'active', 'past_due', 'canceled', 'expired')",
            name="chk_subscriptions_status",
        ),
        sa.CheckConstraint(
            "num_nonnulls(user_id, organization_id) = 1",
            name="chk_subscriptions_owner",
        ),
        sa.ForeignKeyConstraint(["organization_id"], ["organizations.id"]),
        sa.ForeignKeyConstraint(["plan_id"], ["plans.id"]),
        sa.ForeignKeyConstraint(["user_id"], ["users.id"]),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index(
        "ix_subscriptions_user_status",
        "subscriptions",
        ["user_id", "status"],
        unique=False,
    )
    op.create_index(
        "ix_subscriptions_org_status",
        "subscriptions",
        ["organization_id", "status"],
        unique=False,
    )

    op.create_table(
        "payments",
        sa.Column(
            "id",
            postgresql.UUID(as_uuid=True),
            server_default=sa.text("gen_random_uuid()"),
            nullable=False,
        ),
        sa.Column("user_id", postgresql.UUID(as_uuid=True), nullable=True),
        sa.Column("organization_id", postgresql.UUID(as_uuid=True), nullable=True),
        sa.Column("subscription_id", postgresql.UUID(as_uuid=True), nullable=True),
        sa.Column("plan_id", sa.Integer(), nullable=True),
        sa.Column("provider", sa.String(), nullable=False),
        sa.Column("provider_ref", sa.String(), nullable=True),
        sa.Column("idempotency_key", sa.String(), nullable=False),
        sa.Column("purpose", sa.String(), nullable=False),
        sa.Column("amount_xof", sa.Integer(), nullable=False),
        sa.Column(
            "currency",
            sa.String(),
            server_default="XOF",
            nullable=False,
        ),
        sa.Column("payer_phone", sa.String(), nullable=True),
        sa.Column(
            "status",
            sa.String(),
            server_default="pending",
            nullable=False,
        ),
        sa.Column("raw", postgresql.JSONB(astext_type=sa.Text()), nullable=True),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            server_default=sa.func.now(),
            nullable=False,
        ),
        sa.Column("paid_at", sa.DateTime(timezone=True), nullable=True),
        sa.CheckConstraint(
            "provider IN ('orange_money', 'airtel_money', 'moov_money', 'mynita', 'aggregator', 'manual')",
            name="chk_payments_provider",
        ),
        sa.CheckConstraint(
            "purpose IN ('subscription', 'top_up', 'license')",
            name="chk_payments_purpose",
        ),
        sa.CheckConstraint("amount_xof > 0", name="chk_payments_amount_xof_positive"),
        sa.CheckConstraint(
            "status IN ('pending', 'succeeded', 'failed', 'refunded')",
            name="chk_payments_status",
        ),
        sa.ForeignKeyConstraint(["organization_id"], ["organizations.id"]),
        sa.ForeignKeyConstraint(["plan_id"], ["plans.id"]),
        sa.ForeignKeyConstraint(["subscription_id"], ["subscriptions.id"]),
        sa.ForeignKeyConstraint(["user_id"], ["users.id"]),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint("idempotency_key"),
        sa.UniqueConstraint("provider", "provider_ref", name="uq_payments_provider_provider_ref"),
    )
    op.create_index(
        "ix_payments_user_created_at_desc",
        "payments",
        ["user_id", sa.text("created_at DESC")],
        unique=False,
    )
    op.create_index(
        "ix_payments_status_created_at",
        "payments",
        ["status", "created_at"],
        unique=False,
    )

    op.create_table(
        "payment_events",
        sa.Column("id", sa.BigInteger(), autoincrement=True, nullable=False),
        sa.Column("provider", sa.String(), nullable=False),
        sa.Column("event_id", sa.String(), nullable=False),
        sa.Column("payload", postgresql.JSONB(astext_type=sa.Text()), nullable=False),
        sa.Column("signature_valid", sa.Boolean(), nullable=False),
        sa.Column("processed_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            server_default=sa.func.now(),
            nullable=False,
        ),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint("provider", "event_id", name="uq_payment_events_provider_event"),
    )

    op.create_table(
        "usage_records",
        sa.Column("id", sa.BigInteger(), autoincrement=True, nullable=False),
        sa.Column("subscription_id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("metric", sa.String(), nullable=False),
        sa.Column("quantity", sa.Integer(), server_default=sa.text("1"), nullable=False),
        sa.Column("period", sa.Date(), nullable=False),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            server_default=sa.func.now(),
            nullable=False,
        ),
        sa.CheckConstraint(
            "metric IN ('diagnostic', 'llm_message', 'video_analysis', 'storage_mb')",
            name="chk_usage_records_metric",
        ),
        sa.ForeignKeyConstraint(["subscription_id"], ["subscriptions.id"], ondelete="CASCADE"),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index(
        "ix_usage_records_sub_metric_period",
        "usage_records",
        ["subscription_id", "metric", "period"],
        unique=False,
    )

    op.create_table(
        "license_keys",
        sa.Column(
            "id",
            postgresql.UUID(as_uuid=True),
            server_default=sa.text("gen_random_uuid()"),
            nullable=False,
        ),
        sa.Column("organization_id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("plan_id", sa.Integer(), nullable=False),
        sa.Column("key_hash", sa.String(), nullable=False),
        sa.Column("max_activations", sa.Integer(), server_default=sa.text("1"), nullable=False),
        sa.Column("expires_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column(
            "status",
            sa.String(),
            server_default="active",
            nullable=False,
        ),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            server_default=sa.func.now(),
            nullable=False,
        ),
        sa.CheckConstraint(
            "status IN ('active', 'revoked', 'expired')",
            name="chk_license_keys_status",
        ),
        sa.ForeignKeyConstraint(["organization_id"], ["organizations.id"]),
        sa.ForeignKeyConstraint(["plan_id"], ["plans.id"]),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint("key_hash"),
    )

    op.create_table(
        "license_activations",
        sa.Column(
            "id",
            postgresql.UUID(as_uuid=True),
            server_default=sa.text("gen_random_uuid()"),
            nullable=False,
        ),
        sa.Column("license_id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("device_fingerprint", sa.String(), nullable=False),
        sa.Column(
            "activated_at",
            sa.DateTime(timezone=True),
            server_default=sa.func.now(),
            nullable=False,
        ),
        sa.Column("revoked_at", sa.DateTime(timezone=True), nullable=True),
        sa.ForeignKeyConstraint(["license_id"], ["license_keys.id"], ondelete="CASCADE"),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint(
            "license_id", "device_fingerprint", name="uq_license_activations_license_device"
        ),
    )

    op.create_table(
        "audit_logs",
        sa.Column("id", sa.BigInteger(), autoincrement=True, nullable=False),
        sa.Column("user_id", postgresql.UUID(as_uuid=True), nullable=True),
        sa.Column("action", sa.String(), nullable=False),
        sa.Column("entity", sa.String(), nullable=True),
        sa.Column("entity_id", sa.String(), nullable=True),
        sa.Column("ip", postgresql.INET(), nullable=True),
        sa.Column("meta", postgresql.JSONB(astext_type=sa.Text()), nullable=True),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            server_default=sa.func.now(),
            nullable=False,
        ),
        sa.ForeignKeyConstraint(["user_id"], ["users.id"], ondelete="SET NULL"),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index(
        "ix_audit_logs_user_created_at_desc",
        "audit_logs",
        ["user_id", sa.text("created_at DESC")],
        unique=False,
    )
    op.create_index(
        "ix_audit_logs_entity_entity_id",
        "audit_logs",
        ["entity", "entity_id"],
        unique=False,
    )

    op.create_table(
        "api_keys",
        sa.Column(
            "id",
            postgresql.UUID(as_uuid=True),
            server_default=sa.text("gen_random_uuid()"),
            nullable=False,
        ),
        sa.Column("organization_id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("name", sa.String(), nullable=False),
        sa.Column("key_hash", sa.String(), nullable=False),
        sa.Column(
            "scopes",
            postgresql.ARRAY(sa.String()),
            server_default=sa.text("'{}'"),
            nullable=False,
        ),
        sa.Column("last_used_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("revoked_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            server_default=sa.func.now(),
            nullable=False,
        ),
        sa.ForeignKeyConstraint(["organization_id"], ["organizations.id"], ondelete="CASCADE"),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint("key_hash"),
    )

    tables_with_updated_at = [
        "users",
        "organizations",
        "farms",
        "plots",
        "crop_cycles",
        "farm_activities",
        "harvests",
        "diagnostics",
        "subscriptions",
    ]
    for table_name in tables_with_updated_at:
        op.execute(
            f"CREATE TRIGGER trg_set_updated_at_{table_name} "
            f"BEFORE UPDATE ON {table_name} "
            f"FOR EACH ROW "
            f"EXECUTE FUNCTION set_updated_at();"
        )

    op.execute(
        "CREATE OR REPLACE VIEW v_cycle_yield AS "
        "SELECT "
        "cc.id AS crop_cycle_id, "
        "cc.crop_id AS crop_id, "
        "cc.plot_id AS plot_id, "
        "p.area_ha AS area_ha, "
        "COALESCE(SUM(h.quantity_kg), 0) AS total_kg, "
        "ROUND(COALESCE(SUM(h.quantity_kg), 0) / NULLIF(p.area_ha, 0), 1) AS yield_kg_per_ha "
        "FROM crop_cycles cc "
        "JOIN plots p ON cc.plot_id = p.id "
        "LEFT JOIN harvests h ON cc.id = h.crop_cycle_id AND h.deleted_at IS NULL "
        "WHERE cc.deleted_at IS NULL "
        "GROUP BY cc.id, cc.crop_id, cc.plot_id, p.area_ha;"
    )


def downgrade() -> None:
    op.execute("DROP VIEW IF EXISTS v_cycle_yield;")

    tables_with_updated_at = [
        "users",
        "organizations",
        "farms",
        "plots",
        "crop_cycles",
        "farm_activities",
        "harvests",
        "diagnostics",
        "subscriptions",
    ]
    for table_name in tables_with_updated_at:
        op.execute(f"DROP TRIGGER IF EXISTS trg_set_updated_at_{table_name} ON {table_name};")

    op.execute("DROP FUNCTION IF EXISTS set_updated_at();")

    tables_in_reverse = [
        "api_keys",
        "audit_logs",
        "license_activations",
        "license_keys",
        "usage_records",
        "payment_events",
        "payments",
        "subscriptions",
        "plans",
        "notifications",
        "alerts",
        "outbreak_reports",
        "market_prices",
        "markets",
        "satellite_indices",
        "weather_data",
        "chat_messages",
        "chat_sessions",
        "knowledge_chunks",
        "knowledge_documents",
        "training_samples",
        "recommendation_feedback",
        "recommendations",
        "expert_reviews",
        "diagnostic_predictions",
        "diagnostic_media",
        "diagnostics",
        "label_crops",
        "diagnosis_labels",
        "ai_models",
        "media_files",
        "harvests",
        "farm_activities",
        "crop_cycles",
        "crops",
        "plots",
        "farms",
        "organization_members",
        "organizations",
        "consents",
        "refresh_tokens",
        "devices",
        "otp_codes",
        "users",
        "admin_areas",
    ]

    for tbl in tables_in_reverse:
        op.drop_table(tbl)
