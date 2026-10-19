import asyncio
from typing import Any

from sqlalchemy import delete, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.db.models.billing import Plan
from app.db.models.farming import Crop
from app.db.models.identity import AdminArea
from app.db.models.media_ai import DiagnosisLabel, LabelCrop
from app.db.session import AsyncSessionLocal

ADMIN_AREAS = [
    {"code": "NER-AGADEZ", "name": "Agadez", "level": "region"},
    {"code": "NER-DIFFA", "name": "Diffa", "level": "region"},
    {"code": "NER-DOSSO", "name": "Dosso", "level": "region"},
    {"code": "NER-MARADI", "name": "Maradi", "level": "region"},
    {"code": "NER-NIAMEY", "name": "Niamey", "level": "region"},
    {"code": "NER-TAHOUA", "name": "Tahoua", "level": "region"},
    {"code": "NER-TILLABERI", "name": "Tillabéri", "level": "region"},
    {"code": "NER-ZINDER", "name": "Zinder", "level": "region"},
]

CROPS = [
    {
        "code": "millet",
        "name_fr": "Mil",
        "name_ha": "gero",
        "name_dje": None,
        "category": "cereal",
        "cycle_days": 90,
    },
    {
        "code": "sorghum",
        "name_fr": "Sorgho",
        "name_ha": "dawa",
        "name_dje": None,
        "category": "cereal",
        "cycle_days": 110,
    },
    {
        "code": "cowpea",
        "name_fr": "Niébé",
        "name_ha": "wake",
        "name_dje": None,
        "category": "legume",
        "cycle_days": 75,
    },
    {
        "code": "maize",
        "name_fr": "Maïs",
        "name_ha": "masara",
        "name_dje": None,
        "category": "cereal",
        "cycle_days": 100,
    },
    {
        "code": "rice",
        "name_fr": "Riz",
        "name_ha": "shinkafa",
        "name_dje": None,
        "category": "cereal",
        "cycle_days": 120,
    },
    {
        "code": "groundnut",
        "name_fr": "Arachide",
        "name_ha": "gyada",
        "name_dje": None,
        "category": "legume",
        "cycle_days": 105,
    },
    {
        "code": "onion",
        "name_fr": "Oignon",
        "name_ha": "albasa",
        "name_dje": None,
        "category": "vegetable",
        "cycle_days": 120,
    },
    {
        "code": "tomato",
        "name_fr": "Tomate",
        "name_ha": "tumatir",
        "name_dje": None,
        "category": "vegetable",
        "cycle_days": 90,
    },
    {
        "code": "cabbage",
        "name_fr": "Chou",
        "name_ha": "kabeji",
        "name_dje": None,
        "category": "vegetable",
        "cycle_days": 85,
    },
    {
        "code": "pepper",
        "name_fr": "Piment",
        "name_ha": "barkono",
        "name_dje": None,
        "category": "vegetable",
        "cycle_days": 100,
    },
]

DEFAULT_GUIDELINE: dict[str, Any] = {
    "validated": False,
    "urgency": None,
    "cultural": [],
    "biological": [],
    "chemical": [],
    "prevention": [],
}

DIAGNOSIS_LABELS = [
    {
        "code": "healthy",
        "kind": "healthy",
        "name_fr": "Sain",
        "name_ha": "Lafiyayye",
        "name_dje": None,
        "description": "Culture saine sans affection apparente",
        "crops": [
            "millet",
            "sorghum",
            "cowpea",
            "maize",
            "rice",
            "groundnut",
            "onion",
            "tomato",
            "cabbage",
            "pepper",
        ],
    },
    {
        "code": "fall_armyworm",
        "kind": "pest",
        "name_fr": "Chenille légionnaire d'automne",
        "name_ha": "Kwarin masara",
        "name_dje": None,
        "description": "Ravageur des cultures de céréales",
        "crops": ["maize", "sorghum", "millet", "rice"],
    },
    {
        "code": "desert_locust",
        "kind": "pest",
        "name_fr": "Criquet pèlerin",
        "name_ha": "Fara",
        "name_dje": None,
        "description": "Ravageur acridien polyphage",
        "crops": ["millet", "sorghum", "cowpea", "maize", "rice", "groundnut"],
    },
    {
        "code": "millet_downy_mildew",
        "kind": "disease",
        "name_fr": "Mildiou du mil",
        "name_ha": "Kunkuma",
        "name_dje": None,
        "description": "Maladie fongique du mil",
        "crops": ["millet"],
    },
    {
        "code": "striga",
        "kind": "weed",
        "name_fr": "Striga",
        "name_ha": "Kuduji",
        "name_dje": None,
        "description": "Plante parasite des céréales et légumineuses",
        "crops": ["millet", "sorghum", "maize", "cowpea"],
    },
    {
        "code": "cowpea_aphid",
        "kind": "pest",
        "name_fr": "Puceron du niébé",
        "name_ha": "Kudan wake",
        "name_dje": None,
        "description": "Ravageur des cultures de légumineuses",
        "crops": ["cowpea", "groundnut"],
    },
    {
        "code": "tomato_leaf_curl",
        "kind": "disease",
        "name_fr": "Enroulement des feuilles de la tomate",
        "name_ha": "Kukan tumatir",
        "name_dje": None,
        "description": "Virose affectant les solanacées",
        "crops": ["tomato", "pepper"],
    },
    {
        "code": "nitrogen_deficiency",
        "kind": "deficiency",
        "name_fr": "Carence en azote",
        "name_ha": "Rashin sinadarin azote",
        "name_dje": None,
        "description": "Déficit en azote sur la plante",
        "crops": [
            "millet",
            "sorghum",
            "cowpea",
            "maize",
            "rice",
            "groundnut",
            "onion",
            "tomato",
            "cabbage",
            "pepper",
        ],
    },
]

PLANS = [
    {
        "code": "free",
        "name": "Gratuit",
        "audience": "farmer",
        "billing_model": "free",
        "interval": None,
        "price_xof": 0,
        "quotas": {
            "diagnostics_per_month": 10,
            "llm_messages_per_month": 20,
            "video_analyses_per_month": 0,
            "plots": 3,
            "storage_mb": 100,
        },
        "features": {"offline_sync": True, "weather": True},
        "is_active": True,
    },
    {
        "code": "farmer_pro",
        "name": "Producteur Pro",
        "audience": "farmer",
        "billing_model": "subscription",
        "interval": "month",
        "price_xof": 1500,
        "quotas": {
            "diagnostics_per_month": 60,
            "llm_messages_per_month": 100,
            "video_analyses_per_month": 10,
            "plots": 20,
            "storage_mb": 1000,
        },
        "features": {
            "offline_sync": True,
            "weather": True,
            "priority_support": True,
        },
        "is_active": True,
    },
    {
        "code": "coop_standard",
        "name": "Coopérative Standard",
        "audience": "organization",
        "billing_model": "subscription",
        "interval": "month",
        "price_xof": 25000,
        "quotas": {
            "diagnostics_per_month": 500,
            "llm_messages_per_month": 1000,
            "video_analyses_per_month": 100,
            "plots": 200,
            "storage_mb": 10000,
        },
        "features": {
            "offline_sync": True,
            "weather": True,
            "organization_dashboard": True,
        },
        "is_active": True,
    },
    {
        "code": "gov_license",
        "name": "Licence Institutionnelle",
        "audience": "government",
        "billing_model": "license",
        "interval": "year",
        "price_xof": 0,
        "quotas": {
            "diagnostics_per_month": -1,
            "llm_messages_per_month": -1,
            "video_analyses_per_month": -1,
            "plots": -1,
            "storage_mb": -1,
        },
        "features": {
            "offline_sync": True,
            "weather": True,
            "national_surveillance": True,
        },
        "is_active": True,
    },
]


async def seed_database(session: AsyncSession) -> None:
    for area_data in ADMIN_AREAS:
        stmt = select(AdminArea).where(AdminArea.code == area_data["code"])
        area = (await session.execute(stmt)).scalar_one_or_none()
        if area is None:
            area = AdminArea(
                code=area_data["code"],
                name=area_data["name"],
                level=area_data["level"],
                parent_id=None,
                geom=None,
            )
            session.add(area)
        else:
            area.name = area_data["name"]
            area.level = area_data["level"]
            area.parent_id = None
            area.geom = None

    crops_by_code: dict[str, Crop] = {}
    for crop_data in CROPS:
        stmt = select(Crop).where(Crop.code == crop_data["code"])
        crop = (await session.execute(stmt)).scalar_one_or_none()
        if crop is None:
            crop = Crop(
                code=crop_data["code"],
                name_fr=crop_data["name_fr"],
                name_ha=crop_data["name_ha"],
                name_dje=crop_data["name_dje"],
                category=crop_data["category"],
                cycle_days=crop_data["cycle_days"],
            )
            session.add(crop)
            await session.flush()
        else:
            crop.name_fr = crop_data["name_fr"]
            crop.name_ha = crop_data["name_ha"]
            crop.name_dje = crop_data["name_dje"]
            crop.category = crop_data["category"]
            crop.cycle_days = crop_data["cycle_days"]
        crops_by_code[crop.code] = crop

    for label_data in DIAGNOSIS_LABELS:
        stmt = select(DiagnosisLabel).where(DiagnosisLabel.code == label_data["code"])
        label = (await session.execute(stmt)).scalar_one_or_none()
        if label is None:
            label = DiagnosisLabel(
                code=label_data["code"],
                kind=label_data["kind"],
                name_fr=label_data["name_fr"],
                name_ha=label_data["name_ha"],
                name_dje=label_data["name_dje"],
                description=label_data["description"],
                guideline=DEFAULT_GUIDELINE.copy(),
            )
            session.add(label)
            await session.flush()
        else:
            label.kind = label_data["kind"]
            label.name_fr = label_data["name_fr"]
            label.name_ha = label_data["name_ha"]
            label.name_dje = label_data["name_dje"]
            label.description = label_data["description"]
            if label.guideline is None:
                label.guideline = DEFAULT_GUIDELINE.copy()

        await session.execute(
            delete(LabelCrop).where(LabelCrop.label_id == label.id)
        )
        for crop_code in label_data["crops"]:
            target_crop = crops_by_code.get(crop_code)
            if target_crop is not None:
                session.add(
                    LabelCrop(label_id=label.id, crop_id=target_crop.id)
                )

    for plan_data in PLANS:
        stmt = select(Plan).where(Plan.code == plan_data["code"])
        plan = (await session.execute(stmt)).scalar_one_or_none()
        if plan is None:
            plan = Plan(
                code=plan_data["code"],
                name=plan_data["name"],
                audience=plan_data["audience"],
                billing_model=plan_data["billing_model"],
                interval=plan_data["interval"],
                price_xof=plan_data["price_xof"],
                quotas=plan_data["quotas"],
                features=plan_data["features"],
                is_active=plan_data["is_active"],
            )
            session.add(plan)
        else:
            plan.name = plan_data["name"]
            plan.audience = plan_data["audience"]
            plan.billing_model = plan_data["billing_model"]
            plan.interval = plan_data["interval"]
            plan.price_xof = plan_data["price_xof"]
            plan.quotas = plan_data["quotas"]
            plan.features = plan_data["features"]
            plan.is_active = plan_data["is_active"]

    await session.commit()


async def main() -> None:
    async with AsyncSessionLocal() as session:
        await seed_database(session)


if __name__ == "__main__":
    asyncio.run(main())
