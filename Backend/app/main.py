from contextlib import asynccontextmanager
from typing import AsyncGenerator
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from app.api.router import api_router
from app.api.v1.system import router as system_router
from app.core.config import settings
from app.core.errors import register_error_handlers
from app.core.logging import get_logger, setup_logging
from app.core.middleware import (
    RateLimitMiddleware,
    RequestIDMiddleware,
    SecurityHeadersMiddleware,
)
from app.db.session import async_engine

logger = get_logger("main")


@asynccontextmanager
async def lifespan(app: FastAPI) -> AsyncGenerator[None, None]:
    setup_logging()
    logger.info("application_starting", app_name=settings.APP_NAME, env=settings.APP_ENV)
    try:
        yield
    finally:
        logger.info("application_stopping")
        await async_engine.dispose()


def create_application() -> FastAPI:
    app = FastAPI(
        title=settings.APP_NAME,
        version="0.1.0",
        docs_url="/docs",
        redoc_url="/redoc",
        openapi_url="/openapi.json",
        lifespan=lifespan,
    )

    app.add_middleware(
        CORSMiddleware,
        allow_origins=settings.CORS_ORIGINS,
        allow_credentials=True,
        allow_methods=["*"],
        allow_headers=["*"],
    )
    app.add_middleware(RateLimitMiddleware)
    app.add_middleware(SecurityHeadersMiddleware)
    app.add_middleware(RequestIDMiddleware)

    register_error_handlers(app)

    app.include_router(system_router)
    app.include_router(api_router, prefix=settings.API_PREFIX)

    return app


app = create_application()
