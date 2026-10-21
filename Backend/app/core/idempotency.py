import hashlib
import json
from collections.abc import AsyncGenerator
from typing import Any

from fastapi import Depends, Request
from fastapi.responses import JSONResponse
from redis.asyncio import Redis

from app.core.config import settings
from app.core.deps import get_current_user
from app.core.errors import ConflictException, ValidationException
from app.core.rate_limit import get_redis_client
from app.db.models.identity import User

_LOCK_SECONDS = 60


class IdempotencyReplay(Exception):
    def __init__(self, status_code: int, body: Any) -> None:
        self.status_code = status_code
        self.body = body
        super().__init__("idempotency_replay")


class IdempotencyContext:
    def __init__(
        self,
        redis: Redis,
        storage_key: str,
        lock_key: str,
        body_hash: str,
    ) -> None:
        self.redis = redis
        self.storage_key = storage_key
        self.lock_key = lock_key
        self.body_hash = body_hash
        self.saved = False

    async def save(self, status_code: int, body: Any) -> None:
        payload = json.dumps(body, ensure_ascii=False, default=str)
        await self.redis.hset(
            self.storage_key,
            mapping={
                "hash": self.body_hash,
                "status": str(status_code),
                "response": payload,
            },
        )
        await self.redis.expire(self.storage_key, settings.IDEMPOTENCY_TTL_SECONDS)
        await self.redis.delete(self.lock_key)
        self.saved = True


def _body_hash(body: bytes) -> str:
    try:
        parsed = json.loads(body)
    except (TypeError, ValueError):
        return hashlib.sha256(body).hexdigest()
    canonical = json.dumps(
        parsed,
        sort_keys=True,
        separators=(",", ":"),
        ensure_ascii=False,
    )
    return hashlib.sha256(canonical.encode("utf-8")).hexdigest()


def idempotency_dependency(required: bool = False) -> Any:
    async def dependency(
        request: Request,
        current_user: User = Depends(get_current_user),
    ) -> AsyncGenerator[IdempotencyContext | None, None]:
        raw_key = request.headers.get("Idempotency-Key")
        if raw_key is None:
            if required:
                raise ValidationException("En-tête Idempotency-Key requis.")
            yield None
            return
        key = raw_key.strip()
        if not key or len(key) > 255:
            raise ValidationException("Clé d'idempotence invalide.")

        body = await request.body()
        body_hash = _body_hash(body)
        route = request.scope.get("route")
        route_path = getattr(route, "path", request.url.path)
        route_name = f"{request.method}:{route_path}"
        redis = get_redis_client()
        storage_key = (
            f"idempotency:{current_user.id}:{route_name}:{key}"
        )
        lock_key = f"{storage_key}:lock"

        existing = await redis.hgetall(storage_key)
        if existing:
            if existing.get("hash") != body_hash:
                raise ConflictException(
                    "Cette clé d'idempotence a déjà été utilisée avec un "
                    "corps de requête différent."
                )
            try:
                cached = json.loads(existing.get("response", "null"))
                cached_status = int(existing.get("status", "200"))
            except (TypeError, ValueError):
                await redis.delete(storage_key)
            else:
                raise IdempotencyReplay(cached_status, cached)

        acquired = await redis.set(lock_key, "1", nx=True, ex=_LOCK_SECONDS)
        if not acquired:
            raise ConflictException(
                "Une requête avec cette clé d'idempotence est déjà en cours."
            )
        context = IdempotencyContext(redis, storage_key, lock_key, body_hash)
        try:
            yield context
        finally:
            if not context.saved:
                await context.redis.delete(context.lock_key)

    return dependency


async def idempotency_replay_handler(
    request: Request,
    exc: IdempotencyReplay,
) -> JSONResponse:
    return JSONResponse(status_code=exc.status_code, content=exc.body)
