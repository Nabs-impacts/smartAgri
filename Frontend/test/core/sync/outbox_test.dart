import 'package:flutter_test/flutter_test.dart';
import 'package:smartagri/core/database/app_database.dart';
import 'package:smartagri/core/sync/outbox.dart';

void main() {
  late AppDatabase database;
  late Outbox outbox;
  late DateTime now;

  setUp(() {
    database = inMemoryAppDatabase();
    now = DateTime.utc(2026, 11, 8, 10);
    outbox = Outbox(database, now: () => now);
  });

  tearDown(() async {
    await outbox.dispose();
    await database.close();
  });

  test('three upserts on the same entity keep a single entry', () async {
    await outbox.enqueueUpsert('farm', 'f1', <String, dynamic>{'name': 'A'});
    now = now.add(const Duration(seconds: 1));
    await outbox.enqueueUpsert('farm', 'f1', <String, dynamic>{'name': 'B'});
    now = now.add(const Duration(seconds: 1));
    await outbox.enqueueUpsert('farm', 'f1', <String, dynamic>{'name': 'C'});

    final List<PendingChangeRow> rows = await database.getOutbox();

    expect(rows, hasLength(1));
    expect(rows.single.payload, '{"name":"C"}');
    expect(rows.single.op, 'upsert');
    expect(rows.single.clientUpdatedAt.toUtc(), now);
  });

  test('deleting a never sent creation removes it without sending', () async {
    await outbox.enqueueUpsert('farm', 'f1', <String, dynamic>{'name': 'A'});
    await outbox.enqueueDelete('farm', 'f1');

    expect(await database.getOutbox(), isEmpty);
    expect(await database.getPendingChange('farm', 'f1'), isNull);
  });

  test('a delete replaces a pending upsert on a confirmed entity', () async {
    await database.upsertFarm(
      'f1',
      'A',
      updatedAt: DateTime.utc(2026, 11, 8, 9),
    );
    await outbox.enqueueUpsert('farm', 'f1', <String, dynamic>{'name': 'B'});
    await outbox.enqueueDelete('farm', 'f1');

    final PendingChangeRow? row = await database.getPendingChange('farm', 'f1');

    expect(row?.op, 'delete');
    expect(row?.status, 'pending');
  });

  test('a failed change becomes pending again after a new edit', () async {
    await outbox.enqueueUpsert('farm', 'f1', <String, dynamic>{'name': 'A'});
    await database.incrementAttempts('farm', 'f1');
    await database.incrementAttempts('farm', 'f1');
    await database.markFailed('farm', 'f1', 'Donnée invalide.');

    expect((await database.getPendingChange('farm', 'f1'))?.status, 'failed');
    expect((await database.getPendingChange('farm', 'f1'))?.attempts, 2);

    await outbox.enqueueUpsert('farm', 'f1', <String, dynamic>{'name': 'B'});

    final PendingChangeRow? row = await database.getPendingChange('farm', 'f1');
    expect(row?.status, 'pending');
    expect(row?.attempts, 0);
    expect(row?.lastError, isNull);
    expect(row?.payload, '{"name":"B"}');
  });

  test('deletes a confirmed entity but not an unsent creation', () async {
    await database.upsertFarm(
      'confirmed',
      'Confirmée',
      updatedAt: DateTime.utc(2026, 11, 8, 9),
    );
    await database.upsertFarm('draft', 'Brouillon');

    await outbox.enqueueUpsert('farm', 'confirmed', <String, dynamic>{
      'name': 'Confirmée',
    });
    await outbox.enqueueUpsert('farm', 'draft', <String, dynamic>{
      'name': 'Brouillon',
    });
    await outbox.enqueueDelete('farm', 'confirmed');
    await outbox.enqueueDelete('farm', 'draft');

    final List<PendingChangeRow> rows = await database.getOutbox();

    expect(rows, hasLength(1));
    expect(rows.single.id, 'confirmed');
    expect(rows.single.op, 'delete');
  });

  test('emits an event when a change has to be sent', () async {
    final List<void> events = <void>[];
    outbox.enqueues.listen(events.add);

    await outbox.enqueueUpsert('farm', 'f1', <String, dynamic>{'name': 'A'});
    await Future<void>.delayed(Duration.zero);

    expect(events, hasLength(1));
  });
}
