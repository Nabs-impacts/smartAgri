import asyncio
import os
import subprocess
from collections.abc import AsyncGenerator
from pathlib import Path
from urllib.parse import urlsplit, urlunsplit

TEST_DATABASE_NAME = "smartagri_test"
TEST_REDIS_INDEX = 3
TEST_S3_BUCKET = "smartagri-test"
EXCLUDED_TABLES = {"alembic_version", "spatial_ref_sys"}


def _with_database(url: str, database: str) -> str:
    parts = urlsplit(url)
    return urlunsplit((parts.scheme, parts.netloc, f"/{database}", parts.query, parts.fragment))


def _with_redis_index(url: str, index: int) -> str:
    parts = urlsplit(url)
    return urlunsplit((parts.scheme, parts.netloc, f"/{index}", parts.query, parts.fragment))


_base_database_url = os.environ.get(
    "DATABASE_URL",
    "postgresql+asyncpg://smartagri:smartagri@db:5432/smartagri",
)
_base_database_url_sync = os.environ.get(
    "DATABASE_URL_SYNC",
    "postgresql+psycopg://smartagri:smartagri@db:5432/smartagri",
)
_base_redis_url = os.environ.get("REDIS_URL", "redis://redis:6379/0")

os.environ["DATABASE_URL"] = _with_database(_base_database_url, TEST_DATABASE_NAME)
os.environ["DATABASE_URL_SYNC"] = _with_database(_base_database_url_sync, TEST_DATABASE_NAME)
os.environ["REDIS_URL"] = _with_redis_index(_base_redis_url, TEST_REDIS_INDEX)
os.environ["CELERY_BROKER_URL"] = _with_redis_index(_base_redis_url, 4)
os.environ["CELERY_RESULT_BACKEND"] = _with_redis_index(_base_redis_url, 5)
os.environ["SMS_PROVIDER"] = "fake"
os.environ["REFRESH_REUSE_GRACE_SECONDS"] = "0"
os.environ["S3_BUCKET"] = TEST_S3_BUCKET
os.environ["S3_PUBLIC_ENDPOINT_URL"] = os.environ.get(
    "S3_ENDPOINT_URL", "http://rustfs:9000"
)

import asyncpg
import boto3
import pytest
from botocore.exceptions import ClientError
from httpx import ASGITransport, AsyncClient
import redis.asyncio as redis
from sqlalchemy import text
from sqlalchemy.ext.asyncio import (
    AsyncConnection,
    AsyncSession,
    async_sessionmaker,
    create_async_engine,
)
from sqlalchemy.pool import NullPool

from botocore.config import Config

import app.core.rate_limit as rate_limit_module
from app.core.rate_limit import get_redis_client
from app.db.session import get_db
from app.main import app
from app.providers.sms.fake import FakeSmsProvider
from scripts.seed import seed_database

PROJECT_ROOT = Path(__file__).resolve().parents[1]

test_engine = create_async_engine(os.environ["DATABASE_URL"], poolclass=NullPool)
TestSessionLocal = async_sessionmaker(
    bind=test_engine,
    class_=AsyncSession,
    expire_on_commit=False,
    autoflush=False,
)


async def _create_test_database() -> None:
    admin_dsn = _base_database_url.replace("+asyncpg", "")
    connection = await asyncpg.connect(admin_dsn)
    try:
        exists = await connection.fetchval(
            "SELECT 1 FROM pg_database WHERE datname = $1",
            TEST_DATABASE_NAME,
        )
        if not exists:
            await connection.execute(f'CREATE DATABASE "{TEST_DATABASE_NAME}"')
    finally:
        await connection.close()


def _storage_client():
    return boto3.client(
        "s3",
        endpoint_url=os.environ.get("S3_ENDPOINT_URL", "http://rustfs:9000"),
        aws_access_key_id=os.environ.get("S3_ACCESS_KEY", "rustfsadmin"),
        aws_secret_access_key=os.environ.get("S3_SECRET_KEY", "rustfsadmin"),
        region_name=os.environ.get("S3_REGION", "us-east-1"),
        config=Config(s3={"addressing_style": "path"}),
    )


def _assert_storage_target(client) -> None:
    assert TEST_S3_BUCKET == "smartagri-test", (
        f"Réinitialisation refusée: bucket '{TEST_S3_BUCKET}' inattendu."
    )
    client.head_bucket(Bucket=TEST_S3_BUCKET)


def _empty_storage(client) -> None:
    _assert_storage_target(client)
    continuation: str | None = None
    while True:
        kwargs = {"Bucket": TEST_S3_BUCKET}
        if continuation:
            kwargs["ContinuationToken"] = continuation
        response = client.list_objects_v2(**kwargs)
        keys = [{"Key": item["Key"]} for item in response.get("Contents", [])]
        if keys:
            client.delete_objects(
                Bucket=TEST_S3_BUCKET,
                Delete={"Objects": keys, "Quiet": True},
            )
        if not response.get("IsTruncated"):
            break
        continuation = response.get("NextContinuationToken")


@pytest.fixture(scope="session", autouse=True)
def prepare_storage() -> None:
    client = _storage_client()
    try:
        client.head_bucket(Bucket=TEST_S3_BUCKET)
    except ClientError:
        client.create_bucket(Bucket=TEST_S3_BUCKET)
    _empty_storage(client)


@pytest.fixture(scope="session", autouse=True)
def prepare_database() -> None:
    asyncio.run(_create_test_database())
    subprocess.run(
        ["alembic", "upgrade", "head"],
        cwd=PROJECT_ROOT,
        env=os.environ.copy(),
        check=True,
        capture_output=True,
    )


async def _assert_test_targets(
    connection: AsyncConnection, redis_client: redis.Redis
) -> None:
    database_name = await connection.scalar(text("SELECT current_database()"))
    assert database_name == TEST_DATABASE_NAME, (
        f"Réinitialisation refusée: base '{database_name}' au lieu de '{TEST_DATABASE_NAME}'."
    )
    redis_db = redis_client.connection_pool.connection_kwargs.get("db", 0)
    assert int(redis_db) == TEST_REDIS_INDEX, (
        f"Réinitialisation refusée: index Redis {redis_db} au lieu de {TEST_REDIS_INDEX}."
    )


async def _get_test_db() -> AsyncGenerator[AsyncSession, None]:
    async with TestSessionLocal() as session:
        try:
            yield session
            await session.commit()
        except Exception:
            await session.rollback()
            raise


app.dependency_overrides[get_db] = _get_test_db


@pytest.fixture(autouse=True)
async def clean_state() -> AsyncGenerator[None, None]:
    rate_limit_module._redis_pool = None
    FakeSmsProvider.clear()
    redis_client = get_redis_client()
    async with test_engine.connect() as connection:
        await _assert_test_targets(connection, redis_client)
    await redis_client.flushdb()

    async with TestSessionLocal() as session:
        await seed_database(session)

    yield

    async with test_engine.begin() as connection:
        await _assert_test_targets(connection, redis_client)
        result = await connection.execute(
            text("SELECT tablename FROM pg_tables WHERE schemaname = 'public'")
        )
        tables = [row[0] for row in result if row[0] not in EXCLUDED_TABLES]
        if tables:
            quoted = ", ".join(f'"{name}"' for name in tables)
            await connection.execute(text(f"TRUNCATE {quoted} RESTART IDENTITY CASCADE"))
    FakeSmsProvider.clear()


@pytest.fixture
async def client() -> AsyncGenerator[AsyncClient, None]:
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://testserver") as http_client:
        yield http_client


@pytest.fixture
async def db_session() -> AsyncGenerator[AsyncSession, None]:
    async with TestSessionLocal() as session:
        yield session
