import 'dart:io';

import 'package:drift/native.dart';
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

  test('stores cycles with a server timestamp and text dates', () async {
    final DateTime serverAt = DateTime.utc(2026, 11, 8, 23, 59);
    await database.upsertCycle(
      'c1',
      'p1',
      3,
      variety: 'Mil hâtif',
      season: 'rainy',
      sowingDate: '2026-11-08',
      expectedHarvestDate: '2027-02-06',
      status: 'growing',
      notes: 'Note',
      updatedAt: serverAt,
    );

    final CropCycleRow? row = await database.getCycle('c1');
    expect(row?.plotId, 'p1');
    expect(row?.cropId, 3);
    expect(row?.variety, 'Mil hâtif');
    expect(row?.sowingDate, '2026-11-08');
    expect(row?.expectedHarvestDate, '2027-02-06');
    expect(row?.status, 'growing');
    expect(row?.updatedAt?.toUtc(), serverAt);
    expect(await database.hasServerVersion('crop_cycle', 'c1'), isTrue);
  });

  test('keeps omitted fields when upserting a cycle', () async {
    await database.upsertCycle(
      'c1',
      'p1',
      3,
      variety: 'Mil',
      season: 'rainy',
      sowingDate: '2026-05-01',
      notes: 'Ancienne note',
    );

    await database.upsertCycle('c1', 'p1', 4);

    final CropCycleRow? row = await database.getCycle('c1');
    expect(row?.cropId, 4);
    expect(row?.variety, 'Mil');
    expect(row?.season, 'rainy');
    expect(row?.sowingDate, '2026-05-01');
    expect(row?.notes, 'Ancienne note');
    expect(row?.status, 'planned');
  });

  test('keeps omitted fields when upserting an activity', () async {
    await database.upsertActivity(
      'a1',
      'c1',
      'fertilizing',
      '2026-05-02',
      productName: 'Urée',
      quantity: 12.5,
      unit: 'kg',
      costXof: 5000,
      notes: 'Note',
    );

    await database.upsertActivity('a1', 'c1', 'weeding', '2026-05-03');

    final FarmActivityRow? row = await database.getActivity('a1');
    expect(row?.type, 'weeding');
    expect(row?.performedOn, '2026-05-03');
    expect(row?.productName, 'Urée');
    expect(row?.quantity, 12.5);
    expect(row?.unit, 'kg');
    expect(row?.costXof, 5000);
    expect(row?.notes, 'Note');
  });

  test('keeps omitted fields when upserting a harvest', () async {
    await database.upsertHarvest(
      'h1',
      'c1',
      '2026-09-01',
      100,
      quality: 'A',
      soldKg: 60,
      avgPriceXofPerKg: 250,
    );

    await database.upsertHarvest('h1', 'c1', '2026-09-02', 120);

    final HarvestRow? row = await database.getHarvest('h1');
    expect(row?.harvestedOn, '2026-09-02');
    expect(row?.quantityKg, 120);
    expect(row?.quality, 'A');
    expect(row?.soldKg, 60);
    expect(row?.avgPriceXofPerKg, 250);
  });

  test('watches activities and harvests in reverse date order', () async {
    await database.upsertActivity('a1', 'c1', 'sowing', '2026-05-01');
    await database.upsertActivity('a2', 'c1', 'weeding', '2026-05-03');
    await database.upsertActivity('a3', 'c1', 'irrigation', '2026-05-02');
    await database.upsertHarvest('h1', 'c1', '2026-09-01', 10);
    await database.upsertHarvest('h2', 'c1', '2026-09-05', 20);

    expect(
      (await database.watchActivities('c1').first).map(
        (FarmActivityRow row) => row.id,
      ),
      <String>['a2', 'a3', 'a1'],
    );
    expect(
      (await database.watchHarvests('c1').first).map(
        (HarvestRow row) => row.id,
      ),
      <String>['h2', 'h1'],
    );
  });

  test(
    'soft deleting a cycle cascades to its activities and harvests',
    () async {
      await database.upsertCycle('c1', 'p1', 1);
      await database.upsertActivity('a1', 'c1', 'sowing', '2026-05-01');
      await database.upsertHarvest('h1', 'c1', '2026-09-01', 10);

      await database.softDeleteCycle('c1');

      expect(await database.watchCycle('c1').first, isNull);
      expect(await database.watchActivities('c1').first, isEmpty);
      expect(await database.watchHarvests('c1').first, isEmpty);
      expect((await database.getActivity('a1'))?.deletedAt, isNotNull);
      expect((await database.getHarvest('h1'))?.deletedAt, isNotNull);
    },
  );

  test('soft deleting a plot cascades to its cycles and children', () async {
    await database.upsertPlot('p1', 'f1', 'Parcelle');
    await database.upsertCycle('c1', 'p1', 1);
    await database.upsertCycle('c2', 'p1', 2);
    await database.upsertActivity('a1', 'c1', 'sowing', '2026-05-01');
    await database.upsertHarvest('h1', 'c2', '2026-09-01', 10);

    await database.softDeletePlot('p1');

    expect((await database.getPlot('p1'))?.deletedAt, isNotNull);
    expect((await database.getCycle('c1'))?.deletedAt, isNotNull);
    expect((await database.getCycle('c2'))?.deletedAt, isNotNull);
    expect((await database.getActivity('a1'))?.deletedAt, isNotNull);
    expect((await database.getHarvest('h1'))?.deletedAt, isNotNull);
  });

  test('soft deleting a farm cascades to plots cycles and children', () async {
    await database.upsertFarm('f1', 'Ferme');
    await database.upsertPlot('p1', 'f1', 'Parcelle');
    await database.upsertCycle('c1', 'p1', 1);
    await database.upsertActivity('a1', 'c1', 'sowing', '2026-05-01');
    await database.upsertHarvest('h1', 'c1', '2026-09-01', 10);

    await database.softDeleteFarm('f1');

    expect((await database.getFarm('f1'))?.deletedAt, isNotNull);
    expect((await database.getPlot('p1'))?.deletedAt, isNotNull);
    expect((await database.getCycle('c1'))?.deletedAt, isNotNull);
    expect((await database.getActivity('a1'))?.deletedAt, isNotNull);
    expect((await database.getHarvest('h1'))?.deletedAt, isNotNull);
  });

  test('wipeAll clears the cycle activity and harvest tables', () async {
    await database.upsertCycle('c1', 'p1', 1);
    await database.upsertActivity('a1', 'c1', 'sowing', '2026-05-01');
    await database.upsertHarvest('h1', 'c1', '2026-09-01', 10);

    await database.wipeAll();

    expect(await database.getCycle('c1'), isNull);
    expect(await database.getActivity('a1'), isNull);
    expect(await database.getHarvest('h1'), isNull);
  });

  test(
    'orders the outbox with the five entities and inverse deletes',
    () async {
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
      await add('harvest', 'harvest-upsert', 'upsert');
      await add('plot', 'plot-upsert', 'upsert');
      await add('farm_activity', 'activity-delete', 'delete');
      await add('crop_cycle', 'cycle-upsert', 'upsert');
      await add('farm', 'farm-upsert', 'upsert');
      await add('plot', 'plot-delete', 'delete');
      await add('crop_cycle', 'cycle-delete', 'delete');
      await add('farm_activity', 'activity-upsert', 'upsert');
      await add('harvest', 'harvest-delete', 'delete');

      final List<PendingChangeRow> rows = await database.getOutbox();

      expect(rows.map((PendingChangeRow row) => row.id), <String>[
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
    },
  );

  test('migrates a version 2 database to schema 3', () async {
    final Directory directory = await Directory.systemTemp.createTemp(
      'smartagri_migration_v2',
    );
    addTearDown(() => directory.delete(recursive: true));
    final File file = File('${directory.path}/smartagri.sqlite');

    final AppDatabase version2 = AppDatabase.forTesting(NativeDatabase(file));
    await version2.customStatement('DROP TABLE crop_cycles');
    await version2.customStatement('DROP TABLE farm_activities');
    await version2.customStatement('DROP TABLE harvests');
    await version2.customStatement('PRAGMA user_version = 2');
    await version2.writeMeta('cursor_history', 'ancien-curseur');
    await version2.upsertFarm('f1', 'Ferme');
    await version2.close();

    final AppDatabase migrated = AppDatabase.forTesting(NativeDatabase(file));
    addTearDown(migrated.close);

    final rows = await migrated
        .customSelect("SELECT name FROM sqlite_master WHERE type = 'table'")
        .get();
    final List<String> tables = rows
        .map((row) => row.read<String>('name'))
        .toList();
    for (final String table in <String>[
      'crop_cycles',
      'farm_activities',
      'harvests',
    ]) {
      expect(tables, contains(table));
    }
    expect(await migrated.readMeta('cursor_history'), isNull);
    expect((await migrated.getFarm('f1'))?.name, 'Ferme');
  });
}
