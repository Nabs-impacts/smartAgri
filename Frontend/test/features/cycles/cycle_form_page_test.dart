import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartagri/core/database/app_database.dart';
import 'package:smartagri/features/cycles/domain/cycle_status.dart';

import 'cycles_test_app.dart';

void main() {
  testWidgets('requires a crop on creation', (WidgetTester tester) async {
    final CyclesHarness harness = await pumpCyclesApp(
      tester,
      initialLocation: '/plots/plot-1/cycles/new',
      seed: (AppDatabase database) => seedFarmAndPlot(database),
    );

    await tester.tap(find.byKey(const Key('cycle_save')));
    await tester.pumpAndSettle();

    expect(find.text('Choisissez une culture.'), findsOneWidget);
    expect(await harness.database.getActiveCycles('plot-1'), isEmpty);
  });

  testWidgets('rejects an expected harvest before the sowing date', (
    WidgetTester tester,
  ) async {
    await pumpCyclesApp(
      tester,
      initialLocation: '/cycles/c1/edit',
      seed: (AppDatabase database) async {
        await seedFarmAndPlot(database);
        await seedCycle(
          database,
          sowingDate: '2026-11-10',
          expectedHarvestDate: '2026-11-01',
        );
      },
    );

    await tester.tap(find.byKey(const Key('cycle_save')));
    await tester.pumpAndSettle();

    expect(
      find.text('La date de récolte prévue ne peut pas précéder le semis.'),
      findsOneWidget,
    );
  });

  testWidgets('creates a cycle with the chosen crop, status and a UUID', (
    WidgetTester tester,
  ) async {
    final CyclesHarness harness = await pumpCyclesApp(
      tester,
      initialLocation: '/plots/plot-1/cycles/new',
      seed: (AppDatabase database) => seedFarmAndPlot(database),
    );

    await tester.tap(find.byKey(const Key('cycle_crop_field')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Mil'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('cycle_variety_field')),
      'Locale',
    );
    await tester.enterText(
      find.byKey(const Key('cycle_season_field')),
      'Saison sèche',
    );
    await tester.tap(find.text('En cours'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('cycle_save')));
    await tester.pumpAndSettle();

    final List<CropCycleRow> rows = await harness.database.getActiveCycles(
      'plot-1',
    );
    expect(rows, hasLength(1));
    expect(rows.single.cropId, 1);
    expect(rows.single.status, CycleStatus.growing.code);
    expect(rows.single.variety, 'Locale');
    expect(rows.single.season, 'Saison sèche');
    expect(
      rows.single.id,
      matches(
        RegExp(
          r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
        ),
      ),
    );
  });

  testWidgets('updates a cycle without changing its crop or status', (
    WidgetTester tester,
  ) async {
    final CyclesHarness harness = await pumpCyclesApp(
      tester,
      initialLocation: '/cycles/c1/edit',
      seed: (AppDatabase database) async {
        await seedFarmAndPlot(database);
        await seedCycle(
          database,
          status: 'growing',
          cropId: 1,
          variety: 'Ancienne',
        );
      },
    );

    await tester.enterText(
      find.byKey(const Key('cycle_variety_field')),
      'Nouvelle',
    );
    await tester.tap(find.byKey(const Key('cycle_save')));
    await tester.pumpAndSettle();

    final CropCycleRow? row = await harness.database.getCycle('c1');
    expect(row?.cropId, 1);
    expect(row?.status, CycleStatus.growing.code);
    expect(row?.variety, 'Nouvelle');
  });
}
