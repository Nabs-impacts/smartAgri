import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartagri/features/farms/domain/farm.dart';
import 'package:smartagri/features/farms/domain/plot.dart';
import 'package:smartagri/features/farms/presentation/farms_page.dart';
import 'package:smartagri/features/farms/presentation/plot_form_page.dart';

import 'fake_farms_repository.dart';
import 'farms_test_app.dart';

void main() {
  testWidgets('shows the farm information and its plots', (
    WidgetTester tester,
  ) async {
    await pumpFarmsApp(
      tester,
      initialLocation: '/farms/farm-1',
      farms: <Farm>[sampleFarm()],
      plots: <String, List<Plot>>{
        'farm-1': <Plot>[samplePlot()],
      },
    );

    expect(find.text('Ferme du fleuve'), findsWidgets);
    expect(find.text('Saga'), findsOneWidget);
    expect(find.text('Niamey'), findsOneWidget);
    expect(find.text('Parcelle nord'), findsOneWidget);
    expect(find.text('2,5 ha · Limoneux · Goutte-à-goutte'), findsOneWidget);
  });

  testWidgets('opens the plot creation form', (WidgetTester tester) async {
    await pumpFarmsApp(
      tester,
      initialLocation: '/farms/farm-1',
      farms: <Farm>[sampleFarm()],
    );

    await tester.tap(find.byKey(const Key('farm_add_plot')));
    await tester.pumpAndSettle();

    expect(find.byType(PlotFormPage), findsOneWidget);
  });

  testWidgets('deletes the farm after confirmation', (
    WidgetTester tester,
  ) async {
    final FarmsHarness harness = await pumpFarmsApp(
      tester,
      initialLocation: '/farms/farm-1',
      farms: <Farm>[sampleFarm()],
    );

    await tester.tap(find.byKey(const Key('farm_actions')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Supprimer'));
    await tester.pumpAndSettle();

    expect(
      find.text(
        'Cette action supprimera aussi toutes les parcelles associées.',
      ),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const Key('farm_delete_cancel')));
    await tester.pumpAndSettle();
    expect(harness.farms.farms, hasLength(1));

    await tester.tap(find.byKey(const Key('farm_actions')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Supprimer'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('farm_delete_confirm')));
    await tester.pumpAndSettle();

    expect(harness.farms.farms, isEmpty);
    expect(find.byType(FarmsPage), findsOneWidget);
  });
}
