import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartagri/core/database/app_database.dart';

import 'cycles_test_app.dart';

void main() {
  testWidgets('lists the cycles with culture, status and dates', (
    WidgetTester tester,
  ) async {
    await pumpCyclesApp(
      tester,
      seed: (AppDatabase database) async {
        await seedFarmAndPlot(database);
        await seedCycle(
          database,
          id: 'c1',
          cropId: 1,
          status: 'planned',
          variety: 'Variété locale',
        );
        await seedCycle(
          database,
          id: 'c2',
          cropId: 2,
          status: 'growing',
          variety: 'Sorgho rouge',
          sowingDate: '2026-07-15',
          expectedHarvestDate: '2026-11-15',
        );
      },
    );

    expect(find.byKey(const Key('cycle_card_c1')), findsOneWidget);
    expect(find.byKey(const Key('cycle_card_c2')), findsOneWidget);
    expect(find.text('Mil'), findsOneWidget);
    expect(find.text('Sorgho'), findsOneWidget);
    expect(find.text('Variété locale'), findsOneWidget);
    expect(find.text('Sorgho rouge'), findsOneWidget);
    expect(find.text('Prévu'), findsOneWidget);
    expect(find.text('En cours'), findsOneWidget);
    expect(find.text('Semis : 1 juin 2026'), findsOneWidget);
    expect(find.text('Récolte prévue : 1 octobre 2026'), findsOneWidget);
  });

  testWidgets('shows an empty state when the plot has no cycle', (
    WidgetTester tester,
  ) async {
    await pumpCyclesApp(
      tester,
      seed: (AppDatabase database) => seedFarmAndPlot(database),
    );

    expect(find.byKey(const Key('plot_cycles_empty')), findsOneWidget);
    expect(
      find.text(
        'Aucun cycle pour cette parcelle. Ajoutez votre première culture.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('opens the cycle detail, the form and the timeline', (
    WidgetTester tester,
  ) async {
    final CyclesHarness harness = await pumpCyclesApp(
      tester,
      seed: (AppDatabase database) async {
        await seedFarmAndPlot(database);
        await seedCycle(database);
      },
    );

    await tester.tap(find.byKey(const Key('cycle_card_c1')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('cycle_detail_scroll')), findsOneWidget);

    harness.router.go('/plots/plot-1');
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('plot_add_cycle')));
    await tester.pumpAndSettle();
    expect(find.text('Nouveau cycle'), findsOneWidget);

    harness.router.go('/plots/plot-1');
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('plot_timeline_link')));
    await tester.pumpAndSettle();
    expect(find.text('Historique de la parcelle'), findsOneWidget);
  });
}
