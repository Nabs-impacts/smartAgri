from typing import Annotated, Any, Literal

from pydantic import field_validator
from pydantic_settings import BaseSettings, NoDecode, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        extra="ignore",
        case_sensitive=True,
    )

    APP_ENV: Literal["local", "staging", "production"] = "local"
    APP_NAME: str = "SmartAgri API"
    API_PREFIX: str = "/api/v1"
    CORS_ORIGINS: Annotated[list[str], NoDecode] = [
        "http://localhost:3000",
        "http://localhost:8000",
    ]
    LOG_LEVEL: str = "INFO"
    SENTRY_DSN: str | None = None

    DATABASE_URL: str = "postgresql+asyncpg://smartagri:smartagri@localhost:5432/smartagri"
    DATABASE_URL_SYNC: str = "postgresql+psycopg://smartagri:smartagri@localhost:5432/smartagri"
    DB_POOL_SIZE: int = 10
    DB_MAX_OVERFLOW: int = 20

    REDIS_URL: str = "redis://localhost:6379/0"
    CELERY_BROKER_URL: str = "redis://localhost:6379/1"
    CELERY_RESULT_BACKEND: str = "redis://localhost:6379/2"

    JWT_SECRET: str = "dev-jwt-secret-replace-in-production-min-32-chars"
    JWT_ALGORITHM: str = "HS256"
    ACCESS_TOKEN_MINUTES: int = 15
    REFRESH_TOKEN_DAYS: int = 30
    REFRESH_REUSE_GRACE_SECONDS: int = 45
    OTP_HMAC_SECRET: str = "dev-otp-hmac-secret-min-32-chars"
    OTP_TTL_SECONDS: int = 300
    OTP_MAX_ATTEMPTS: int = 5
    OTP_REQUESTS_PER_WINDOW: int = 3
    OTP_REQUESTS_PER_IP_WINDOW: int = 10
    OTP_WINDOW_SECONDS: int = 600
    API_KEY_PEPPER: str = "dev-api-key-pepper-min-32-chars"
    LICENSE_KEY_PEPPER: str = "dev-license-key-pepper-min-32-chars"
    LICENSE_TOKEN_SECRET: str = "dev-license-token-secret-min-32-chars"

    S3_ENDPOINT_URL: str = "http://localhost:9000"
    S3_REGION: str = "us-east-1"
    S3_ACCESS_KEY: str = "rustfsadmin"
    S3_SECRET_KEY: str = "rustfsadmin"
    S3_BUCKET: str = "smartagri-media"
    S3_PRESIGN_UPLOAD_SECONDS: int = 600
    S3_PRESIGN_READ_SECONDS: int = 600

    MAX_IMAGE_BYTES: int = 3145728
    MAX_VIDEO_BYTES: int = 20971520
    MAX_VIDEO_SECONDS: int = 15
    MAX_AUDIO_BYTES: int = 2097152
    MAX_AUDIO_SECONDS: int = 60
    ALLOWED_IMAGE_MIME: Annotated[list[str], NoDecode] = [
        "image/jpeg",
        "image/png",
        "image/webp",
    ]
    ALLOWED_VIDEO_MIME: Annotated[list[str], NoDecode] = [
        "video/mp4",
        "video/quicktime",
    ]
    ALLOWED_AUDIO_MIME: Annotated[list[str], NoDecode] = [
        "audio/mpeg",
        "audio/wav",
        "audio/ogg",
        "audio/mp4",
        "audio/aac",
    ]

    INFERENCE_MODE: Literal["stub", "onnx"] = "stub"
    MODEL_CACHE_DIR: str = "/tmp/smartagri_models"
    DIAGNOSTIC_CONFIDENCE_THRESHOLD: float = 0.70
    OUTBREAK_MIN_CONFIDENCE: float = 0.50
    OUTBREAK_ALERT_THRESHOLD: int = 5
    OUTBREAK_ALERT_WINDOW_DAYS: int = 7
    KEYFRAME_COUNT: int = 5

    SMS_PROVIDER: Literal["fake", "http"] = "fake"
    SMS_HTTP_URL: str | None = None
    SMS_HTTP_KEY: str | None = None
    PUSH_PROVIDER: Literal["fake", "fcm"] = "fake"
    FCM_CREDENTIALS_PATH: str | None = None
    LLM_PROVIDER: Literal["fake", "anthropic"] = "fake"
    LLM_API_KEY: str | None = None
    LLM_MODEL: str = "claude-3-5-sonnet-20241022"
    EMBEDDING_PROVIDER: Literal["fake", "http"] = "fake"
    EMBEDDING_HTTP_URL: str | None = None
    EMBEDDING_HTTP_KEY: str | None = None
    EMBEDDING_DIM: int = 1024
    WEATHER_PROVIDER: Literal["fake", "open_meteo"] = "fake"
    SATELLITE_PROVIDER: Literal["fake", "sentinel"] = "fake"
    SENTINEL_CLIENT_ID: str | None = None
    SENTINEL_CLIENT_SECRET: str | None = None

    PAYMENT_PROVIDER_MODE: Literal["fake", "live"] = "fake"
    PAYMENT_AGGREGATOR_BASE_URL: str = "http://localhost:8000/fake-aggregator"
    PAYMENT_AGGREGATOR_API_KEY: str = "fake-api-key"
    PAYMENT_AGGREGATOR_WEBHOOK_SECRET: str = "fake-webhook-secret"
    PAYMENT_PENDING_TIMEOUT_MINUTES: int = 30
    SUBSCRIPTION_RENEWAL_REMINDER_DAYS: int = 3

    DATA_EXPORT_URL_SECONDS: int = 86400
    RATE_LIMIT_LOGIN_PER_MINUTE: int = 10
    RATE_LIMIT_DEFAULT_PER_MINUTE: int = 120

    @field_validator(
        "CORS_ORIGINS",
        "ALLOWED_IMAGE_MIME",
        "ALLOWED_VIDEO_MIME",
        "ALLOWED_AUDIO_MIME",
        mode="before",
    )
    @classmethod
    def parse_comma_separated_list(cls, value: Any) -> list[str]:
        if isinstance(value, str):
            stripped = value.strip()
            if not stripped:
                return []
            return [item.strip() for item in stripped.split(",") if item.strip()]
        if isinstance(value, list):
            return [str(item).strip() for item in value if str(item).strip()]
        return []


settings = Settings()
