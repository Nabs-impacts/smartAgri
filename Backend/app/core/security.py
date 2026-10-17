import hashlib
import hmac
import re
import secrets
import uuid
from datetime import UTC, datetime, timedelta
from typing import Any

import jwt
from argon2 import PasswordHasher
from argon2.exceptions import VerifyMismatchError

from app.core.config import settings
from app.core.errors import UnauthorizedException

password_hasher = PasswordHasher()


def hash_password(password: str) -> str:
    return password_hasher.hash(password)


def verify_password(password: str, hash_str: str) -> bool:
    try:
        return password_hasher.verify(hash_str, password)
    except (VerifyMismatchError, Exception):
        return False


def normalize_phone(phone: str) -> str:
    cleaned = re.sub(r"[\s\-\.\(\)]", "", phone.strip())
    if cleaned.startswith("+"):
        return cleaned
    if cleaned.startswith("00"):
        return f"+{cleaned[2:]}"
    if cleaned.startswith("227") and len(cleaned) == 11:
        return f"+{cleaned}"
    if len(cleaned) == 8 and cleaned.isdigit():
        return f"+227{cleaned}"
    return f"+{cleaned}"


def generate_otp_code() -> str:
    return f"{secrets.randbelow(1_000_000):06d}"


def hash_otp(code: str) -> str:
    return hmac.new(
        settings.OTP_HMAC_SECRET.encode("utf-8"),
        code.strip().encode("utf-8"),
        hashlib.sha256,
    ).hexdigest()


def verify_otp(code: str, hashed_code: str) -> bool:
    computed = hash_otp(code)
    return hmac.compare_digest(computed, hashed_code)


def generate_refresh_token() -> str:
    return secrets.token_urlsafe(64)


def hash_refresh_token(token: str) -> str:
    return hashlib.sha256(token.encode("utf-8")).hexdigest()


def generate_api_key() -> str:
    return f"sa_live_{secrets.token_urlsafe(32)}"


def hash_api_key(raw_key: str) -> str:
    return hmac.new(
        settings.API_KEY_PEPPER.encode("utf-8"),
        raw_key.strip().encode("utf-8"),
        hashlib.sha256,
    ).hexdigest()


def generate_license_key() -> str:
    part1 = secrets.token_hex(2).upper()
    part2 = secrets.token_hex(2).upper()
    part3 = secrets.token_hex(2).upper()
    part4 = secrets.token_hex(2).upper()
    return f"SA-{part1}-{part2}-{part3}-{part4}"


def hash_license_key(raw_key: str) -> str:
    return hmac.new(
        settings.LICENSE_KEY_PEPPER.encode("utf-8"),
        raw_key.strip().encode("utf-8"),
        hashlib.sha256,
    ).hexdigest()


def create_access_token(
    user_id: uuid.UUID | str,
    role: str,
    expires_delta: timedelta | None = None,
) -> str:
    now = datetime.now(UTC)
    if expires_delta is not None:
        expire = now + expires_delta
    else:
        expire = now + timedelta(minutes=settings.ACCESS_TOKEN_MINUTES)

    payload = {
        "sub": str(user_id),
        "role": role,
        "jti": uuid.uuid4().hex,
        "iat": int(now.timestamp()),
        "exp": int(expire.timestamp()),
    }
    return jwt.encode(payload, settings.JWT_SECRET, algorithm=settings.JWT_ALGORITHM)


def decode_access_token(token: str) -> dict[str, Any]:
    try:
        payload = jwt.decode(
            token,
            settings.JWT_SECRET,
            algorithms=[settings.JWT_ALGORITHM],
        )
        return payload
    except jwt.PyJWTError as exc:
        raise UnauthorizedException(
            message="Jeton d'accès invalide ou expiré.",
            details=str(exc),
        ) from exc


def create_license_token(
    license_id: uuid.UUID | str,
    organization_id: uuid.UUID | str,
    plan_id: int,
    device_fingerprint: str,
    expires_at: datetime | None = None,
) -> str:
    now = datetime.now(UTC)
    payload = {
        "license_id": str(license_id),
        "organization_id": str(organization_id),
        "plan_id": plan_id,
        "device": device_fingerprint,
        "iat": int(now.timestamp()),
    }
    if expires_at:
        payload["exp"] = int(expires_at.timestamp())
    return jwt.encode(payload, settings.LICENSE_TOKEN_SECRET, algorithm="HS256")


def decode_license_token(token: str) -> dict[str, Any]:
    try:
        return jwt.decode(
            token,
            settings.LICENSE_TOKEN_SECRET,
            algorithms=["HS256"],
        )
    except jwt.PyJWTError as exc:
        raise UnauthorizedException(
            message="Jeton de licence invalide ou expiré.",
            details=str(exc),
        ) from exc
