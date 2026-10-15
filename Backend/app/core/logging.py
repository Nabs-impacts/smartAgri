import logging
import re
import sys
from contextvars import ContextVar
from typing import Any
import structlog
from app.core.config import settings

request_id_ctx: ContextVar[str] = ContextVar("request_id", default="")

PHONE_PATTERN = re.compile(r"(\+227)(\d{4})(\d{4})")
SENSITIVE_KEYS = {
    "password",
    "token",
    "access_token",
    "refresh_token",
    "otp",
    "code",
    "secret",
    "authorization",
    "api_key",
    "license_key",
    "key_hash",
}


def mask_sensitive_data(
    logger: Any, method_name: str, event_dict: dict[str, Any]
) -> dict[str, Any]:
    for key, value in list(event_dict.items()):
        lower_key = key.lower()
        if any(secret_term in lower_key for secret_term in SENSITIVE_KEYS):
            event_dict[key] = "********"
        elif isinstance(value, str):
            event_dict[key] = PHONE_PATTERN.sub(r"\1****\3", value)
    return event_dict


def add_request_id(
    logger: Any, method_name: str, event_dict: dict[str, Any]
) -> dict[str, Any]:
    req_id = request_id_ctx.get()
    if req_id:
        event_dict["request_id"] = req_id
    return event_dict


def setup_logging() -> None:
    log_level = getattr(logging, settings.LOG_LEVEL.upper(), logging.INFO)

    shared_processors: list[Any] = [
        structlog.contextvars.merge_contextvars,
        add_request_id,
        structlog.stdlib.add_logger_name,
        structlog.stdlib.add_log_level,
        structlog.processors.TimeStamper(fmt="iso", utc=True),
        mask_sensitive_data,
        structlog.processors.StackInfoRenderer(),
        structlog.processors.format_exc_info,
    ]

    structlog.configure(
        processors=shared_processors + [
            structlog.stdlib.ProcessorFormatter.wrap_for_formatter,
        ],
        logger_factory=structlog.stdlib.LoggerFactory(),
        wrapper_class=structlog.stdlib.BoundLogger,
        cache_logger_on_first_use=True,
    )

    formatter = structlog.stdlib.ProcessorFormatter(
        foreign_pre_chain=shared_processors,
        processors=[
            structlog.stdlib.ProcessorFormatter.remove_processors_meta,
            structlog.processors.JSONRenderer(),
        ],
    )

    handler = logging.StreamHandler(sys.stdout)
    handler.setFormatter(formatter)

    root_logger = logging.getLogger()
    root_logger.handlers = [handler]
    root_logger.setLevel(log_level)

    for uvicorn_logger_name in ("uvicorn", "uvicorn.error", "uvicorn.access"):
        uv_logger = logging.getLogger(uvicorn_logger_name)
        uv_logger.handlers = [handler]
        uv_logger.propagate = False


def get_logger(name: str | None = None) -> structlog.stdlib.BoundLogger:
    return structlog.get_logger(name)
