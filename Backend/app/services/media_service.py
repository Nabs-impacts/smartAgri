import math
import uuid
from datetime import UTC, datetime
from typing import Any

from botocore.exceptions import ClientError
from sqlalchemy import select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import settings
from app.core.errors import (
    ConflictException,
    NotFoundException,
    UploadInvalidException,
    ValidationException,
)
from app.core.geo import geojson_to_postgis_point, postgis_to_geojson
from app.core.rate_limit import get_redis_client
from app.db.models.farming import CropCycle, Farm, Plot
from app.db.models.identity import User
from app.db.models.media_ai import MediaFile
from app.schemas.media import (
    MediaCompleteRequest,
    MediaResponse,
    MediaUploadInstructions,
    MediaUploadPart,
    MediaUploadRequest,
    MediaUploadResponse,
)
from app.services.quota_service import ensure_storage_quota
from app.services.storage_service import storage_service

_MULTIPART_TTL_SECONDS = 86400

_ALLOWED_MIME = {
    "image": settings.ALLOWED_IMAGE_MIME,
    "video": settings.ALLOWED_VIDEO_MIME,
    "audio": settings.ALLOWED_AUDIO_MIME,
}
_MAX_BYTES = {
    "image": settings.MAX_IMAGE_BYTES,
    "video": settings.MAX_VIDEO_BYTES,
    "audio": settings.MAX_AUDIO_BYTES,
}
_MAX_DURATION = {
    "video": settings.MAX_VIDEO_SECONDS,
    "audio": settings.MAX_AUDIO_SECONDS,
}
_EXTENSIONS = {
    "image/jpeg": "jpg",
    "image/png": "png",
    "image/webp": "webp",
    "video/mp4": "mp4",
    "video/quicktime": "mov",
    "audio/mpeg": "mp3",
    "audio/wav": "wav",
    "audio/ogg": "ogg",
    "audio/mp4": "m4a",
    "audio/aac": "aac",
}


def _multipart_key(media_id: uuid.UUID) -> str:
    return f"media:multipart:{media_id}"


def _validate_upload(data: MediaUploadRequest) -> None:
    if data.mime_type not in _ALLOWED_MIME[data.kind]:
        raise UploadInvalidException(
            "Type MIME non autorisé pour ce type de média."
        )

    max_bytes = _MAX_BYTES[data.kind]
    if data.size_bytes <= 0 or data.size_bytes > max_bytes:
        raise UploadInvalidException(
            f"La taille du fichier doit être comprise entre 1 et {max_bytes} octets."
        )

    if data.kind in ("video", "audio"):
        if data.duration_s is None:
            raise UploadInvalidException(
                "La durée est obligatoire pour ce type de média."
            )
        max_duration = _MAX_DURATION[data.kind]
        if data.duration_s <= 0 or data.duration_s > max_duration:
            raise UploadInvalidException(
                f"La durée doit être comprise entre 0 et {max_duration} secondes."
            )

    if (data.lat is None) != (data.lng is None):
        raise UploadInvalidException(
            "La latitude et la longitude doivent être fournies ensemble."
        )


def media_to_response(media: MediaFile) -> MediaResponse:
    url = None
    if media.upload_status == "uploaded":
        url = storage_service.presign_get(media.storage_key)["url"]
    return MediaResponse(
        id=media.id,
        owner_id=media.owner_id,
        plot_id=media.plot_id,
        crop_cycle_id=media.crop_cycle_id,
        kind=media.kind,
        mime_type=media.mime_type,
        size_bytes=media.size_bytes,
        width=media.width,
        height=media.height,
        duration_s=media.duration_s,
        sha256=media.sha256,
        location=postgis_to_geojson(media.location),
        captured_at=media.captured_at,
        upload_status=media.upload_status,
        created_at=media.created_at,
        url=url,
    )


class MediaService:
    async def _build_upload(
        self,
        media: MediaFile,
    ) -> MediaUploadInstructions:
        if media.size_bytes > settings.S3_MULTIPART_THRESHOLD_BYTES:
            redis = get_redis_client()
            key = _multipart_key(media.id)
            upload_id = await redis.get(key)
            if not upload_id:
                upload_id = await storage_service.create_multipart_upload(
                    media.storage_key,
                    media.mime_type,
                )
                await redis.set(key, upload_id, ex=_MULTIPART_TTL_SECONDS)
            part_count = math.ceil(
                media.size_bytes / settings.S3_MULTIPART_PART_BYTES
            )
            parts = [
                MediaUploadPart(
                    part_number=part_number,
                    url=storage_service.presign_upload_part(
                        media.storage_key,
                        upload_id,
                        part_number,
                    ),
                )
                for part_number in range(1, part_count + 1)
            ]
            return MediaUploadInstructions(
                method="multipart",
                upload_id=upload_id,
                part_size=settings.S3_MULTIPART_PART_BYTES,
                parts=parts,
                expires_in=settings.S3_PRESIGN_UPLOAD_SECONDS,
            )

        presigned = storage_service.presign_put(
            media.storage_key,
            media.mime_type,
            media.size_bytes,
        )
        return MediaUploadInstructions(**presigned)

    async def _abort_multipart(self, media: MediaFile) -> None:
        if media.size_bytes <= settings.S3_MULTIPART_THRESHOLD_BYTES:
            return
        redis = get_redis_client()
        redis_key = _multipart_key(media.id)
        upload_id = await redis.get(redis_key)
        if not upload_id:
            return
        await storage_service.abort_multipart_upload(
            media.storage_key,
            upload_id,
        )
        await redis.delete(redis_key)

    async def _ensure_plot_owned(
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

    async def _ensure_cycle_owned(
        self,
        session: AsyncSession,
        user_id: uuid.UUID,
        cycle_id: uuid.UUID,
    ) -> None:
        found = (
            await session.execute(
                select(CropCycle.id)
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
        if found is None:
            raise NotFoundException("Cycle de culture introuvable.")

    async def _resume_pending(
        self,
        session: AsyncSession,
        media: MediaFile,
    ) -> MediaUploadResponse:
        if media.upload_status != "pending":
            media.upload_status = "pending"
            await session.commit()
            await session.refresh(media)
        upload = await self._build_upload(media)
        return MediaUploadResponse(
            media=media_to_response(media),
            upload=upload,
            already_uploaded=False,
        )

    async def request_upload(
        self,
        session: AsyncSession,
        user: User,
        data: MediaUploadRequest,
    ) -> tuple[MediaUploadResponse, bool]:
        _validate_upload(data)

        if data.id is not None:
            existing = (
                await session.execute(
                    select(MediaFile).where(MediaFile.id == data.id)
                )
            ).scalar_one_or_none()
            if existing is not None:
                if existing.owner_id != user.id:
                    raise ConflictException(
                        "Une ressource avec cet identifiant existe déjà."
                    )
                if existing.deleted_at is not None:
                    raise ConflictException("Cette ressource a été supprimée.")
                if existing.upload_status == "uploaded":
                    return (
                        MediaUploadResponse(
                            media=media_to_response(existing),
                            upload=None,
                            already_uploaded=True,
                        ),
                        False,
                    )
                return await self._resume_pending(session, existing), False

        duplicate = (
            await session.execute(
                select(MediaFile)
                .where(
                    MediaFile.owner_id == user.id,
                    MediaFile.sha256 == data.sha256,
                    MediaFile.upload_status == "uploaded",
                    MediaFile.deleted_at.is_(None),
                )
                .order_by(MediaFile.created_at)
                .limit(1)
            )
        ).scalar_one_or_none()
        if duplicate is not None:
            return (
                MediaUploadResponse(
                    media=media_to_response(duplicate),
                    upload=None,
                    already_uploaded=True,
                ),
                False,
            )

        if data.plot_id is not None:
            await self._ensure_plot_owned(session, user.id, data.plot_id)
        if data.crop_cycle_id is not None:
            await self._ensure_cycle_owned(session, user.id, data.crop_cycle_id)

        await ensure_storage_quota(session, user, data.size_bytes)

        now = datetime.now(UTC)
        media_id = data.id or uuid.uuid4()
        extension = _EXTENSIONS[data.mime_type]
        location = None
        if data.lat is not None and data.lng is not None:
            location = geojson_to_postgis_point(
                {"type": "Point", "coordinates": [data.lng, data.lat]}
            )
        media = MediaFile(
            id=media_id,
            owner_id=user.id,
            plot_id=data.plot_id,
            crop_cycle_id=data.crop_cycle_id,
            kind=data.kind,
            storage_key=(
                f"users/{user.id}/{now.year:04d}/{now.month:02d}/{media_id}.{extension}"
            ),
            mime_type=data.mime_type,
            size_bytes=data.size_bytes,
            width=data.width,
            height=data.height,
            duration_s=(
                data.duration_s if data.kind in ("video", "audio") else None
            ),
            sha256=data.sha256,
            location=location,
            captured_at=data.captured_at,
            upload_status="pending",
        )
        session.add(media)
        try:
            await session.commit()
        except IntegrityError:
            await session.rollback()
            if data.id is not None:
                existing = (
                    await session.execute(
                        select(MediaFile).where(MediaFile.id == data.id)
                    )
                ).scalar_one_or_none()
                if existing is not None:
                    if existing.owner_id != user.id:
                        raise ConflictException(
                            "Une ressource avec cet identifiant existe déjà."
                        ) from None
                    if existing.deleted_at is not None:
                        raise ConflictException(
                            "Cette ressource a été supprimée."
                        ) from None
                    if existing.upload_status == "uploaded":
                        return (
                            MediaUploadResponse(
                                media=media_to_response(existing),
                                upload=None,
                                already_uploaded=True,
                            ),
                            False,
                        )
                    return await self._resume_pending(session, existing), False
            raise

        await session.refresh(media)
        upload = await self._build_upload(media)
        return (
            MediaUploadResponse(
                media=media_to_response(media),
                upload=upload,
                already_uploaded=False,
            ),
            True,
        )

    async def _load_owned(
        self,
        session: AsyncSession,
        user_id: uuid.UUID,
        media_id: uuid.UUID,
    ) -> MediaFile:
        media = (
            await session.execute(
                select(MediaFile).where(
                    MediaFile.id == media_id,
                    MediaFile.deleted_at.is_(None),
                )
            )
        ).scalar_one_or_none()
        if media is None or media.owner_id != user_id:
            raise NotFoundException("Média introuvable.")
        return media

    async def complete_upload(
        self,
        session: AsyncSession,
        user: User,
        media_id: uuid.UUID,
        data: MediaCompleteRequest,
    ) -> MediaResponse:
        media = await self._load_owned(session, user.id, media_id)
        if media.upload_status == "uploaded":
            return media_to_response(media)

        is_multipart = media.size_bytes > settings.S3_MULTIPART_THRESHOLD_BYTES
        redis = get_redis_client()
        redis_key = _multipart_key(media.id)
        upload_id = await redis.get(redis_key) if is_multipart else None

        if is_multipart:
            if not data.parts:
                raise ValidationException(
                    "La liste des parties est obligatoire pour un envoi multipart."
                )
            if upload_id is None:
                raise UploadInvalidException(
                    "Envoi multipart expiré ou introuvable."
                )
            parts: list[dict[str, Any]] = [
                {
                    "PartNumber": part.part_number,
                    "ETag": part.etag,
                }
                for part in data.parts
            ]
            try:
                await storage_service.complete_multipart_upload(
                    media.storage_key,
                    upload_id,
                    parts,
                )
            except ClientError as exc:
                await self._abort_multipart(media)
                media.upload_status = "failed"
                await session.commit()
                raise UploadInvalidException(
                    "La liste des parties envoyées est invalide."
                ) from exc
            await redis.delete(redis_key)

        exists, size = await storage_service.head(media.storage_key)
        if not exists or size != media.size_bytes:
            await self._abort_multipart(media)
            media.upload_status = "failed"
            await session.commit()
            raise UploadInvalidException(
                "Le fichier téléversé est absent ou sa taille ne correspond pas."
            )

        media.upload_status = "uploaded"
        await session.commit()
        await session.refresh(media)
        return media_to_response(media)

    async def get_media(
        self,
        session: AsyncSession,
        user: User,
        media_id: uuid.UUID,
    ) -> MediaResponse:
        media = (
            await session.execute(
                select(MediaFile).where(
                    MediaFile.id == media_id,
                    MediaFile.deleted_at.is_(None),
                )
            )
        ).scalar_one_or_none()
        if media is None:
            raise NotFoundException("Média introuvable.")
        if media.owner_id != user.id and user.role != "super_admin":
            raise NotFoundException("Média introuvable.")
        return media_to_response(media)

    async def delete_media(
        self,
        session: AsyncSession,
        user_id: uuid.UUID,
        media_id: uuid.UUID,
    ) -> None:
        media = await self._load_owned(session, user_id, media_id)
        await self._abort_multipart(media)
        media.deleted_at = datetime.now(UTC)
        await session.commit()


media_service = MediaService()
