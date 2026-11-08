import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/sync/outbox.dart';
import '../../profile/data/me_repository.dart';
import '../domain/farm.dart';
import '../domain/plot.dart';

const Object unchanged = Object();

abstract interface class FarmsRepository {
  Future<List<Farm>> listFarms();

  Future<Farm> createFarm(
    String id,
    String name, {
    String? village,
    int? adminAreaId,
  });

  Future<Farm> updateFarm(
    String id, {
    Object? name = unchanged,
    Object? village = unchanged,
    Object? adminAreaId = unchanged,
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
  });

  Future<Plot> getPlot(String id);

  Future<Plot> updatePlot(
    String id, {
    Object? name = unchanged,
    Object? areaHa = unchanged,
    Object? soilType = unchanged,
    Object? irrigation = unchanged,
  });

  Future<void> deletePlot(String id);
}

Farm farmFromRow(FarmRow row) {
  return Farm(
    id: row.id,
    name: row.name,
    village: row.village,
    adminAreaId: row.adminAreaId,
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
    updatedAt: row.updatedAt?.toUtc(),
  );
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
  }) async {
    await database.transaction(() async {
      await database.upsertFarm(
        id,
        name,
        village: village,
        adminAreaId: adminAreaId,
      );
      await outbox.enqueueUpsert(
        'farm',
        id,
        _farmData(name: name, village: village, adminAreaId: adminAreaId),
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
    await database.transaction(() async {
      await database.upsertFarm(
        id,
        nextName,
        village: nextVillage,
        adminAreaId: nextAdminAreaId,
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
    await database.transaction(() async {
      await database.upsertPlot(
        id,
        farmId,
        name,
        areaHa: areaHa,
        soilType: soilType?.apiValue,
        irrigation: irrigation?.apiValue,
      );
      await outbox.enqueueUpsert(
        'plot',
        id,
        _plotData(
          farmId: farmId,
          name: name,
          areaHa: areaHa,
          soilType: soilType,
          irrigation: irrigation,
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
  }) async {
    final PlotRow? current = await database.getPlot(id);
    if (current == null) {
      throw const ApiException(code: 'NOT_FOUND', message: 'Introuvable');
    }
    final String nextName = identical(name, unchanged)
        ? current.name
        : name as String;
    final double? nextAreaHa = identical(areaHa, unchanged)
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
    await database.transaction(() async {
      await database.upsertPlot(
        id,
        current.farmId,
        nextName,
        areaHa: nextAreaHa,
        soilType: nextSoilType?.apiValue,
        irrigation: nextIrrigation?.apiValue,
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
        ),
      );
    });
    final PlotRow? row = await database.getPlot(id);
    return plotFromRow(row!);
  }

  @override
  Future<void> deletePlot(String id) async {
    await database.transaction(() async {
      await database.softDeletePlot(id);
      await outbox.enqueueDelete('plot', id);
    });
  }

  Map<String, dynamic> _farmData({
    required String name,
    String? village,
    int? adminAreaId,
  }) {
    return <String, dynamic>{
      'name': name,
      'village': village,
      'admin_area_id': adminAreaId,
      'location': null,
    };
  }

  Map<String, dynamic> _plotData({
    required String farmId,
    required String name,
    double? areaHa,
    SoilType? soilType,
    IrrigationType? irrigation,
  }) {
    return <String, dynamic>{
      'farm_id': farmId,
      'name': name,
      'area_ha': areaHa,
      'geom': null,
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
