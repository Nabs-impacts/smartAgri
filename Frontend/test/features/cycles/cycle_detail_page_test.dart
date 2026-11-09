import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartagri/core/database/app_database.dart';
import 'package:smartagri/design_system/tokens.dart';
import 'package:smartagri/features/cycles/domain/cycle_exception.dart';
import 'package:smartagri/features/cycles/domain/cycle_summary.dart';
import 'package:smartagri/features/cycles/presentation/cycle_format.dart';

import 'cycles_test_app.dart';

void main() {
  testWidgets('shows the actions allowed for a planned cycle', (
    WidgetTester tester,
  ) async {
    await pumpCyclesApp(
      tester,
      initialLocation: '/cycles/c1',
      seed: (AppDatabase database) async {
        await seedFarmAndPlot(database);
        await seedCycle(database, status: 'planned');
      },
    );

    expect(find.byKey(const Key('cycle_start')), findsOneWidget);
    expect(find.byKey(const Key('cycle_fail')), findsNothing);
    expect(find.byKey(const Key('cycle_add_harvest')), findsOneWidget);
    expect(find.byKey(const Key('cycle_add_activity')), findsOneWidget);
  });

  testWidgets('shows the actions allowed for a growing cycle', (
    WidgetTester tester,
  ) async {
    await pumpCyclesApp(
      tester,
      initialLocation: '/cycles/c1',
      seed: (AppDatabase database) async {
        await seedFarmAndPlot(database);
        await seedCycle(database, status: 'growing');
      },
    );

    expect(find.byKey(const Key('cycle_start')), findsNothing);
    expect(find.byKey(const Key('cycle_fail')), findsOneWidget);
    expect(find.byKey(const Key('cycle_add_harvest')), findsOneWidget);
    expect(find.byKey(const Key('cycle_add_activity')), findsOneWidget);
  });

  testWidgets('only keeps the activity action for a harvested cycle', (
    WidgetTester tester,
  ) async {
    await pumpCyclesApp(
      tester,
      initialLocation: '/cycles/c1',
      seed: (AppDatabase database) async {
        await seedFarmAndPlot(database);
        await seedCycle(database, status: 'harvested');
      },
    );

    expect(find.byKey(const Key('cycle_start')), findsNothing);
    expect(find.byKey(const Key('cycle_fail')), findsNothing);
    expect(find.byKey(const Key('cycle_add_harvest')), findsNothing);
    expect(find.byKey(const Key('cycle_add_activity')), findsOneWidget);
  });

  testWidgets('declares a failure after confirmation', (
    WidgetTester tester,
  ) async {
    final CyclesHarness harness = await pumpCyclesApp(
      tester,
      initialLocation: '/cycles/c1',
      seed: (AppDatabase database) async {
        await seedFarmAndPlot(database);
        await seedCycle(database, status: 'growing');
      },
    );

    await tester.tap(find.byKey(const Key('cycle_fail')));
    await tester.pumpAndSettle();
    expect(find.text('Déclarer un échec ?'), findsOneWidget);

    await tester.tap(find.byKey(const Key('cycle_fail_confirm')));
    await tester.pumpAndSettle();

    expect((await harness.database.getCycle('c1'))?.status, 'failed');
  });

  testWidgets('deletes a cycle after confirmation', (
    WidgetTester tester,
  ) async {
    final CyclesHarness harness = await pumpCyclesApp(
      tester,
      initialLocation: '/cycles/c1',
      seed: (AppDatabase database) async {
        await seedFarmAndPlot(database);
        await seedCycle(database);
      },
    );

    await tester.tap(find.byKey(const Key('cycle_actions')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Supprimer'));
    await tester.pumpAndSettle();
    expect(
      find.text(
        'Les activités et récoltes de ce cycle seront aussi supprimées.',
      ),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const Key('cycle_delete_confirm')));
    await tester.pumpAndSettle();

    expect((await harness.database.getCycle('c1'))?.deletedAt, isNotNull);
  });

  testWidgets('shows a cycle domain exception as a snackbar', (
    WidgetTester tester,
  ) async {
    await pumpCyclesApp(
      tester,
      initialLocation: '/cycles/c1',
      updateError: const CycleDomainException(
        'invalid_transition',
        'Transition de statut non autorisée.',
      ),
      seed: (AppDatabase database) async {
        await seedFarmAndPlot(database);
        await seedCycle(database);
      },
    );

    await tester.tap(find.byKey(const Key('cycle_start')));
    await tester.pumpAndSettle();

    expect(find.text('Transition de statut non autorisée.'), findsOneWidget);
  });

  testWidgets('shows a not found state for a missing cycle', (
    WidgetTester tester,
  ) async {
    await pumpCyclesApp(tester, initialLocation: '/cycles/missing');

    expect(find.byKey(const Key('cycle_not_found')), findsOneWidget);
    expect(find.text('Cycle introuvable.'), findsOneWidget);
    expect(find.byKey(const Key('cycle_not_found_back')), findsOneWidget);
  });

  testWidgets('computes the summary from the plot, activities and harvests', (
    WidgetTester tester,
  ) async {
    await pumpCyclesApp(
      tester,
      initialLocation: '/cycles/c1',
      seed: (AppDatabase database) async {
        await seedFarmAndPlot(database);
        await seedCycle(database, status: 'growing');
        await seedActivity(database, costXof: 5000);
        await seedHarvest(database);
      },
    );

    expect(find.text(formatAreaHaForTest(2.5)), findsOneWidget);
    expect(find.text(formatKg(100)), findsWidgets);
    expect(find.text(formatKgPerHa(40)), findsOneWidget);
    expect(find.text(formatXof(5000)), findsOneWidget);
    expect(find.text(formatXof(20000)), findsOneWidget);
    expect(find.text(formatXof(15000)), findsOneWidget);
    expect(find.text('Calculé sur votre téléphone'), findsOneWidget);
  });

  testWidgets('shows a negative margin in the danger color', (
    WidgetTester tester,
  ) async {
    await pumpCyclesApp(
      tester,
      initialLocation: '/cycles/c1',
      seed: (AppDatabase database) async {
        await seedFarmAndPlot(database);
        await seedCycle(database, status: 'growing');
        await seedActivity(database, costXof: 5000);
      },
    );

    final Text margin = tester.widget<Text>(
      find.byKey(const Key('summary_margin')),
    );
    expect(margin.data, formatXof(-5000));
    expect(margin.style?.color, AppColors.danger);
  });

  testWidgets('shows dashes when the plot has no area', (
    WidgetTester tester,
  ) async {
    await pumpCyclesApp(
      tester,
      initialLocation: '/cycles/c1',
      seed: (AppDatabase database) async {
        final DateTime serverAt = DateTime.utc(2026, 11, 8, 9);
        await database.upsertFarm('farm-1', 'Ferme', updatedAt: serverAt);
        await database.upsertPlot(
          'plot-1',
          'farm-1',
          'Parcelle nord',
          updatedAt: serverAt,
        );
        await seedCycle(database, status: 'growing');
        await seedHarvest(database);
      },
    );

    expect(
      tester.widget<Text>(find.byKey(const Key('summary_area'))).data,
      '—',
    );
    expect(
      tester.widget<Text>(find.byKey(const Key('summary_yield'))).data,
      '—',
    );
  });

  testWidgets('updates the summary when a harvest is added', (
    WidgetTester tester,
  ) async {
    final CyclesHarness harness = await pumpCyclesApp(
      tester,
      initialLocation: '/cycles/c1',
      seed: (AppDatabase database) async {
        await seedFarmAndPlot(database);
        await seedCycle(database, status: 'growing');
      },
    );

    expect(
      tester.widget<Text>(find.byKey(const Key('summary_total_kg'))).data,
      formatKg(0),
    );

    await seedHarvest(harness.database);
    await tester.pumpAndSettle();

    expect(
      tester.widget<Text>(find.byKey(const Key('summary_total_kg'))).data,
      formatKg(100),
    );
  });

  testWidgets('shows the comparison only when a value is returned', (
    WidgetTester tester,
  ) async {
    final CyclesHarness harness = await pumpCyclesApp(
      tester,
      initialLocation: '/cycles/c1',
      comparison: const CycleComparison(
        sampleSize: 12,
        averageYieldKgPerHa: 55,
      ),
      seed: (AppDatabase database) async {
        await seedFarmAndPlot(database);
        await seedCycle(database, status: 'growing');
      },
    );

    expect(find.byKey(const Key('cycle_comparison')), findsOneWidget);
    expect(
      find.text(
        'Moyenne des autres agriculteurs : ${formatKgPerHa(55)} (12 cycles)',
      ),
      findsOneWidget,
    );
    expect(harness.repository.comparisonCalls, 1);
  });

  testWidgets('never shows an error when the comparison fails', (
    WidgetTester tester,
  ) async {
    final CyclesHarness harness = await pumpCyclesApp(
      tester,
      initialLocation: '/cycles/c1',
      comparisonError: Exception('boom'),
      seed: (AppDatabase database) async {
        await seedFarmAndPlot(database);
        await seedCycle(database, status: 'growing');
      },
    );

    expect(find.byKey(const Key('cycle_comparison')), findsNothing);
    expect(find.textContaining('boom'), findsNothing);
    expect(harness.repository.comparisonCalls, 1);
  });
}

String formatAreaHaForTest(double value) {
  return '${value.toString().replaceAll('.', ',')} ha';
}
