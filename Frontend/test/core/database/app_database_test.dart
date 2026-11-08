import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:smartagri/core/database/app_database.dart';

void main() {
  late AppDatabase database;

  setUp(() {
    database = inMemoryAppDatabase();
  });

  tearDown(() async {
    await database.close();
  });

  test('watches farms sorted and without deleted rows', () async {
    await database.upsertFarm('f2', 'Zinder');
    await database.upsertFarm('f1', 'Agadez');
    await database.upsertFarm('f3', 'Maradi');

    final List<FarmRow> rows = await database.watchFarms().first;

    expect(rows.map((FarmRow row) => row.id), <String>['f1', 'f3', 'f2']);
  });

  test('soft deleting a farm deletes its local plots', () async {
    await database.upsertFarm('f1', 'Agadez');
    await database.upsertPlot('p1', 'f1', 'Parcelle 1');
    await database.upsertPlot('p2', 'f2', 'Parcelle 2');

    await database.softDeleteFarm('f1');

    expect(await database.watchFarms().first, isEmpty);
    expect(await database.watchPlots('f1').first, isEmpty);
    expect((await database.getPlot('p1'))?.deletedAt, isNotNull);
    expect((await database.getPlot('p2'))?.deletedAt, isNull);
  });

  test('soft deleting a plot hides it from the farm plots stream', () async {
    await database.upsertFarm('f1', 'Agadez');
    await database.upsertPlot('p1', 'f1', 'Parcelle 1');

    await database.softDeletePlot('p1');

    expect(await database.watchPlots('f1').first, isEmpty);
    expect((await database.getPlot('p1'))?.deletedAt, isNotNull);
  });

  test('orders the outbox by entity and operation', () async {
    final DateTime now = DateTime.utc(2026, 11, 8, 10);
    Future<void> add(String entity, String id, String op) {
      return database.putPendingChange(
        PendingChangesCompanion.insert(
          entity: entity,
          id: id,
          op: op,
          payload: '{}',
          clientUpdatedAt: now,
          createdAt: now,
        ),
      );
    }

    await add('farm', 'farm-delete', 'delete');
    await add('plot', 'plot-upsert', 'upsert');
    await add('farm', 'farm-upsert', 'upsert');
    await add('plot', 'plot-delete', 'delete');

    final List<PendingChangeRow> rows = await database.getOutbox();

    expect(rows.map((PendingChangeRow row) => row.id), <String>[
      'farm-upsert',
      'plot-upsert',
      'plot-delete',
      'farm-delete',
    ]);
  });

  test('only takes pending changes and respects the limit', () async {
    final DateTime now = DateTime.utc(2026, 11, 8, 10);
    for (int index = 0; index < 5; index++) {
      await database.putPendingChange(
        PendingChangesCompanion.insert(
          entity: 'farm',
          id: 'farm-$index',
          op: 'upsert',
          payload: '{}',
          clientUpdatedAt: now,
          status: Value<String>(index == 4 ? 'failed' : 'pending'),
          createdAt: now,
        ),
      );
    }

    final List<PendingChangeRow> rows = await database.getOutbox(limit: 3);

    expect(rows, hasLength(3));
    expect(
      rows.every((PendingChangeRow row) => row.status == 'pending'),
      isTrue,
    );
  });

  test('exposes pending and failed counters as streams', () async {
    final DateTime now = DateTime.utc(2026, 11, 8, 10);
    await database.putPendingChange(
      PendingChangesCompanion.insert(
        entity: 'farm',
        id: 'f1',
        op: 'upsert',
        payload: '{}',
        clientUpdatedAt: now,
        createdAt: now,
      ),
    );
    await database.putPendingChange(
      PendingChangesCompanion.insert(
        entity: 'farm',
        id: 'f2',
        op: 'upsert',
        payload: '{}',
        clientUpdatedAt: now,
        status: const Value<String>('failed'),
        createdAt: now,
      ),
    );

    expect(await database.pendingCount.first, 1);
    expect(await database.failedCount.first, 1);
  });

  test('reads, writes and watches sync metadata', () async {
    expect(await database.readMeta('cursor'), isNull);

    await database.writeMeta('cursor', 'abc');
    expect(await database.readMeta('cursor'), 'abc');
    expect(await database.watchMeta('cursor').first, 'abc');

    await database.writeMeta('cursor', 'def');
    expect(await database.readMeta('cursor'), 'def');
  });

  test('wipeAll clears every table', () async {
    await database.upsertFarm('f1', 'Agadez');
    await database.upsertPlot('p1', 'f1', 'Parcelle');
    final DateTime now = DateTime.utc(2026, 11, 8, 10);
    await database.putPendingChange(
      PendingChangesCompanion.insert(
        entity: 'farm',
        id: 'f1',
        op: 'delete',
        payload: '{}',
        clientUpdatedAt: now,
        createdAt: now,
      ),
    );
    await database.writeMeta('owner_id', 'user-1');

    await database.wipeAll();

    expect(await database.getFarm('f1'), isNull);
    expect(await database.getPlot('p1'), isNull);
    expect(await database.getOutbox(), isEmpty);
    expect(await database.readMeta('owner_id'), isNull);
  });

  test(
    'preserves the server timestamp when a local upsert edits a row',
    () async {
      final DateTime serverAt = DateTime.utc(2026, 11, 8, 10);
      await database.upsertFarm('f1', 'Agadez', updatedAt: serverAt);

      await database.upsertFarm('f1', 'Agadez modifiée');

      final FarmRow? row = await database.getFarm('f1');
      expect(row?.name, 'Agadez modifiée');
      expect(row?.updatedAt?.toUtc(), serverAt);
      expect(await database.hasServerVersion('farm', 'f1'), isTrue);
    },
  );

  test('a local creation has no server timestamp', () async {
    await database.upsertFarm('f1', 'Agadez');

    expect((await database.getFarm('f1'))?.updatedAt, isNull);
    expect(await database.hasServerVersion('farm', 'f1'), isFalse);
  });
}
