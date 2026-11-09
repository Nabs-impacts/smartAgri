import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:smartagri/core/database/app_database.dart';
import 'package:smartagri/core/sync/outbox.dart';
import 'package:smartagri/core/sync/sync_service.dart';

Future<void> seedChange(
  AppDatabase database,
  String entity,
  String id, {
  String op = 'upsert',
  String status = 'failed',
  String? error = 'Refusée.',
  DateTime? createdAt,
  int attempts = 2,
}) {
  final DateTime at = createdAt ?? DateTime.utc(2026, 11, 8, 10);
  return database.putPendingChange(
    PendingChangesCompanion.insert(
      entity: entity,
      id: id,
      op: op,
      payload: '{}',
      clientUpdatedAt: at,
      attempts: Value<int>(attempts),
      status: Value<String>(status),
      lastError: Value<String?>(error),
      createdAt: at,
    ),
  );
}

void main() {
  late AppDatabase database;
  late Outbox outbox;

  setUp(() {
    database = inMemoryAppDatabase();
    outbox = Outbox(database, now: () => DateTime.utc(2026, 11, 8, 10));
  });

  tearDown(() async {
    await outbox.dispose();
    await database.close();
  });

  test('watches failed changes ordered by date', () async {
    await seedChange(
      database,
      'farm',
      'late',
      createdAt: DateTime.utc(2026, 11, 8, 12),
    );
    await seedChange(
      database,
      'plot',
      'early',
      createdAt: DateTime.utc(2026, 11, 8, 9),
    );
    await seedChange(
      database,
      'farm',
      'pending',
      status: 'pending',
      createdAt: DateTime.utc(2026, 11, 8, 8),
    );

    final List<PendingChangeRow> rows = await database
        .watchFailedChanges()
        .first;

    expect(rows.map((PendingChangeRow row) => row.id), <String>[
      'early',
      'late',
    ]);
  });

  test('retryFailed makes a failed change pending again', () async {
    await seedChange(database, 'farm', 'f1');
    final List<void> events = <void>[];
    outbox.enqueues.listen(events.add);

    await outbox.retryFailed('farm', 'f1');
    await Future<void>.delayed(Duration.zero);

    final PendingChangeRow? row = await database.getPendingChange('farm', 'f1');
    expect(row?.status, 'pending');
    expect(row?.attempts, 0);
    expect(row?.lastError, isNull);
    expect(events, hasLength(1));
  });

  test('retryAllFailed resets every failed change', () async {
    await seedChange(database, 'farm', 'f1');
    await seedChange(database, 'plot', 'p1');
    final List<void> events = <void>[];
    outbox.enqueues.listen(events.add);

    await outbox.retryAllFailed();
    await Future<void>.delayed(Duration.zero);

    expect((await database.getPendingChange('farm', 'f1'))?.status, 'pending');
    expect((await database.getPendingChange('plot', 'p1'))?.status, 'pending');
    expect(await database.getOutbox(), hasLength(2));
    expect(events, hasLength(1));
  });

  test(
    'discardFailed keeps the server version of a confirmed entity',
    () async {
      await database.upsertFarm(
        'f1',
        'Locale',
        updatedAt: DateTime.utc(2026, 11, 8, 9),
      );
      await seedChange(database, 'farm', 'f1');
      await database.writeMeta(
        SyncService.cursorHistoryKey,
        '[{"cursor":"abc","savedAt":"2026-11-08T09:00:00Z"}]',
      );
      final List<void> events = <void>[];
      outbox.enqueues.listen(events.add);

      await outbox.discardFailed('farm', 'f1');
      await Future<void>.delayed(Duration.zero);

      expect(await database.getPendingChange('farm', 'f1'), isNull);
      expect(await database.getFarm('f1'), isNotNull);
      expect(await database.readMeta(SyncService.cursorHistoryKey), isNull);
      expect(events, hasLength(1));
    },
  );

  test(
    'discardFailed deletes a never confirmed entity and its plots',
    () async {
      await database.upsertFarm('f1', 'Brouillon');
      await database.upsertPlot('p1', 'f1', 'Brouillon');
      await database.upsertPlot(
        'p2',
        'f1',
        'Confirmée',
        updatedAt: DateTime.utc(2026, 11, 8, 9),
      );
      await seedChange(database, 'farm', 'f1');
      await seedChange(database, 'plot', 'p1');

      await outbox.discardFailed('farm', 'f1');

      expect(await database.getFarm('f1'), isNull);
      expect(await database.getPlot('p1'), isNull);
      expect(await database.getPlot('p2'), isNotNull);
      expect(await database.getPendingChange('farm', 'f1'), isNull);
      expect(await database.getPendingChange('plot', 'p1'), isNull);
    },
  );

  test('discardFailed restores a deleted entity from the server', () async {
    await database.upsertFarm(
      'f1',
      'Ferme',
      updatedAt: DateTime.utc(2026, 11, 8, 9),
    );
    await database.softDeleteFarm('f1');
    await seedChange(database, 'farm', 'f1', op: 'delete');
    await database.writeMeta(
      SyncService.cursorHistoryKey,
      '[{"cursor":"abc","savedAt":"2026-11-08T09:00:00Z"}]',
    );
    final List<void> events = <void>[];
    outbox.enqueues.listen(events.add);

    await outbox.discardFailed('farm', 'f1');
    await Future<void>.delayed(Duration.zero);

    expect(await database.getPendingChange('farm', 'f1'), isNull);
    expect((await database.getFarm('f1'))?.deletedAt, isNotNull);
    expect(await database.readMeta(SyncService.cursorHistoryKey), isNull);
    expect(events, hasLength(1));
  });
}
