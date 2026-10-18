from datetime import UTC, datetime, timedelta

from fastapi import BackgroundTasks
from sqlalchemy import desc, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import settings
from app.core.errors import RateLimitedException, UnauthorizedException
from app.core.logging import get_logger
from app.core.rate_limit import check_rate_limit
from app.core.security import generate_otp_code, hash_otp, normalize_phone
from app.core.security import verify_otp as verify_otp_hash
from app.db.models.identity import OtpCode
from app.providers.sms import get_sms_provider
from app.providers.sms.base import SmsProvider

logger = get_logger("otp_service")

_INVALID_OTP_MESSAGE = "Code invalide ou expiré."


async def _deliver_sms(provider: SmsProvider, phone: str, message: str) -> None:
    try:
        await provider.send_sms(phone=phone, message=message)
    except Exception as exc:
        logger.warning("sms_send_failed", error=str(exc))


class OtpService:
    async def enforce_phone_rate_limit(self, phone: str) -> None:
        norm_phone = normalize_phone(phone)
        allowed = await check_rate_limit(
            f"rl:otp:{norm_phone}",
            settings.OTP_REQUESTS_PER_WINDOW,
            settings.OTP_WINDOW_SECONDS,
        )
        if not allowed:
            raise RateLimitedException(
                message="Trop de demandes de code, veuillez patienter.",
                details={"window_seconds": settings.OTP_WINDOW_SECONDS},
            )

    async def _store_and_schedule(
        self,
        session: AsyncSession,
        norm_phone: str,
        purpose: str,
        background_tasks: BackgroundTasks,
    ) -> None:
        code = generate_otp_code()
        code_hash = hash_otp(code)
        now = datetime.now(UTC)
        expires_at = now + timedelta(seconds=settings.OTP_TTL_SECONDS)

        otp_record = OtpCode(
            phone=norm_phone,
            code_hash=code_hash,
            purpose=purpose,
            expires_at=expires_at,
        )
        session.add(otp_record)
        await session.commit()

        sms_provider = get_sms_provider()
        message = f"Votre code de vérification SmartAgri est: {code}"
        background_tasks.add_task(_deliver_sms, sms_provider, norm_phone, message)

    async def send_otp(
        self,
        session: AsyncSession,
        phone: str,
        purpose: str,
        background_tasks: BackgroundTasks,
        apply_rate_limit: bool = True,
    ) -> None:
        norm_phone = normalize_phone(phone)
        if apply_rate_limit:
            await self.enforce_phone_rate_limit(norm_phone)
        await self._store_and_schedule(session, norm_phone, purpose, background_tasks)

    async def verify_otp(
        self, session: AsyncSession, phone: str, code: str, purpose: str
    ) -> bool:
        norm_phone = normalize_phone(phone)
        now = datetime.now(UTC)

        query = (
            select(OtpCode)
            .where(
                OtpCode.phone == norm_phone,
                OtpCode.purpose == purpose,
                OtpCode.consumed_at.is_(None),
            )
            .order_by(desc(OtpCode.created_at))
            .with_for_update()
        )
        result = await session.execute(query)
        record = result.scalars().first()

        if not record:
            raise UnauthorizedException(message=_INVALID_OTP_MESSAGE)

        if record.expires_at < now:
            raise UnauthorizedException(message=_INVALID_OTP_MESSAGE)

        if record.attempts >= settings.OTP_MAX_ATTEMPTS:
            raise UnauthorizedException(message=_INVALID_OTP_MESSAGE)

        record.attempts += 1

        if not verify_otp_hash(code, record.code_hash):
            await session.commit()
            raise UnauthorizedException(message=_INVALID_OTP_MESSAGE)

        record.consumed_at = now
        await session.commit()
        return True


otp_service = OtpService()
