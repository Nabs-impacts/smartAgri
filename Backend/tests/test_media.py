import hashlib
import re
import uuid
from datetime import UTC, datetime, timedelta

import httpx
import pytest
from httpx import AsyncClient
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.errors import QuotaExceededException
from app.db.models.identity import User
from app.db.models.media_ai import MediaFile
from app.providers.sms.fake import FakeSmsProvider
from app.services.quota_service import ensure_storage_quota
from app.services.storage_service import storage_service

PHONE_USER1 = "+22793000001"
PHONE_USER2 = "+22793000002"
OTP_PATTERN = re.compile(r"(\d{6})")
PNG_SIGNATURE = b"\x89PNG\r\n\x1a\n"
MP4_SIGNATURE = b"\x00\x00\x00\x18ftypisom"


def _png(payload: bytes) -> bytes:
    return PNG_SIGNATURE + payload


def _mp4(payload: bytes, size: int) -> bytes:
    return (MP4_SIGNATURE + payload)[:size]


def _last_otp_code() -> str:
    message = FakeSmsProvider.sent_messages[-1]["message"]
    match = OTP_PATTERN.search(message)
    assert match is not None
    return match.group(1)


async def _register_verified(client: AsyncClient, phone: str) -> dict[str, str]:
    registered = await client.post(
        "/api/v1/auth/register",
        json={"phone": phone, "full_name": "Test Média", "language": "fr"},
    )
    assert registered.status_code == 201
    verified = await client.post(
        "/api/v1/auth/otp/verify",
        json={"phone": phone, "code": _last_otp_code(), "purpose": "verify_phone"},
    )
    assert verified.status_code == 200
    data = verified.json()
    return {"Authorization": f"Bearer {data['access_token']}"}


def _image_payload(data: bytes, **overrides) -> dict:
    payload = {
        "kind": "image",
        "mime_type": "image/png",
        "size_bytes": len(data),
        "sha256": hashlib.sha256(data).hexdigest(),
    }
    payload.update(overrides)
    return payload


async def _put_object(upload: dict, data: bytes) -> httpx.Response:
    async with httpx.AsyncClient() as storage_client:
        return await storage_client.put(
            upload["url"],
            headers=upload["headers"],
            content=data,
        )


async def _request_upload(
    client: AsyncClient,
    headers: dict[str, str],
    payload: dict,
    idempotency_key: str | None = None,
) -> httpx.Response:
    request_headers = dict(headers)
    if idempotency_key is not None:
        request_headers["Idempotency-Key"] = idempotency_key
    return await client.post(
        "/api/v1/media/uploads",
        json=payload,
        headers=request_headers,
    )


async def _upload_and_complete(
    client: AsyncClient,
    headers: dict[str, str],
    data: bytes,
    payload: dict | None = None,
) -> dict:
    body = payload or _image_payload(data)
    requested = await _request_upload(client, headers, body)
    assert requested.status_code == 201, requested.text
    upload = requested.json()["upload"]
    put = await _put_object(upload, data)
    assert put.status_code == 200, put.text
    completed = await client.post(
        f"/api/v1/media/{body.get('id') or requested.json()['media']['id']}/complete",
        json={},
        headers=headers,
    )
    assert completed.status_code == 200, completed.text
    return requested.json()["media"]


def _iter_keys(value: object):
    if isinstance(value, dict):
        for key, item in value.items():
            yield key
            yield from _iter_keys(item)
    elif isinstance(value, list):
        for item in value:
            yield from _iter_keys(item)


async def test_media_upload_roundtrip(client: AsyncClient) -> None:
    headers = await _register_verified(client, PHONE_USER1)
    data = _png(b"contenu-image-de-test")

    requested = await _request_upload(client, headers, _image_payload(data))
    assert requested.status_code == 201
    body = requested.json()
    assert body["already_uploaded"] is False
    assert body["media"]["upload_status"] == "pending"
    upload = body["upload"]
    assert upload["method"] == "PUT"
    assert upload["headers"]["Content-Type"] == "image/png"
    assert upload["expires_in"] > 0
    assert "storage_key" not in set(_iter_keys(body))

    put = await _put_object(upload, data)
    assert put.status_code == 200

    media_id = body["media"]["id"]
    completed = await client.post(
        f"/api/v1/media/{media_id}/complete",
        json={},
        headers=headers,
    )
    assert completed.status_code == 200
    assert completed.json()["upload_status"] == "uploaded"
    assert completed.json()["url"]

    fetched = await client.get(f"/api/v1/media/{media_id}", headers=headers)
    assert fetched.status_code == 200
    assert "storage_key" not in set(_iter_keys(fetched.json()))
    async with httpx.AsyncClient() as storage_client:
        download = await storage_client.get(fetched.json()["url"])
    assert download.status_code == 200
    assert download.content == data


async def test_presigned_put_rejects_wrong_type_and_size(
    client: AsyncClient,
) -> None:
    headers = await _register_verified(client, PHONE_USER1)
    data = b"1234"
    requested = await _request_upload(client, headers, _image_payload(data))
    assert requested.status_code == 201
    upload = requested.json()["upload"]

    wrong_type = await _put_object(
        {
            "url": upload["url"],
            "headers": {
                "Content-Type": "text/plain",
                "Content-Length": upload["headers"]["Content-Length"],
            },
        },
        data,
    )
    assert wrong_type.status_code == 403

    async with httpx.AsyncClient() as storage_client:
        wrong_size = await storage_client.put(
            upload["url"],
            headers={"Content-Type": "image/png"},
            content=b"12345",
        )
    assert wrong_size.status_code == 403


async def test_upload_validation_limits(client: AsyncClient) -> None:
    headers = await _register_verified(client, PHONE_USER1)
    sha = "a" * 64

    invalid_size = await _request_upload(
        client,
        headers,
        {
            "kind": "image",
            "mime_type": "image/png",
            "size_bytes": 0,
            "sha256": sha,
        },
    )
    assert invalid_size.status_code == 400
    assert invalid_size.json()["error"]["code"] == "UPLOAD_INVALID"

    too_big = await _request_upload(
        client,
        headers,
        {
            "kind": "image",
            "mime_type": "image/png",
            "size_bytes": 4_000_000,
            "sha256": sha,
        },
    )
    assert too_big.status_code == 400
    assert too_big.json()["error"]["code"] == "UPLOAD_INVALID"

    wrong_mime = await _request_upload(
        client,
        headers,
        {
            "kind": "image",
            "mime_type": "video/mp4",
            "size_bytes": 10,
            "sha256": sha,
        },
    )
    assert wrong_mime.status_code == 400

    video_without_duration = await _request_upload(
        client,
        headers,
        {
            "kind": "video",
            "mime_type": "video/mp4",
            "size_bytes": 10,
            "sha256": sha,
        },
    )
    assert video_without_duration.status_code == 400

    video_too_long = await _request_upload(
        client,
        headers,
        {
            "kind": "video",
            "mime_type": "video/mp4",
            "size_bytes": 10,
            "duration_s": 16,
            "sha256": sha,
        },
    )
    assert video_too_long.status_code == 400

    audio_without_duration = await _request_upload(
        client,
        headers,
        {
            "kind": "audio",
            "mime_type": "audio/mpeg",
            "size_bytes": 10,
            "sha256": sha,
        },
    )
    assert audio_without_duration.status_code == 400

    audio_too_long = await _request_upload(
        client,
        headers,
        {
            "kind": "audio",
            "mime_type": "audio/mpeg",
            "size_bytes": 10,
            "duration_s": 61,
            "sha256": sha,
        },
    )
    assert audio_too_long.status_code == 400

    invalid_sha = await _request_upload(
        client,
        headers,
        {
            "kind": "image",
            "mime_type": "image/png",
            "size_bytes": 10,
            "sha256": "ABC",
        },
    )
    assert invalid_sha.status_code == 422


async def test_unknown_mime_without_extension_is_rejected(
    client: AsyncClient,
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    from app.core.config import settings

    headers = await _register_verified(client, PHONE_USER1)
    monkeypatch.setattr(
        settings,
        "ALLOWED_IMAGE_MIME",
        [*settings.ALLOWED_IMAGE_MIME, "image/tiff"],
    )
    response = await _request_upload(
        client,
        headers,
        {
            "kind": "image",
            "mime_type": "image/tiff",
            "size_bytes": 10,
            "sha256": "a" * 64,
        },
    )
    assert response.status_code == 400
    assert response.json()["error"]["code"] == "UPLOAD_INVALID"


async def test_media_id_idempotence(client: AsyncClient) -> None:
    headers = await _register_verified(client, PHONE_USER1)
    other_headers = await _register_verified(client, PHONE_USER2)
    data = _png(b"image-idempotente")
    media_id = str(uuid.uuid4())
    payload = _image_payload(data, id=media_id)

    first = await _request_upload(client, headers, payload)
    assert first.status_code == 201
    assert first.json()["media"]["id"] == media_id

    resumed = await _request_upload(client, headers, payload)
    assert resumed.status_code == 200
    assert resumed.json()["already_uploaded"] is False
    assert resumed.json()["upload"]["method"] == "PUT"

    put = await _put_object(first.json()["upload"], data)
    assert put.status_code == 200
    completed = await client.post(
        f"/api/v1/media/{media_id}/complete", json={}, headers=headers
    )
    assert completed.status_code == 200

    already = await _request_upload(client, headers, payload)
    assert already.status_code == 200
    assert already.json()["already_uploaded"] is True
    assert already.json()["upload"] is None

    conflict = await _request_upload(client, other_headers, payload)
    assert conflict.status_code == 409
    assert conflict.json()["error"]["message"] == (
        "Une ressource avec cet identifiant existe déjà."
    )

    deleted = await client.delete(f"/api/v1/media/{media_id}", headers=headers)
    assert deleted.status_code == 204
    removed = await _request_upload(client, headers, payload)
    assert removed.status_code == 409
    assert removed.json()["error"]["message"] == "Cette ressource a été supprimée."

    other_on_deleted = await _request_upload(client, other_headers, payload)
    assert other_on_deleted.status_code == 409
    assert other_on_deleted.json()["error"]["message"] == (
        "Une ressource avec cet identifiant existe déjà."
    )


async def test_media_deduplicates_sha256(client: AsyncClient) -> None:
    headers = await _register_verified(client, PHONE_USER1)
    data = _png(b"meme-contenu")

    first = await _upload_and_complete(client, headers, data)
    second = await _request_upload(client, headers, _image_payload(data))
    assert second.status_code == 200
    assert second.json()["already_uploaded"] is True
    assert second.json()["media"]["id"] == first["id"]
    assert second.json()["upload"] is None


async def test_complete_without_put_marks_failed(client: AsyncClient) -> None:
    headers = await _register_verified(client, PHONE_USER1)
    requested = await _request_upload(
        client, headers, _image_payload(b"absent-du-stockage")
    )
    assert requested.status_code == 201
    media_id = requested.json()["media"]["id"]

    completed = await client.post(
        f"/api/v1/media/{media_id}/complete", json={}, headers=headers
    )
    assert completed.status_code == 400
    assert completed.json()["error"]["code"] == "UPLOAD_INVALID"

    fetched = await client.get(f"/api/v1/media/{media_id}", headers=headers)
    assert fetched.status_code == 200
    assert fetched.json()["upload_status"] == "failed"
    assert fetched.json()["url"] is None


async def test_complete_twice_is_stable(client: AsyncClient) -> None:
    headers = await _register_verified(client, PHONE_USER1)
    data = _png(b"deux-fois")
    requested = await _request_upload(client, headers, _image_payload(data))
    media_id = requested.json()["media"]["id"]
    assert (await _put_object(requested.json()["upload"], data)).status_code == 200

    first = await client.post(
        f"/api/v1/media/{media_id}/complete", json={}, headers=headers
    )
    second = await client.post(
        f"/api/v1/media/{media_id}/complete", json={}, headers=headers
    )
    assert first.status_code == 200
    assert second.status_code == 200
    assert second.json()["upload_status"] == "uploaded"


async def test_inter_user_isolation(client: AsyncClient) -> None:
    headers = await _register_verified(client, PHONE_USER1)
    other_headers = await _register_verified(client, PHONE_USER2)
    data = _png(b"prive")
    requested = await _request_upload(client, headers, _image_payload(data))
    media_id = requested.json()["media"]["id"]

    assert (
        await client.get(f"/api/v1/media/{media_id}", headers=other_headers)
    ).status_code == 404
    assert (
        await client.post(
            f"/api/v1/media/{media_id}/complete", json={}, headers=other_headers
        )
    ).status_code == 404
    assert (
        await client.delete(f"/api/v1/media/{media_id}", headers=other_headers)
    ).status_code == 404

    assert (
        await client.get(f"/api/v1/media/{media_id}", headers=headers)
    ).status_code == 200


async def test_plot_of_other_user_is_not_found(client: AsyncClient) -> None:
    headers = await _register_verified(client, PHONE_USER1)
    other_headers = await _register_verified(client, PHONE_USER2)
    farm = await client.post(
        "/api/v1/farms", json={"name": "Ferme Plot"}, headers=headers
    )
    assert farm.status_code == 201
    plot = await client.post(
        f"/api/v1/farms/{farm.json()['id']}/plots",
        json={"name": "Parcelle", "area_ha": 1.0},
        headers=headers,
    )
    assert plot.status_code == 201

    response = await _request_upload(
        client,
        other_headers,
        _image_payload(b"parcelle-autrui", plot_id=plot.json()["id"]),
    )
    assert response.status_code == 404


async def test_soft_delete_keeps_s3_object(
    client: AsyncClient, db_session: AsyncSession
) -> None:
    headers = await _register_verified(client, PHONE_USER1)
    data = _png(b"suppression-douce")
    media = await _upload_and_complete(client, headers, data)
    media_id = media["id"]

    assert (
        await client.delete(f"/api/v1/media/{media_id}", headers=headers)
    ).status_code == 204
    assert (
        await client.get(f"/api/v1/media/{media_id}", headers=headers)
    ).status_code == 404

    row = (
        await db_session.execute(select(MediaFile).where(MediaFile.id == uuid.UUID(media_id)))
    ).scalar_one()
    assert row.deleted_at is not None
    exists, size = await storage_service.head(row.storage_key)
    assert exists is True
    assert size == len(data)


async def test_idempotency_key(client: AsyncClient) -> None:
    headers = await _register_verified(client, PHONE_USER1)
    other_headers = await _register_verified(client, PHONE_USER2)
    data = _png(b"idempotence-cle")
    payload = _image_payload(data)
    key = "cle-partagee"

    first = await _request_upload(client, headers, payload, idempotency_key=key)
    second = await _request_upload(client, headers, payload, idempotency_key=key)
    assert first.status_code == 201
    assert second.status_code == 201
    assert first.json() == second.json()

    different_body = _image_payload(_png(b"autre-corps"))
    conflict = await _request_upload(
        client, headers, different_body, idempotency_key=key
    )
    assert conflict.status_code == 409

    other_user = await _request_upload(
        client, other_headers, payload, idempotency_key=key
    )
    assert other_user.status_code == 201
    assert other_user.json()["media"]["id"] != first.json()["media"]["id"]


async def test_idempotency_lock_released_after_error(
    client: AsyncClient,
) -> None:
    headers = await _register_verified(client, PHONE_USER1)
    key = "cle-erreur-puis-reprise"
    invalid = _image_payload(
        _png(b"corps-invalide"),
        size_bytes=0,
    )
    body = _png(b"corps-corrige")

    failed = await _request_upload(client, headers, invalid, idempotency_key=key)
    assert failed.status_code == 400
    assert failed.json()["error"]["code"] == "UPLOAD_INVALID"

    retried = await _request_upload(
        client,
        headers,
        _image_payload(body),
        idempotency_key=key,
    )
    assert retried.status_code == 201
    assert retried.json()["already_uploaded"] is False


async def test_idempotency_ignores_json_key_order(client: AsyncClient) -> None:
    headers = await _register_verified(client, PHONE_USER1)
    data = _png(b"ordre-des-cles")
    key = "cle-ordre-json"
    payload = _image_payload(data)
    reordered = {
        "sha256": payload["sha256"],
        "size_bytes": payload["size_bytes"],
        "mime_type": payload["mime_type"],
        "kind": payload["kind"],
    }

    first = await _request_upload(client, headers, payload, idempotency_key=key)
    second = await _request_upload(client, headers, reordered, idempotency_key=key)
    assert first.status_code == 201
    assert second.status_code == 201
    assert first.json() == second.json()


async def test_complete_rejects_content_not_matching_type(
    client: AsyncClient,
    db_session: AsyncSession,
) -> None:
    headers = await _register_verified(client, PHONE_USER1)
    data = b"ceci est un fichier texte, pas une image jpeg"
    payload = {
        "kind": "image",
        "mime_type": "image/jpeg",
        "size_bytes": len(data),
        "sha256": hashlib.sha256(data).hexdigest(),
    }

    requested = await _request_upload(client, headers, payload)
    assert requested.status_code == 201
    media_id = requested.json()["media"]["id"]
    assert (await _put_object(requested.json()["upload"], data)).status_code == 200

    completed = await client.post(
        f"/api/v1/media/{media_id}/complete",
        json={},
        headers=headers,
    )
    assert completed.status_code == 400
    assert completed.json()["error"]["code"] == "UPLOAD_INVALID"
    assert completed.json()["error"]["message"] == (
        "Le contenu du fichier ne correspond pas au type annoncé."
    )

    fetched = await client.get(f"/api/v1/media/{media_id}", headers=headers)
    assert fetched.status_code == 200
    assert fetched.json()["upload_status"] == "failed"
    assert fetched.json()["url"] is None

    row = (
        await db_session.execute(
            select(MediaFile).where(MediaFile.id == uuid.UUID(media_id))
        )
    ).scalar_one()
    exists, _ = await storage_service.head(row.storage_key)
    assert exists is False


def test_purge_user_media_retry_attributes() -> None:
    from app.workers.tasks_media import purge_user_media

    assert purge_user_media.autoretry_for == (Exception,)
    assert purge_user_media.retry_backoff is True
    assert purge_user_media.retry_backoff_max == 600
    assert purge_user_media.max_retries == 5


async def test_storage_quota_counts_only_active_media(
    client: AsyncClient,
    db_session: AsyncSession,
) -> None:
    await _register_verified(client, PHONE_USER1)
    owner = (
        await db_session.execute(select(User).where(User.phone == PHONE_USER1))
    ).scalar_one()
    now = datetime.now(UTC)
    megabyte = 1024 * 1024
    rows = [
        ("uploaded", 10, now),
        ("pending", 20, now - timedelta(hours=1)),
        ("pending", 30, now - timedelta(hours=25)),
        ("failed", 40, now),
    ]
    for index, (status, size_mb, created_at) in enumerate(rows):
        db_session.add(
            MediaFile(
                owner_id=owner.id,
                kind="image",
                storage_key=f"users/{owner.id}/quota/{index}.png",
                mime_type="image/png",
                size_bytes=size_mb * megabyte,
                sha256=f"{index:064d}",
                upload_status=status,
                created_at=created_at,
            )
        )
    await db_session.commit()

    with pytest.raises(QuotaExceededException) as error:
        await ensure_storage_quota(db_session, owner, 80 * megabyte)
    assert error.value.details == {
        "metric": "storage_mb",
        "limit": 100,
        "used": 30,
    }


async def test_storage_quota_exceeded(
    client: AsyncClient, db_session: AsyncSession
) -> None:
    headers = await _register_verified(client, PHONE_USER1)
    owner = (
        await db_session.execute(select(User).where(User.phone == PHONE_USER1))
    ).scalar_one()
    db_session.add(
        MediaFile(
            owner_id=owner.id,
            kind="image",
            storage_key=f"users/{owner.id}/2026/10/existant.png",
            mime_type="image/png",
            size_bytes=100 * 1024 * 1024,
            sha256="b" * 64,
            upload_status="uploaded",
            created_at=datetime.now(UTC),
        )
    )
    await db_session.commit()

    response = await _request_upload(client, headers, _image_payload(b"trop"))
    assert response.status_code == 403
    error = response.json()["error"]
    assert error["code"] == "QUOTA_EXCEEDED"
    assert error["details"] == {"metric": "storage_mb", "limit": 100, "used": 100}


async def test_multipart_video_roundtrip(client: AsyncClient) -> None:
    headers = await _register_verified(client, PHONE_USER1)
    data = _mp4(bytes(range(256)) * (10 * 1024 * 1024), 10 * 1024 * 1024)
    assert len(data) == 10 * 1024 * 1024
    payload = {
        "kind": "video",
        "mime_type": "video/mp4",
        "size_bytes": len(data),
        "duration_s": 10,
        "sha256": hashlib.sha256(data).hexdigest(),
    }

    requested = await _request_upload(client, headers, payload)
    assert requested.status_code == 201
    body = requested.json()
    upload = body["upload"]
    assert upload["method"] == "multipart"
    assert upload["upload_id"]
    assert upload["part_size"] == 8 * 1024 * 1024
    assert len(upload["parts"]) == 2
    assert "storage_key" not in set(_iter_keys(body))

    media_id = body["media"]["id"]
    missing_parts = await client.post(
        f"/api/v1/media/{media_id}/complete",
        json={},
        headers=headers,
    )
    assert missing_parts.status_code == 422

    completed_parts = []
    async with httpx.AsyncClient() as storage_client:
        for index, part in enumerate(upload["parts"]):
            start = index * upload["part_size"]
            chunk = data[start : start + upload["part_size"]]
            put = await storage_client.put(part["url"], content=chunk)
            assert put.status_code == 200, put.text
            completed_parts.append(
                {
                    "part_number": part["part_number"],
                    "etag": put.headers["etag"],
                }
            )

    completed = await client.post(
        f"/api/v1/media/{media_id}/complete",
        json={"parts": completed_parts},
        headers=headers,
    )
    assert completed.status_code == 200, completed.text
    assert completed.json()["upload_status"] == "uploaded"

    fetched = await client.get(f"/api/v1/media/{media_id}", headers=headers)
    assert fetched.status_code == 200
    async with httpx.AsyncClient() as storage_client:
        download = await storage_client.get(fetched.json()["url"])
    assert download.status_code == 200
    assert download.content == data


async def test_multipart_pending_resume_reuses_upload_id(
    client: AsyncClient,
) -> None:
    headers = await _register_verified(client, PHONE_USER1)
    data = b"x" * (9 * 1024 * 1024)
    payload = {
        "id": str(uuid.uuid4()),
        "kind": "video",
        "mime_type": "video/mp4",
        "size_bytes": len(data),
        "duration_s": 5,
        "sha256": hashlib.sha256(data).hexdigest(),
    }
    first = await _request_upload(client, headers, payload)
    second = await _request_upload(client, headers, payload)
    assert first.status_code == 201
    assert second.status_code == 200
    assert first.json()["upload"]["upload_id"] == second.json()["upload"]["upload_id"]
    assert second.json()["upload"]["method"] == "multipart"
    assert second.json()["already_uploaded"] is False


async def test_purge_user_media_is_idempotent(
    client: AsyncClient, db_session: AsyncSession
) -> None:
    import asyncio

    from app.workers.tasks_media import purge_user_media

    headers = await _register_verified(client, PHONE_USER1)
    data = _png(b"media-a-purger")
    payload = _image_payload(
        data,
        lat=13.5116,
        lng=2.1098,
    )
    media = await _upload_and_complete(client, headers, data, payload)
    media_id = uuid.UUID(media["id"])
    owner_id = uuid.UUID(media["owner_id"])

    row = (
        await db_session.execute(select(MediaFile).where(MediaFile.id == media_id))
    ).scalar_one()
    assert row.location is not None
    assert row.deleted_at is None
    exists, _ = await storage_service.head(row.storage_key)
    assert exists is True

    count = await asyncio.to_thread(purge_user_media, str(owner_id))
    assert count == 1

    db_session.expire_all()
    purged = (
        await db_session.execute(select(MediaFile).where(MediaFile.id == media_id))
    ).scalar_one()
    assert purged.location is None
    assert purged.deleted_at is not None
    exists, _ = await storage_service.head(purged.storage_key)
    assert exists is False

    second_count = await asyncio.to_thread(purge_user_media, str(owner_id))
    assert second_count == 1
    db_session.expire_all()
    again = (
        await db_session.execute(select(MediaFile).where(MediaFile.id == media_id))
    ).scalar_one()
    assert again.location is None
    assert again.deleted_at == purged.deleted_at
