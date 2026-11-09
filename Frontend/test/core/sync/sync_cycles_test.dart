import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartagri/core/database/app_database.dart';
import 'package:smartagri/core/sync/outbox.dart';
import 'package:smartagri/core/sync/sync_service.dart';

import '../network/recording_adapter.dart';

class Harness {
  Harness({
    required this.database,
    required this.service,
    required this.adapter,
    required this.outbox,
  });

  final AppDatabase database;
  final SyncService service;
  final RecordingAdapter adapter;
  final Outbox outbox;

  Future<void> close() async {
    await outbox.dispose();
    await database.close();
  }
}

typedef PullHandler = Future<ResponseBody> Function(
  int pullIndex,
  RecordedRequest request,
);

Harness buildHarness(PullHandler pull) {
  final AppDatabase database = inMemoryAppDatabase();
  int pulls = 0;
  final RecordingAdapter adapter = RecordingAdapter((
    RequestOptions options,
    RecordedRequest request,
  ) async {
    if (options.path == '/sync/push') {
      return body(200, <String, dynamic>{'results': <dynamic>[]});
    }
    final int index = pulls++;
    return pull(index, request);
  });
  final Dio dio = Dio(BaseOptions(baseUrl: 'http://test.local/api/v1'));
  dio.httpClientAdapter = adapter;
  final Outbox outbox = Outbox(
    database,
    now: () => DateTime.utc(2026, 11, 8, 10),
  );
  return Harness(
    database: database,
    service: SyncService(
      database: database,
      dio: dio,
      outbox: outbox,
      now: () => DateTime.utc(2026, 11, 8, 10),
    ),
    adapter: adapter,
    outbox: outbox,
  );
}

ResponseBody pullPage(List<Map<String, dynamic>> changes) {
  return body(200, <String, dynamic>{
    'changes': changes,
    'next_cursor': null,
    'has_more': false,
  });
}

Map<String, dynamic> cycleChange({
  String id = 'c1',
  String plotId = 'p1',
  int cropId = 3,
  String? variety = 'Mil',
  String? sowingDate = '2026-11-08',
  String? expected = '2027-02-06',
  String? harvestDate,
  String status = 'growing',
  String? notes = 'Note',
  String updatedAt = '2026-11-08T23:59:00Z',
  String? deletedAt,
}) {
  return <String, dynamic>{
    'entity': 'crop_cycle',
    'id': id,
    'data': <String, dynamic>{
      'plot_id': plotId,
      'crop_id': cropId,
      'variety': variety,
      'season': 'rainy',
      'sowing_date': sowingDate,
      'expected_harvest_date': expected,
      'harvest_date': harvestDate,
      'status': status,
      'notes': notes,
    },
    'updated_at': updatedAt,
    'deleted_at': deletedAt,
  };
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

void main() {
  test('pulls a crop cycle without shifting its dates', () async {
    final Harness harness = buildHarness((
      int index,
      RecordedRequest request,
    ) async {
      return pullPage(<Map<String, dynamic>>[cycleChange()]);
    });
    addTearDown(harness.close);

    final SyncResult result = await harness.service.syncNow();

    expect(result.pulled, 1);
    expect(result.ignored, 0);
    final CropCycleRow? row = await harness.database.getCycle('c1');
    expect(row?.plotId, 'p1');
    expect(row?.cropId, 3);
    expect(row?.variety, 'Mil');
    expect(row?.sowingDate, '2026-11-08');
    expect(row?.expectedHarvestDate, '2027-02-06');
    expect(row?.status, 'growing');
    expect(row?.updatedAt?.toUtc(), DateTime.utc(2026, 11, 8, 23, 59));
  });

  test('pulls a crop cycle update as a full replacement', () async {
    final Harness harness = buildHarness((
      int index,
      RecordedRequest request,
    ) async {
      if (index == 0) {
        return pullPage(<Map<String, dynamic>>[cycleChange()]);
      }
      return pullPage(<Map<String, dynamic>>[
        cycleChange(
          cropId: 7,
          variety: null,
          sowingDate: '2026-12-01',
          expected: null,
          status: 'harvested',
          harvestDate: '2027-03-01',
          notes: null,
          updatedAt: '2026-11-09T08:00:00Z',
        ),
      ]);
    });
    addTearDown(harness.close);

    await harness.service.syncNow();
    await harness.service.syncNow();

    final CropCycleRow? row = await harness.database.getCycle('c1');
    expect(row?.cropId, 7);
    expect(row?.variety, isNull);
    expect(row?.sowingDate, '2026-12-01');
    expect(row?.expectedHarvestDate, isNull);
    expect(row?.status, 'harvested');
    expect(row?.harvestDate, '2027-03-01');
    expect(row?.notes, isNull);
  });

  test('a pulled cycle deletion cascades to local children', () async {
    final Harness harness = buildHarness((
      int index,
      RecordedRequest request,
    ) async {
      return pullPage(<Map<String, dynamic>>[
        cycleChange(
          updatedAt: '2026-11-08T10:05:00Z',
          deletedAt: '2026-11-08T10:05:00Z',
        ),
      ]);
    });
    addTearDown(harness.close);
    await harness.database.upsertCycle(
      'c1',
      'p1',
      3,
      updatedAt: DateTime.utc(2026, 11, 8, 9),
    );
    await harness.database.upsertActivity('a1', 'c1', 'sowing', '2026-11-08');
    await harness.database.upsertHarvest('h1', 'c1', '2027-03-01', 100);

    final SyncResult result = await harness.service.syncNow();

    expect(result.pulled, 1);
    expect((await harness.database.getCycle('c1'))?.deletedAt, isNotNull);
    expect((await harness.database.getActivity('a1'))?.deletedAt, isNotNull);
    expect((await harness.database.getHarvest('h1'))?.deletedAt, isNotNull);
  });

  test('pulls activities with decimal strings', () async {
    final Harness harness = buildHarness((
      int index,
      RecordedRequest request,
    ) async {
      return pullPage(<Map<String, dynamic>>[
        <String, dynamic>{
          'entity': 'farm_activity',
          'id': 'a1',
          'data': <String, dynamic>{
            'crop_cycle_id': 'c1',
            'type': 'fertilizing',
            'performed_on': '2026-11-08',
            'product_name': 'Urée',
            'quantity': '12.5',
            'unit': 'kg',
            'cost_xof': '5000',
            'notes': null,
          },
          'updated_at': '2026-11-08T09:00:00Z',
          'deleted_at': null,
        },
      ]);
    });
    addTearDown(harness.close);

    final SyncResult result = await harness.service.syncNow();

    expect(result.pulled, 1);
    final FarmActivityRow? row = await harness.database.getActivity('a1');
    expect(row?.type, 'fertilizing');
    expect(row?.performedOn, '2026-11-08');
    expect(row?.quantity, 12.5);
    expect(row?.costXof, 5000);
  });

  test('pulls harvests with decimal strings and quality', () async {
    final Harness harness = buildHarness((
      int index,
      RecordedRequest request,
    ) async {
      return pullPage(<Map<String, dynamic>>[
        <String, dynamic>{
          'entity': 'harvest',
          'id': 'h1',
          'data': <String, dynamic>{
            'crop_cycle_id': 'c1',
            'harvested_on': '2026-11-08',
            'quantity_kg': '15.5',
            'quality': 'A',
            'sold_kg': '10',
            'avg_price_xof_per_kg': '250.75',
          },
          'updated_at': '2026-11-08T09:00:00Z',
          'deleted_at': null,
        },
      ]);
    });
    addTearDown(harness.close);

    final SyncResult result = await harness.service.syncNow();

    expect(result.pulled, 1);
    final HarvestRow? row = await harness.database.getHarvest('h1');
    expect(row?.harvestedOn, '2026-11-08');
    expect(row?.quantityKg, 15.5);
    expect(row?.quality, 'A');
    expect(row?.soldKg, 10);
    expect(row?.avgPriceXofPerKg, 250.75);
  });

  test('does not overwrite a cycle with a pending change', () async {
    final Harness harness = buildHarness((
      int index,
      RecordedRequest request,
    ) async {
      return pullPage(<Map<String, dynamic>>[cycleChange()]);
    });
    addTearDown(harness.close);
    await harness.database.upsertCycle('c1', 'p1', 3, variety: 'Locale');
    await harness.outbox.enqueueUpsert('crop_cycle', 'c1', <String, dynamic>{
      'variety': 'Locale',
    });

    final SyncResult result = await harness.service.syncNow();

    expect(result.pulled, 0);
    expect((await harness.database.getCycle('c1'))?.variety, 'Locale');
    expect(await harness.database.hasPendingChange('crop_cycle', 'c1'), isTrue);
  });

  test('pushes five upserts then five inverse deletes', () async {
    final AppDatabase database = inMemoryAppDatabase();
    addTearDown(database.close);
    final RecordingAdapter adapter = RecordingAdapter((
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
      return body(200, <String, dynamic>{
        'changes': <dynamic>[],
        'next_cursor': null,
        'has_more': false,
      });
    });
    final Dio dio = Dio(BaseOptions(baseUrl: 'http://test.local/api/v1'));
    dio.httpClientAdapter = adapter;
    final SyncService service = SyncService(
      database: database,
      dio: dio,
      now: () => DateTime.utc(2026, 11, 8, 10),
    );
    final DateTime now = DateTime.utc(2026, 11, 8, 10);
    Future<void> add(String entity, String id, String op) {
      return database.putPendingChange(
        PendingChangesCompanion.insert(
          entity: entity,
          id: id,
          op: op,
          payload: jsonEncode(<String, dynamic>{'id': id}),
          clientUpdatedAt: now,
          createdAt: now,
        ),
      );
    }

    await add('harvest', 'harvest-delete', 'delete');
    await add('farm', 'farm-delete', 'delete');
    await add('harvest', 'harvest-upsert', 'upsert');
    await add('farm_activity', 'activity-delete', 'delete');
    await add('plot', 'plot-upsert', 'upsert');
    await add('crop_cycle', 'cycle-upsert', 'upsert');
    await add('farm', 'farm-upsert', 'upsert');
    await add('plot', 'plot-delete', 'delete');
    await add('crop_cycle', 'cycle-delete', 'delete');
    await add('farm_activity', 'activity-upsert', 'upsert');

    final SyncResult result = await service.syncNow();

    expect(result.pushed, 10);
    final List<Map<String, dynamic>> pushed = changesOf(
      adapter.requests.firstWhere(
        (RecordedRequest request) => request.path == '/sync/push',
      ),
    );
    expect(pushed.map((Map<String, dynamic> change) => change['id']), <String>[
      'farm-upsert',
      'plot-upsert',
      'cycle-upsert',
      'activity-upsert',
      'harvest-upsert',
      'harvest-delete',
      'activity-delete',
      'cycle-delete',
      'plot-delete',
      'farm-delete',
    ]);
    expect(
      pushed.map((Map<String, dynamic> change) => change['entity']),
      <String>[
        'farm',
        'plot',
        'crop_cycle',
        'farm_activity',
        'harvest',
        'harvest',
        'farm_activity',
        'crop_cycle',
        'plot',
        'farm',
      ],
    );
    expect(await database.getOutbox(), isEmpty);
  });
}
