from typing import Literal
from pydantic import BaseModel, Field
from app.schemas.user import UserResponse


class RegisterRequest(BaseModel):
    phone: str
    full_name: str
    language: Literal["fr", "ha", "dje", "en"] = "fr"
    password: str | None = None


class RegisterResponse(BaseModel):
    message: str
    phone: str


class OtpRequest(BaseModel):
    phone: str
    purpose: Literal["login", "verify_phone", "reset_password"]


class OtpRequestResponse(BaseModel):
    message: str


class DevicePayload(BaseModel):
    platform: Literal["android", "ios"]
    fcm_token: str
    app_version: str | None = None


class OtpVerifyRequest(BaseModel):
    phone: str
    code: str
    purpose: Literal["login", "verify_phone", "reset_password"]
    device: DevicePayload | None = None


class LoginRequest(BaseModel):
    phone: str
    password: str
    device: DevicePayload | None = None


class TokenResponse(BaseModel):
    access_token: str
    refresh_token: str
    token_type: str = "bearer"
    expires_in: int
    user: UserResponse


class RefreshRequest(BaseModel):
    refresh_token: str


class LogoutRequest(BaseModel):
    refresh_token: str


class PasswordResetRequest(BaseModel):
    phone: str
    code: str
    new_password: str


class MessageResponse(BaseModel):
    message: str
