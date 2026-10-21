import asyncio
from typing import Any

import boto3
from botocore.config import Config
from botocore.exceptions import ClientError

from app.core.config import settings


class StorageService:
    def __init__(self) -> None:
        self._internal_client: Any = None
        self._public_client: Any = None

    def _build_client(self, endpoint_url: str) -> Any:
        return boto3.client(
            "s3",
            endpoint_url=endpoint_url,
            aws_access_key_id=settings.S3_ACCESS_KEY,
            aws_secret_access_key=settings.S3_SECRET_KEY,
            region_name=settings.S3_REGION,
            config=Config(
                signature_version="s3v4",
                s3={"addressing_style": "path"},
            ),
        )

    def _internal(self) -> Any:
        if self._internal_client is None:
            self._internal_client = self._build_client(settings.S3_ENDPOINT_URL)
        return self._internal_client

    def _public(self) -> Any:
        if self._public_client is None:
            endpoint = settings.S3_PUBLIC_ENDPOINT_URL or settings.S3_ENDPOINT_URL
            self._public_client = self._build_client(endpoint)
        return self._public_client

    def presign_put(
        self,
        key: str,
        content_type: str,
        size_bytes: int,
    ) -> dict[str, Any]:
        url = self._public().generate_presigned_url(
            "put_object",
            Params={
                "Bucket": settings.S3_BUCKET,
                "Key": key,
                "ContentType": content_type,
                "ContentLength": size_bytes,
            },
            ExpiresIn=settings.S3_PRESIGN_UPLOAD_SECONDS,
        )
        return {
            "method": "PUT",
            "url": url,
            "headers": {
                "Content-Type": content_type,
                "Content-Length": str(size_bytes),
            },
            "expires_in": settings.S3_PRESIGN_UPLOAD_SECONDS,
        }

    def presign_get(self, key: str) -> dict[str, Any]:
        url = self._public().generate_presigned_url(
            "get_object",
            Params={"Bucket": settings.S3_BUCKET, "Key": key},
            ExpiresIn=settings.S3_PRESIGN_READ_SECONDS,
        )
        return {
            "method": "GET",
            "url": url,
            "headers": {},
            "expires_in": settings.S3_PRESIGN_READ_SECONDS,
        }

    def presign_upload_part(
        self,
        key: str,
        upload_id: str,
        part_number: int,
    ) -> str:
        return self._public().generate_presigned_url(
            "upload_part",
            Params={
                "Bucket": settings.S3_BUCKET,
                "Key": key,
                "UploadId": upload_id,
                "PartNumber": part_number,
            },
            ExpiresIn=settings.S3_PRESIGN_UPLOAD_SECONDS,
        )

    async def head(self, key: str) -> tuple[bool, int | None]:
        def _head() -> tuple[bool, int | None]:
            try:
                response = self._internal().head_object(
                    Bucket=settings.S3_BUCKET,
                    Key=key,
                )
            except ClientError as exc:
                code = exc.response.get("Error", {}).get("Code")
                if code in ("404", "NoSuchKey", "NotFound"):
                    return False, None
                raise
            return True, int(response["ContentLength"])

        return await asyncio.to_thread(_head)

    async def read_prefix(self, key: str, length: int = 32) -> bytes:
        def _read() -> bytes:
            try:
                response = self._internal().get_object(
                    Bucket=settings.S3_BUCKET,
                    Key=key,
                    Range=f"bytes=0-{length - 1}",
                )
            except ClientError as exc:
                code = exc.response.get("Error", {}).get("Code")
                if code in ("404", "NoSuchKey", "NotFound"):
                    return b""
                raise
            body = response["Body"]
            try:
                return body.read(length)
            finally:
                body.close()

        return await asyncio.to_thread(_read)

    async def delete(self, key: str) -> None:
        def _delete() -> None:
            try:
                self._internal().delete_object(
                    Bucket=settings.S3_BUCKET,
                    Key=key,
                )
            except ClientError as exc:
                code = exc.response.get("Error", {}).get("Code")
                if code in ("404", "NoSuchKey", "NotFound"):
                    return
                raise

        await asyncio.to_thread(_delete)

    async def create_multipart_upload(
        self,
        key: str,
        content_type: str,
    ) -> str:
        def _create() -> str:
            response = self._internal().create_multipart_upload(
                Bucket=settings.S3_BUCKET,
                Key=key,
                ContentType=content_type,
            )
            return str(response["UploadId"])

        return await asyncio.to_thread(_create)

    async def complete_multipart_upload(
        self,
        key: str,
        upload_id: str,
        parts: list[dict[str, Any]],
    ) -> None:
        def _complete() -> None:
            self._internal().complete_multipart_upload(
                Bucket=settings.S3_BUCKET,
                Key=key,
                UploadId=upload_id,
                MultipartUpload={"Parts": parts},
            )

        await asyncio.to_thread(_complete)

    async def abort_multipart_upload(
        self,
        key: str,
        upload_id: str,
    ) -> None:
        def _abort() -> None:
            try:
                self._internal().abort_multipart_upload(
                    Bucket=settings.S3_BUCKET,
                    Key=key,
                    UploadId=upload_id,
                )
            except ClientError:
                return

        await asyncio.to_thread(_abort)


storage_service = StorageService()
