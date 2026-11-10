import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:smartagri/features/farms/domain/farm.dart';
import 'package:smartagri/features/farms/domain/plot.dart';
import 'package:smartagri/features/farms/domain/plot_geometry.dart';

import 'farms_test_app.dart';
import 'farms_test_data.dart';

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
  testWidgets('shows the plot information and the sections', (
    WidgetTester tester,
  ) async {
    await pumpPlotDetail(tester);

    expect(find.text('Parcelle nord'), findsOneWidget);
    expect(find.text('2,5 ha'), findsOneWidget);
    expect(find.text('Type de sol : Limoneux'), findsOneWidget);
    expect(find.text('Irrigation : Goutte-à-goutte'), findsOneWidget);
    expect(find.text('Cycles de culture'), findsOneWidget);
    expect(
      find.text(
        'Aucun cycle pour cette parcelle. Ajoutez votre première culture.',
      ),
      findsOneWidget,
    );
    expect(find.text("Voir l'historique de la parcelle"), findsOneWidget);
    expect(find.text('Diagnostics'), findsOneWidget);
    expect(find.text('Disponible prochainement'), findsOneWidget);
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
    expect((await harness.database.getPlot('plot-1'))?.deletedAt, isNull);

    await tester.tap(find.byKey(const Key('plot_actions')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Supprimer'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('plot_delete_confirm')));
    await tester.pumpAndSettle();

    expect((await harness.database.getPlot('plot-1'))?.deletedAt, isNotNull);
  });

  testWidgets('shows the map only when a geometry exists', (
    WidgetTester tester,
  ) async {
    final PlotGeometry geometry = PlotGeometry(<LatLng>[
      const LatLng(13.5, 2.1),
      const LatLng(13.5, 2.2),
      const LatLng(13.6, 2.2),
    ]);
    await pumpFarmsApp(
      tester,
      initialLocation: '/plots/plot-1',
      farms: <Farm>[sampleFarm()],
      plots: <String, List<Plot>>{
        'farm-1': <Plot>[samplePlot(geometry: geometry)],
      },
    );

    expect(find.byKey(const Key('plot_detail_map')), findsOneWidget);
    expect(find.byKey(const Key('map_attribution')), findsOneWidget);
  });

  testWidgets('hides the map without a geometry', (WidgetTester tester) async {
    await pumpPlotDetail(tester);

    expect(find.byKey(const Key('plot_detail_map')), findsNothing);
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
