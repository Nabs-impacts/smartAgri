import time

import redis.asyncio as redis

from app.core.config import settings
from app.core.errors import RateLimitedException
from app.core.logging import get_logger

logger = get_logger("rate_limit")

_redis_pool: redis.ConnectionPool | None = None


def get_redis_client() -> redis.Redis:
    global _redis_pool
    if _redis_pool is None:
        _redis_pool = redis.ConnectionPool.from_url(
            settings.REDIS_URL,
            decode_responses=True,
        )
    return redis.Redis(connection_pool=_redis_pool)


async def check_rate_limit(
    key: str,
    limit: int,
    window_seconds: int,
    client: redis.Redis | None = None,
) -> bool:
    r = client or get_redis_client()
    try:
        now = time.time()
        pipeline = r.pipeline()
        pipeline.zremrangebyscore(key, 0, now - window_seconds)
        pipeline.zadd(key, {str(now): now})
        pipeline.zcard(key)
        pipeline.expire(key, window_seconds)
        results = await pipeline.execute()
        current_count = results[2]
        return int(current_count) <= limit
    except Exception as exc:
        logger.warning("rate_limit_redis_failed", error=str(exc))
        return True


async def enforce_rate_limit(
    key: str,
    limit: int,
    window_seconds: int,
    client: redis.Redis | None = None,
    error_message: str = "Limite de requêtes atteinte, veuillez patienter.",
) -> None:
    allowed = await check_rate_limit(key, limit, window_seconds, client)
    if not allowed:
        raise RateLimitedException(
            message=error_message,
            details={"limit": limit, "window_seconds": window_seconds},
        )
