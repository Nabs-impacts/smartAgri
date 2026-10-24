import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartagri/features/farms/domain/farm.dart';
import 'package:smartagri/features/farms/domain/plot.dart';

import 'fake_farms_repository.dart';
import 'farms_test_app.dart';

Future<FarmsHarness> pumpPlotDetail(WidgetTester tester) {
  return pumpFarmsApp(
    tester,
    initialLocation: '/plots/plot-1',
    farms: <Farm>[sampleFarm()],
    plots: <String, List<Plot>>{
      'farm-1': <Plot>[samplePlot()],
    },
  );
}

void main() {
  testWidgets('shows the plot information and the coming soon sections', (
    WidgetTester tester,
  ) async {
    await pumpPlotDetail(tester);

    expect(find.text('Parcelle nord'), findsOneWidget);
    expect(find.text('2,5 ha'), findsOneWidget);
    expect(find.text('Type de sol : Limoneux'), findsOneWidget);
    expect(find.text('Irrigation : Goutte-à-goutte'), findsOneWidget);
    expect(find.text('Cycles de culture'), findsOneWidget);
    expect(find.text('Diagnostics'), findsOneWidget);
    expect(find.text('Disponible prochainement'), findsNWidgets(2));
  });

  testWidgets('deletes the plot after confirmation', (
    WidgetTester tester,
  ) async {
    final FarmsHarness harness = await pumpPlotDetail(tester);

    await tester.tap(find.byKey(const Key('plot_actions')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Supprimer'));
    await tester.pumpAndSettle();

    expect(
      find.text('Voulez-vous vraiment supprimer cette parcelle ?'),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const Key('plot_delete_cancel')));
    await tester.pumpAndSettle();
    expect(harness.farms.plots['farm-1'], hasLength(1));

    await tester.tap(find.byKey(const Key('plot_actions')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Supprimer'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('plot_delete_confirm')));
    await tester.pumpAndSettle();

    expect(harness.farms.plots['farm-1'], isEmpty);
  });

  testWidgets('opens the edit form', (WidgetTester tester) async {
    await pumpPlotDetail(tester);

    await tester.tap(find.byKey(const Key('plot_actions')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Modifier'));
    await tester.pumpAndSettle();

    expect(find.text('Modifier la parcelle'), findsOneWidget);
    expect(find.text('Parcelle nord'), findsWidgets);
  });
}
