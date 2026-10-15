from abc import ABC, abstractmethod


class SmsProvider(ABC):
    @abstractmethod
    async def send_sms(self, phone: str, message: str) -> bool:
        return False
