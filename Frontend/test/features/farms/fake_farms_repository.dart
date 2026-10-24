import 'package:smartagri/core/network/api_exception.dart';
import 'package:smartagri/features/farms/data/farms_repository.dart';
import 'package:smartagri/features/farms/domain/farm.dart';
import 'package:smartagri/features/farms/domain/plot.dart';

class FakeFarmsRepository implements FarmsRepository {
  FakeFarmsRepository({List<Farm>? farms, Map<String, List<Plot>>? plots})
    : farms = farms ?? <Farm>[],
      plots = plots ?? <String, List<Plot>>{};

  List<Farm> farms;
  Map<String, List<Plot>> plots;
  ApiException? listFarmsError;
  ApiException? createFarmError;
  ApiException? updateFarmError;
  ApiException? deleteFarmError;
  ApiException? listPlotsError;
  ApiException? createPlotError;
  ApiException? getPlotError;
  ApiException? updatePlotError;
  ApiException? deletePlotError;

  int listFarmsCalls = 0;
  int listPlotsCalls = 0;
  int getPlotCalls = 0;

  String? lastFarmId;
  String? lastFarmName;
  String? lastVillage;
  int? lastAdminAreaId;
  String? lastUpdatedFarmId;
  Object? lastUpdatedName;
  Object? lastUpdatedVillage;
  Object? lastUpdatedAdminAreaId;

  String? lastPlotId;
  String? lastPlotFarmId;
  String? lastPlotName;
  double? lastPlotAreaHa;
  SoilType? lastPlotSoilType;
  IrrigationType? lastPlotIrrigation;
  String? lastUpdatedPlotId;
  Object? lastUpdatedPlotName;
  Object? lastUpdatedPlotAreaHa;
  Object? lastUpdatedPlotSoilType;
  Object? lastUpdatedPlotIrrigation;

  @override
  Future<List<Farm>> listFarms() async {
    listFarmsCalls++;
    if (listFarmsError != null) {
      throw listFarmsError!;
    }
    return List<Farm>.of(farms);
  }

  @override
  Future<Farm> createFarm(
    String id,
    String name, {
    String? village,
    int? adminAreaId,
  }) async {
    lastFarmId = id;
    lastFarmName = name;
    lastVillage = village;
    lastAdminAreaId = adminAreaId;
    if (createFarmError != null) {
      throw createFarmError!;
    }
    final Farm farm = _farm(
      id,
      name,
      village: village,
      adminAreaId: adminAreaId,
    );
    farms = <Farm>[farm, ...farms];
    return farm;
  }

  @override
  Future<Farm> updateFarm(
    String id, {
    Object? name = unchanged,
    Object? village = unchanged,
    Object? adminAreaId = unchanged,
  }) async {
    lastUpdatedFarmId = id;
    lastUpdatedName = name;
    lastUpdatedVillage = village;
    lastUpdatedAdminAreaId = adminAreaId;
    if (updateFarmError != null) {
      throw updateFarmError!;
    }
    final Farm current = farms.firstWhere((Farm item) => item.id == id);
    final Farm updated = Farm(
      id: current.id,
      name: name is String ? name : current.name,
      village: identical(village, unchanged)
          ? current.village
          : village as String?,
      adminAreaId: identical(adminAreaId, unchanged)
          ? current.adminAreaId
          : adminAreaId as int?,
      createdAt: current.createdAt,
      updatedAt: current.updatedAt,
    );
    farms = farms.map((Farm item) => item.id == id ? updated : item).toList();
    return updated;
  }

  @override
  Future<void> deleteFarm(String id) async {
    if (deleteFarmError != null) {
      throw deleteFarmError!;
    }
    farms = farms.where((Farm item) => item.id != id).toList();
    plots.remove(id);
  }

  @override
  Future<List<Plot>> listPlots(String farmId) async {
    listPlotsCalls++;
    if (listPlotsError != null) {
      throw listPlotsError!;
    }
    return List<Plot>.of(plots[farmId] ?? <Plot>[]);
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
    lastPlotId = id;
    lastPlotFarmId = farmId;
    lastPlotName = name;
    lastPlotAreaHa = areaHa;
    lastPlotSoilType = soilType;
    lastPlotIrrigation = irrigation;
    if (createPlotError != null) {
      throw createPlotError!;
    }
    final Plot plot = _plot(
      id,
      farmId,
      name,
      areaHa: areaHa,
      soilType: soilType,
      irrigation: irrigation,
    );
    plots[farmId] = <Plot>[plot, ...(plots[farmId] ?? <Plot>[])];
    return plot;
  }

  @override
  Future<Plot> getPlot(String id) async {
    getPlotCalls++;
    if (getPlotError != null) {
      throw getPlotError!;
    }
    for (final List<Plot> items in plots.values) {
      for (final Plot plot in items) {
        if (plot.id == id) {
          return plot;
        }
      }
    }
    throw const ApiException(code: 'NOT_FOUND', message: 'Introuvable');
  }

  @override
  Future<Plot> updatePlot(
    String id, {
    Object? name = unchanged,
    Object? areaHa = unchanged,
    Object? soilType = unchanged,
    Object? irrigation = unchanged,
  }) async {
    lastUpdatedPlotId = id;
    lastUpdatedPlotName = name;
    lastUpdatedPlotAreaHa = areaHa;
    lastUpdatedPlotSoilType = soilType;
    lastUpdatedPlotIrrigation = irrigation;
    if (updatePlotError != null) {
      throw updatePlotError!;
    }
    for (final String farmId in plots.keys) {
      final List<Plot> items = plots[farmId] ?? <Plot>[];
      for (int index = 0; index < items.length; index++) {
        final Plot current = items[index];
        if (current.id != id) {
          continue;
        }
        final Plot updated = Plot(
          id: current.id,
          farmId: current.farmId,
          name: name is String ? name : current.name,
          areaHa: identical(areaHa, unchanged)
              ? current.areaHa
              : areaHa as double?,
          soilType: identical(soilType, unchanged)
              ? current.soilType
              : soilType as SoilType?,
          irrigation: identical(irrigation, unchanged)
              ? current.irrigation
              : irrigation as IrrigationType?,
          createdAt: current.createdAt,
          updatedAt: current.updatedAt,
        );
        items[index] = updated;
        plots[farmId] = items;
        return updated;
      }
    }
    throw const ApiException(code: 'NOT_FOUND', message: 'Introuvable');
  }

  @override
  Future<void> deletePlot(String id) async {
    if (deletePlotError != null) {
      throw deletePlotError!;
    }
    for (final String farmId in plots.keys.toList()) {
      plots[farmId] = (plots[farmId] ?? <Plot>[])
          .where((Plot item) => item.id != id)
          .toList();
    }
  }
}

Farm _farm(String id, String name, {String? village, int? adminAreaId}) {
  final DateTime date = DateTime.utc(2026, 10, 20);
  return Farm(
    id: id,
    name: name,
    village: village,
    adminAreaId: adminAreaId,
    createdAt: date,
    updatedAt: date,
  );
}

Plot _plot(
  String id,
  String farmId,
  String name, {
  double? areaHa,
  SoilType? soilType,
  IrrigationType? irrigation,
}) {
  final DateTime date = DateTime.utc(2026, 10, 20);
  return Plot(
    id: id,
    farmId: farmId,
    name: name,
    areaHa: areaHa,
    soilType: soilType,
    irrigation: irrigation,
    createdAt: date,
    updatedAt: date,
  );
}

Farm sampleFarm({
  String id = 'farm-1',
  String name = 'Ferme du fleuve',
  String? village = 'Saga',
  int? adminAreaId = 1,
}) {
  return _farm(id, name, village: village, adminAreaId: adminAreaId);
}

Plot samplePlot({
  String id = 'plot-1',
  String farmId = 'farm-1',
  String name = 'Parcelle nord',
  double? areaHa = 2.5,
  SoilType? soilType = SoilType.loam,
  IrrigationType? irrigation = IrrigationType.drip,
}) {
  return _plot(
    id,
    farmId,
    name,
    areaHa: areaHa,
    soilType: soilType,
    irrigation: irrigation,
  );
}
