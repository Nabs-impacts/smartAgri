import re

from httpx import AsyncClient
from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.db.models.billing import Plan
from app.db.models.farming import Crop
from app.db.models.identity import AdminArea
from app.db.models.media_ai import DiagnosisLabel
from app.providers.sms.fake import FakeSmsProvider
from scripts.seed import seed_database

PHONE = "+22791110001"
OTP_PATTERN = re.compile(r"(\d{6})")


def _last_otp_code() -> str:
    message = FakeSmsProvider.sent_messages[-1]["message"]
    match = OTP_PATTERN.search(message)
    assert match is not None
    return match.group(1)


async def _register_verified(
    client: AsyncClient, phone: str = PHONE
) -> dict[str, object]:
    registered = await client.post(
        "/api/v1/auth/register",
        json={"phone": phone, "full_name": "Amina", "language": "fr"},
    )
    assert registered.status_code == 201

    verified = await client.post(
        "/api/v1/auth/otp/verify",
        json={"phone": phone, "code": _last_otp_code(), "purpose": "verify_phone"},
    )
    assert verified.status_code == 200
    return verified.json()


def _auth_headers(tokens: dict[str, object]) -> dict[str, str]:
    return {"Authorization": f"Bearer {tokens['access_token']}"}


async def test_seed_is_idempotent(db_session: AsyncSession) -> None:
    await seed_database(db_session)
    await seed_database(db_session)

    area_count = await db_session.scalar(select(func.count(AdminArea.id)))
    crop_count = await db_session.scalar(select(func.count(Crop.id)))
    label_count = await db_session.scalar(select(func.count(DiagnosisLabel.id)))
    plan_count = await db_session.scalar(select(func.count(Plan.id)))

    assert area_count == 8
    assert crop_count == 10
    assert label_count == 8
    assert plan_count == 4


async def test_catalog_endpoints_require_auth(client: AsyncClient) -> None:
    res_crops = await client.get("/api/v1/crops")
    assert res_crops.status_code == 401

    res_labels = await client.get("/api/v1/diagnosis-labels")
    assert res_labels.status_code == 401

    res_areas = await client.get("/api/v1/admin-areas")
    assert res_areas.status_code == 401


async def test_get_crops_content_and_etag(client: AsyncClient) -> None:
    tokens = await _register_verified(client)
    headers = _auth_headers(tokens)

    response = await client.get("/api/v1/crops", headers=headers)
    assert response.status_code == 200
    etag = response.headers.get("ETag")
    assert etag is not None

    crops = response.json()
    assert len(crops) == 10

    crops_by_code = {c["code"]: c for c in crops}
    expected_ha = {
        "millet": "gero",
        "sorghum": "dawa",
        "cowpea": "wake",
        "maize": "masara",
        "rice": "shinkafa",
        "groundnut": "gyada",
        "onion": "albasa",
        "tomato": "tumatir",
        "cabbage": "kabeji",
        "pepper": "barkono",
    }
    for code, ha_name in expected_ha.items():
        assert code in crops_by_code
        assert crops_by_code[code]["name_ha"] == ha_name
        assert crops_by_code[code]["name_dje"] is None
        assert crops_by_code[code]["cycle_days"] is not None

    conditional = await client.get(
        "/api/v1/crops",
        headers={**headers, "If-None-Match": etag},
    )
    assert conditional.status_code == 304


async def test_get_diagnosis_labels_and_filters_and_etag(
    client: AsyncClient, db_session: AsyncSession
) -> None:
    tokens = await _register_verified(client)
    headers = _auth_headers(tokens)

    response = await client.get("/api/v1/diagnosis-labels", headers=headers)
    assert response.status_code == 200
    etag = response.headers.get("ETag")
    assert etag is not None

    labels = response.json()
    assert len(labels) == 8

    labels_by_code = {item["code"]: item for item in labels}
    expected_codes = [
        "healthy",
        "fall_armyworm",
        "desert_locust",
        "millet_downy_mildew",
        "striga",
        "cowpea_aphid",
        "tomato_leaf_curl",
        "nitrogen_deficiency",
    ]
    for code in expected_codes:
        assert code in labels_by_code
        label = labels_by_code[code]
        assert label["guideline"] == {
            "validated": False,
            "urgency": None,
            "cultural": [],
            "biological": [],
            "chemical": [],
            "prevention": [],
        }
        assert isinstance(label["crop_ids"], list)

    conditional = await client.get(
        "/api/v1/diagnosis-labels",
        headers={**headers, "If-None-Match": etag},
    )
    assert conditional.status_code == 304

    millet = await db_session.scalar(select(Crop).where(Crop.code == "millet"))
    assert millet is not None

    filtered_res = await client.get(
        f"/api/v1/diagnosis-labels?crop_id={millet.id}",
        headers=headers,
    )
    assert filtered_res.status_code == 200
    filtered_labels = filtered_res.json()
    filtered_codes = [item["code"] for item in filtered_labels]
    assert "millet_downy_mildew" in filtered_codes
    assert "tomato_leaf_curl" not in filtered_codes


async def test_get_admin_areas_content_and_filters(client: AsyncClient) -> None:
    tokens = await _register_verified(client)
    headers = _auth_headers(tokens)

    response = await client.get("/api/v1/admin-areas", headers=headers)
    assert response.status_code == 200
    areas = response.json()
    assert len(areas) == 8

    area_names = {a["name"] for a in areas}
    expected_names = {
        "Agadez",
        "Diffa",
        "Dosso",
        "Maradi",
        "Niamey",
        "Tahoua",
        "Tillabéri",
        "Zinder",
    }
    assert area_names == expected_names
    for a in areas:
        assert a["level"] == "region"
        assert a["geom"] is None

    res_region = await client.get("/api/v1/admin-areas?level=region", headers=headers)
    assert res_region.status_code == 200
    assert len(res_region.json()) == 8

    res_commune = await client.get("/api/v1/admin-areas?level=commune", headers=headers)
    assert res_commune.status_code == 200
    assert len(res_commune.json()) == 0

    res_geom = await client.get("/api/v1/admin-areas?include_geom=true", headers=headers)
    assert res_geom.status_code == 200
    assert len(res_geom.json()) == 8


async def test_get_plans_public_and_filter(client: AsyncClient) -> None:
    response = await client.get("/api/v1/plans")
    assert response.status_code == 200
    plans = response.json()
    assert len(plans) == 4

    plans_by_code = {p["code"]: p for p in plans}
    assert "free" in plans_by_code
    assert "farmer_pro" in plans_by_code
    assert "coop_standard" in plans_by_code
    assert "gov_license" in plans_by_code

    free_plan = plans_by_code["free"]
    assert free_plan["price_xof"] == 0
    assert free_plan["quotas"]["diagnostics_per_month"] == 10
    assert free_plan["quotas"]["llm_messages_per_month"] == 20
    assert free_plan["quotas"]["video_analyses_per_month"] == 0
    assert free_plan["quotas"]["plots"] == 3

    farmer_pro = plans_by_code["farmer_pro"]
    assert farmer_pro["price_xof"] == 1500
    assert farmer_pro["quotas"]["diagnostics_per_month"] == 60
    assert farmer_pro["quotas"]["llm_messages_per_month"] == 100
    assert farmer_pro["quotas"]["video_analyses_per_month"] == 10
    assert farmer_pro["quotas"]["plots"] == 20

    coop = plans_by_code["coop_standard"]
    assert coop["price_xof"] == 25000
    assert coop["audience"] == "organization"

    gov = plans_by_code["gov_license"]
    assert gov["price_xof"] == 0
    assert gov["billing_model"] == "license"
    assert gov["audience"] == "government"
    assert gov["quotas"]["diagnostics_per_month"] == -1
    assert gov["quotas"]["plots"] == -1

    farmer_filter = await client.get("/api/v1/plans?audience=farmer")
    assert farmer_filter.status_code == 200
    assert len(farmer_filter.json()) == 2

    org_filter = await client.get("/api/v1/plans?audience=organization")
    assert org_filter.status_code == 200
    assert len(org_filter.json()) == 1
    assert org_filter.json()[0]["code"] == "coop_standard"

    gov_filter = await client.get("/api/v1/plans?audience=government")
    assert gov_filter.status_code == 200
    assert len(gov_filter.json()) == 1
    assert gov_filter.json()[0]["code"] == "gov_license"
