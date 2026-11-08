import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartagri/core/database/app_database.dart';
import 'package:smartagri/core/sync/sync_service.dart';

import '../network/recording_adapter.dart';

class Harness {
  Harness({
    required this.database,
    required this.service,
    required this.adapter,
  });

  final AppDatabase database;
  final SyncService service;
  final RecordingAdapter adapter;

  Future<void> close() async {
    await database.close();
  }
}

Harness buildHarness(RecordingHandler handler, {DateTime Function()? now}) {
  final AppDatabase database = inMemoryAppDatabase();
  final RecordingAdapter adapter = RecordingAdapter(handler);
  final Dio dio = Dio(BaseOptions(baseUrl: 'http://test.local/api/v1'));
  dio.httpClientAdapter = adapter;
  return Harness(
    database: database,
    service: SyncService(
      database: database,
      dio: dio,
      now: now ?? () => DateTime.utc(2026, 11, 8, 10),
    ),
    adapter: adapter,
  );
}

List<Map<String, dynamic>> changesOf(RecordedRequest request) {
  final Object? data = request.data;
  if (data is! Map) {
    return <Map<String, dynamic>>[];
  }
  final Object? changes = data['changes'];
  if (changes is! List) {
    return <Map<String, dynamic>>[];
  }
  return changes
      .whereType<Map>()
      .map((Map item) => Map<String, dynamic>.from(item))
      .toList();
}

Future<ResponseBody> emptyPull(
  RequestOptions options,
  RecordedRequest request,
) async {
  return body(200, <String, dynamic>{
    'changes': <dynamic>[],
    'next_cursor': null,
    'has_more': false,
  });
}

Future<void> seedPending(
  AppDatabase database,
  String entity,
  String id, {
  String op = 'upsert',
  Map<String, dynamic> data = const <String, dynamic>{},
  DateTime? clientUpdatedAt,
}) {
  final DateTime at = clientUpdatedAt ?? DateTime.utc(2026, 11, 8, 10);
  return database.putPendingChange(
    PendingChangesCompanion.insert(
      entity: entity,
      id: id,
      op: op,
      payload: jsonEncode(data),
      clientUpdatedAt: at,
      createdAt: at,
    ),
  );
}

void main() {
  test('applies a pushed upsert and stores the server timestamp', () async {
    final Harness harness = buildHarness((
      RequestOptions options,
      RecordedRequest request,
    ) async {
      if (options.path == '/sync/push') {
        return body(200, <String, dynamic>{
          'results': changesOf(request)
              .map(
                (Map<String, dynamic> change) => <String, dynamic>{
                  'id': change['id'],
                  'entity': change['entity'],
                  'status': 'applied',
                  'server_updated_at': '2026-11-08T10:00:05Z',
                  'error': null,
                },
              )
              .toList(),
        });
      }
      return emptyPull(options, request);
    });
    addTearDown(harness.close);
    await harness.database.upsertFarm('f1', 'Agadez');
    await seedPending(
      harness.database,
      'farm',
      'f1',
      data: <String, dynamic>{'name': 'Agadez'},
    );

    final SyncResult result = await harness.service.syncNow();

    expect(result.pushed, 1);
    expect(result.offline, isFalse);
    expect(await harness.database.getOutbox(), isEmpty);
    final FarmRow? farm = await harness.database.getFarm('f1');
    expect(farm?.updatedAt?.toUtc(), DateTime.utc(2026, 11, 8, 10, 0, 5));
    final Map<String, dynamic> pushed = changesOf(
      harness.adapter.requests.first,
    ).single;
    expect(pushed['entity'], 'farm');
    expect(pushed['op'], 'upsert');
    expect(pushed['data'], <String, dynamic>{'name': 'Agadez'});
    expect(pushed['updated_at'], '2026-11-08T10:00:00.000Z');
  });

  test('removes a conflict from the outbox', () async {
    final Harness harness = buildHarness((
      RequestOptions options,
      RecordedRequest request,
    ) async {
      if (options.path == '/sync/push') {
        return body(200, <String, dynamic>{
          'results': <Map<String, dynamic>>[
            <String, dynamic>{
              'id': 'f1',
              'entity': 'farm',
              'status': 'conflict',
              'server_updated_at': '2026-11-08T10:05:00Z',
              'error': null,
            },
          ],
        });
      }
      return emptyPull(options, request);
    });
    addTearDown(harness.close);
    await harness.database.upsertFarm('f1', 'Locale');
    await seedPending(harness.database, 'farm', 'f1');

    final SyncResult result = await harness.service.syncNow();

    expect(result.conflicts, 1);
    expect(await harness.database.getOutbox(), isEmpty);
    final FarmRow? farm = await harness.database.getFarm('f1');
    expect(farm?.updatedAt?.toUtc(), DateTime.utc(2026, 11, 8, 10, 5));
  });

  test('marks a rejected change as failed without retrying it', () async {
    int pushCalls = 0;
    final Harness harness = buildHarness((
      RequestOptions options,
      RecordedRequest request,
    ) async {
      if (options.path == '/sync/push') {
        pushCalls++;
        return body(200, <String, dynamic>{
          'results': <Map<String, dynamic>>[
            <String, dynamic>{
              'id': 'f1',
              'entity': 'farm',
              'status': 'rejected',
              'server_updated_at': null,
              'error': 'Cette ressource a été supprimée.',
            },
          ],
        });
      }
      return emptyPull(options, request);
    });
    addTearDown(harness.close);
    await seedPending(harness.database, 'farm', 'f1');

    final SyncResult result = await harness.service.syncNow();

    expect(result.rejected, 1);
    final PendingChangeRow? row = await harness.database.getPendingChange(
      'farm',
      'f1',
    );
    expect(row?.status, 'failed');
    expect(row?.lastError, 'Cette ressource a été supprimée.');

    await harness.service.syncNow();
    expect(pushCalls, 1);
  });

  test('a network error increments attempts and reports offline', () async {
    final Harness harness = buildHarness((
      RequestOptions options,
      RecordedRequest request,
    ) async {
      if (options.path == '/sync/push') {
        throw DioException.connectionError(
          requestOptions: options,
          reason: 'offline',
        );
      }
      return emptyPull(options, request);
    });
    addTearDown(harness.close);
    await seedPending(harness.database, 'farm', 'f1');

    final SyncResult result = await harness.service.syncNow();

    expect(result.offline, isTrue);
    final PendingChangeRow? row = await harness.database.getPendingChange(
      'farm',
      'f1',
    );
    expect(row?.attempts, 1);
    expect(row?.status, 'pending');
    expect(
      harness.adapter.requests.where(
        (RecordedRequest request) => request.path == '/sync/pull',
      ),
      isEmpty,
    );
  });

  test('pushes changes in batches of 200', () async {
    final List<int> batchSizes = <int>[];
    final Harness harness = buildHarness((
      RequestOptions options,
      RecordedRequest request,
    ) async {
      if (options.path == '/sync/push') {
        final List<Map<String, dynamic>> changes = changesOf(request);
        batchSizes.add(changes.length);
        return body(200, <String, dynamic>{
          'results': changes
              .map(
                (Map<String, dynamic> change) => <String, dynamic>{
                  'id': change['id'],
                  'entity': change['entity'],
                  'status': 'applied',
                  'server_updated_at': '2026-11-08T10:00:05Z',
                  'error': null,
                },
              )
              .toList(),
        });
      }
      return emptyPull(options, request);
    });
    addTearDown(harness.close);
    for (int index = 0; index < 205; index++) {
      await seedPending(harness.database, 'farm', 'farm-$index');
    }

    final SyncResult result = await harness.service.syncNow();

    expect(batchSizes, <int>[200, 5]);
    expect(result.pushed, 205);
    expect(await harness.database.getOutbox(), isEmpty);
  });

  test('pulls several pages and ignores other entities', () async {
    final List<String?> sines = <String?>[];
    final Harness harness = buildHarness((
      RequestOptions options,
      RecordedRequest request,
    ) async {
      if (options.path == '/sync/push') {
        return body(200, <String, dynamic>{'results': <dynamic>[]});
      }
      final String? since = request.queryParameters['since'] as String?;
      sines.add(since);
      if (since == null) {
        return body(200, <String, dynamic>{
          'changes': <Map<String, dynamic>>[
            <String, dynamic>{
              'entity': 'farm',
              'id': 'f1',
              'data': <String, dynamic>{'name': 'Agadez'},
              'updated_at': '2026-11-08T09:00:00Z',
              'deleted_at': null,
            },
            <String, dynamic>{
              'entity': 'plot',
              'id': 'p1',
              'data': <String, dynamic>{
                'farm_id': 'f1',
                'name': 'Parcelle',
                'area_ha': 2.5,
                'soil_type': 'loam',
                'irrigation': 'drip',
              },
              'updated_at': '2026-11-08T09:01:00Z',
              'deleted_at': null,
            },
          ],
          'next_cursor': 'cursor-1',
          'has_more': true,
        });
      }
      return body(200, <String, dynamic>{
        'changes': <Map<String, dynamic>>[
          <String, dynamic>{
            'entity': 'crop_cycle',
            'id': 'c1',
            'data': <String, dynamic>{},
            'updated_at': '2026-11-08T09:02:00Z',
            'deleted_at': null,
          },
          <String, dynamic>{
            'entity': 'farm',
            'id': 'f2',
            'data': <String, dynamic>{'name': 'Dosso'},
            'updated_at': '2026-11-08T09:03:00Z',
            'deleted_at': null,
          },
        ],
        'next_cursor': 'cursor-2',
        'has_more': false,
      });
    });
    addTearDown(harness.close);

    final SyncResult result = await harness.service.syncNow();

    expect(sines, <String?>[null, 'cursor-1']);
    expect(result.pulled, 3);
    expect(result.ignored, 1);
    expect((await harness.database.getFarm('f1'))?.name, 'Agadez');
    final PlotRow? plot = await harness.database.getPlot('p1');
    expect(plot?.areaHa, 2.5);
    expect(plot?.soilType, 'loam');
    expect((await harness.database.getFarm('f2'))?.name, 'Dosso');
    final String? history = await harness.database.readMeta(
      SyncService.cursorHistoryKey,
    );
    final List<dynamic> entries = jsonDecode(history!) as List<dynamic>;
    expect(entries, hasLength(1));
    expect((entries.single as Map<String, dynamic>)['cursor'], 'cursor-2');
  });

  test('a pulled farm deletion deletes its local plots', () async {
    final Harness harness = buildHarness((
      RequestOptions options,
      RecordedRequest request,
    ) async {
      if (options.path == '/sync/push') {
        return body(200, <String, dynamic>{'results': <dynamic>[]});
      }
      return body(200, <String, dynamic>{
        'changes': <Map<String, dynamic>>[
          <String, dynamic>{
            'entity': 'farm',
            'id': 'f1',
            'data': <String, dynamic>{'name': 'Agadez'},
            'updated_at': '2026-11-08T09:05:00Z',
            'deleted_at': '2026-11-08T09:05:00Z',
          },
        ],
        'next_cursor': null,
        'has_more': false,
      });
    });
    addTearDown(harness.close);
    await harness.database.upsertFarm(
      'f1',
      'Agadez',
      updatedAt: DateTime.utc(2026, 11, 8, 8),
    );
    await harness.database.upsertPlot(
      'p1',
      'f1',
      'Parcelle',
      updatedAt: DateTime.utc(2026, 11, 8, 8),
    );

    final SyncResult result = await harness.service.syncNow();

    expect(result.pulled, 1);
    expect(await harness.database.watchFarms().first, isEmpty);
    expect(await harness.database.watchPlots('f1').first, isEmpty);
    expect((await harness.database.getPlot('p1'))?.deletedAt, isNotNull);
  });

  test('does not overwrite a row with a pending change', () async {
    final Harness harness = buildHarness((
      RequestOptions options,
      RecordedRequest request,
    ) async {
      if (options.path == '/sync/push') {
        return body(200, <String, dynamic>{'results': <dynamic>[]});
      }
      return body(200, <String, dynamic>{
        'changes': <Map<String, dynamic>>[
          <String, dynamic>{
            'entity': 'farm',
            'id': 'f1',
            'data': <String, dynamic>{'name': 'Serveur'},
            'updated_at': '2026-11-08T09:00:00Z',
            'deleted_at': null,
          },
        ],
        'next_cursor': null,
        'has_more': false,
      });
    });
    addTearDown(harness.close);
    await harness.database.upsertFarm('f1', 'Locale');
    await seedPending(harness.database, 'farm', 'f1');

    final SyncResult result = await harness.service.syncNow();

    expect(result.pulled, 0);
    expect((await harness.database.getFarm('f1'))?.name, 'Locale');
    expect(await harness.database.hasPendingChange('farm', 'f1'), isTrue);
  });

  test('does not use a cursor saved less than 15 seconds ago', () async {
    DateTime now = DateTime.utc(2026, 11, 8, 10);
    final List<String?> sines = <String?>[];
    final Harness harness = buildHarness((
      RequestOptions options,
      RecordedRequest request,
    ) async {
      if (options.path == '/sync/push') {
        return body(200, <String, dynamic>{'results': <dynamic>[]});
      }
      sines.add(request.queryParameters['since'] as String?);
      return emptyPull(options, request);
    }, now: () => now);
    addTearDown(harness.close);
    await harness.database.writeMeta(
      SyncService.cursorHistoryKey,
      jsonEncode(<dynamic>[
        <String, String>{
          'cursor': 'recent',
          'savedAt': now
              .subtract(const Duration(seconds: 14))
              .toIso8601String(),
        },
      ]),
    );

    await harness.service.syncNow();

    expect(sines.single, isNull);
  });

  test('uses a cursor saved at least 15 seconds ago', () async {
    DateTime now = DateTime.utc(2026, 11, 8, 10);
    final List<String?> sines = <String?>[];
    final Harness harness = buildHarness((
      RequestOptions options,
      RecordedRequest request,
    ) async {
      if (options.path == '/sync/push') {
        return body(200, <String, dynamic>{'results': <dynamic>[]});
      }
      sines.add(request.queryParameters['since'] as String?);
      return emptyPull(options, request);
    }, now: () => now);
    addTearDown(harness.close);
    await harness.database.writeMeta(
      SyncService.cursorHistoryKey,
      jsonEncode(<dynamic>[
        <String, String>{
          'cursor': 'safe',
          'savedAt': now
              .subtract(const Duration(seconds: 16))
              .toIso8601String(),
        },
      ]),
    );

    await harness.service.syncNow();

    expect(sines.single, 'safe');
  });

  test('keeps at most ten cursor entries', () async {
    final DateTime now = DateTime.utc(2026, 11, 8, 10);
    final Harness harness = buildHarness((
      RequestOptions options,
      RecordedRequest request,
    ) async {
      if (options.path == '/sync/push') {
        return body(200, <String, dynamic>{'results': <dynamic>[]});
      }
      return body(200, <String, dynamic>{
        'changes': <dynamic>[],
        'next_cursor': 'newest',
        'has_more': false,
      });
    }, now: () => now);
    addTearDown(harness.close);
    await harness.database.writeMeta(
      SyncService.cursorHistoryKey,
      jsonEncode(<dynamic>[
        for (int index = 0; index < 12; index++)
          <String, String>{
            'cursor': 'cursor-$index',
            'savedAt': now
                .subtract(Duration(minutes: 10 - index))
                .toIso8601String(),
          },
      ]),
    );

    await harness.service.syncNow();

    final String? raw = await harness.database.readMeta(
      SyncService.cursorHistoryKey,
    );
    final List<dynamic> entries = jsonDecode(raw!) as List<dynamic>;
    expect(entries, hasLength(10));
    expect((entries.last as Map<String, dynamic>)['cursor'], 'newest');
  });

  test('shares a single execution between simultaneous calls', () async {
    final Completer<ResponseBody> pushCompleter = Completer<ResponseBody>();
    final Harness harness = buildHarness((
      RequestOptions options,
      RecordedRequest request,
    ) async {
      if (options.path == '/sync/push') {
        return pushCompleter.future;
      }
      return emptyPull(options, request);
    });
    addTearDown(harness.close);
    await seedPending(harness.database, 'farm', 'f1');

    final Future<SyncResult> first = harness.service.syncNow();
    final Future<SyncResult> second = harness.service.syncNow();
    await pumpEventQueue();

    expect(identical(first, second), isTrue);
    final RecordedRequest pushRequest = harness.adapter.requests.firstWhere(
      (RecordedRequest request) => request.path == '/sync/push',
    );
    pushCompleter.complete(
      body(200, <String, dynamic>{
        'results': changesOf(pushRequest)
            .map(
              (Map<String, dynamic> change) => <String, dynamic>{
                'id': change['id'],
                'entity': change['entity'],
                'status': 'applied',
                'server_updated_at': '2026-11-08T10:00:05Z',
                'error': null,
              },
            )
            .toList(),
      }),
    );

    final SyncResult result = await first;
    await second;

    expect(result.pushed, 1);
    expect(
      harness.adapter.requests.where(
        (RecordedRequest request) => request.path == '/sync/push',
      ),
      hasLength(1),
    );
  });

  test('records the last sync date after a complete run', () async {
    final DateTime now = DateTime.utc(2026, 11, 8, 10, 30);
    final Harness harness = buildHarness((
      RequestOptions options,
      RecordedRequest request,
    ) async {
      if (options.path == '/sync/push') {
        return body(200, <String, dynamic>{'results': <dynamic>[]});
      }
      return emptyPull(options, request);
    }, now: () => now);
    addTearDown(harness.close);

    await harness.service.syncNow();

    expect(
      await harness.database.readMeta(SyncService.lastSyncAtKey),
      now.toIso8601String(),
    );
  });
}
