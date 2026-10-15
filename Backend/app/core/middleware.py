import uuid
from typing import Callable
from fastapi import Request, Response, status
from fastapi.responses import JSONResponse
from starlette.middleware.base import BaseHTTPMiddleware
from app.core.config import settings
from app.core.logging import request_id_ctx
from app.core.rate_limit import check_rate_limit


class RequestIDMiddleware(BaseHTTPMiddleware):
    async def dispatch(self, request: Request, call_next: Callable) -> Response:
        req_id = request.headers.get("X-Request-ID") or str(uuid.uuid4())
        token = request_id_ctx.set(req_id)
        try:
            response = await call_next(request)
            response.headers["X-Request-ID"] = req_id
            return response
        finally:
            request_id_ctx.reset(token)


class SecurityHeadersMiddleware(BaseHTTPMiddleware):
    async def dispatch(self, request: Request, call_next: Callable) -> Response:
        response = await call_next(request)
        response.headers["X-Content-Type-Options"] = "nosniff"
        response.headers["X-Frame-Options"] = "DENY"
        response.headers["Referrer-Policy"] = "strict-origin-when-cross-origin"
        response.headers["Permissions-Policy"] = "geolocation=(), camera=(), microphone=()"
        return response


class RateLimitMiddleware(BaseHTTPMiddleware):
    async def dispatch(self, request: Request, call_next: Callable) -> Response:
        client_ip = request.client.host if request.client else "unknown"
        path = request.url.path

        if path.startswith(f"{settings.API_PREFIX}/auth/login"):
            limit = settings.RATE_LIMIT_LOGIN_PER_MINUTE
            window = 60
            key = f"rl:login:{client_ip}"
        elif path.startswith(f"{settings.API_PREFIX}/auth/otp"):
            return await call_next(request)
        elif path in ("/health", "/version", "/docs", "/openapi.json", "/redoc"):
            return await call_next(request)
        else:
            limit = settings.RATE_LIMIT_DEFAULT_PER_MINUTE
            window = 60
            key = f"rl:default:{client_ip}"

        allowed = await check_rate_limit(key, limit, window)
        if not allowed:
            return JSONResponse(
                status_code=status.HTTP_429_TOO_MANY_REQUESTS,
                content={
                    "error": {
                        "code": "RATE_LIMITED",
                        "message": "Trop de requêtes, veuillez réessayer dans quelques instants.",
                        "details": {"limit": limit, "window_seconds": window},
                    }
                },
                headers={"Retry-After": str(window)},
            )

        return await call_next(request)
