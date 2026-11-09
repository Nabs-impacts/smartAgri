import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

part 'app_database.g.dart';

const Object _absent = Object();

@DataClassName('FarmRow')
class Farms extends Table {
  TextColumn get id => text()();

  TextColumn get name => text()();

  TextColumn get village => text().nullable()();

  IntColumn get adminAreaId => integer().nullable()();

  TextColumn get location => text().nullable()();

  DateTimeColumn get updatedAt => dateTime().nullable()();

  DateTimeColumn get deletedAt => dateTime().nullable()();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{id};
}

@DataClassName('PlotRow')
class Plots extends Table {
  TextColumn get id => text()();

  TextColumn get farmId => text()();

  TextColumn get name => text()();

  RealColumn get areaHa => real().nullable()();

  TextColumn get soilType => text().nullable()();

  TextColumn get irrigation => text().nullable()();

  TextColumn get geom => text().nullable()();

  DateTimeColumn get updatedAt => dateTime().nullable()();

  DateTimeColumn get deletedAt => dateTime().nullable()();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{id};
}

@DataClassName('CropCycleRow')
class CropCycles extends Table {
  TextColumn get id => text()();

  TextColumn get plotId => text()();

  IntColumn get cropId => integer()();

  TextColumn get variety => text().nullable()();

  TextColumn get season => text().nullable()();

  TextColumn get sowingDate => text().nullable()();

  TextColumn get expectedHarvestDate => text().nullable()();

  TextColumn get harvestDate => text().nullable()();

  TextColumn get status =>
      text().withDefault(const Constant<String>('planned'))();

  TextColumn get notes => text().nullable()();

  DateTimeColumn get updatedAt => dateTime().nullable()();

  DateTimeColumn get deletedAt => dateTime().nullable()();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{id};
}

@DataClassName('FarmActivityRow')
class FarmActivities extends Table {
  TextColumn get id => text()();

  TextColumn get cropCycleId => text()();

  TextColumn get type => text()();

  TextColumn get performedOn => text()();

  TextColumn get productName => text().nullable()();

  RealColumn get quantity => real().nullable()();

  TextColumn get unit => text().nullable()();

  IntColumn get costXof => integer().nullable()();

  TextColumn get notes => text().nullable()();

  DateTimeColumn get updatedAt => dateTime().nullable()();

  DateTimeColumn get deletedAt => dateTime().nullable()();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{id};
}

@DataClassName('HarvestRow')
class Harvests extends Table {
  TextColumn get id => text()();

  TextColumn get cropCycleId => text()();

  TextColumn get harvestedOn => text()();

  RealColumn get quantityKg => real()();

  TextColumn get quality => text().nullable()();

  RealColumn get soldKg => real().withDefault(const Constant<double>(0))();

  RealColumn get avgPriceXofPerKg => real().nullable()();

  DateTimeColumn get updatedAt => dateTime().nullable()();

  DateTimeColumn get deletedAt => dateTime().nullable()();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{id};
}

@DataClassName('PendingChangeRow')
class PendingChanges extends Table {
  TextColumn get entity => text()();

  TextColumn get id => text()();

  TextColumn get op => text()();

  TextColumn get payload => text()();

  DateTimeColumn get clientUpdatedAt => dateTime()();

  IntColumn get attempts => integer().withDefault(const Constant<int>(0))();

  TextColumn get status =>
      text().withDefault(const Constant<String>('pending'))();

  TextColumn get lastError => text().nullable()();

  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{entity, id};
}

@DataClassName('SyncMetaEntry')
class SyncMeta extends Table {
  TextColumn get key => text()();

  TextColumn get value => text()();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{key};
}

@DriftDatabase(
  tables: <Type>[
    Farms,
    Plots,
    CropCycles,
    FarmActivities,
    Harvests,
    PendingChanges,
    SyncMeta,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  AppDatabase.forTesting(super.executor);

  @override
  int get schemaVersion => 3;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (Migrator migrator) => migrator.createAll(),
    onUpgrade: (Migrator migrator, int from, int to) async {
      if (from < 2) {
        await migrator.addColumn(farms, farms.location);
        await migrator.addColumn(plots, plots.geom);
        await customStatement(
          "DELETE FROM sync_meta WHERE key = 'cursor_history'",
        );
      }
      if (from < 3) {
        await migrator.createTable(cropCycles);
        await migrator.createTable(farmActivities);
        await migrator.createTable(harvests);
        await customStatement(
          "DELETE FROM sync_meta WHERE key = 'cursor_history'",
        );
      }
    },
    beforeOpen: (OpeningDetails details) async {
      await customStatement('PRAGMA foreign_keys = OFF');
    },
  );

  Future<void> upsertFarm(
    String id,
    String name, {
    String? village,
    int? adminAreaId,
    Object? location = _absent,
    DateTime? updatedAt,
    DateTime? deletedAt,
  }) async {
    final FarmRow? existing = await getFarm(id);
    final String? nextLocation = identical(location, _absent)
        ? existing?.location
        : location as String?;
    await into(farms).insertOnConflictUpdate(
      FarmsCompanion.insert(
        id: id,
        name: name,
        village: Value<String?>(village),
        adminAreaId: Value<int?>(adminAreaId),
        location: Value<String?>(nextLocation),
        updatedAt: Value<DateTime?>(updatedAt ?? existing?.updatedAt),
        deletedAt: Value<DateTime?>(deletedAt),
      ),
    );
  }

  Future<void> upsertPlot(
    String id,
    String farmId,
    String name, {
    double? areaHa,
    String? soilType,
    String? irrigation,
    Object? geom = _absent,
    DateTime? updatedAt,
    DateTime? deletedAt,
  }) async {
    final PlotRow? existing = await getPlot(id);
    final String? nextGeom = identical(geom, _absent)
        ? existing?.geom
        : geom as String?;
    await into(plots).insertOnConflictUpdate(
      PlotsCompanion.insert(
        id: id,
        farmId: farmId,
        name: name,
        areaHa: Value<double?>(areaHa),
        soilType: Value<String?>(soilType),
        irrigation: Value<String?>(irrigation),
        geom: Value<String?>(nextGeom),
        updatedAt: Value<DateTime?>(updatedAt ?? existing?.updatedAt),
        deletedAt: Value<DateTime?>(deletedAt),
      ),
    );
  }

  Future<void> upsertCycle(
    String id,
    String plotId,
    int cropId, {
    Object? variety = _absent,
    Object? season = _absent,
    Object? sowingDate = _absent,
    Object? expectedHarvestDate = _absent,
    Object? harvestDate = _absent,
    Object? status = _absent,
    Object? notes = _absent,
    DateTime? updatedAt,
    DateTime? deletedAt,
  }) async {
    final CropCycleRow? existing = await getCycle(id);
    final String? nextVariety = identical(variety, _absent)
        ? existing?.variety
        : variety as String?;
    final String? nextSeason = identical(season, _absent)
        ? existing?.season
        : season as String?;
    final String? nextSowingDate = identical(sowingDate, _absent)
        ? existing?.sowingDate
        : sowingDate as String?;
    final String? nextExpectedHarvestDate =
        identical(expectedHarvestDate, _absent)
        ? existing?.expectedHarvestDate
        : expectedHarvestDate as String?;
    final String? nextHarvestDate = identical(harvestDate, _absent)
        ? existing?.harvestDate
        : harvestDate as String?;
    final String nextStatus = identical(status, _absent)
        ? existing?.status ?? 'planned'
        : status as String;
    final String? nextNotes = identical(notes, _absent)
        ? existing?.notes
        : notes as String?;
    await into(cropCycles).insertOnConflictUpdate(
      CropCyclesCompanion.insert(
        id: id,
        plotId: plotId,
        cropId: cropId,
        variety: Value<String?>(nextVariety),
        season: Value<String?>(nextSeason),
        sowingDate: Value<String?>(nextSowingDate),
        expectedHarvestDate: Value<String?>(nextExpectedHarvestDate),
        harvestDate: Value<String?>(nextHarvestDate),
        status: Value<String>(nextStatus),
        notes: Value<String?>(nextNotes),
        updatedAt: Value<DateTime?>(updatedAt ?? existing?.updatedAt),
        deletedAt: Value<DateTime?>(deletedAt),
      ),
    );
  }

  Future<void> upsertActivity(
    String id,
    String cropCycleId,
    String type,
    String performedOn, {
    Object? productName = _absent,
    Object? quantity = _absent,
    Object? unit = _absent,
    Object? costXof = _absent,
    Object? notes = _absent,
    DateTime? updatedAt,
    DateTime? deletedAt,
  }) async {
    final FarmActivityRow? existing = await getActivity(id);
    final String? nextProductName = identical(productName, _absent)
        ? existing?.productName
        : productName as String?;
    final double? nextQuantity = identical(quantity, _absent)
        ? existing?.quantity
        : _doubleOrNull(quantity);
    final String? nextUnit = identical(unit, _absent)
        ? existing?.unit
        : unit as String?;
    final int? nextCostXof = identical(costXof, _absent)
        ? existing?.costXof
        : _intOrNull(costXof);
    final String? nextNotes = identical(notes, _absent)
        ? existing?.notes
        : notes as String?;
    await into(farmActivities).insertOnConflictUpdate(
      FarmActivitiesCompanion.insert(
        id: id,
        cropCycleId: cropCycleId,
        type: type,
        performedOn: performedOn,
        productName: Value<String?>(nextProductName),
        quantity: Value<double?>(nextQuantity),
        unit: Value<String?>(nextUnit),
        costXof: Value<int?>(nextCostXof),
        notes: Value<String?>(nextNotes),
        updatedAt: Value<DateTime?>(updatedAt ?? existing?.updatedAt),
        deletedAt: Value<DateTime?>(deletedAt),
      ),
    );
  }

  Future<void> upsertHarvest(
    String id,
    String cropCycleId,
    String harvestedOn,
    double quantityKg, {
    Object? quality = _absent,
    Object? soldKg = _absent,
    Object? avgPriceXofPerKg = _absent,
    DateTime? updatedAt,
    DateTime? deletedAt,
  }) async {
    final HarvestRow? existing = await getHarvest(id);
    final String? nextQuality = identical(quality, _absent)
        ? existing?.quality
        : quality as String?;
    final double nextSoldKg = identical(soldKg, _absent)
        ? existing?.soldKg ?? 0
        : _doubleOrNull(soldKg) ?? 0;
    final double? nextAvgPrice = identical(avgPriceXofPerKg, _absent)
        ? existing?.avgPriceXofPerKg
        : _doubleOrNull(avgPriceXofPerKg);
    await into(harvests).insertOnConflictUpdate(
      HarvestsCompanion.insert(
        id: id,
        cropCycleId: cropCycleId,
        harvestedOn: harvestedOn,
        quantityKg: quantityKg,
        quality: Value<String?>(nextQuality),
        soldKg: Value<double>(nextSoldKg),
        avgPriceXofPerKg: Value<double?>(nextAvgPrice),
        updatedAt: Value<DateTime?>(updatedAt ?? existing?.updatedAt),
        deletedAt: Value<DateTime?>(deletedAt),
      ),
    );
  }

  Future<void> softDeleteFarm(String id, {DateTime? deletedAt}) async {
    final DateTime when = (deletedAt ?? DateTime.now()).toUtc();
    await transaction(() async {
      await (update(farms)..where((Farms t) => t.id.equals(id))).write(
        FarmsCompanion(deletedAt: Value<DateTime?>(when)),
      );
      final List<String> plotIds = await _plotIdsForFarm(id);
      await (update(plots)..where((Plots t) => t.farmId.equals(id))).write(
        PlotsCompanion(deletedAt: Value<DateTime?>(when)),
      );
      await _softDeleteCyclesForPlots(plotIds, when);
    });
  }

  Future<void> softDeletePlot(String id, {DateTime? deletedAt}) async {
    final DateTime when = (deletedAt ?? DateTime.now()).toUtc();
    await transaction(() async {
      await (update(plots)..where((Plots t) => t.id.equals(id))).write(
        PlotsCompanion(deletedAt: Value<DateTime?>(when)),
      );
      final List<String> plotIds = <String>[id];
      await _softDeleteCyclesForPlots(plotIds, when);
    });
  }

  Future<void> softDeleteCycle(String id, {DateTime? deletedAt}) async {
    final DateTime when = (deletedAt ?? DateTime.now()).toUtc();
    await transaction(() async {
      await (update(cropCycles)..where((CropCycles t) => t.id.equals(id)))
          .write(CropCyclesCompanion(deletedAt: Value<DateTime?>(when)));
      await (update(farmActivities)
            ..where((FarmActivities t) => t.cropCycleId.equals(id)))
          .write(FarmActivitiesCompanion(deletedAt: Value<DateTime?>(when)));
      await (update(harvests)..where((Harvests t) => t.cropCycleId.equals(id)))
          .write(HarvestsCompanion(deletedAt: Value<DateTime?>(when)));
    });
  }

  Future<void> softDeleteActivity(String id, {DateTime? deletedAt}) async {
    final DateTime when = (deletedAt ?? DateTime.now()).toUtc();
    await (update(farmActivities)..where((FarmActivities t) => t.id.equals(id)))
        .write(FarmActivitiesCompanion(deletedAt: Value<DateTime?>(when)));
  }

  Future<void> softDeleteHarvest(String id, {DateTime? deletedAt}) async {
    final DateTime when = (deletedAt ?? DateTime.now()).toUtc();
    await (update(harvests)..where((Harvests t) => t.id.equals(id))).write(
      HarvestsCompanion(deletedAt: Value<DateTime?>(when)),
    );
  }

  Future<List<String>> _plotIdsForFarm(String farmId) async {
    final List<PlotRow> rows = await (select(
      plots,
    )..where((Plots t) => t.farmId.equals(farmId))).get();
    return rows.map((PlotRow row) => row.id).toList();
  }

  Future<void> _softDeleteCyclesForPlots(
    List<String> plotIds,
    DateTime when,
  ) async {
    if (plotIds.isEmpty) {
      return;
    }
    final List<CropCycleRow> cycles = await (select(
      cropCycles,
    )..where((CropCycles t) => t.plotId.isIn(plotIds))).get();
    final List<String> cycleIds = cycles
        .map((CropCycleRow row) => row.id)
        .toList();
    if (cycleIds.isEmpty) {
      return;
    }
    await (update(cropCycles)..where((CropCycles t) => t.id.isIn(cycleIds)))
        .write(CropCyclesCompanion(deletedAt: Value<DateTime?>(when)));
    await (update(farmActivities)
          ..where((FarmActivities t) => t.cropCycleId.isIn(cycleIds)))
        .write(FarmActivitiesCompanion(deletedAt: Value<DateTime?>(when)));
    await (update(harvests)
          ..where((Harvests t) => t.cropCycleId.isIn(cycleIds)))
        .write(HarvestsCompanion(deletedAt: Value<DateTime?>(when)));
  }

  Stream<List<FarmRow>> watchFarms() {
    return (select(farms)
          ..where((Farms t) => t.deletedAt.isNull())
          ..orderBy([
            (Farms t) => OrderingTerm.asc(t.name),
            (Farms t) => OrderingTerm.asc(t.id),
          ]))
        .watch();
  }

  Stream<List<PlotRow>> watchPlots(String farmId) {
    return (select(plots)
          ..where((Plots t) => t.farmId.equals(farmId) & t.deletedAt.isNull())
          ..orderBy([
            (Plots t) => OrderingTerm.asc(t.name),
            (Plots t) => OrderingTerm.asc(t.id),
          ]))
        .watch();
  }

  Stream<List<CropCycleRow>> watchCycles(String plotId) {
    return (select(cropCycles)
          ..where(
            (CropCycles t) => t.plotId.equals(plotId) & t.deletedAt.isNull(),
          )
          ..orderBy([
            (CropCycles t) => OrderingTerm.desc(t.sowingDate),
            (CropCycles t) => OrderingTerm.asc(t.id),
          ]))
        .watch();
  }

  Stream<List<FarmActivityRow>> watchActivities(String cycleId) {
    return (select(farmActivities)
          ..where(
            (FarmActivities t) =>
                t.cropCycleId.equals(cycleId) & t.deletedAt.isNull(),
          )
          ..orderBy([
            (FarmActivities t) => OrderingTerm.desc(t.performedOn),
            (FarmActivities t) => OrderingTerm.desc(t.id),
          ]))
        .watch();
  }

  Stream<List<HarvestRow>> watchHarvests(String cycleId) {
    return (select(harvests)
          ..where(
            (Harvests t) =>
                t.cropCycleId.equals(cycleId) & t.deletedAt.isNull(),
          )
          ..orderBy([
            (Harvests t) => OrderingTerm.desc(t.harvestedOn),
            (Harvests t) => OrderingTerm.desc(t.id),
          ]))
        .watch();
  }

  Stream<List<FarmActivityRow>> watchPlotActivities(String plotId) {
    final query = select(farmActivities).join(<Join<HasResultSet, dynamic>>[
      innerJoin(
        cropCycles,
        cropCycles.id.equalsExp(farmActivities.cropCycleId),
      ),
    ]);
    query.where(
      farmActivities.deletedAt.isNull() &
          cropCycles.deletedAt.isNull() &
          cropCycles.plotId.equals(plotId),
    );
    query.orderBy([
      OrderingTerm.desc(farmActivities.performedOn),
      OrderingTerm.desc(farmActivities.id),
    ]);
    return query.watch().map(
      (List<TypedResult> rows) =>
          rows.map((TypedResult row) => row.readTable(farmActivities)).toList(),
    );
  }

  Stream<List<HarvestRow>> watchPlotHarvests(String plotId) {
    final query = select(harvests).join(<Join<HasResultSet, dynamic>>[
      innerJoin(cropCycles, cropCycles.id.equalsExp(harvests.cropCycleId)),
    ]);
    query.where(
      harvests.deletedAt.isNull() &
          cropCycles.deletedAt.isNull() &
          cropCycles.plotId.equals(plotId),
    );
    query.orderBy([
      OrderingTerm.desc(harvests.harvestedOn),
      OrderingTerm.desc(harvests.id),
    ]);
    return query.watch().map(
      (List<TypedResult> rows) =>
          rows.map((TypedResult row) => row.readTable(harvests)).toList(),
    );
  }

  Stream<FarmRow?> watchFarm(String id) {
    return (select(
      farms,
    )..where((Farms t) => t.id.equals(id))).watchSingleOrNull();
  }

  Stream<PlotRow?> watchPlot(String id) {
    return (select(
      plots,
    )..where((Plots t) => t.id.equals(id))).watchSingleOrNull();
  }

  Stream<CropCycleRow?> watchCycle(String id) {
    return (select(cropCycles)
          ..where((CropCycles t) => t.id.equals(id) & t.deletedAt.isNull()))
        .watchSingleOrNull();
  }

  Future<List<PlotRow>> getActivePlots(String farmId) {
    return (select(plots)
          ..where((Plots t) => t.farmId.equals(farmId) & t.deletedAt.isNull())
          ..orderBy([
            (Plots t) => OrderingTerm.asc(t.name),
            (Plots t) => OrderingTerm.asc(t.id),
          ]))
        .get();
  }

  Future<List<CropCycleRow>> getActiveCycles(String plotId) {
    return (select(cropCycles)
          ..where(
            (CropCycles t) => t.plotId.equals(plotId) & t.deletedAt.isNull(),
          )
          ..orderBy([
            (CropCycles t) => OrderingTerm.desc(t.sowingDate),
            (CropCycles t) => OrderingTerm.asc(t.id),
          ]))
        .get();
  }

  Future<List<FarmActivityRow>> getActiveActivities(String cycleId) {
    return (select(farmActivities)
          ..where(
            (FarmActivities t) =>
                t.cropCycleId.equals(cycleId) & t.deletedAt.isNull(),
          )
          ..orderBy([
            (FarmActivities t) => OrderingTerm.desc(t.performedOn),
            (FarmActivities t) => OrderingTerm.desc(t.id),
          ]))
        .get();
  }

  Future<List<HarvestRow>> getActiveHarvests(String cycleId) {
    return (select(harvests)
          ..where(
            (Harvests t) =>
                t.cropCycleId.equals(cycleId) & t.deletedAt.isNull(),
          )
          ..orderBy([
            (Harvests t) => OrderingTerm.desc(t.harvestedOn),
            (Harvests t) => OrderingTerm.desc(t.id),
          ]))
        .get();
  }

  Future<int> countActivePlots() async {
    final List<PlotRow> rows = await (select(
      plots,
    )..where((Plots t) => t.deletedAt.isNull())).get();
    return rows.length;
  }

  Future<FarmRow?> getFarm(String id) {
    return (select(
      farms,
    )..where((Farms t) => t.id.equals(id))).getSingleOrNull();
  }

  Future<PlotRow?> getPlot(String id) {
    return (select(
      plots,
    )..where((Plots t) => t.id.equals(id))).getSingleOrNull();
  }

  Future<CropCycleRow?> getCycle(String id) {
    return (select(
      cropCycles,
    )..where((CropCycles t) => t.id.equals(id))).getSingleOrNull();
  }

  Future<FarmActivityRow?> getActivity(String id) {
    return (select(
      farmActivities,
    )..where((FarmActivities t) => t.id.equals(id))).getSingleOrNull();
  }

  Future<HarvestRow?> getHarvest(String id) {
    return (select(
      harvests,
    )..where((Harvests t) => t.id.equals(id))).getSingleOrNull();
  }

  Future<List<PendingChangeRow>> getOutbox({int limit = 200}) {
    return (select(pendingChanges)
          ..where((PendingChanges t) => t.status.equals('pending'))
          ..orderBy([
            (PendingChanges t) =>
                OrderingTerm(expression: CustomExpression<int>(_outboxRank())),
            (PendingChanges t) => OrderingTerm.asc(t.createdAt),
          ])
          ..limit(limit))
        .get();
  }

  String _outboxRank() {
    return '''
CASE
  WHEN op = 'upsert' AND entity = 'farm' THEN 0
  WHEN op = 'upsert' AND entity = 'plot' THEN 1
  WHEN op = 'upsert' AND entity = 'crop_cycle' THEN 2
  WHEN op = 'upsert' AND entity = 'farm_activity' THEN 3
  WHEN op = 'upsert' AND entity = 'harvest' THEN 4
  WHEN op = 'delete' AND entity = 'harvest' THEN 5
  WHEN op = 'delete' AND entity = 'farm_activity' THEN 6
  WHEN op = 'delete' AND entity = 'crop_cycle' THEN 7
  WHEN op = 'delete' AND entity = 'plot' THEN 8
  WHEN op = 'delete' AND entity = 'farm' THEN 9
  ELSE 10
END
''';
  }

  Stream<int> get pendingCount {
    return (select(pendingChanges)
          ..where((PendingChanges t) => t.status.equals('pending')))
        .watch()
        .map((List<PendingChangeRow> rows) => rows.length);
  }

  Stream<int> get failedCount {
    return (select(pendingChanges)
          ..where((PendingChanges t) => t.status.equals('failed')))
        .watch()
        .map((List<PendingChangeRow> rows) => rows.length);
  }

  Stream<List<PendingChangeRow>> watchFailedChanges() {
    return (select(pendingChanges)
          ..where((PendingChanges t) => t.status.equals('failed'))
          ..orderBy([
            (PendingChanges t) => OrderingTerm.asc(t.createdAt),
            (PendingChanges t) => OrderingTerm.asc(t.entity),
            (PendingChanges t) => OrderingTerm.asc(t.id),
          ]))
        .watch();
  }

  Future<bool> resetFailedChange(String entity, String id) async {
    final int updated =
        await (update(pendingChanges)..where(
              (PendingChanges t) =>
                  t.entity.equals(entity) &
                  t.id.equals(id) &
                  t.status.equals('failed'),
            ))
            .write(
              const PendingChangesCompanion(
                status: Value<String>('pending'),
                attempts: Value<int>(0),
                lastError: Value<String?>(null),
              ),
            );
    return updated > 0;
  }

  Future<int> resetAllFailedChanges() {
    return (update(
      pendingChanges,
    )..where((PendingChanges t) => t.status.equals('failed'))).write(
      const PendingChangesCompanion(
        status: Value<String>('pending'),
        attempts: Value<int>(0),
        lastError: Value<String?>(null),
      ),
    );
  }

  Future<void> deleteLocalEntity(String entity, String id) async {
    await transaction(() async {
      if (entity == 'farm') {
        final List<PlotRow> localPlots = await (select(
          plots,
        )..where((Plots t) => t.farmId.equals(id))).get();
        for (final PlotRow plot in localPlots) {
          await _removeUnconfirmedCycles(plot.id);
          if (plot.updatedAt == null) {
            await removePendingChange('plot', plot.id);
            await (delete(
              plots,
            )..where((Plots t) => t.id.equals(plot.id))).go();
          }
        }
        await removePendingChange('farm', id);
        await (delete(farms)..where((Farms t) => t.id.equals(id))).go();
      } else if (entity == 'plot') {
        await _removeUnconfirmedCycles(id);
        await removePendingChange('plot', id);
        await (delete(plots)..where((Plots t) => t.id.equals(id))).go();
      } else if (entity == 'crop_cycle') {
        await _removeUnconfirmedChildren(id);
        await removePendingChange('crop_cycle', id);
        await (delete(
          cropCycles,
        )..where((CropCycles t) => t.id.equals(id))).go();
      } else if (entity == 'farm_activity') {
        await removePendingChange('farm_activity', id);
        await (delete(
          farmActivities,
        )..where((FarmActivities t) => t.id.equals(id))).go();
      } else if (entity == 'harvest') {
        await removePendingChange('harvest', id);
        await (delete(harvests)..where((Harvests t) => t.id.equals(id))).go();
      }
    });
  }

  Future<void> _removeUnconfirmedCycles(String plotId) async {
    final List<CropCycleRow> cycles = await (select(
      cropCycles,
    )..where((CropCycles t) => t.plotId.equals(plotId))).get();
    for (final CropCycleRow cycle in cycles) {
      await _removeUnconfirmedChildren(cycle.id);
      if (cycle.updatedAt == null) {
        await removePendingChange('crop_cycle', cycle.id);
        await (delete(
          cropCycles,
        )..where((CropCycles t) => t.id.equals(cycle.id))).go();
      }
    }
  }

  Future<void> _removeUnconfirmedChildren(String cycleId) async {
    final List<FarmActivityRow> activities =
        await (select(farmActivities)..where(
              (FarmActivities t) =>
                  t.cropCycleId.equals(cycleId) & t.updatedAt.isNull(),
            ))
            .get();
    for (final FarmActivityRow activity in activities) {
      await removePendingChange('farm_activity', activity.id);
    }
    await (delete(farmActivities)..where(
          (FarmActivities t) =>
              t.cropCycleId.equals(cycleId) & t.updatedAt.isNull(),
        ))
        .go();

    final List<HarvestRow> harvestRows =
        await (select(harvests)..where(
              (Harvests t) =>
                  t.cropCycleId.equals(cycleId) & t.updatedAt.isNull(),
            ))
            .get();
    for (final HarvestRow harvest in harvestRows) {
      await removePendingChange('harvest', harvest.id);
    }
    await (delete(harvests)..where(
          (Harvests t) => t.cropCycleId.equals(cycleId) & t.updatedAt.isNull(),
        ))
        .go();
  }

  Future<void> deleteMeta(String key) {
    return (delete(syncMeta)..where((SyncMeta t) => t.key.equals(key))).go();
  }

  Future<String?> readMeta(String key) async {
    final SyncMetaEntry? entry = await (select(
      syncMeta,
    )..where((SyncMeta t) => t.key.equals(key))).getSingleOrNull();
    return entry?.value;
  }

  Future<void> writeMeta(String key, String value) {
    return into(
      syncMeta,
    ).insertOnConflictUpdate(SyncMetaCompanion.insert(key: key, value: value));
  }

  Stream<String?> watchMeta(String key) {
    return (select(syncMeta)..where((SyncMeta t) => t.key.equals(key)))
        .watchSingleOrNull()
        .map((SyncMetaEntry? entry) => entry?.value);
  }

  Future<PendingChangeRow?> getPendingChange(String entity, String id) {
    return (select(pendingChanges)..where(
          (PendingChanges t) => t.entity.equals(entity) & t.id.equals(id),
        ))
        .getSingleOrNull();
  }

  Future<void> putPendingChange(PendingChangesCompanion companion) {
    return into(pendingChanges).insertOnConflictUpdate(companion);
  }

  Future<void> removePendingChange(String entity, String id) {
    return (delete(pendingChanges)..where(
          (PendingChanges t) => t.entity.equals(entity) & t.id.equals(id),
        ))
        .go();
  }

  Future<bool> removePendingChangeIfUnchanged(
    String entity,
    String id,
    DateTime clientUpdatedAt,
  ) async {
    final int deleted =
        await (delete(pendingChanges)..where(
              (PendingChanges t) =>
                  t.entity.equals(entity) &
                  t.id.equals(id) &
                  t.clientUpdatedAt.equals(clientUpdatedAt),
            ))
            .go();
    return deleted > 0;
  }

  Future<bool> markFailedIfUnchanged(
    String entity,
    String id,
    DateTime clientUpdatedAt,
    String error,
  ) async {
    final int updated =
        await (update(pendingChanges)..where(
              (PendingChanges t) =>
                  t.entity.equals(entity) &
                  t.id.equals(id) &
                  t.clientUpdatedAt.equals(clientUpdatedAt),
            ))
            .write(
              PendingChangesCompanion(
                status: const Value<String>('failed'),
                lastError: Value<String?>(error),
              ),
            );
    return updated > 0;
  }

  Future<void> incrementAttempts(String entity, String id) async {
    await customUpdate(
      'UPDATE pending_changes SET attempts = attempts + 1 '
      'WHERE entity = ?1 AND id = ?2',
      variables: <Variable<Object>>[
        Variable<String>(entity),
        Variable<String>(id),
      ],
      updates: <ResultSetImplementation<dynamic, dynamic>>{pendingChanges},
    );
  }

  Future<void> markFailed(String entity, String id, String error) async {
    await customUpdate(
      "UPDATE pending_changes SET status = 'failed', last_error = ?3 "
      'WHERE entity = ?1 AND id = ?2',
      variables: <Variable<Object>>[
        Variable<String>(entity),
        Variable<String>(id),
        Variable<String>(error),
      ],
      updates: <ResultSetImplementation<dynamic, dynamic>>{pendingChanges},
    );
  }

  Future<bool> hasPendingChange(String entity, String id) async {
    final PendingChangeRow? row = await getPendingChange(entity, id);
    return row != null && row.status == 'pending';
  }

  Future<bool> isSoftDeleted(String entity, String id) async {
    if (entity == 'farm') {
      final FarmRow? row = await getFarm(id);
      return row?.deletedAt != null;
    }
    if (entity == 'plot') {
      final PlotRow? row = await getPlot(id);
      return row?.deletedAt != null;
    }
    if (entity == 'crop_cycle') {
      final CropCycleRow? row = await getCycle(id);
      return row?.deletedAt != null;
    }
    if (entity == 'farm_activity') {
      final FarmActivityRow? row = await getActivity(id);
      return row?.deletedAt != null;
    }
    if (entity == 'harvest') {
      final HarvestRow? row = await getHarvest(id);
      return row?.deletedAt != null;
    }
    return false;
  }

  Future<bool> hasServerVersion(String entity, String id) async {
    if (entity == 'farm') {
      final FarmRow? row = await getFarm(id);
      return row?.updatedAt != null;
    }
    if (entity == 'plot') {
      final PlotRow? row = await getPlot(id);
      return row?.updatedAt != null;
    }
    if (entity == 'crop_cycle') {
      final CropCycleRow? row = await getCycle(id);
      return row?.updatedAt != null;
    }
    if (entity == 'farm_activity') {
      final FarmActivityRow? row = await getActivity(id);
      return row?.updatedAt != null;
    }
    if (entity == 'harvest') {
      final HarvestRow? row = await getHarvest(id);
      return row?.updatedAt != null;
    }
    return false;
  }

  Future<void> touchServerUpdatedAt(
    String entity,
    String id,
    DateTime updatedAt,
  ) async {
    if (entity == 'farm') {
      await (update(farms)..where((Farms t) => t.id.equals(id))).write(
        FarmsCompanion(updatedAt: Value<DateTime?>(updatedAt)),
      );
    } else if (entity == 'plot') {
      await (update(plots)..where((Plots t) => t.id.equals(id))).write(
        PlotsCompanion(updatedAt: Value<DateTime?>(updatedAt)),
      );
    } else if (entity == 'crop_cycle') {
      await (update(cropCycles)..where((CropCycles t) => t.id.equals(id)))
          .write(CropCyclesCompanion(updatedAt: Value<DateTime?>(updatedAt)));
    } else if (entity == 'farm_activity') {
      await (update(
        farmActivities,
      )..where((FarmActivities t) => t.id.equals(id))).write(
        FarmActivitiesCompanion(updatedAt: Value<DateTime?>(updatedAt)),
      );
    } else if (entity == 'harvest') {
      await (update(harvests)..where((Harvests t) => t.id.equals(id))).write(
        HarvestsCompanion(updatedAt: Value<DateTime?>(updatedAt)),
      );
    }
  }

  Future<void> wipeAll() async {
    await transaction(() async {
      await delete(pendingChanges).go();
      await delete(harvests).go();
      await delete(farmActivities).go();
      await delete(cropCycles).go();
      await delete(plots).go();
      await delete(farms).go();
      await delete(syncMeta).go();
    });
  }
}

double? _doubleOrNull(Object? value) {
  if (value is num) {
    return value.toDouble();
  }
  return value as double?;
}

int? _intOrNull(Object? value) {
  if (value is num) {
    return value.toInt();
  }
  return value as int?;
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final Directory directory = await getApplicationDocumentsDirectory();
    final File file = File(p.join(directory.path, 'smartagri.sqlite'));
    return NativeDatabase.createInBackground(file);
  });
}

AppDatabase inMemoryAppDatabase() {
  return AppDatabase.forTesting(NativeDatabase.memory());
}

final Provider<AppDatabase> appDatabaseProvider = Provider<AppDatabase>((
  Ref ref,
) {
  final AppDatabase database = AppDatabase();
  ref.onDispose(database.close);
  return database;
});
