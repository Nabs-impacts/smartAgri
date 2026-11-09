import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartagri/core/database/app_database.dart';
import 'package:smartagri/core/sync/outbox.dart';
import 'package:smartagri/features/cycles/data/cycles_repository.dart';
import 'package:smartagri/features/cycles/domain/activity_type.dart';
import 'package:smartagri/features/cycles/domain/cycle.dart';
import 'package:smartagri/features/cycles/domain/cycle_exception.dart';
import 'package:smartagri/features/cycles/domain/cycle_status.dart';
import 'package:smartagri/features/cycles/domain/harvest.dart';
import 'package:smartagri/features/cycles/domain/harvest_quality.dart';
import 'package:smartagri/features/cycles/domain/timeline_entry.dart';

import '../../core/network/recording_adapter.dart';

class Harness {
  Harness({
    required this.database,
    required this.outbox,
    required this.repository,
    required this.adapter,
  });

  final AppDatabase database;
  final Outbox outbox;
  final LocalCyclesRepository repository;
  final RecordingAdapter? adapter;

  Future<void> close() async {
    await outbox.dispose();
    await database.close();
  }
}

Harness buildHarness({RecordingHandler? handler}) {
  final AppDatabase database = inMemoryAppDatabase();
  final DateTime now = DateTime.utc(2026, 11, 8, 10);
  final Outbox outbox = Outbox(database, now: () => now);
  Dio? dio;
  RecordingAdapter? adapter;
  if (handler != null) {
    adapter = RecordingAdapter(handler);
    dio = Dio(BaseOptions(baseUrl: 'http://test.local/api/v1'));
    dio.httpClientAdapter = adapter;
  }
  return Harness(
    database: database,
    outbox: outbox,
    repository: LocalCyclesRepository(
      database: database,
      outbox: outbox,
      dio: dio,
    ),
    adapter: adapter,
  );
}

Map<String, dynamic> payloadOf(PendingChangeRow row) {
  return jsonDecode(row.payload) as Map<String, dynamic>;
}

Future<CropCycleRow> seedCycle(
  AppDatabase database, {
  String id = 'c1',
  String plotId = 'p1',
  int cropId = 3,
  String status = 'planned',
  String variety = 'Mil',
  String? season = 'rainy',
  String? sowingDate = '2026-05-01',
  DateTime? updatedAt,
}) async {
  final DateTime serverAt = updatedAt ?? DateTime.utc(2026, 11, 8, 9);
  await database.upsertCycle(
    id,
    plotId,
    cropId,
    variety: variety,
    season: season,
    sowingDate: sowingDate,
    status: status,
    notes: 'Note',
    updatedAt: serverAt,
  );
  return (await database.getCycle(id))!;
}

Future<void> seedFarmAndPlot(AppDatabase database) async {
  final DateTime serverAt = DateTime.utc(2026, 11, 8, 9);
  await database.upsertFarm('f1', 'Ferme', updatedAt: serverAt);
  await database.upsertPlot(
    'p1',
    'f1',
    'Parcelle',
    areaHa: 2,
    updatedAt: serverAt,
  );
}

void main() {
  test('creates a cycle with a complete upsert payload', () async {
    final Harness harness = buildHarness();
    addTearDown(harness.close);
    await seedFarmAndPlot(harness.database);

    final Cycle cycle = await harness.repository.createCycle(
      'c1',
      'p1',
      3,
      variety: 'Mil',
      season: 'rainy',
      sowingDate: DateTime.utc(2026, 5, 1),
      expectedHarvestDate: DateTime.utc(2026, 8, 1),
      notes: 'Note',
    );

    expect(cycle.status, CycleStatus.planned);
    final CropCycleRow? row = await harness.database.getCycle('c1');
    expect(row?.sowingDate, '2026-05-01');
    expect(row?.expectedHarvestDate, '2026-08-01');
    expect(row?.updatedAt, isNull);
    final List<PendingChangeRow> outbox = await harness.database.getOutbox();
    expect(outbox.single.entity, 'crop_cycle');
    expect(outbox.single.op, 'upsert');
    expect(payloadOf(outbox.single), <String, dynamic>{
      'plot_id': 'p1',
      'crop_id': 3,
      'variety': 'Mil',
      'season': 'rainy',
      'sowing_date': '2026-05-01',
      'expected_harvest_date': '2026-08-01',
      'harvest_date': null,
      'status': 'planned',
      'notes': 'Note',
    });
  });

  test(
    'updateCycle merges absent fields and allows planned to growing',
    () async {
      final Harness harness = buildHarness();
      addTearDown(harness.close);
      await seedFarmAndPlot(harness.database);
      await harness.repository.createCycle(
        'c1',
        'p1',
        3,
        variety: 'Mil',
        season: 'rainy',
        sowingDate: DateTime.utc(2026, 5, 1),
        notes: 'Note',
      );
      final DateTime serverAt = DateTime.utc(2026, 11, 8, 9);
      await harness.database.upsertCycle('c1', 'p1', 3, updatedAt: serverAt);

      final Cycle cycle = await harness.repository.updateCycle(
        'c1',
        status: CycleStatus.growing,
      );

      expect(cycle.status, CycleStatus.growing);
      expect(cycle.variety, 'Mil');
      expect(cycle.season, 'rainy');
      expect(cycle.sowingDate, DateTime.utc(2026, 5, 1));
      expect(cycle.notes, 'Note');
      final CropCycleRow? row = await harness.database.getCycle('c1');
      expect(row?.status, 'growing');
      expect(row?.variety, 'Mil');
      expect(row?.updatedAt?.toUtc(), serverAt);
      final List<PendingChangeRow> outbox = await harness.database.getOutbox();
      expect(payloadOf(outbox.single), <String, dynamic>{
        'plot_id': 'p1',
        'crop_id': 3,
        'variety': 'Mil',
        'season': 'rainy',
        'sowing_date': '2026-05-01',
        'expected_harvest_date': null,
        'harvest_date': null,
        'status': 'growing',
        'notes': 'Note',
      });
    },
  );

  test('updateCycle keeps the same status', () async {
    final Harness harness = buildHarness();
    addTearDown(harness.close);
    await seedCycle(harness.database, status: 'growing');

    final Cycle cycle = await harness.repository.updateCycle(
      'c1',
      status: CycleStatus.growing,
      variety: 'Sorgho',
    );

    expect(cycle.status, CycleStatus.growing);
    expect(cycle.variety, 'Sorgho');
  });

  test('updateCycle rejects invalid transitions', () async {
    final Harness harness = buildHarness();
    addTearDown(harness.close);
    await seedCycle(harness.database, status: 'planned');

    await expectLater(
      harness.repository.updateCycle('c1', status: CycleStatus.harvested),
      throwsA(isA<CycleDomainException>()),
    );
    await expectLater(
      harness.repository.updateCycle('c1', status: CycleStatus.failed),
      throwsA(isA<CycleDomainException>()),
    );
    expect(await harness.database.getOutbox(), isEmpty);
    expect((await harness.database.getCycle('c1'))?.status, 'planned');
  });

  test('updateCycle rejects transitions from terminal states', () async {
    final Harness harness = buildHarness();
    addTearDown(harness.close);
    await seedCycle(harness.database, id: 'c1', status: 'harvested');
    await seedCycle(harness.database, id: 'c2', status: 'failed');

    await expectLater(
      harness.repository.updateCycle('c1', status: CycleStatus.growing),
      throwsA(isA<CycleDomainException>()),
    );
    await expectLater(
      harness.repository.updateCycle('c2', status: CycleStatus.planned),
      throwsA(isA<CycleDomainException>()),
    );
  });

  test('creates and updates an activity with complete payloads', () async {
    final Harness harness = buildHarness();
    addTearDown(harness.close);
    await seedCycle(harness.database);

    await harness.repository.createActivity(
      'a1',
      'c1',
      ActivityType.fertilizing,
      DateTime.utc(2026, 5, 2),
      productName: 'Urée',
      quantity: 12.5,
      unit: 'kg',
      costXof: 5000,
      notes: 'Note',
    );

    PendingChangeRow change = (await harness.database.getOutbox()).single;
    expect(change.entity, 'farm_activity');
    expect(payloadOf(change), <String, dynamic>{
      'crop_cycle_id': 'c1',
      'type': 'fertilizing',
      'performed_on': '2026-05-02',
      'product_name': 'Urée',
      'quantity': 12.5,
      'unit': 'kg',
      'cost_xof': 5000,
      'notes': 'Note',
    });

    await harness.repository.updateActivity('a1', costXof: 7000);

    final FarmActivityRow? row = await harness.database.getActivity('a1');
    expect(row?.type, 'fertilizing');
    expect(row?.productName, 'Urée');
    expect(row?.quantity, 12.5);
    expect(row?.unit, 'kg');
    expect(row?.costXof, 7000);
    change = (await harness.database.getOutbox()).single;
    expect(payloadOf(change)['cost_xof'], 7000);
    expect(payloadOf(change)['product_name'], 'Urée');
  });

  test('creates a harvest with a complete payload', () async {
    final Harness harness = buildHarness();
    addTearDown(harness.close);
    await seedCycle(harness.database, status: 'growing');

    await harness.repository.createHarvest(
      'h1',
      'c1',
      DateTime.utc(2026, 9, 1),
      100,
      quality: HarvestQuality.a,
      soldKg: 60,
      avgPriceXofPerKg: 250,
    );

    final HarvestRow? row = await harness.database.getHarvest('h1');
    expect(row?.harvestedOn, '2026-09-01');
    expect(row?.quantityKg, 100);
    expect(row?.quality, 'A');
    final List<PendingChangeRow> outbox = await harness.database.getOutbox();
    expect(outbox.single.entity, 'harvest');
    expect(payloadOf(outbox.single), <String, dynamic>{
      'crop_cycle_id': 'c1',
      'harvested_on': '2026-09-01',
      'quantity_kg': 100.0,
      'quality': 'A',
      'sold_kg': 60.0,
      'avg_price_xof_per_kg': 250.0,
    });
  });

  test('closeCycle updates the cycle and enqueues both changes', () async {
    final Harness harness = buildHarness();
    addTearDown(harness.close);
    await seedCycle(harness.database, status: 'growing');

    final Harvest harvest = await harness.repository.createHarvest(
      'h1',
      'c1',
      DateTime.utc(2026, 9, 1),
      100,
      closeCycle: true,
    );

    expect(harvest.quantityKg, 100);
    final CropCycleRow? cycle = await harness.database.getCycle('c1');
    expect(cycle?.status, 'harvested');
    expect(cycle?.harvestDate, '2026-09-01');
    final List<PendingChangeRow> outbox = await harness.database.getOutbox();
    expect(outbox.map((PendingChangeRow row) => row.entity), <String>[
      'crop_cycle',
      'harvest',
    ]);
    expect(outbox.map((PendingChangeRow row) => row.op), <String>[
      'upsert',
      'upsert',
    ]);
    expect(payloadOf(outbox.first)['status'], 'harvested');
    expect(payloadOf(outbox.first)['harvest_date'], '2026-09-01');
  });

  test('closeCycle requires a growing cycle', () async {
    final Harness harness = buildHarness();
    addTearDown(harness.close);
    await seedCycle(harness.database, status: 'planned');

    await expectLater(
      harness.repository.createHarvest(
        'h1',
        'c1',
        DateTime.utc(2026, 9, 1),
        100,
        closeCycle: true,
      ),
      throwsA(isA<CycleDomainException>()),
    );
    expect(await harness.database.getHarvest('h1'), isNull);
    expect((await harness.database.getCycle('c1'))?.status, 'planned');
    expect(await harness.database.getOutbox(), isEmpty);
  });

  test(
    'deletes a cycle with confirmed children and drops unsent ones',
    () async {
      final Harness harness = buildHarness();
      addTearDown(harness.close);
      await seedFarmAndPlot(harness.database);
      final DateTime serverAt = DateTime.utc(2026, 11, 8, 9);
      await seedCycle(harness.database, status: 'growing');
      await harness.database.upsertActivity(
        'a1',
        'c1',
        'sowing',
        '2026-05-01',
        updatedAt: serverAt,
      );
      await harness.database.upsertHarvest(
        'h1',
        'c1',
        '2026-09-01',
        100,
        updatedAt: serverAt,
      );
      await harness.repository.createActivity(
        'a2',
        'c1',
        ActivityType.other,
        DateTime.utc(2026, 5, 3),
      );
      await harness.repository.createHarvest(
        'h2',
        'c1',
        DateTime.utc(2026, 9, 2),
        50,
      );

      await harness.repository.deleteCycle('c1');

      final List<PendingChangeRow> outbox = await harness.database.getOutbox();
      expect(outbox.map((PendingChangeRow row) => row.id), <String>[
        'h1',
        'a1',
        'c1',
      ]);
      expect(outbox.map((PendingChangeRow row) => row.op), <String>[
        'delete',
        'delete',
        'delete',
      ]);
      expect((await harness.database.getCycle('c1'))?.deletedAt, isNotNull);
      expect((await harness.database.getActivity('a1'))?.deletedAt, isNotNull);
      expect((await harness.database.getHarvest('h1'))?.deletedAt, isNotNull);
      expect((await harness.database.getActivity('a2'))?.deletedAt, isNotNull);
      expect((await harness.database.getHarvest('h2'))?.deletedAt, isNotNull);
    },
  );

  test('deletes an activity and a harvest', () async {
    final Harness harness = buildHarness();
    addTearDown(harness.close);
    await seedCycle(harness.database, status: 'growing');
    await harness.database.upsertActivity(
      'a1',
      'c1',
      'sowing',
      '2026-05-01',
      updatedAt: DateTime.utc(2026, 11, 8, 9),
    );
    await harness.database.upsertHarvest(
      'h1',
      'c1',
      '2026-09-01',
      100,
      updatedAt: DateTime.utc(2026, 11, 8, 9),
    );

    await harness.repository.deleteActivity('a1');
    await harness.repository.deleteHarvest('h1');

    final List<PendingChangeRow> outbox = await harness.database.getOutbox();
    expect(outbox.map((PendingChangeRow row) => row.entity), <String>[
      'harvest',
      'farm_activity',
    ]);
    expect((await harness.database.getActivity('a1'))?.deletedAt, isNotNull);
    expect((await harness.database.getHarvest('h1'))?.deletedAt, isNotNull);
  });

  test('builds the plot timeline without deleted entries', () async {
    final Harness harness = buildHarness();
    addTearDown(harness.close);
    await seedFarmAndPlot(harness.database);
    await seedCycle(harness.database, id: 'c1', status: 'growing');
    await seedCycle(harness.database, id: 'c2', status: 'growing');
    await harness.database.upsertActivity('a1', 'c1', 'sowing', '2026-05-01');
    await harness.database.upsertActivity('a2', 'c2', 'weeding', '2026-05-01');
    await harness.database.upsertActivity(
      'a3',
      'c2',
      'irrigation',
      '2026-06-01',
    );
    await harness.database.upsertHarvest('h1', 'c1', '2026-09-01', 100);
    await harness.database.upsertActivity('a4', 'c1', 'other', '2026-07-01');
    await harness.database.softDeleteActivity('a4');

    final List<TimelineEntry> entries = await harness.repository
        .watchPlotTimeline('p1')
        .first;

    expect(entries.map((TimelineEntry entry) => entry.id), <String>[
      'h1',
      'a3',
      'a2',
      'a1',
    ]);
  });

  test('fetches the comparison of a confirmed cycle', () async {
    final Harness harness = buildHarness(
      handler: (RequestOptions options, RecordedRequest request) async {
        return body(200, <String, dynamic>{
          'cycle_id': 'c1',
          'comparison': <String, dynamic>{
            'sample_size': 7,
            'average_yield_kg_per_ha': '1200.5',
          },
        });
      },
    );
    addTearDown(harness.close);
    await seedCycle(harness.database);

    final comparison = await harness.repository.fetchComparison('c1');

    expect(comparison?.sampleSize, 7);
    expect(comparison?.averageYieldKgPerHa, 1200.5);
    expect(harness.adapter?.requests.single.path, '/cycles/c1/summary');
  });

  test('does not fetch a comparison for an unconfirmed cycle', () async {
    final Harness harness = buildHarness(
      handler: (RequestOptions options, RecordedRequest request) async {
        return body(200, <String, dynamic>{'comparison': null});
      },
    );
    addTearDown(harness.close);
    await harness.database.upsertCycle('c1', 'p1', 3, variety: 'Mil');

    expect(await harness.repository.fetchComparison('c1'), isNull);
    expect(harness.adapter?.requests, isEmpty);
  });

  test('returns null when the comparison request fails', () async {
    final Harness harness = buildHarness(
      handler: (RequestOptions options, RecordedRequest request) async {
        throw DioException.connectionError(
          requestOptions: options,
          reason: 'offline',
        );
      },
    );
    addTearDown(harness.close);
    await seedCycle(harness.database);

    expect(await harness.repository.fetchComparison('c1'), isNull);
  });
}
