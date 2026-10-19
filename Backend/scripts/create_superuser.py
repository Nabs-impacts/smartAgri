import argparse
import asyncio
import sys
from datetime import UTC, datetime

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.security import hash_password, normalize_phone
from app.db.models.identity import User
from app.db.session import AsyncSessionLocal


async def create_or_update_superuser(
    session: AsyncSession,
    phone: str,
    name: str,
    password: str,
) -> None:
    norm_phone = normalize_phone(phone)
    pwd_hash = hash_password(password)
    now = datetime.now(UTC)

    stmt = select(User).where(User.phone == norm_phone)
    user = (await session.execute(stmt)).scalar_one_or_none()

    if user is None:
        user = User(
            phone=norm_phone,
            full_name=name,
            password_hash=pwd_hash,
            role="super_admin",
            is_active=True,
            phone_verified_at=now,
            language="fr",
        )
        session.add(user)
    else:
        user.full_name = name
        user.password_hash = pwd_hash
        user.role = "super_admin"
        user.is_active = True
        if user.phone_verified_at is None:
            user.phone_verified_at = now

    await session.commit()


async def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("pos_phone", nargs="?", default=None)
    parser.add_argument("pos_name", nargs="?", default=None)
    parser.add_argument("pos_password", nargs="?", default=None)
    parser.add_argument("--phone", dest="flag_phone", default=None)
    parser.add_argument("--name", dest="flag_name", default=None)
    parser.add_argument("--password", dest="flag_password", default=None)

    args = parser.parse_args()

    phone = args.flag_phone or args.pos_phone
    name = args.flag_name or args.pos_name
    password = args.flag_password or args.pos_password

    if not phone or not name or not password:
        sys.exit(1)

    async with AsyncSessionLocal() as session:
        await create_or_update_superuser(session, phone, name, password)


if __name__ == "__main__":
    asyncio.run(main())
