import 'dart:async';
import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../database/app_database.dart';

const String cursorHistoryMetaKey = 'cursor_history';

class Outbox {
  Outbox(this.database, {DateTime Function()? now})
    : _now = now ?? DateTime.now;

  final AppDatabase database;
  final DateTime Function() _now;
  final StreamController<void> _enqueues = StreamController<void>.broadcast();

  Stream<void> get enqueues => _enqueues.stream;

  Future<void> enqueueUpsert(
    String entity,
    String id,
    Map<String, dynamic> payload,
  ) async {
    final DateTime now = _now().toUtc();
    await database.transaction(() async {
      final PendingChangeRow? existing = await database.getPendingChange(
        entity,
        id,
      );
      await database.putPendingChange(
        PendingChangesCompanion.insert(
          entity: entity,
          id: id,
          op: 'upsert',
          payload: jsonEncode(payload),
          clientUpdatedAt: now,
          attempts: const Value<int>(0),
          status: const Value<String>('pending'),
          lastError: const Value<String?>(null),
          createdAt: existing?.createdAt ?? now,
        ),
      );
    });
    _enqueues.add(null);
  }

  Future<void> enqueueDelete(String entity, String id) async {
    final DateTime now = _now().toUtc();
    final bool enqueued = await database.transaction<bool>(() async {
      final PendingChangeRow? existing = await database.getPendingChange(
        entity,
        id,
      );
      if (existing != null && existing.op == 'upsert') {
        final bool confirmed = await database.hasServerVersion(entity, id);
        if (!confirmed) {
          await database.removePendingChange(entity, id);
          return false;
        }
      }
      await database.putPendingChange(
        PendingChangesCompanion.insert(
          entity: entity,
          id: id,
          op: 'delete',
          payload: '{}',
          clientUpdatedAt: now,
          attempts: const Value<int>(0),
          status: const Value<String>('pending'),
          lastError: const Value<String?>(null),
          createdAt: existing?.createdAt ?? now,
        ),
      );
      return true;
    });
    if (enqueued) {
      _enqueues.add(null);
    }
  }

  Future<void> retryFailed(String entity, String id) async {
    final bool changed = await database.resetFailedChange(entity, id);
    if (changed) {
      _enqueues.add(null);
    }
  }

  Future<void> retryAllFailed() async {
    final int changed = await database.resetAllFailedChanges();
    if (changed > 0) {
      _enqueues.add(null);
    }
  }

  Future<void> discardFailed(String entity, String id) async {
    final PendingChangeRow? change = await database.getPendingChange(
      entity,
      id,
    );
    if (change == null || change.status != 'failed') {
      return;
    }
    if (change.op == 'delete') {
      await database.transaction(() async {
        await database.removePendingChange(entity, id);
        await database.deleteMeta(cursorHistoryMetaKey);
      });
      _enqueues.add(null);
      return;
    }
    final bool confirmed = await database.hasServerVersion(entity, id);
    if (confirmed) {
      await database.transaction(() async {
        await database.removePendingChange(entity, id);
        await database.deleteMeta(cursorHistoryMetaKey);
      });
      _enqueues.add(null);
      return;
    }
    await database.deleteLocalEntity(entity, id);
  }

  Future<void> dispose() => _enqueues.close();
}

final Provider<Outbox> outboxProvider = Provider<Outbox>((Ref ref) {
  final Outbox outbox = Outbox(ref.watch(appDatabaseProvider));
  ref.onDispose(outbox.dispose);
  return outbox;
});
