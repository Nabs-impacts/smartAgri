from datetime import UTC, datetime, timedelta
from typing import Literal

from sqlalchemy import text
from sqlalchemy.ext.asyncio import AsyncSession

from app.schemas.stats import (
    OverviewResponse,
    RegionAdoption,
    StatsCrop,
    StatsRegion,
    YieldCell,
    YieldsResponse,
)

REGION_CTE = """
WITH RECURSIVE area_region AS (
    SELECT id, id AS region_id
    FROM admin_areas
    WHERE level = 'region'
    UNION
    SELECT child.id, parent.region_id
    FROM admin_areas child
    JOIN area_region parent ON child.parent_id = parent.id
)
"""


class StatsService:
    async def get_yields(
        self,
        session: AsyncSession,
        crop_id: int | None = None,
        region_id: int | None = None,
        season_year: int | None = None,
        season_type: Literal["rainy", "dry"] | None = None,
    ) -> YieldsResponse:
        conditions = [
            "cc.deleted_at IS NULL",
            "p.deleted_at IS NULL",
            "f.deleted_at IS NULL",
            "cc.sowing_date IS NOT NULL",
            "v.yield_kg_per_ha IS NOT NULL",
            (
                "EXISTS (SELECT 1 FROM harvests h "
                "WHERE h.crop_cycle_id = cc.id AND h.deleted_at IS NULL)"
            ),
        ]
        params: dict[str, object] = {}

        if crop_id is not None:
            conditions.append("cc.crop_id = :crop_id")
            params["crop_id"] = crop_id
        if region_id is not None:
            conditions.append(
                "r.id = (SELECT region_id FROM area_region WHERE id = :region_id)"
            )
            params["region_id"] = region_id
        if season_year is not None:
            conditions.append(
                "EXTRACT(YEAR FROM cc.sowing_date)::int = :season_year"
            )
            params["season_year"] = season_year
        if season_type == "rainy":
            conditions.append(
                "EXTRACT(MONTH FROM cc.sowing_date) BETWEEN 5 AND 10"
            )
        elif season_type == "dry":
            conditions.append(
                "EXTRACT(MONTH FROM cc.sowing_date) NOT BETWEEN 5 AND 10"
            )

        sql = (
            REGION_CTE
            + """
SELECT
    c.id AS crop_id,
    c.code AS crop_code,
    c.name_fr AS crop_name,
    r.id AS region_id,
    r.name AS region_name,
    EXTRACT(YEAR FROM cc.sowing_date)::int AS season_year,
    CASE
        WHEN EXTRACT(MONTH FROM cc.sowing_date) BETWEEN 5 AND 10 THEN 'rainy'
        ELSE 'dry'
    END AS season_type,
    COUNT(DISTINCT cc.id) AS cycles,
    COUNT(DISTINCT f.owner_id) AS farmers,
    ROUND(AVG(v.yield_kg_per_ha), 1) AS avg_yield,
    ROUND(MIN(v.yield_kg_per_ha), 1) AS min_yield,
    ROUND(MAX(v.yield_kg_per_ha), 1) AS max_yield
FROM v_cycle_yield v
JOIN crop_cycles cc ON cc.id = v.crop_cycle_id
JOIN plots p ON p.id = cc.plot_id
JOIN farms f ON f.id = p.farm_id
JOIN crops c ON c.id = cc.crop_id
JOIN area_region ar ON ar.id = f.admin_area_id
JOIN admin_areas r ON r.id = ar.region_id
WHERE """
            + " AND ".join(conditions)
            + """
GROUP BY
    c.id,
    c.code,
    c.name_fr,
    r.id,
    r.name,
    EXTRACT(YEAR FROM cc.sowing_date),
    CASE
        WHEN EXTRACT(MONTH FROM cc.sowing_date) BETWEEN 5 AND 10 THEN 'rainy'
        ELSE 'dry'
    END
ORDER BY season_year DESC, c.name_fr ASC, r.name ASC
"""
        )
        rows = (await session.execute(text(sql), params)).mappings().all()

        items: list[YieldCell] = []
        for row in rows:
            crop = StatsCrop(
                id=int(row["crop_id"]),
                code=row["crop_code"],
                name_fr=row["crop_name"],
            )
            region = StatsRegion(
                id=int(row["region_id"]),
                name_fr=row["region_name"],
            )
            cycles = int(row["cycles"])
            farmers = int(row["farmers"])
            masked = cycles < 5 or farmers < 3
            if masked:
                items.append(
                    YieldCell(
                        crop=crop,
                        region=region,
                        season_year=int(row["season_year"]),
                        season_type=row["season_type"],
                        masked=True,
                    )
                )
            else:
                items.append(
                    YieldCell(
                        crop=crop,
                        region=region,
                        season_year=int(row["season_year"]),
                        season_type=row["season_type"],
                        masked=False,
                        cycles=cycles,
                        farmers=farmers,
                        avg_yield_kg_per_ha=float(row["avg_yield"]),
                        min_yield_kg_per_ha=float(row["min_yield"]),
                        max_yield_kg_per_ha=float(row["max_yield"]),
                    )
                )

        return YieldsResponse(items=items)

    async def get_overview(self, session: AsyncSession) -> OverviewResponse:
        cutoff = datetime.now(UTC) - timedelta(days=30)

        active_users = int(
            (
                await session.execute(
                    text(
                        "SELECT COUNT(*) FROM users "
                        "WHERE deleted_at IS NULL AND is_active = true "
                        "AND last_login_at >= :cutoff"
                    ),
                    {"cutoff": cutoff},
                )
            ).scalar_one()
        )

        diagnostics = int(
            (
                await session.execute(
                    text(
                        "SELECT COUNT(*) FROM diagnostics "
                        "WHERE deleted_at IS NULL AND created_at >= :cutoff"
                    ),
                    {"cutoff": cutoff},
                )
            ).scalar_one()
        )

        tracked_area = (
            await session.execute(
                text(
                    "SELECT COALESCE(SUM(p.area_ha), 0) "
                    "FROM plots p "
                    "JOIN farms f ON f.id = p.farm_id "
                    "JOIN users u ON u.id = f.owner_id "
                    "WHERE p.deleted_at IS NULL "
                    "AND f.deleted_at IS NULL "
                    "AND u.deleted_at IS NULL "
                    "AND u.is_active = true "
                    "AND u.last_login_at >= :cutoff"
                ),
                {"cutoff": cutoff},
            )
        ).scalar_one()

        adoption_rows = (
            await session.execute(
                text(
                    REGION_CTE
                    + """
SELECT
    r.id AS region_id,
    r.name AS region_name,
    COUNT(DISTINCT u.id) AS users,
    COUNT(DISTINCT p.id) AS plots
FROM users u
JOIN farms f ON f.owner_id = u.id AND f.deleted_at IS NULL
JOIN area_region ar ON ar.id = f.admin_area_id
JOIN admin_areas r ON r.id = ar.region_id
LEFT JOIN plots p ON p.farm_id = f.id AND p.deleted_at IS NULL
WHERE u.deleted_at IS NULL
AND u.is_active = true
AND u.last_login_at >= :cutoff
GROUP BY r.id, r.name
ORDER BY r.name ASC
""",
                ),
                {"cutoff": cutoff},
            )
        ).mappings().all()

        adoption: list[RegionAdoption] = []
        for row in adoption_rows:
            region = StatsRegion(
                id=int(row["region_id"]),
                name_fr=row["region_name"],
            )
            users = int(row["users"])
            if users < 5:
                adoption.append(
                    RegionAdoption(region=region, masked=True)
                )
            else:
                adoption.append(
                    RegionAdoption(
                        region=region,
                        masked=False,
                        users=users,
                        plots=int(row["plots"]),
                    )
                )

        return OverviewResponse(
            active_users_30d=active_users,
            diagnostics_30d=diagnostics,
            tracked_area_ha=round(float(tracked_area), 1),
            adoption=adoption,
        )


stats_service = StatsService()
