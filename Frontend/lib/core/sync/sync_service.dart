import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';

import '../database/app_database.dart';
import 'outbox.dart';

const int syncBatchSize = 200;
const Duration cursorSafetyWindow = Duration(seconds: 15);
const int cursorHistoryLimit = 10;

class SyncResult {
  const SyncResult({
    this.pushed = 0,
    this.conflicts = 0,
    this.rejected = 0,
    this.pulled = 0,
    this.ignored = 0,
    this.offline = false,
    this.error,
  });

  final int pushed;
  final int conflicts;
  final int rejected;
  final int pulled;
  final int ignored;
  final bool offline;
  final String? error;

  static const SyncResult none = SyncResult();
}

class SyncService {
  SyncService({
    required this.database,
    required this.dio,
    Outbox? outbox,
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now,
       _outbox = outbox ?? Outbox(database, now: now);

  static const String lastSyncAtKey = 'last_sync_at';
  static const String cursorHistoryKey = 'cursor_history';

  final AppDatabase database;
  final Dio dio;
  final DateTime Function() _now;
  final Outbox _outbox;

  Future<SyncResult>? _inFlight;

  Future<SyncResult> syncNow() {
    final Future<SyncResult>? running = _inFlight;
    if (running != null) {
      return running;
    }
    final Future<SyncResult> future = _run();
    _inFlight = future;
    void clear() {
      if (identical(_inFlight, future)) {
        _inFlight = null;
      }
    }

    future.then<void>(
      (SyncResult _) => clear(),
      onError: (Object error, StackTrace stackTrace) => clear(),
    );
    return future;
  }

  Future<SyncResult> _run() async {
    final _PushOutcome push = await _push();
    if (push.offline) {
      return SyncResult(
        pushed: push.pushed,
        conflicts: push.conflicts,
        rejected: push.rejected,
        offline: true,
      );
    }
    final _PullOutcome pull = await _pull(full: push.conflicts > 0);
    final bool offline = pull.offline;
    if (!offline && pull.error == null) {
      await database.writeMeta(lastSyncAtKey, _now().toUtc().toIso8601String());
    }
    return SyncResult(
      pushed: push.pushed,
      conflicts: push.conflicts,
      rejected: push.rejected,
      pulled: pull.pulled,
      ignored: pull.ignored,
      offline: offline,
      error: pull.error,
    );
  }

  Future<_PushOutcome> _push() async {
    int pushed = 0;
    int conflicts = 0;
    int rejected = 0;
    while (true) {
      final List<PendingChangeRow> batch = await database.getOutbox(
        limit: syncBatchSize,
      );
      if (batch.isEmpty) {
        break;
      }
      final List<Map<String, dynamic>> changes = batch
          .map(_changePayload)
          .toList(growable: false);
      final Response<dynamic> response;
      try {
        response = await dio.post<dynamic>(
          '/sync/push',
          data: <String, dynamic>{'changes': changes},
        );
      } on DioException catch (error) {
        if (_isOfflineError(error)) {
          for (final PendingChangeRow change in batch) {
            await database.incrementAttempts(change.entity, change.id);
          }
          return _PushOutcome(
            pushed: pushed,
            conflicts: conflicts,
            rejected: rejected,
            offline: true,
          );
        }
        final String message = _errorMessage(error);
        for (final PendingChangeRow change in batch) {
          await database.markFailedIfUnchanged(
            change.entity,
            change.id,
            change.clientUpdatedAt,
            message,
          );
        }
        rejected += batch.length;
        continue;
      }
      final Map<String, Map<String, dynamic>> results = _pushResults(
        response.data,
      );
      bool resolved = false;
      for (final PendingChangeRow change in batch) {
        final Map<String, dynamic>? result =
            results['${change.entity}|${change.id}'];
        if (result == null) {
          continue;
        }
        final Object? status = result['status'];
        final DateTime? serverUpdatedAt = _parseDate(
          result['server_updated_at'],
        );
        if (status == 'applied') {
          await database.removePendingChangeIfUnchanged(
            change.entity,
            change.id,
            change.clientUpdatedAt,
          );
          if (serverUpdatedAt != null) {
            await database.touchServerUpdatedAt(
              change.entity,
              change.id,
              serverUpdatedAt,
            );
          }
          if (change.op == 'upsert' &&
              await database.isSoftDeleted(change.entity, change.id) &&
              !await database.hasPendingChange(change.entity, change.id)) {
            await _outbox.enqueueDelete(change.entity, change.id);
          }
          pushed++;
          resolved = true;
        } else if (status == 'conflict') {
          await database.removePendingChangeIfUnchanged(
            change.entity,
            change.id,
            change.clientUpdatedAt,
          );
          if (serverUpdatedAt != null) {
            await database.touchServerUpdatedAt(
              change.entity,
              change.id,
              serverUpdatedAt,
            );
          }
          conflicts++;
          resolved = true;
        } else if (status == 'rejected') {
          final Object? error = result['error'];
          await database.markFailedIfUnchanged(
            change.entity,
            change.id,
            change.clientUpdatedAt,
            error is String ? error : '',
          );
          rejected++;
          resolved = true;
        }
      }
      if (!resolved) {
        break;
      }
    }
    return _PushOutcome(
      pushed: pushed,
      conflicts: conflicts,
      rejected: rejected,
    );
  }

  Map<String, dynamic> _changePayload(PendingChangeRow change) {
    final Map<String, dynamic> payload = <String, dynamic>{
      'entity': change.entity,
      'op': change.op,
      'id': change.id,
      'updated_at': change.clientUpdatedAt.toUtc().toIso8601String(),
    };
    if (change.op == 'upsert') {
      payload['data'] = _decodePayload(change.payload);
    }
    return payload;
  }

  Map<String, dynamic> _decodePayload(String raw) {
    try {
      final Object? decoded = jsonDecode(raw);
      if (decoded is Map) {
        return Map<String, dynamic>.from(decoded);
      }
    } catch (_) {}
    return <String, dynamic>{};
  }

  Map<String, Map<String, dynamic>> _pushResults(Object? data) {
    final Map<String, Map<String, dynamic>> results =
        <String, Map<String, dynamic>>{};
    final Object? rawResults = data is Map ? data['results'] : null;
    if (rawResults is! List) {
      return results;
    }
    for (final Object? item in rawResults) {
      if (item is! Map) {
        continue;
      }
      final Map<String, dynamic> result = Map<String, dynamic>.from(item);
      final Object? entity = result['entity'];
      final Object? id = result['id'];
      if (entity is String && id is String) {
        results['$entity|$id'] = result;
      }
    }
    return results;
  }

  Future<_PullOutcome> _pull({bool full = false}) async {
    int pulled = 0;
    int ignored = 0;
    String? since = full ? null : await _selectSince();
    String? lastCursor;
    bool offline = false;
    while (true) {
      final Response<dynamic> response;
      try {
        response = await dio.get<dynamic>(
          '/sync/pull',
          queryParameters: <String, dynamic>{
            'since': ?since,
            'limit': syncBatchSize,
          },
        );
      } on DioException catch (error) {
        if (_isOfflineError(error)) {
          offline = true;
          break;
        }
        return _PullOutcome(
          pulled: pulled,
          ignored: ignored,
          error: _errorMessage(error),
        );
      }
      final Object? data = response.data;
      final Map<String, dynamic> page = data is Map
          ? Map<String, dynamic>.from(data)
          : <String, dynamic>{};
      final Object? rawChanges = page['changes'];
      final Object? rawNext = page['next_cursor'];
      final bool hasMore = page['has_more'] == true;
      if (rawChanges is List) {
        await database.transaction(() async {
          for (final Object? item in rawChanges) {
            if (item is! Map) {
              continue;
            }
            final Map<String, dynamic> change = Map<String, dynamic>.from(item);
            final Object? entityValue = change['entity'];
            final Object? idValue = change['id'];
            if (entityValue is! String || idValue is! String) {
              continue;
            }
            final String entity = entityValue;
            final String id = idValue;
            if (entity != 'farm' && entity != 'plot') {
              ignored++;
              continue;
            }
            if (await database.hasPendingChange(entity, id)) {
              continue;
            }
            final Map<String, dynamic> changeData = change['data'] is Map
                ? Map<String, dynamic>.from(change['data'] as Map)
                : <String, dynamic>{};
            final DateTime? updatedAt = _parseDate(change['updated_at']);
            final DateTime? deletedAt = _parseDate(change['deleted_at']);
            if (entity == 'farm') {
              if (deletedAt != null) {
                await database.softDeleteFarm(id, deletedAt: deletedAt);
              } else {
                await database.upsertFarm(
                  id,
                  changeData['name'] as String? ?? '',
                  village: changeData['village'] as String?,
                  adminAreaId: _asInt(changeData['admin_area_id']),
                  updatedAt: updatedAt,
                );
              }
            } else if (deletedAt != null) {
              await database.softDeletePlot(id, deletedAt: deletedAt);
            } else {
              await database.upsertPlot(
                id,
                changeData['farm_id'] as String? ?? '',
                changeData['name'] as String? ?? '',
                areaHa: _asDouble(changeData['area_ha']),
                soilType: changeData['soil_type'] as String?,
                irrigation: changeData['irrigation'] as String?,
                updatedAt: updatedAt,
              );
            }
            pulled++;
          }
        });
      }
      if (rawNext is String && rawNext.isNotEmpty) {
        lastCursor = rawNext;
        since = rawNext;
      }
      if (!hasMore) {
        break;
      }
      if (rawNext is! String || rawNext.isEmpty) {
        break;
      }
    }
    if (lastCursor != null) {
      await _appendCursor(lastCursor);
    }
    return _PullOutcome(pulled: pulled, ignored: ignored, offline: offline);
  }

  Future<String?> _selectSince() async {
    final String? raw = await database.readMeta(cursorHistoryKey);
    if (raw == null) {
      return null;
    }
    final Object? decoded;
    try {
      decoded = jsonDecode(raw);
    } catch (_) {
      return null;
    }
    if (decoded is! List) {
      return null;
    }
    final DateTime threshold = _now().toUtc().subtract(cursorSafetyWindow);
    String? selected;
    DateTime? selectedAt;
    for (final Object? item in decoded) {
      if (item is! Map) {
        continue;
      }
      final Object? cursor = item['cursor'];
      final DateTime? savedAt = _parseDate(item['savedAt']);
      if (cursor is! String || savedAt == null) {
        continue;
      }
      if (savedAt.isAfter(threshold)) {
        continue;
      }
      if (selectedAt == null || savedAt.isAfter(selectedAt)) {
        selected = cursor;
        selectedAt = savedAt;
      }
    }
    return selected;
  }

  Future<void> _appendCursor(String cursor) async {
    final List<dynamic> history = <dynamic>[];
    final String? raw = await database.readMeta(cursorHistoryKey);
    if (raw != null) {
      try {
        final Object? decoded = jsonDecode(raw);
        if (decoded is List) {
          history.addAll(decoded);
        }
      } catch (_) {}
    }
    history.add(<String, String>{
      'cursor': cursor,
      'savedAt': _now().toUtc().toIso8601String(),
    });
    final List<dynamic> trimmed = history.length > cursorHistoryLimit
        ? history.sublist(history.length - cursorHistoryLimit)
        : history;
    await database.writeMeta(cursorHistoryKey, jsonEncode(trimmed));
  }

  bool _isOfflineError(DioException error) {
    final Response<dynamic>? response = error.response;
    final int? status = response?.statusCode;
    if (status == null) {
      return true;
    }
    if (status >= 500 || status == 429 || status == 401) {
      return true;
    }
    return false;
  }

  String _errorMessage(DioException error) {
    final Object? data = error.response?.data;
    if (data is Map) {
      final Object? envelope = data['error'];
      if (envelope is Map) {
        final Object? message = envelope['message'];
        if (message is String && message.trim().isNotEmpty) {
          return message;
        }
      }
    }
    return 'Les modifications ont été refusées par le serveur.';
  }

  DateTime? _parseDate(Object? value) {
    if (value is DateTime) {
      return value.toUtc();
    }
    if (value is String) {
      return DateTime.tryParse(value)?.toUtc();
    }
    return null;
  }

  int? _asInt(Object? value) {
    if (value is num) {
      return value.toInt();
    }
    if (value is String) {
      return int.tryParse(value);
    }
    return null;
  }

  double? _asDouble(Object? value) {
    if (value is num) {
      return value.toDouble();
    }
    if (value is String) {
      return double.tryParse(value.replaceAll(',', '.'));
    }
    return null;
  }
}

class _PushOutcome {
  const _PushOutcome({
    this.pushed = 0,
    this.conflicts = 0,
    this.rejected = 0,
    this.offline = false,
  });

  final int pushed;
  final int conflicts;
  final int rejected;
  final bool offline;
}

class _PullOutcome {
  const _PullOutcome({
    this.pulled = 0,
    this.ignored = 0,
    this.offline = false,
    this.error,
  });

  final int pulled;
  final int ignored;
  final bool offline;
  final String? error;
}
