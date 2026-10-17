import asyncio
import os
import subprocess
from collections.abc import AsyncGenerator
from pathlib import Path
from urllib.parse import urlsplit, urlunsplit

TEST_DATABASE_NAME = "smartagri_test"
TEST_REDIS_INDEX = 3
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
os.environ["SMS_PROVIDER"] = "fake"
os.environ["REFRESH_REUSE_GRACE_SECONDS"] = "0"

import asyncpg
import pytest
from httpx import ASGITransport, AsyncClient
from sqlalchemy import text
from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker, create_async_engine
from sqlalchemy.pool import NullPool

import app.core.rate_limit as rate_limit_module
from app.core.rate_limit import get_redis_client
from app.db.session import get_db
from app.main import app
from app.providers.sms.fake import FakeSmsProvider

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
    await redis_client.flushdb()

    yield

    async with test_engine.begin() as connection:
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
