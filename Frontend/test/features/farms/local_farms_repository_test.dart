import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:smartagri/core/database/app_database.dart';
import 'package:smartagri/core/network/api_exception.dart';
import 'package:smartagri/core/sync/outbox.dart';
import 'package:smartagri/features/farms/data/farms_repository.dart';
import 'package:smartagri/features/farms/domain/farm.dart';
import 'package:smartagri/features/farms/domain/plot.dart';

class Harness {
  Harness(this.database, this.outbox, this.repository);

  final AppDatabase database;
  final Outbox outbox;
  final LocalFarmsRepository repository;

  Future<void> close() async {
    await outbox.dispose();
    await database.close();
  }
}

Harness buildHarness({int? Function()? plotLimit}) {
  final AppDatabase database = inMemoryAppDatabase();
  final DateTime now = DateTime.utc(2026, 11, 8, 10);
  final Outbox outbox = Outbox(database, now: () => now);
  return Harness(
    database,
    outbox,
    LocalFarmsRepository(
      database: database,
      outbox: outbox,
      plotLimit: plotLimit,
    ),
  );
}

Map<String, dynamic> payloadOf(PendingChangeRow row) {
  return jsonDecode(row.payload) as Map<String, dynamic>;
}

void main() {
  test('creates a farm locally with a complete upsert', () async {
    final Harness harness = buildHarness();
    addTearDown(harness.close);

    final Farm farm = await harness.repository.createFarm(
      'farm-1',
      'Ferme',
      village: 'Saga',
      adminAreaId: 1,
    );

    final FarmRow? row = await harness.database.getFarm('farm-1');
    expect(row?.name, 'Ferme');
    expect(row?.updatedAt, isNull);
    expect(farm.updatedAt, isNull);
    final List<PendingChangeRow> outbox = await harness.database.getOutbox();
    expect(outbox, hasLength(1));
    expect(outbox.single.entity, 'farm');
    expect(outbox.single.op, 'upsert');
    expect(payloadOf(outbox.single), <String, dynamic>{
      'name': 'Ferme',
      'village': 'Saga',
      'admin_area_id': 1,
      'location': null,
    });
  });

  test('creates a plot locally with a complete upsert', () async {
    final Harness harness = buildHarness();
    addTearDown(harness.close);
    await harness.database.upsertFarm(
      'farm-1',
      'Ferme',
      updatedAt: DateTime.utc(2026, 11, 8, 9),
    );

    final Plot plot = await harness.repository.createPlot(
      'farm-1',
      'plot-1',
      'Nord',
      areaHa: 2.5,
      soilType: SoilType.loam,
      irrigation: IrrigationType.drip,
    );

    final PlotRow? row = await harness.database.getPlot('plot-1');
    expect(row?.name, 'Nord');
    expect(row?.updatedAt, isNull);
    expect(plot.updatedAt, isNull);
    final List<PendingChangeRow> outbox = await harness.database.getOutbox();
    expect(outbox, hasLength(1));
    expect(outbox.single.entity, 'plot');
    expect(outbox.single.op, 'upsert');
    expect(payloadOf(outbox.single), <String, dynamic>{
      'farm_id': 'farm-1',
      'name': 'Nord',
      'area_ha': 2.5,
      'geom': null,
      'soil_type': 'loam',
      'irrigation': 'drip',
    });
  });

  test('updates a farm while keeping its server timestamp', () async {
    final Harness harness = buildHarness();
    addTearDown(harness.close);
    final DateTime serverAt = DateTime.utc(2026, 11, 8, 9);
    await harness.database.upsertFarm(
      'farm-1',
      'Ancienne',
      updatedAt: serverAt,
      village: 'Saga',
    );

    await harness.repository.updateFarm(
      'farm-1',
      name: 'Nouvelle',
      village: null,
    );

    final FarmRow? row = await harness.database.getFarm('farm-1');
    expect(row?.name, 'Nouvelle');
    expect(row?.village, isNull);
    expect(row?.updatedAt?.toUtc(), serverAt);
    final List<PendingChangeRow> outbox = await harness.database.getOutbox();
    expect(outbox.single.op, 'upsert');
    expect(payloadOf(outbox.single), <String, dynamic>{
      'name': 'Nouvelle',
      'village': null,
      'admin_area_id': null,
      'location': null,
    });
  });

  test(
    'updates a plot with the complete object and server timestamp',
    () async {
      final Harness harness = buildHarness();
      addTearDown(harness.close);
      final DateTime serverAt = DateTime.utc(2026, 11, 8, 9);
      await harness.database.upsertFarm('farm-1', 'Ferme', updatedAt: serverAt);
      await harness.database.upsertPlot(
        'plot-1',
        'farm-1',
        'Ancienne',
        areaHa: 2,
        soilType: 'loam',
        irrigation: 'drip',
        updatedAt: serverAt,
      );

      await harness.repository.updatePlot(
        'plot-1',
        name: 'Nouvelle',
        areaHa: 3,
        irrigation: IrrigationType.rainfed,
      );

      final PlotRow? row = await harness.database.getPlot('plot-1');
      expect(row?.name, 'Nouvelle');
      expect(row?.areaHa, 3);
      expect(row?.soilType, 'loam');
      expect(row?.irrigation, 'rainfed');
      expect(row?.updatedAt?.toUtc(), serverAt);
      final List<PendingChangeRow> outbox = await harness.database.getOutbox();
      expect(payloadOf(outbox.single), <String, dynamic>{
        'farm_id': 'farm-1',
        'name': 'Nouvelle',
        'area_ha': 3,
        'geom': null,
        'soil_type': 'loam',
        'irrigation': 'rainfed',
      });
    },
  );

  test('deletes a confirmed plot and sends a delete', () async {
    final Harness harness = buildHarness();
    addTearDown(harness.close);
    await harness.database.upsertPlot(
      'plot-1',
      'farm-1',
      'Nord',
      updatedAt: DateTime.utc(2026, 11, 8, 9),
    );

    await harness.repository.deletePlot('plot-1');

    final List<PendingChangeRow> outbox = await harness.database.getOutbox();
    expect(outbox.single.entity, 'plot');
    expect(outbox.single.op, 'delete');
    expect((await harness.database.getPlot('plot-1'))?.deletedAt, isNotNull);
  });

  test('deletes a never confirmed plot without sending anything', () async {
    final Harness harness = buildHarness();
    addTearDown(harness.close);
    await harness.database.upsertFarm('farm-1', 'Ferme');
    await harness.repository.createPlot('farm-1', 'plot-1', 'Nord');

    await harness.repository.deletePlot('plot-1');

    expect(await harness.database.getOutbox(), isEmpty);
    expect((await harness.database.getPlot('plot-1'))?.deletedAt, isNotNull);
  });

  test('deletes the plots of a farm before the farm itself', () async {
    final Harness harness = buildHarness();
    addTearDown(harness.close);
    final DateTime serverAt = DateTime.utc(2026, 11, 8, 9);
    await harness.database.upsertFarm('farm-1', 'Ferme', updatedAt: serverAt);
    await harness.database.upsertPlot(
      'plot-1',
      'farm-1',
      'Nord',
      updatedAt: serverAt,
    );
    await harness.database.upsertPlot(
      'plot-2',
      'farm-1',
      'Sud',
      updatedAt: serverAt,
    );

    await harness.repository.deleteFarm('farm-1');

    final List<PendingChangeRow> outbox = await harness.database.getOutbox();
    expect(outbox.map((PendingChangeRow row) => row.op), <String>[
      'delete',
      'delete',
      'delete',
    ]);
    expect(outbox.map((PendingChangeRow row) => row.entity), <String>[
      'plot',
      'plot',
      'farm',
    ]);
    expect(outbox.last.id, 'farm-1');
    expect((await harness.database.getFarm('farm-1'))?.deletedAt, isNotNull);
    expect((await harness.database.getPlot('plot-1'))?.deletedAt, isNotNull);
    expect((await harness.database.getPlot('plot-2'))?.deletedAt, isNotNull);
  });

  test(
    'deletes nothing when the farm and its plots were never confirmed',
    () async {
      final Harness harness = buildHarness();
      addTearDown(harness.close);
      await harness.repository.createFarm('farm-1', 'Ferme');
      await harness.repository.createPlot('farm-1', 'plot-1', 'Nord');
      await harness.repository.createPlot('farm-1', 'plot-2', 'Sud');

      await harness.repository.deleteFarm('farm-1');

      expect(await harness.database.getOutbox(), isEmpty);
      expect((await harness.database.getFarm('farm-1'))?.deletedAt, isNotNull);
      expect((await harness.database.getPlot('plot-1'))?.deletedAt, isNotNull);
      expect((await harness.database.getPlot('plot-2'))?.deletedAt, isNotNull);
    },
  );

  test('refuses to create a plot when the local quota is reached', () async {
    final Harness harness = buildHarness(plotLimit: () => 2);
    addTearDown(harness.close);
    await harness.database.upsertFarm('farm-1', 'Ferme');
    await harness.database.upsertPlot('plot-1', 'farm-1', 'Nord');
    await harness.database.upsertPlot('plot-2', 'farm-1', 'Sud');

    await expectLater(
      harness.repository.createPlot('farm-1', 'plot-3', 'Est'),
      throwsA(
        isA<ApiException>()
            .having(
              (ApiException error) => error.code,
              'code',
              'QUOTA_EXCEEDED',
            )
            .having(
              (ApiException error) => error.details,
              'details',
              <String, dynamic>{'metric': 'plots', 'limit': 2, 'used': 2},
            ),
      ),
    );
    expect(await harness.database.getOutbox(), isEmpty);
  });

  test('counts plots from every farm and ignores deleted ones', () async {
    final Harness harness = buildHarness(plotLimit: () => 2);
    addTearDown(harness.close);
    await harness.database.upsertFarm('farm-1', 'Ferme 1');
    await harness.database.upsertFarm('farm-2', 'Ferme 2');
    await harness.database.upsertPlot('plot-1', 'farm-1', 'Nord');
    await harness.database.upsertPlot('plot-2', 'farm-2', 'Sud');
    await harness.database.softDeletePlot('plot-2');

    await harness.repository.createPlot('farm-1', 'plot-3', 'Est', areaHa: 1);

    expect(await harness.database.getOutbox(), hasLength(1));
    expect((await harness.database.getPlot('plot-3'))?.deletedAt, isNull);
  });
}
