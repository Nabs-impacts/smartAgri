import os
from typing import Any
import aioboto3
from fastapi import APIRouter, Response, status
from pydantic import BaseModel
from sqlalchemy import text
from app.core.config import settings
from app.core.rate_limit import get_redis_client
from app.db.session import AsyncSessionLocal

router = APIRouter()


class HealthResponse(BaseModel):
    status: str
    database: str
    redis: str
    storage: str


class VersionResponse(BaseModel):
    version: str
    commit: str
    environment: str


async def check_database() -> bool:
    try:
        async with AsyncSessionLocal() as session:
            await session.execute(text("SELECT 1"))
            return True
    except Exception:
        return False


async def check_redis() -> bool:
    try:
        client = get_redis_client()
        res = await client.ping()
        return bool(res)
    except Exception:
        return False


async def check_storage() -> bool:
    try:
        session = aioboto3.Session()
        async with session.client(
            "s3",
            endpoint_url=settings.S3_ENDPOINT_URL,
            aws_access_key_id=settings.S3_ACCESS_KEY,
            aws_secret_access_key=settings.S3_SECRET_KEY,
            region_name=settings.S3_REGION,
        ) as s3:
            await s3.head_bucket(Bucket=settings.S3_BUCKET)
            return True
    except Exception:
        return False


@router.get("/health", response_model=HealthResponse)
async def health_check(response: Response) -> dict[str, Any]:
    db_ok = await check_database()
    redis_ok = await check_redis()
    storage_ok = await check_storage()

    all_ok = db_ok and redis_ok and storage_ok
    if not all_ok:
        response.status_code = status.HTTP_503_SERVICE_UNAVAILABLE

    return {
        "status": "healthy" if all_ok else "unhealthy",
        "database": "ok" if db_ok else "error",
        "redis": "ok" if redis_ok else "error",
        "storage": "ok" if storage_ok else "error",
    }


@router.get("/version", response_model=VersionResponse)
async def version_info() -> dict[str, str]:
    commit_sha = os.environ.get("GIT_COMMIT_SHA", "local")
    return {
        "version": "0.1.0",
        "commit": commit_sha,
        "environment": settings.APP_ENV,
    }
