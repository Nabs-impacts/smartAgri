import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/database/app_database.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/sync/outbox.dart';
import '../../profile/data/me_repository.dart';
import '../domain/farm.dart';
import '../domain/farms_exception.dart';
import '../domain/plot.dart';
import '../domain/plot_geometry.dart';

const Object unchanged = Object();

abstract interface class FarmsRepository {
  Future<List<Farm>> listFarms();

  Future<Farm> createFarm(
    String id,
    String name, {
    String? village,
    int? adminAreaId,
    Object? location = unchanged,
  });

  Future<Farm> updateFarm(
    String id, {
    Object? name = unchanged,
    Object? village = unchanged,
    Object? adminAreaId = unchanged,
    Object? location = unchanged,
  });

  Future<void> deleteFarm(String id);

  Future<List<Plot>> listPlots(String farmId);

  Future<Plot> createPlot(
    String farmId,
    String id,
    String name, {
    double? areaHa,
    SoilType? soilType,
    IrrigationType? irrigation,
    Object? geometry = unchanged,
  });

  Future<Plot> getPlot(String id);

  Future<Plot> updatePlot(
    String id, {
    Object? name = unchanged,
    Object? areaHa = unchanged,
    Object? soilType = unchanged,
    Object? irrigation = unchanged,
    Object? geometry = unchanged,
  });

  Future<void> deletePlot(String id);
}

Farm farmFromRow(FarmRow row) {
  return Farm(
    id: row.id,
    name: row.name,
    village: row.village,
    adminAreaId: row.adminAreaId,
    location: _locationMap(row.location),
    updatedAt: row.updatedAt?.toUtc(),
  );
}

Plot plotFromRow(PlotRow row) {
  return Plot(
    id: row.id,
    farmId: row.farmId,
    name: row.name,
    areaHa: row.areaHa,
    soilType: SoilType.fromApi(row.soilType),
    irrigation: IrrigationType.fromApi(row.irrigation),
    geometry: _plotGeometry(row.geom),
    updatedAt: row.updatedAt?.toUtc(),
  );
}

PlotGeometry? _plotGeometry(String? raw) {
  final Object? decoded = _decodeGeo(raw);
  if (decoded is! Map) {
    return null;
  }
  try {
    return PlotGeometry.fromGeoJson(Map<String, dynamic>.from(decoded));
  } catch (_) {
    return null;
  }
}

Map<String, dynamic>? _locationMap(String? raw) {
  final Object? decoded = _decodeGeo(raw);
  if (decoded is Map) {
    return Map<String, dynamic>.from(decoded);
  }
  return null;
}

Object? _decodeGeo(String? raw) {
  if (raw == null) {
    return null;
  }
  try {
    return jsonDecode(raw);
  } catch (_) {
    return null;
  }
}

Map<String, dynamic> _validatedLocation(Object? value) {
  if (value is! Map) {
    throw const FarmsDomainException(
      'invalid_location',
      'La position de l’exploitation est invalide.',
    );
  }
  final Map<String, dynamic> location = Map<String, dynamic>.from(value);
  final LatLng? point = pointFromGeoJson(location);
  if (point == null || !pointInWgs84Bounds(point)) {
    throw const FarmsDomainException(
      'invalid_location',
      'La position de l’exploitation est invalide.',
    );
  }
  return location;
}

class LocalFarmsRepository implements FarmsRepository {
  LocalFarmsRepository({
    required this.database,
    required this.outbox,
    this.plotLimit,
  });

  final AppDatabase database;
  final Outbox outbox;
  final int? Function()? plotLimit;

  @override
  Future<List<Farm>> listFarms() async {
    final List<FarmRow> rows = await database.watchFarms().first;
    return rows.map(farmFromRow).toList();
  }

  @override
  Future<Farm> createFarm(
    String id,
    String name, {
    String? village,
    int? adminAreaId,
    Object? location = unchanged,
  }) async {
    final Map<String, dynamic>? nextLocation = identical(location, unchanged)
        ? null
        : location == null
        ? null
        : _validatedLocation(location);
    await database.transaction(() async {
      await database.upsertFarm(
        id,
        name,
        village: village,
        adminAreaId: adminAreaId,
        location: nextLocation == null ? null : jsonEncode(nextLocation),
      );
      await outbox.enqueueUpsert(
        'farm',
        id,
        _farmData(
          name: name,
          village: village,
          adminAreaId: adminAreaId,
          location: nextLocation,
        ),
      );
    });
    final FarmRow? row = await database.getFarm(id);
    return farmFromRow(row!);
  }

  @override
  Future<Farm> updateFarm(
    String id, {
    Object? name = unchanged,
    Object? village = unchanged,
    Object? adminAreaId = unchanged,
    Object? location = unchanged,
  }) async {
    final FarmRow? current = await database.getFarm(id);
    if (current == null) {
      throw const ApiException(code: 'NOT_FOUND', message: 'Introuvable');
    }
    final String nextName = identical(name, unchanged)
        ? current.name
        : name as String;
    final String? nextVillage = identical(village, unchanged)
        ? current.village
        : village as String?;
    final int? nextAdminAreaId = identical(adminAreaId, unchanged)
        ? current.adminAreaId
        : adminAreaId as int?;
    final Map<String, dynamic>? nextLocation = identical(location, unchanged)
        ? _locationMap(current.location)
        : location == null
        ? null
        : _validatedLocation(location);
    await database.transaction(() async {
      await database.upsertFarm(
        id,
        nextName,
        village: nextVillage,
        adminAreaId: nextAdminAreaId,
        location: nextLocation == null ? null : jsonEncode(nextLocation),
        updatedAt: current.updatedAt,
        deletedAt: current.deletedAt,
      );
      await outbox.enqueueUpsert(
        'farm',
        id,
        _farmData(
          name: nextName,
          village: nextVillage,
          adminAreaId: nextAdminAreaId,
          location: nextLocation,
        ),
      );
    });
    final FarmRow? row = await database.getFarm(id);
    return farmFromRow(row!);
  }

  @override
  Future<void> deleteFarm(String id) async {
    await database.transaction(() async {
      final List<PlotRow> plots = await database.getActivePlots(id);
      for (final PlotRow plot in plots) {
        await _enqueueCycleDeletes(plot.id);
        await outbox.enqueueDelete('plot', plot.id);
      }
      await database.softDeleteFarm(id);
      await outbox.enqueueDelete('farm', id);
    });
  }

  @override
  Future<List<Plot>> listPlots(String farmId) async {
    final List<PlotRow> rows = await database.watchPlots(farmId).first;
    return rows.map(plotFromRow).toList();
  }

  @override
  Future<Plot> createPlot(
    String farmId,
    String id,
    String name, {
    double? areaHa,
    SoilType? soilType,
    IrrigationType? irrigation,
    Object? geometry = unchanged,
  }) async {
    final int? limit = plotLimit?.call();
    if (limit != null && limit >= 0) {
      final int used = await database.countActivePlots();
      if (used >= limit) {
        throw ApiException(
          statusCode: 403,
          code: 'QUOTA_EXCEEDED',
          message: 'Vous avez atteint la limite de votre formule.',
          details: <String, dynamic>{
            'metric': 'plots',
            'limit': limit,
            'used': used,
          },
        );
      }
    }
    final PlotGeometry? nextGeometry = identical(geometry, unchanged)
        ? null
        : _validatedGeometry(geometry);
    final double? nextAreaHa = nextGeometry?.areaHectares() ?? areaHa;
    final Map<String, dynamic>? nextGeom = nextGeometry?.toGeoJson();
    await database.transaction(() async {
      await database.upsertPlot(
        id,
        farmId,
        name,
        areaHa: nextAreaHa,
        soilType: soilType?.apiValue,
        irrigation: irrigation?.apiValue,
        geom: nextGeom == null ? null : jsonEncode(nextGeom),
      );
      await outbox.enqueueUpsert(
        'plot',
        id,
        _plotData(
          farmId: farmId,
          name: name,
          areaHa: nextAreaHa,
          soilType: soilType,
          irrigation: irrigation,
          geom: nextGeom,
        ),
      );
    });
    final PlotRow? row = await database.getPlot(id);
    return plotFromRow(row!);
  }

  @override
  Future<Plot> getPlot(String id) async {
    final PlotRow? row = await database.getPlot(id);
    if (row == null || row.deletedAt != null) {
      throw const ApiException(code: 'NOT_FOUND', message: 'Introuvable');
    }
    return plotFromRow(row);
  }

  @override
  Future<Plot> updatePlot(
    String id, {
    Object? name = unchanged,
    Object? areaHa = unchanged,
    Object? soilType = unchanged,
    Object? irrigation = unchanged,
    Object? geometry = unchanged,
  }) async {
    final PlotRow? current = await database.getPlot(id);
    if (current == null) {
      throw const ApiException(code: 'NOT_FOUND', message: 'Introuvable');
    }
    final String nextName = identical(name, unchanged)
        ? current.name
        : name as String;
    final PlotGeometry? nextGeometry = identical(geometry, unchanged)
        ? _plotGeometry(current.geom)
        : _validatedGeometry(geometry);
    final bool geometryChanged = !identical(geometry, unchanged);
    final double? nextAreaHa = nextGeometry != null
        ? (geometryChanged ? nextGeometry.areaHectares() : current.areaHa)
        : identical(areaHa, unchanged)
        ? current.areaHa
        : areaHa is num
        ? areaHa.toDouble()
        : areaHa as double?;
    final SoilType? nextSoilType = identical(soilType, unchanged)
        ? SoilType.fromApi(current.soilType)
        : soilType as SoilType?;
    final IrrigationType? nextIrrigation = identical(irrigation, unchanged)
        ? IrrigationType.fromApi(current.irrigation)
        : irrigation as IrrigationType?;
    final String? nextGeomRaw = nextGeometry != null
        ? (geometryChanged
              ? jsonEncode(nextGeometry.toGeoJson())
              : current.geom)
        : null;
    final Map<String, dynamic>? nextGeom = nextGeometry?.toGeoJson();
    await database.transaction(() async {
      await database.upsertPlot(
        id,
        current.farmId,
        nextName,
        areaHa: nextAreaHa,
        soilType: nextSoilType?.apiValue,
        irrigation: nextIrrigation?.apiValue,
        geom: nextGeomRaw,
        updatedAt: current.updatedAt,
        deletedAt: current.deletedAt,
      );
      await outbox.enqueueUpsert(
        'plot',
        id,
        _plotData(
          farmId: current.farmId,
          name: nextName,
          areaHa: nextAreaHa,
          soilType: nextSoilType,
          irrigation: nextIrrigation,
          geom: nextGeom,
        ),
      );
    });
    final PlotRow? row = await database.getPlot(id);
    return plotFromRow(row!);
  }

  @override
  Future<void> deletePlot(String id) async {
    await database.transaction(() async {
      await _enqueueCycleDeletes(id);
      await database.softDeletePlot(id);
      await outbox.enqueueDelete('plot', id);
    });
  }

  PlotGeometry? _validatedGeometry(Object? value) {
    if (value == null) {
      return null;
    }
    if (value is! PlotGeometry) {
      throw const FarmsDomainException(
        'invalid_geometry',
        'Le tracé de la parcelle est invalide.',
      );
    }
    final PlotGeometryError? error = value.validate();
    if (error != null) {
      throw FarmsDomainException(
        'invalid_geometry',
        _geometryErrorMessage(error),
        geometryError: error,
      );
    }
    return value;
  }

  String _geometryErrorMessage(PlotGeometryError error) {
    switch (error) {
      case PlotGeometryError.tooFewVertices:
        return 'Ajoutez au moins 3 sommets distincts.';
      case PlotGeometryError.selfIntersection:
        return 'Le contour se croise. Corrigez le tracé.';
      case PlotGeometryError.tooManyVertices:
        return 'Le tracé ne doit pas dépasser 500 sommets.';
      case PlotGeometryError.zeroArea:
        return 'La surface du tracé est nulle.';
      case PlotGeometryError.areaTooLarge:
        return 'La surface ne doit pas dépasser 10 000 ha.';
      case PlotGeometryError.coordinatesOutOfBounds:
        return 'Le tracé contient des coordonnées hors limites.';
    }
  }

  Future<void> _enqueueCycleDeletes(String plotId) async {
    final List<CropCycleRow> cycles = await database.getActiveCycles(plotId);
    for (final CropCycleRow cycle in cycles) {
      final List<HarvestRow> harvests = await database.getActiveHarvests(
        cycle.id,
      );
      for (final HarvestRow harvest in harvests) {
        await outbox.enqueueDelete('harvest', harvest.id);
      }
      final List<FarmActivityRow> activities = await database
          .getActiveActivities(cycle.id);
      for (final FarmActivityRow activity in activities) {
        await outbox.enqueueDelete('farm_activity', activity.id);
      }
      await outbox.enqueueDelete('crop_cycle', cycle.id);
    }
  }

  Map<String, dynamic> _farmData({
    required String name,
    String? village,
    int? adminAreaId,
    required Object? location,
  }) {
    return <String, dynamic>{
      'name': name,
      'village': village,
      'admin_area_id': adminAreaId,
      'location': location,
    };
  }

  Map<String, dynamic> _plotData({
    required String farmId,
    required String name,
    double? areaHa,
    SoilType? soilType,
    IrrigationType? irrigation,
    required Object? geom,
  }) {
    return <String, dynamic>{
      'farm_id': farmId,
      'name': name,
      'area_ha': areaHa,
      'geom': geom,
      'soil_type': soilType?.apiValue,
      'irrigation': irrigation?.apiValue,
    };
  }
}

int? _plotLimit(Ref ref) {
  final MeData? data = ref.read(meProvider).value;
  if (data == null) {
    return null;
  }
  for (final Quota quota in data.quotas) {
    if (quota.metric == 'plots') {
      return quota.limit;
    }
  }
  return null;
}

final Provider<FarmsRepository> farmsRepositoryProvider =
    Provider<FarmsRepository>((Ref ref) {
      return LocalFarmsRepository(
        database: ref.watch(appDatabaseProvider),
        outbox: ref.watch(outboxProvider),
        plotLimit: () => _plotLimit(ref),
      );
    });
