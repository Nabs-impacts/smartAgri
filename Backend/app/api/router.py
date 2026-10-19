from fastapi import APIRouter

from app.api.v1 import (
    auth,
    catalog,
    cycles,
    farms,
    organizations,
    sync,
    system,
    users,
)

api_router = APIRouter()
api_router.include_router(system.router, tags=["system"])
api_router.include_router(auth.router, prefix="/auth", tags=["auth"])
api_router.include_router(users.router, prefix="/users", tags=["users"])
api_router.include_router(catalog.router, tags=["catalog"])
api_router.include_router(farms.router, tags=["farms", "plots"])
api_router.include_router(organizations.router, tags=["organizations"])
api_router.include_router(
    cycles.router, tags=["cycles", "activities", "harvests", "timeline"]
)
api_router.include_router(sync.router, prefix="/sync", tags=["sync"])


