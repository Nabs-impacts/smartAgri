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

  Future<void> seedFarmPlotCycle({
    String farmId = 'farm-1',
    String plotId = 'plot-1',
    String cycleId = 'cycle-1',
    String status = 'growing',
    String? sowingDate,
    String? expectedHarvestDate,
  }) async {
    await database.upsertFarm(farmId, 'Ferme $farmId');
    await database.upsertPlot(plotId, farmId, 'Parcelle $plotId');
    await database.upsertCycle(
      cycleId,
      plotId,
      1,
      status: status,
      sowingDate: sowingDate,
      expectedHarvestDate: expectedHarvestDate,
    );
  }

  test(
    'active cycles filter status and order by next harvest then sowing',
    () async {
      await database.upsertFarm('farm-1', 'Ferme');
      await database.upsertPlot('plot-1', 'farm-1', 'Parcelle');
      await database.upsertCycle(
        'c1',
        'plot-1',
        1,
        sowingDate: '2026-01-01',
        expectedHarvestDate: '2026-03-01',
        status: 'growing',
      );
      await database.upsertCycle(
        'c2',
        'plot-1',
        2,
        sowingDate: '2025-12-01',
        expectedHarvestDate: '2026-02-01',
        status: 'planned',
      );
      await database.upsertCycle(
        'c3',
        'plot-1',
        3,
        sowingDate: '2026-02-01',
        status: 'growing',
      );
      await database.upsertCycle(
        'c4',
        'plot-1',
        4,
        sowingDate: '2026-03-01',
        status: 'planned',
      );
      await database.upsertCycle(
        'c5',
        'plot-1',
        5,
        sowingDate: '2026-01-01',
        expectedHarvestDate: '2026-01-15',
        status: 'harvested',
      );
      await database.upsertCycle(
        'c6',
        'plot-1',
        6,
        sowingDate: '2026-01-01',
        expectedHarvestDate: '2026-01-16',
        status: 'failed',
      );

      final List<ActiveCycleOverviewRow> rows = await database
          .watchActiveCycleOverview()
          .first;

      expect(rows.map((ActiveCycleOverviewRow row) => row.id), <String>[
        'c2',
        'c1',
        'c4',
        'c3',
      ]);
      expect(rows.first.plotName, 'Parcelle');
      expect(rows.first.farmName, 'Ferme');
    },
  );

  test('active cycles exclude deleted cycles plots and farms', () async {
    await seedFarmPlotCycle();
    expect(await database.watchActiveCycleOverview().first, hasLength(1));

    await database.softDeleteCycle('cycle-1');
    expect(await database.watchActiveCycleOverview().first, isEmpty);

    await seedFarmPlotCycle(
      farmId: 'farm-2',
      plotId: 'plot-2',
      cycleId: 'cycle-2',
    );
    await database.softDeletePlot('plot-2');
    expect(await database.watchActiveCycleOverview().first, isEmpty);

    await seedFarmPlotCycle(
      farmId: 'farm-3',
      plotId: 'plot-3',
      cycleId: 'cycle-3',
    );
    await database.softDeleteFarm('farm-3');
    expect(await database.watchActiveCycleOverview().first, isEmpty);
  });

  test('recent activities order limit and exclude deleted rows', () async {
    await database.upsertFarm('farm-1', 'Ferme');
    await database.upsertPlot('plot-1', 'farm-1', 'Parcelle');
    await database.upsertPlot('plot-2', 'farm-1', 'Parcelle supprimée');
    await database.upsertCycle('c1', 'plot-1', 1);
    await database.upsertCycle('c2', 'plot-2', 2);
    await database.upsertActivity('a1', 'c1', 'sowing', '2026-05-01');
    await database.upsertActivity('a2', 'c1', 'weeding', '2026-05-03');
    await database.upsertActivity('a3', 'c1', 'irrigation', '2026-05-02');
    await database.upsertActivity('a4', 'c1', 'other', '2026-05-03');
    await database.upsertActivity('a5', 'c1', 'harvest', '2026-05-04');
    await database.softDeleteActivity('a5');
    await database.upsertActivity('a6', 'c2', 'fertilizing', '2026-05-05');
    await database.softDeletePlot('plot-2');

    final List<RecentActivityOverviewRow> rows = await database
        .watchRecentActivities(3)
        .first;

    expect(rows.map((RecentActivityOverviewRow row) => row.id), <String>[
      'a4',
      'a2',
      'a3',
    ]);
    expect(rows.first.cropCycleId, 'c1');
    expect(rows.first.cropId, 1);
    expect(rows.first.type, 'other');
    expect(rows.first.performedOn, '2026-05-03');
    expect(rows.first.plotName, 'Parcelle');
  });

  test('has farms ignores deleted farms', () async {
    expect(await database.watchHasFarms().first, isFalse);

    await database.upsertFarm('farm-1', 'Ferme');
    expect(await database.watchHasFarms().first, isTrue);

    await database.softDeleteFarm('farm-1');
    expect(await database.watchHasFarms().first, isFalse);
  });
}
