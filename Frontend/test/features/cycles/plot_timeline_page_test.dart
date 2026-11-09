import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartagri/core/database/app_database.dart';

import 'cycles_test_app.dart';

void main() {
  testWidgets('groups the timeline by month in descending order', (
    WidgetTester tester,
  ) async {
    await pumpCyclesApp(
      tester,
      initialLocation: '/plots/plot-1/timeline',
      seed: (AppDatabase database) async {
        await seedFarmAndPlot(database);
        await seedCycle(database, id: 'c1', cropId: 1);
        await seedCycle(database, id: 'c2', cropId: 2);
        await seedActivity(
          database,
          id: 'a1',
          cycleId: 'c1',
          performedOn: '2026-11-05',
        );
        await seedHarvest(
          database,
          id: 'h1',
          cycleId: 'c1',
          harvestedOn: '2026-11-20',
        );
        await seedActivity(
          database,
          id: 'a2',
          cycleId: 'c2',
          performedOn: '2026-10-10',
        );
      },
    );

    expect(find.byKey(const Key('timeline_month_2026_11')), findsOneWidget);
    expect(find.byKey(const Key('timeline_month_2026_10')), findsOneWidget);
    expect(find.text('novembre 2026'), findsOneWidget);
    expect(find.text('octobre 2026'), findsOneWidget);
    expect(find.text('Mil · Récolte'), findsOneWidget);
    expect(find.text('Mil · Fertilisation'), findsOneWidget);
    expect(find.text('Sorgho · Fertilisation'), findsOneWidget);

    final double harvestY = tester
        .getTopLeft(find.byKey(const Key('timeline_entry_h1')))
        .dy;
    final double activityY = tester
        .getTopLeft(find.byKey(const Key('timeline_entry_a1')))
        .dy;
    final double olderY = tester
        .getTopLeft(find.byKey(const Key('timeline_entry_a2')))
        .dy;
    expect(harvestY, lessThan(activityY));
    expect(activityY, lessThan(olderY));
  });

  testWidgets('opens the cycle detail from an entry', (
    WidgetTester tester,
  ) async {
    await pumpCyclesApp(
      tester,
      initialLocation: '/plots/plot-1/timeline',
      seed: (AppDatabase database) async {
        await seedFarmAndPlot(database);
        await seedCycle(database, id: 'c1');
        await seedActivity(database, id: 'a1', cycleId: 'c1');
      },
    );

    await tester.tap(find.byKey(const Key('timeline_entry_a1')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('cycle_detail_scroll')), findsOneWidget);
  });

  testWidgets('shows an empty state with the diagnostics hint', (
    WidgetTester tester,
  ) async {
    await pumpCyclesApp(
      tester,
      initialLocation: '/plots/plot-1/timeline',
      seed: (AppDatabase database) => seedFarmAndPlot(database),
    );

    expect(find.text('Aucun événement pour cette parcelle.'), findsOneWidget);
    expect(
      find.text("Les diagnostics sont dans l'onglet Diagnostics."),
      findsOneWidget,
    );
  });
}
