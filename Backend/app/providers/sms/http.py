import httpx

from app.core.config import settings
from app.core.logging import get_logger
from app.providers.sms.base import SmsProvider

logger = get_logger("sms.http")


class HttpSmsProvider(SmsProvider):
    def __init__(self) -> None:
        self.url = settings.SMS_HTTP_URL
        self.api_key = settings.SMS_HTTP_KEY

    async def send_sms(self, phone: str, message: str) -> bool:
        if not self.url:
            logger.error("sms_http_url_not_configured")
            return False

        headers = {
            "Content-Type": "application/json",
        }
        if self.api_key:
            headers["Authorization"] = f"Bearer {self.api_key}"

        payload = {
            "to": phone,
            "message": message,
        }

        try:
            async with httpx.AsyncClient(timeout=10.0) as client:
                response = await client.post(self.url, json=payload, headers=headers)
                if response.status_code in (200, 201, 202):
                    return True
                logger.error(
                    "sms_http_failed",
                    status_code=response.status_code,
                    body=response.text,
                )
                return False
        except Exception as exc:
            logger.error("sms_http_exception", error=str(exc))
            return False
