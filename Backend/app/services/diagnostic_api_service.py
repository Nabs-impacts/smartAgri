import uuid
from datetime import UTC, date, datetime
from decimal import Decimal

from sqlalchemy import and_, func, or_, select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.core.errors import ConflictException, NotFoundException, ValidationException
from app.core.geo import geojson_to_postgis_point, postgis_to_geojson
from app.core.logging import get_logger
from app.core.pagination import decode_cursor, encode_cursor
from app.db.models.billing import UsageRecord
from app.db.models.farming import Crop, CropCycle, Farm, Plot
from app.db.models.identity import User
from app.db.models.media_ai import (
    DiagnosisLabel,
    Diagnostic,
    DiagnosticMedia,
    DiagnosticPrediction,
    MediaFile,
    Recommendation,
)
from app.schemas.diagnostic import (
    DiagnosticCreateRequest,
    DiagnosticDetailResponse,
    DiagnosticLabelBrief,
    DiagnosticMediaResponse,
    DiagnosticPredictionResponse,
    DiagnosticResponse,
)
from app.schemas.recommendation import RecommendationResponse
from app.services.access_service import can_read_farm
from app.services.quota_service import ensure_monthly_quota
from app.services.storage_service import storage_service
from app.services.subscription_service import subscription_service
from app.workers.tasks_diagnostic import run_diagnostic

logger = get_logger("diagnostic_api_service")

_ON_DEVICE_SOURCE = "on_device"
_ON_DEVICE_RANK = 9
_VIDEO_KIND = "video"


def _localized_name(label: DiagnosisLabel, language: str) -> str:
    if language == "ha" and label.name_ha:
        return label.name_ha
    if language == "dje" and label.name_dje:
        return label.name_dje
    return label.name_fr


def _label_brief(label: DiagnosisLabel, language: str) -> DiagnosticLabelBrief:
    return DiagnosticLabelBrief(
        id=label.id,
        code=label.code,
        kind=label.kind,
        name=_localized_name(label, language),
    )


def _diagnostic_to_response(diagnostic: Diagnostic) -> DiagnosticResponse:
    return DiagnosticResponse(
        id=diagnostic.id,
        status=diagnostic.status,
        error=diagnostic.error,
        confidence=diagnostic.confidence,
        severity=diagnostic.severity,
        crop_id=diagnostic.crop_id,
        plot_id=diagnostic.plot_id,
        crop_cycle_id=diagnostic.crop_cycle_id,
        source=diagnostic.source,
        user_note=diagnostic.user_note,
        location=postgis_to_geojson(diagnostic.location),
        created_at=diagnostic.created_at,
        updated_at=diagnostic.updated_at,
        completed_at=diagnostic.completed_at,
    )


def _parse_uuid_cursor(cursor: str) -> tuple[datetime, uuid.UUID]:
    cursor_dt, cursor_id = decode_cursor(cursor)
    try:
        cursor_uuid = uuid.UUID(cursor_id)
    except (ValueError, TypeError) as err:
        raise ValidationException("Curseur de pagination invalide.") from err
    return cursor_dt, cursor_uuid


def _month_start() -> date:
    return datetime.now(UTC).date().replace(day=1)


def _server_prediction_filter():
    return or_(
        DiagnosticPrediction.bbox.is_(None),
        DiagnosticPrediction.bbox["source"].astext.is_distinct_from(
            _ON_DEVICE_SOURCE
        ),
    )


class DiagnosticApiService:
    async def _find_by_id(
        self,
        session: AsyncSession,
        diagnostic_id: uuid.UUID,
    ) -> Diagnostic | None:
        return (
            await session.execute(
                select(Diagnostic).where(Diagnostic.id == diagnostic_id)
            )
        ).scalar_one_or_none()

    def _check_existing(
        self,
        existing: Diagnostic,
        user_id: uuid.UUID,
    ) -> Diagnostic:
        if existing.user_id != user_id:
            raise ConflictException(
                "Une ressource avec cet identifiant existe déjà."
            )
        if existing.deleted_at is not None:
            raise ConflictException("Cette ressource a été supprimée.")
        return existing

    async def _load_media(
        self,
        session: AsyncSession,
        user_id: uuid.UUID,
        media_ids: list[uuid.UUID],
    ) -> list[MediaFile]:
        rows = list(
            (
                await session.execute(
                    select(MediaFile).where(MediaFile.id.in_(media_ids))
                )
            )
            .scalars()
            .all()
        )
        by_id = {media.id: media for media in rows}
        medias: list[MediaFile] = []
        for media_id in media_ids:
            media = by_id.get(media_id)
            if (
                media is None
                or media.deleted_at is not None
                or media.owner_id != user_id
            ):
                raise NotFoundException("Média introuvable.")
            medias.append(media)

        for media in medias:
            if media.upload_status != "uploaded":
                raise ConflictException(
                    "Le média n'a pas fini d'être téléversé."
                )
        for media in medias:
            if media.kind == "audio":
                raise ValidationException(
                    "Les médias audio ne sont pas acceptés pour un diagnostic."
                )
        return medias

    async def _load_owned_plot(
        self,
        session: AsyncSession,
        user_id: uuid.UUID,
        plot_id: uuid.UUID,
    ) -> None:
        found = (
            await session.execute(
                select(Plot.id)
                .join(Farm, Plot.farm_id == Farm.id)
                .where(
                    Plot.id == plot_id,
                    Plot.deleted_at.is_(None),
                    Farm.deleted_at.is_(None),
                    Farm.owner_id == user_id,
                )
            )
        ).scalar_one_or_none()
        if found is None:
            raise NotFoundException("Parcelle introuvable.")

    async def _load_owned_cycle(
        self,
        session: AsyncSession,
        user_id: uuid.UUID,
        cycle_id: uuid.UUID,
    ) -> CropCycle:
        cycle = (
            await session.execute(
                select(CropCycle)
                .join(Plot, CropCycle.plot_id == Plot.id)
                .join(Farm, Plot.farm_id == Farm.id)
                .where(
                    CropCycle.id == cycle_id,
                    CropCycle.deleted_at.is_(None),
                    Plot.deleted_at.is_(None),
                    Farm.deleted_at.is_(None),
                    Farm.owner_id == user_id,
                )
            )
        ).scalar_one_or_none()
        if cycle is None:
            raise NotFoundException("Cycle de culture introuvable.")
        return cycle

    async def _load_label_by_code(
        self,
        session: AsyncSession,
        code: str,
    ) -> DiagnosisLabel:
        label = (
            await session.execute(
                select(DiagnosisLabel).where(DiagnosisLabel.code == code)
            )
        ).scalar_one_or_none()
        if label is None:
            raise ValidationException("Code de diagnostic inconnu.")
        return label

    async def _enqueue(self, diagnostic_id: uuid.UUID) -> None:
        try:
            run_diagnostic.delay(str(diagnostic_id))
        except Exception:
            logger.exception(
                "diagnostic_enqueue_failed",
                diagnostic_id=str(diagnostic_id),
            )

    async def create_diagnostic(
        self,
        session: AsyncSession,
        user: User,
        data: DiagnosticCreateRequest,
    ) -> tuple[DiagnosticResponse, bool]:
        if data.id is not None:
            existing = await self._find_by_id(session, data.id)
            if existing is not None:
                self._check_existing(existing, user.id)
                return _diagnostic_to_response(existing), False

        medias = await self._load_media(session, user.id, data.media_ids)

        cycle = None
        if data.plot_id is not None:
            await self._load_owned_plot(session, user.id, data.plot_id)
        if data.crop_cycle_id is not None:
            cycle = await self._load_owned_cycle(
                session, user.id, data.crop_cycle_id
            )
        if (
            cycle is not None
            and data.plot_id is not None
            and cycle.plot_id != data.plot_id
        ):
            raise ValidationException(
                "Le cycle de culture ne correspond pas à la parcelle."
            )

        crop_id = data.crop_id
        if crop_id is None and cycle is not None:
            crop_id = cycle.crop_id
        if crop_id is not None:
            crop = await session.get(Crop, crop_id)
            if crop is None:
                raise NotFoundException("Culture introuvable.")

        on_device_label = None
        if data.on_device_result is not None:
            on_device_label = await self._load_label_by_code(
                session, data.on_device_result.label_code
            )

        await ensure_monthly_quota(session, user, "diagnostic")
        if any(media.kind == _VIDEO_KIND for media in medias):
            await ensure_monthly_quota(session, user, "video_analysis")

        subscription, _ = await subscription_service.get_effective_subscription(
            session, user.id
        )

        diagnostic_id = data.id or uuid.uuid4()
        location = None
        if data.lat is not None and data.lng is not None:
            location = geojson_to_postgis_point(
                {"type": "Point", "coordinates": [data.lng, data.lat]}
            )

        diagnostic = Diagnostic(
            id=diagnostic_id,
            user_id=user.id,
            plot_id=data.plot_id,
            crop_cycle_id=data.crop_cycle_id,
            crop_id=crop_id,
            source=data.source or "server",
            status="pending",
            user_note=data.user_note,
            location=location,
        )
        session.add(diagnostic)
        await session.flush()

        for media in medias:
            session.add(
                DiagnosticMedia(
                    diagnostic_id=diagnostic.id,
                    media_id=media.id,
                )
            )

        if subscription is not None:
            period = _month_start()
            session.add(
                UsageRecord(
                    subscription_id=subscription.id,
                    metric="diagnostic",
                    quantity=1,
                    period=period,
                )
            )
            if any(media.kind == _VIDEO_KIND for media in medias):
                session.add(
                    UsageRecord(
                        subscription_id=subscription.id,
                        metric="video_analysis",
                        quantity=1,
                        period=period,
                    )
                )

        if data.on_device_result is not None and on_device_label is not None:
            session.add(
                DiagnosticPrediction(
                    diagnostic_id=diagnostic.id,
                    label_id=on_device_label.id,
                    confidence=Decimal(str(data.on_device_result.confidence)),
                    rank=_ON_DEVICE_RANK,
                    bbox={"source": _ON_DEVICE_SOURCE},
                )
            )

        try:
            await session.commit()
        except IntegrityError:
            await session.rollback()
            if data.id is not None:
                existing = await self._find_by_id(session, data.id)
                if existing is not None:
                    self._check_existing(existing, user.id)
                    return _diagnostic_to_response(existing), False
            raise

        await session.refresh(diagnostic)
        await self._enqueue(diagnostic.id)
        return _diagnostic_to_response(diagnostic), True

    async def list_diagnostics(
        self,
        session: AsyncSession,
        user_id: uuid.UUID,
        plot_id: uuid.UUID | None = None,
        crop_id: int | None = None,
        status: str | None = None,
        from_date: date | None = None,
        to_date: date | None = None,
        limit: int = 20,
        cursor: str | None = None,
    ) -> tuple[list[DiagnosticResponse], str | None]:
        stmt = select(Diagnostic).where(
            Diagnostic.user_id == user_id,
            Diagnostic.deleted_at.is_(None),
        )
        if plot_id is not None:
            stmt = stmt.where(Diagnostic.plot_id == plot_id)
        if crop_id is not None:
            stmt = stmt.where(Diagnostic.crop_id == crop_id)
        if status is not None:
            stmt = stmt.where(Diagnostic.status == status)
        if from_date is not None:
            stmt = stmt.where(func.date(Diagnostic.created_at) >= from_date)
        if to_date is not None:
            stmt = stmt.where(func.date(Diagnostic.created_at) <= to_date)

        if cursor:
            cursor_dt, cursor_uuid = _parse_uuid_cursor(cursor)
            stmt = stmt.where(
                or_(
                    Diagnostic.created_at < cursor_dt,
                    and_(
                        Diagnostic.created_at == cursor_dt,
                        Diagnostic.id < cursor_uuid,
                    ),
                )
            )

        stmt = stmt.order_by(
            Diagnostic.created_at.desc(), Diagnostic.id.desc()
        ).limit(limit + 1)
        rows = list((await session.scalars(stmt)).all())
        if len(rows) > limit:
            items = rows[:limit]
            next_cursor = encode_cursor(items[-1].created_at, items[-1].id)
        else:
            items = rows
            next_cursor = None
        return [_diagnostic_to_response(item) for item in items], next_cursor

    async def _load_readable(
        self,
        session: AsyncSession,
        user: User,
        diagnostic_id: uuid.UUID,
    ) -> Diagnostic:
        diagnostic = (
            await session.execute(
                select(Diagnostic).where(
                    Diagnostic.id == diagnostic_id,
                    Diagnostic.deleted_at.is_(None),
                )
            )
        ).scalar_one_or_none()
        if diagnostic is None:
            raise NotFoundException("Diagnostic introuvable.")

        if diagnostic.user_id == user.id:
            return diagnostic

        if user.role == "agronomist" and diagnostic.status == "needs_review":
            return diagnostic

        if diagnostic.plot_id is not None:
            row = (
                await session.execute(
                    select(Farm)
                    .join(Plot, Plot.farm_id == Farm.id)
                    .where(
                        Plot.id == diagnostic.plot_id,
                        Plot.deleted_at.is_(None),
                        Farm.deleted_at.is_(None),
                    )
                )
            ).scalar_one_or_none()
            if row is not None and await can_read_farm(session, user.id, row):
                return diagnostic

        raise NotFoundException("Diagnostic introuvable.")

    async def _load_owned(
        self,
        session: AsyncSession,
        user_id: uuid.UUID,
        diagnostic_id: uuid.UUID,
    ) -> Diagnostic:
        diagnostic = (
            await session.execute(
                select(Diagnostic).where(
                    Diagnostic.id == diagnostic_id,
                    Diagnostic.deleted_at.is_(None),
                )
            )
        ).scalar_one_or_none()
        if diagnostic is None or diagnostic.user_id != user_id:
            raise NotFoundException("Diagnostic introuvable.")
        return diagnostic

    async def get_diagnostic(
        self,
        session: AsyncSession,
        user: User,
        diagnostic_id: uuid.UUID,
    ) -> DiagnosticDetailResponse:
        diagnostic = await self._load_readable(session, user, diagnostic_id)

        media_rows = list(
            (
                await session.execute(
                    select(MediaFile)
                    .join(
                        DiagnosticMedia,
                        DiagnosticMedia.media_id == MediaFile.id,
                    )
                    .where(
                        DiagnosticMedia.diagnostic_id == diagnostic.id,
                        MediaFile.upload_status == "uploaded",
                        MediaFile.deleted_at.is_(None),
                    )
                    .order_by(MediaFile.created_at)
                )
            )
            .scalars()
            .all()
        )
        media = [
            DiagnosticMediaResponse(
                id=item.id,
                kind=item.kind,
                mime_type=item.mime_type,
                url=storage_service.presign_get(item.storage_key)["url"],
            )
            for item in media_rows
        ]

        prediction_rows = list(
            (
                await session.execute(
                    select(DiagnosticPrediction)
                    .options(selectinload(DiagnosticPrediction.label))
                    .where(
                        DiagnosticPrediction.diagnostic_id == diagnostic.id,
                        _server_prediction_filter(),
                    )
                    .order_by(DiagnosticPrediction.rank)
                )
            )
            .scalars()
            .all()
        )
        predictions = [
            DiagnosticPredictionResponse(
                rank=row.rank,
                confidence=row.confidence,
                label=_label_brief(row.label, user.language),
            )
            for row in prediction_rows
        ]

        on_device = (
            await session.execute(
                select(DiagnosticPrediction)
                .options(selectinload(DiagnosticPrediction.label))
                .where(
                    DiagnosticPrediction.diagnostic_id == diagnostic.id,
                    DiagnosticPrediction.bbox["source"].astext
                    == _ON_DEVICE_SOURCE,
                )
                .order_by(DiagnosticPrediction.rank)
                .limit(1)
            )
        ).scalar_one_or_none()
        on_device_prediction = None
        if on_device is not None:
            on_device_prediction = DiagnosticPredictionResponse(
                rank=on_device.rank,
                confidence=on_device.confidence,
                label=_label_brief(on_device.label, user.language),
            )

        recommendation_row = (
            await session.execute(
                select(Recommendation)
                .where(
                    Recommendation.diagnostic_id == diagnostic.id,
                    Recommendation.status == "published",
                )
                .order_by(Recommendation.created_at.desc())
                .limit(1)
            )
        ).scalar_one_or_none()
        recommendation = None
        if recommendation_row is not None:
            recommendation = RecommendationResponse(
                id=recommendation_row.id,
                diagnostic_id=recommendation_row.diagnostic_id,
                plot_id=recommendation_row.plot_id,
                crop_cycle_id=recommendation_row.crop_cycle_id,
                source=recommendation_row.source,
                language=recommendation_row.language,
                title=recommendation_row.title,
                body=recommendation_row.body,
                steps=recommendation_row.steps,
                citations=recommendation_row.citations,
                status=recommendation_row.status,
                validated_by=recommendation_row.validated_by,
                created_at=recommendation_row.created_at,
            )

        base = _diagnostic_to_response(diagnostic)
        return DiagnosticDetailResponse(
            **base.model_dump(),
            media=media,
            predictions=predictions,
            on_device_prediction=on_device_prediction,
            recommendation=recommendation,
        )

    async def retry_diagnostic(
        self,
        session: AsyncSession,
        user_id: uuid.UUID,
        diagnostic_id: uuid.UUID,
    ) -> DiagnosticResponse:
        diagnostic = await self._load_owned(session, user_id, diagnostic_id)
        if diagnostic.status != "failed":
            raise ConflictException(
                "Seul un diagnostic en échec peut être relancé."
            )
        diagnostic.status = "pending"
        diagnostic.error = None
        diagnostic.completed_at = None
        await session.commit()
        await session.refresh(diagnostic)
        await self._enqueue(diagnostic.id)
        return _diagnostic_to_response(diagnostic)

    async def delete_diagnostic(
        self,
        session: AsyncSession,
        user_id: uuid.UUID,
        diagnostic_id: uuid.UUID,
    ) -> None:
        diagnostic = await self._load_owned(session, user_id, diagnostic_id)
        diagnostic.deleted_at = datetime.now(UTC)
        await session.commit()


diagnostic_api_service = DiagnosticApiService()
