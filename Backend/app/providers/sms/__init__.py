from app.core.config import settings
from app.providers.sms.base import SmsProvider
from app.providers.sms.fake import FakeSmsProvider
from app.providers.sms.http import HttpSmsProvider


def get_sms_provider() -> SmsProvider:
    if settings.SMS_PROVIDER == "http" and settings.SMS_HTTP_URL:
        return HttpSmsProvider()
    return FakeSmsProvider()


__all__ = ["SmsProvider", "FakeSmsProvider", "HttpSmsProvider", "get_sms_provider"]
