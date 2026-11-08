import 'package:smartagri/core/database/app_database.dart';
import 'package:smartagri/features/farms/domain/farm.dart';
import 'package:smartagri/features/farms/domain/plot.dart';

Farm sampleFarm({
  String id = 'farm-1',
  String name = 'Ferme du fleuve',
  String? village = 'Saga',
  int? adminAreaId = 1,
  DateTime? updatedAt,
}) {
  return Farm(
    id: id,
    name: name,
    village: village,
    adminAreaId: adminAreaId,
    updatedAt: updatedAt ?? DateTime.utc(2026, 10, 20),
  );
}

Plot samplePlot({
  String id = 'plot-1',
  String farmId = 'farm-1',
  String name = 'Parcelle nord',
  double? areaHa = 2.5,
  SoilType? soilType = SoilType.loam,
  IrrigationType? irrigation = IrrigationType.drip,
  DateTime? updatedAt,
}) {
  return Plot(
    id: id,
    farmId: farmId,
    name: name,
    areaHa: areaHa,
    soilType: soilType,
    irrigation: irrigation,
    updatedAt: updatedAt ?? DateTime.utc(2026, 10, 20),
  );
}

Future<void> seedFarm(AppDatabase database, Farm farm) {
  return database.upsertFarm(
    farm.id,
    farm.name,
    village: farm.village,
    adminAreaId: farm.adminAreaId,
    updatedAt: farm.updatedAt,
  );
}

Future<void> seedPlot(AppDatabase database, Plot plot) {
  return database.upsertPlot(
    plot.id,
    plot.farmId,
    plot.name,
    areaHa: plot.areaHa,
    soilType: plot.soilType?.apiValue,
    irrigation: plot.irrigation?.apiValue,
    updatedAt: plot.updatedAt,
  );
}
