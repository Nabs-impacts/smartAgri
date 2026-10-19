import uuid
from datetime import datetime
from decimal import Decimal
from typing import Literal

from pydantic import BaseModel, ConfigDict, EmailStr, Field, field_validator

OrganizationType = Literal[
    "cooperative",
    "ngo",
    "agri_company",
    "bank",
    "insurer",
    "government",
    "other",
]
MemberRole = Literal["owner", "admin", "agent", "member"]


class OrganizationCreateRequest(BaseModel):
    name: str = Field(min_length=1, max_length=200)
    type: OrganizationType
    registration_no: str | None = None
    admin_area_id: int | None = None
    contact_phone: str | None = None
    contact_email: EmailStr | None = None

    @field_validator("name", mode="before")
    @classmethod
    def _strip_name(cls, value: object) -> object:
        return value.strip() if isinstance(value, str) else value


class OrganizationUpdateRequest(BaseModel):
    name: str | None = Field(default=None, min_length=1, max_length=200)
    type: OrganizationType | None = None
    registration_no: str | None = None
    admin_area_id: int | None = None
    contact_phone: str | None = None
    contact_email: EmailStr | None = None

    @field_validator("name", mode="before")
    @classmethod
    def _strip_name(cls, value: object) -> object:
        return value.strip() if isinstance(value, str) else value


class OrganizationResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    name: str
    type: str
    registration_no: str | None = None
    admin_area_id: int | None = None
    contact_phone: str | None = None
    contact_email: str | None = None
    is_active: bool
    created_at: datetime
    updated_at: datetime
    member_role: str | None = None


class OrganizationMemberCreateRequest(BaseModel):
    phone: str
    member_role: MemberRole = "member"


class OrganizationMemberResponse(BaseModel):
    user_id: uuid.UUID
    phone: str
    full_name: str
    member_role: str
    joined_at: datetime
    plot_count: int
    area_ha: Decimal


class CropYieldResponse(BaseModel):
    crop_id: int
    crop_code: str
    crop_name: str
    average_yield_kg_per_ha: Decimal | None = None
    sample_size: int


class OrganizationDashboardResponse(BaseModel):
    member_count: int
    plot_count: int
    total_area_ha: Decimal
    average_yield_by_crop: list[CropYieldResponse]
    diagnostics_this_month: int
    active_alerts: int
