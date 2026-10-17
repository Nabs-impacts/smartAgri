from datetime import UTC, datetime, timedelta

from sqlalchemy import desc, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import settings
from app.core.errors import RateLimitedException, UnauthorizedException
from app.core.rate_limit import check_rate_limit
from app.core.security import generate_otp_code, hash_otp, normalize_phone
from app.core.security import verify_otp as verify_otp_hash
from app.db.models.identity import OtpCode
from app.providers.sms import get_sms_provider


class OtpService:
    async def send_otp(self, session: AsyncSession, phone: str, purpose: str) -> None:
        norm_phone = normalize_phone(phone)
        rate_key = f"rl:otp:{norm_phone}"
        allowed = await check_rate_limit(
            rate_key,
            settings.OTP_REQUESTS_PER_WINDOW,
            settings.OTP_WINDOW_SECONDS,
        )
        if not allowed:
            raise RateLimitedException(
                message="Trop de demandes de code, veuillez patienter.",
                details={"window_seconds": settings.OTP_WINDOW_SECONDS},
            )

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
        await sms_provider.send_sms(phone=norm_phone, message=message)

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
            raise UnauthorizedException(
                message="Code de vérification introuvable ou invalide."
            )

        if record.expires_at < now:
            raise UnauthorizedException(
                message="Code de vérification expiré."
            )

        if record.attempts >= settings.OTP_MAX_ATTEMPTS:
            raise UnauthorizedException(
                message="Nombre maximal de tentatives dépassé."
            )

        record.attempts += 1

        if not verify_otp_hash(code, record.code_hash):
            await session.commit()
            raise UnauthorizedException(
                message="Code de vérification incorrect."
            )

        record.consumed_at = now
        await session.commit()
        return True


otp_service = OtpService()
