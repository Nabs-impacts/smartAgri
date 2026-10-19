import json
from decimal import Decimal
from typing import Any

from geoalchemy2 import Geography
from geoalchemy2.elements import WKBElement
from geoalchemy2.shape import from_shape, to_shape
from shapely.geometry import Point, Polygon, mapping, shape
from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.errors import ValidationException


def postgis_to_geojson(geom: Any) -> dict[str, Any] | None:
    if geom is None:
        return None
    if isinstance(geom, (dict, list)):
        return geom
    if isinstance(geom, str):
        try:
            return json.loads(geom)
        except Exception:
            return None
    if isinstance(geom, WKBElement):
        try:
            shapely_geom = to_shape(geom)
            return mapping(shapely_geom)
        except Exception:
            return None
    try:
        shapely_geom = to_shape(geom)
        return mapping(shapely_geom)
    except Exception:
        return None


def validate_polygon_geojson(geojson_data: dict[str, Any] | str) -> Polygon:
    if isinstance(geojson_data, str):
        try:
            data = json.loads(geojson_data)
        except Exception as err:
            raise ValidationException("Format GeoJSON invalide.") from err
    elif isinstance(geojson_data, dict):
        data = geojson_data
    else:
        raise ValidationException("La géométrie doit être un polygone.")

    geom_type = data.get("type")
    if geom_type != "Polygon":
        raise ValidationException("La géométrie doit être un polygone.")

    coords = data.get("coordinates")
    if not coords or not isinstance(coords, list):
        raise ValidationException("Coordonnées de polygone invalides.")

    try:
        polygon = shape(data)
    except Exception as err:
        raise ValidationException("La géométrie du polygone est invalide.") from err

    if not isinstance(polygon, Polygon):
        raise ValidationException("La géométrie doit être un polygone.")

    if polygon.is_empty or not polygon.is_valid:
        raise ValidationException("La géométrie du polygone est invalide.")

    for x, y in polygon.exterior.coords:
        if not (-180.0 <= x <= 180.0 and -90.0 <= y <= 90.0):
            raise ValidationException(
                "Les coordonnées doivent être en WGS84 (SRID 4326)."
            )

    for ring in polygon.interiors:
        for x, y in ring.coords:
            if not (-180.0 <= x <= 180.0 and -90.0 <= y <= 90.0):
                raise ValidationException(
                    "Les coordonnées doivent être en WGS84 (SRID 4326)."
                )

    vertex_count = len(polygon.exterior.coords) + sum(
        len(ring.coords) for ring in polygon.interiors
    )
    if vertex_count > 500:
        raise ValidationException("Le polygone ne doit pas dépasser 500 sommets.")

    return polygon


def geojson_to_postgis_polygon(geojson_data: dict[str, Any] | str) -> WKBElement:
    polygon = validate_polygon_geojson(geojson_data)
    return from_shape(polygon, srid=4326)


def validate_point_geojson(geojson_data: dict[str, Any] | str) -> Point:
    if isinstance(geojson_data, str):
        try:
            data = json.loads(geojson_data)
        except Exception as err:
            raise ValidationException("Format GeoJSON invalide.") from err
    elif isinstance(geojson_data, dict):
        data = geojson_data
    else:
        raise ValidationException("La géométrie doit être un point.")

    geom_type = data.get("type")
    if geom_type != "Point":
        raise ValidationException("La géométrie doit être un point.")

    coords = data.get("coordinates")
    if not coords or not isinstance(coords, (list, tuple)) or len(coords) < 2:
        raise ValidationException("Coordonnées de point invalides.")

    lng, lat = float(coords[0]), float(coords[1])
    if not (-180.0 <= lng <= 180.0 and -90.0 <= lat <= 90.0):
        raise ValidationException(
            "Les coordonnées doivent être en WGS84 (SRID 4326)."
        )

    return Point(lng, lat)


def geojson_to_postgis_point(geojson_data: dict[str, Any] | str) -> WKBElement:
    pt = validate_point_geojson(geojson_data)
    return from_shape(pt, srid=4326)


async def compute_area_ha(session: AsyncSession, geom: WKBElement) -> Decimal:
    stmt = select(func.ST_Area(func.cast(geom, Geography)) / 10000.0)
    raw_area = (await session.execute(stmt)).scalar_one_or_none()
    if raw_area is None:
        raise ValidationException("Impossible de calculer la surface de la géométrie.")

    area_ha = Decimal(str(round(float(raw_area), 3)))
    if area_ha > Decimal("10000"):
        raise ValidationException(
            "La surface du polygone ne doit pas dépasser 10 000 hectares."
        )
    return area_ha
