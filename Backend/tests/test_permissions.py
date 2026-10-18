import uuid

from fastapi import Depends, FastAPI
from httpx import ASGITransport, AsyncClient
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.deps import get_current_user, require_roles
from app.core.errors import AppException, app_exception_handler
from app.core.security import create_access_token
from app.db.models.identity import User

PHONE = "+22792000001"

USER_ME_ROUTES = [
    ("GET", "/api/v1/users/me", None),
    ("PATCH", "/api/v1/users/me", {"full_name": "Amina"}),
    ("PUT", "/api/v1/users/me/password", {"new_password": "MotDePasse123!"}),
    ("POST", "/api/v1/users/me/devices", {"platform": "android", "fcm_token": "t"}),
    (
        "POST",
        "/api/v1/users/me/consents",
        {"type": "terms", "version": "1.0", "accepted": True},
    ),
    ("DELETE", f"/api/v1/users/me/devices/{uuid.uuid4()}", None),
    ("GET", "/api/v1/users/me/consents", None),
    ("GET", "/api/v1/users/me/export", None),
    ("DELETE", "/api/v1/users/me", None),
]


def _iter_keys(value: object):
    if isinstance(value, dict):
        for key, item in value.items():
            yield key
            yield from _iter_keys(item)
    elif isinstance(value, list):
        for item in value:
            yield from _iter_keys(item)


async def test_users_me_routes_require_auth(client: AsyncClient) -> None:
    for method, path, body in USER_ME_ROUTES:
        response = await client.request(method, path, json=body)
        assert response.status_code == 401, (method, path, response.status_code)
        assert response.json()["error"]["code"] == "UNAUTHORIZED"


def _build_role_app() -> FastAPI:
    mini_app = FastAPI()
    mini_app.add_exception_handler(AppException, app_exception_handler)

    @mini_app.get("/admin")
    async def admin_only(user: User = Depends(require_roles("org_admin"))) -> dict:
        return {"role": user.role}

    return mini_app


async def _call_role_app(role: str) -> object:
    mini_app = _build_role_app()
    user = User(phone=f"+22792{role[:6]}", full_name="Test", role=role)
    mini_app.dependency_overrides[get_current_user] = lambda: user
    transport = ASGITransport(app=mini_app)
    async with AsyncClient(
        transport=transport, base_url="http://testserver"
    ) as http_client:
        return await http_client.get("/admin")


async def test_require_roles_allows_matching_role() -> None:
    response = await _call_role_app("org_admin")

    assert response.status_code == 200
    assert response.json() == {"role": "org_admin"}


async def test_require_roles_rejects_other_role() -> None:
    response = await _call_role_app("farmer")

    assert response.status_code == 403
    assert response.json()["error"]["code"] == "FORBIDDEN"


async def test_me_and_export_have_no_secret_keys(
    client: AsyncClient, db_session: AsyncSession
) -> None:
    registered = await client.post(
        "/api/v1/auth/register",
        json={"phone": PHONE, "full_name": "Amina", "language": "fr"},
    )
    assert registered.status_code == 201

    user = (
        await db_session.execute(select(User).where(User.phone == PHONE))
    ).scalar_one()
    headers = {"Authorization": f"Bearer {create_access_token(user.id, user.role)}"}

    me = await client.get("/api/v1/users/me", headers=headers)
    export = await client.get("/api/v1/users/me/export", headers=headers)

    assert me.status_code == 200
    assert export.status_code == 200

    for response in (me, export):
        keys = list(_iter_keys(response.json()))
        assert not any(
            "hash" in key.lower() or "password" in key.lower() for key in keys
        )
