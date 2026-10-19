import hashlib
import json
from typing import Any

from sqlalchemy import func, null, select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.db.models.billing import Plan
from app.db.models.farming import Crop
from app.db.models.identity import AdminArea
from app.db.models.media_ai import DiagnosisLabel
from app.schemas.catalog import (
    AdminAreaResponse,
    CropResponse,
    DiagnosisLabelResponse,
    PlanResponse,
)


class CatalogService:
    @staticmethod
    def compute_etag(items: list[Any]) -> str:
        dumped = json.dumps(
            [item.model_dump(mode="json") for item in items],
            sort_keys=True,
            separators=(",", ":"),
        )
        digest = hashlib.sha256(dumped.encode("utf-8")).hexdigest()
        return f'"{digest}"'

    async def list_crops(self, session: AsyncSession) -> list[CropResponse]:
        stmt = select(Crop).order_by(Crop.id)
        result = await session.execute(stmt)
        crops = result.scalars().all()
        return [CropResponse.model_validate(crop) for crop in crops]

    async def list_diagnosis_labels(
        self,
        session: AsyncSession,
        crop_id: int | None = None,
    ) -> list[DiagnosisLabelResponse]:
        stmt = (
            select(DiagnosisLabel)
            .options(selectinload(DiagnosisLabel.crops))
            .order_by(DiagnosisLabel.id)
        )
        if crop_id is not None:
            stmt = stmt.where(DiagnosisLabel.crops.any(Crop.id == crop_id))

        result = await session.execute(stmt)
        labels = result.scalars().all()

        responses: list[DiagnosisLabelResponse] = []
        for label in labels:
            crop_ids = [crop.id for crop in label.crops]
            responses.append(
                DiagnosisLabelResponse(
                    id=label.id,
                    code=label.code,
                    kind=label.kind,
                    name_fr=label.name_fr,
                    name_ha=label.name_ha,
                    name_dje=label.name_dje,
                    description=label.description,
                    guideline=label.guideline,
                    crop_ids=crop_ids,
                )
            )
        return responses

    async def list_admin_areas(
        self,
        session: AsyncSession,
        parent_id: int | None = None,
        level: str | None = None,
        include_geom: bool = False,
    ) -> list[AdminAreaResponse]:
        if include_geom:
            stmt = select(
                AdminArea,
                func.ST_AsGeoJSON(AdminArea.geom).label("geojson"),
            )
        else:
            stmt = select(AdminArea, null().label("geojson"))

        if parent_id is not None:
            stmt = stmt.where(AdminArea.parent_id == parent_id)
        if level is not None:
            stmt = stmt.where(AdminArea.level == level)

        stmt = stmt.order_by(AdminArea.id)
        result = await session.execute(stmt)
        rows = result.all()

        responses: list[AdminAreaResponse] = []
        for area, geojson_str in rows:
            geom_data = json.loads(geojson_str) if geojson_str else None
            responses.append(
                AdminAreaResponse(
                    id=area.id,
                    parent_id=area.parent_id,
                    level=area.level,
                    name=area.name,
                    code=area.code,
                    geom=geom_data,
                )
            )
        return responses

    async def list_plans(
        self,
        session: AsyncSession,
        audience: str | None = None,
    ) -> list[PlanResponse]:
        stmt = select(Plan)
        if audience is not None:
            stmt = stmt.where(Plan.audience == audience)
        stmt = stmt.order_by(Plan.id)
        result = await session.execute(stmt)
        plans = result.scalars().all()
        return [PlanResponse.model_validate(plan) for plan in plans]


catalog_service = CatalogService()
