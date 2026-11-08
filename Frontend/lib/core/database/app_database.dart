import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

part 'app_database.g.dart';

@DataClassName('FarmRow')
class Farms extends Table {
  TextColumn get id => text()();

  TextColumn get name => text()();

  TextColumn get village => text().nullable()();

  IntColumn get adminAreaId => integer().nullable()();

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

@DriftDatabase(tables: <Type>[Farms, Plots, PendingChanges, SyncMeta])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  AppDatabase.forTesting(super.executor);

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (Migrator migrator) => migrator.createAll(),
    onUpgrade: (Migrator migrator, int from, int to) async {},
    beforeOpen: (OpeningDetails details) async {
      await customStatement('PRAGMA foreign_keys = OFF');
    },
  );

  Future<void> upsertFarm(
    String id,
    String name, {
    String? village,
    int? adminAreaId,
    DateTime? updatedAt,
    DateTime? deletedAt,
  }) async {
    final FarmRow? existing = await getFarm(id);
    await into(farms).insertOnConflictUpdate(
      FarmsCompanion.insert(
        id: id,
        name: name,
        village: Value<String?>(village),
        adminAreaId: Value<int?>(adminAreaId),
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
    DateTime? updatedAt,
    DateTime? deletedAt,
  }) async {
    final PlotRow? existing = await getPlot(id);
    await into(plots).insertOnConflictUpdate(
      PlotsCompanion.insert(
        id: id,
        farmId: farmId,
        name: name,
        areaHa: Value<double?>(areaHa),
        soilType: Value<String?>(soilType),
        irrigation: Value<String?>(irrigation),
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
      await (update(plots)..where((Plots t) => t.farmId.equals(id))).write(
        PlotsCompanion(deletedAt: Value<DateTime?>(when)),
      );
    });
  }

  Future<void> softDeletePlot(String id, {DateTime? deletedAt}) async {
    final DateTime when = (deletedAt ?? DateTime.now()).toUtc();
    await (update(plots)..where((Plots t) => t.id.equals(id))).write(
      PlotsCompanion(deletedAt: Value<DateTime?>(when)),
    );
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

  Future<List<PlotRow>> getActivePlots(String farmId) {
    return (select(plots)
          ..where((Plots t) => t.farmId.equals(farmId) & t.deletedAt.isNull())
          ..orderBy([
            (Plots t) => OrderingTerm.asc(t.name),
            (Plots t) => OrderingTerm.asc(t.id),
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
  WHEN op = 'delete' AND entity = 'plot' THEN 2
  WHEN op = 'delete' AND entity = 'farm' THEN 3
  ELSE 4
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
    }
  }

  Future<void> wipeAll() async {
    await transaction(() async {
      await delete(pendingChanges).go();
      await delete(plots).go();
      await delete(farms).go();
      await delete(syncMeta).go();
    });
  }
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
