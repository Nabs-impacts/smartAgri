from typing import ClassVar
from app.core.logging import get_logger
from app.providers.sms.base import SmsProvider

logger = get_logger("sms.fake")


class FakeSmsProvider(SmsProvider):
    sent_messages: ClassVar[list[dict[str, str]]] = []

    async def send_sms(self, phone: str, message: str) -> bool:
        logger.info("fake_sms_dispatched", phone=phone, message=message)
        self.sent_messages.append({"phone": phone, "message": message})
        return True

    @classmethod
    def clear(cls) -> None:
        cls.sent_messages.clear()
