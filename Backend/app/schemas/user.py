import uuid
from datetime import datetime
from typing import Any, Literal

from pydantic import BaseModel, ConfigDict, EmailStr


class UserResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    phone: str
    email: str | None = None
    full_name: str
    role: str
    language: str
    admin_area_id: int | None = None
    is_active: bool
    phone_verified_at: datetime | None = None
    created_at: datetime


class PlanSummary(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    code: str
    name: str
    audience: str
    billing_model: str
    quotas: dict[str, Any]
    features: dict[str, Any]


class QuotaStatus(BaseModel):
    metric: str
    limit: int
    used: int
    remaining: int


class UserMeResponse(BaseModel):
    user: UserResponse
    effective_plan: PlanSummary
    quotas: list[QuotaStatus]


class UserUpdateRequest(BaseModel):
    full_name: str | None = None
    language: Literal["fr", "ha", "dje", "en"] | None = None
    admin_area_id: int | None = None
    email: EmailStr | None = None


class DeviceCreateRequest(BaseModel):
    platform: Literal["android", "ios"]
    fcm_token: str
    app_version: str | None = None


class DeviceResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    platform: str
    fcm_token: str
    app_version: str | None = None
    last_seen_at: datetime | None = None
    created_at: datetime


class ConsentCreateRequest(BaseModel):
    type: Literal["terms", "privacy", "data_sharing_gov", "research"]
    version: str
    accepted: bool


class ConsentResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    type: str
    version: str
    accepted: bool
    created_at: datetime


class UserDataExportResponse(BaseModel):
    user: dict[str, Any]
    devices: list[dict[str, Any]]
    consents: list[dict[str, Any]]
    farms: list[dict[str, Any]]
    plots: list[dict[str, Any]]
    crop_cycles: list[dict[str, Any]]
    activities: list[dict[str, Any]]
    harvests: list[dict[str, Any]]
    diagnostics: list[dict[str, Any]]
    recommendations: list[dict[str, Any]]
    payments: list[dict[str, Any]]
