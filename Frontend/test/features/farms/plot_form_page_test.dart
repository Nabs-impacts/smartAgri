import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:smartagri/core/database/app_database.dart';
import 'package:smartagri/core/location/location_service.dart';
import 'package:smartagri/features/farms/domain/farm.dart';
import 'package:smartagri/features/farms/domain/plot.dart';
import 'package:smartagri/features/farms/domain/plot_geometry.dart';
import 'package:smartagri/features/profile/data/me_repository.dart';

import '../../core/location/fake_location_service.dart';
import '../app_test_utils.dart';
import 'farms_test_app.dart';
import 'farms_test_data.dart';

Future<void> enterName(WidgetTester tester, String value) async {
  await tester.enterText(find.byKey(const Key('plot_name_field')), value);
}

Future<void> enterArea(WidgetTester tester, String value) async {
  await tester.enterText(find.byKey(const Key('plot_area_field')), value);
}

Future<void> tapSave(WidgetTester tester) async {
  await tester.scrollUntilVisible(
    find.byKey(const Key('plot_save')),
    200,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.tap(find.byKey(const Key('plot_save')));
  await tester.pumpAndSettle();
}

Future<void> scrollUpTo(WidgetTester tester, Finder finder) async {
  await tester.scrollUntilVisible(
    finder,
    -200,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.pumpAndSettle();
}

Future<FarmsHarness> pumpPlotForm(
  WidgetTester tester, {
  FakeMeRepository? meRepository,
  List<Plot>? plots,
  LocationService? locationService,
}) async {
  await tester.binding.setSurfaceSize(const Size(900, 1600));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  return pumpFarmsApp(
    tester,
    initialLocation: '/farms/farm-1/plots/new',
    farms: <Farm>[sampleFarm()],
    plots: <String, List<Plot>>{'farm-1': plots ?? <Plot>[]},
    meRepository: meRepository,
    locationService: locationService,
  );
}

void main() {
  testWidgets('rejects 0 and 10000,5 and accepts 10000', (
    WidgetTester tester,
  ) async {
    final FarmsHarness harness = await pumpPlotForm(tester);
    await enterName(tester, 'Parcelle test');

    await enterArea(tester, '0');
    await tapSave(tester);
    await scrollUpTo(
      tester,
      find.text('La surface doit être supérieure à 0 et au plus 10000.'),
    );
    expect(
      find.text('La surface doit être supérieure à 0 et au plus 10000.'),
      findsOneWidget,
    );

    await enterArea(tester, '10000,5');
    await tapSave(tester);
    await scrollUpTo(
      tester,
      find.text('La surface doit être supérieure à 0 et au plus 10000.'),
    );
    expect(
      find.text('La surface doit être supérieure à 0 et au plus 10000.'),
      findsOneWidget,
    );

    await enterArea(tester, '10000');
    await tapSave(tester);

    final List<PendingChangeRow> outbox = await harness.database.getOutbox();
    final Map<String, dynamic> data =
        jsonDecode(outbox.single.payload) as Map<String, dynamic>;
    expect(data['area_ha'], 10000);
  });

  testWidgets('accepts a comma and sends the selected chips', (
    WidgetTester tester,
  ) async {
    final FarmsHarness harness = await pumpPlotForm(tester);
    await enterName(tester, 'Parcelle test');
    await enterArea(tester, '2,5');

    await tester.ensureVisible(find.text('Sableux'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sableux'));
    await tester.ensureVisible(find.text('Pluvial'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Pluvial'));
    await tester.pumpAndSettle();
    await tapSave(tester);

    final List<PendingChangeRow> outbox = await harness.database.getOutbox();
    final Map<String, dynamic> data =
        jsonDecode(outbox.single.payload) as Map<String, dynamic>;
    expect(data['area_ha'], 2.5);
    expect(data['soil_type'], 'sandy');
    expect(data['irrigation'], 'rainfed');
    expect(data['farm_id'], 'farm-1');
    expect(data['geom'], isNull);
  });

  testWidgets('accepts a decimal point', (WidgetTester tester) async {
    final FarmsHarness harness = await pumpPlotForm(tester);
    await enterName(tester, 'Parcelle test');
    await enterArea(tester, '3.25');
    await tapSave(tester);

    final List<PendingChangeRow> outbox = await harness.database.getOutbox();
    final Map<String, dynamic> data =
        jsonDecode(outbox.single.payload) as Map<String, dynamic>;
    expect(data['area_ha'], 3.25);
  });

  testWidgets('shows the plan limit when the local quota is reached', (
    WidgetTester tester,
  ) async {
    final FakeMeRepository me = FakeMeRepository(
      sampleMeData(
        quotas: const <Quota>[
          Quota(metric: 'plots', limit: 2, used: 2, remaining: 0),
        ],
      ),
    );
    final FarmsHarness harness = await pumpPlotForm(
      tester,
      meRepository: me,
      plots: <Plot>[
        samplePlot(id: 'plot-1'),
        samplePlot(id: 'plot-2', name: 'Parcelle sud'),
      ],
    );
    await harness.container.read(meProvider.future);
    await enterName(tester, 'Parcelle test');
    await enterArea(tester, '2');

    await tapSave(tester);
    await scrollUpTo(tester, find.byKey(const Key('plot_form_error')));

    expect(
      find.text('Vous avez atteint la limite de votre formule (2 parcelles).'),
      findsOneWidget,
    );
  });

  testWidgets('draws a boundary and saves the computed area', (
    WidgetTester tester,
  ) async {
    final FakeLocationService location = FakeLocationService(
      results: <LocationResult>[
        const LocationResult.success(
          LocationPosition(latitude: 13.5, longitude: 2.1, accuracyMeters: 8),
        ),
        const LocationResult.success(
          LocationPosition(latitude: 13.5, longitude: 2.101, accuracyMeters: 8),
        ),
        const LocationResult.success(
          LocationPosition(
            latitude: 13.501,
            longitude: 2.101,
            accuracyMeters: 8,
          ),
        ),
      ],
    );
    final FarmsHarness harness = await pumpPlotForm(
      tester,
      locationService: location,
    );
    await enterName(tester, 'Parcelle dessinée');

    await tester.scrollUntilVisible(
      find.byKey(const Key('plot_boundary_button')),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.byKey(const Key('plot_boundary_button')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('boundary_add_position')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('location_explanation_continue')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('boundary_add_position')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('boundary_add_position')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('boundary_finish')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('plot_calculated_area')), findsOneWidget);
    expect(find.byKey(const Key('plot_area_field')), findsNothing);

    await tapSave(tester);

    final List<PendingChangeRow> outbox = await harness.database.getOutbox();
    final Map<String, dynamic> data =
        jsonDecode(outbox.single.payload) as Map<String, dynamic>;
    expect(data['geom'], isNotNull);
    expect(data['area_ha'], isA<num>());
    expect((data['area_ha'] as num).toDouble(), greaterThan(0));
  });

  testWidgets('deletes an existing boundary and saves the manual area', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(900, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final PlotGeometry geometry = PlotGeometry(<LatLng>[
      const LatLng(13.5, 2.1),
      const LatLng(13.5, 2.101),
      const LatLng(13.501, 2.101),
    ]);
    final FarmsHarness harness = await pumpFarmsApp(
      tester,
      initialLocation: '/plots/plot-1/edit',
      farms: <Farm>[sampleFarm()],
      plots: <String, List<Plot>>{
        'farm-1': <Plot>[samplePlot(geometry: geometry)],
      },
    );

    await tester.scrollUntilVisible(
      find.byKey(const Key('plot_boundary_button')),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.byKey(const Key('plot_boundary_button')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('boundary_delete')));
    await tester.tap(find.byKey(const Key('boundary_delete')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('plot_area_field')), findsOneWidget);
    await tapSave(tester);

    final List<PendingChangeRow> outbox = await harness.database.getOutbox();
    final Map<String, dynamic> data =
        jsonDecode(outbox.single.payload) as Map<String, dynamic>;
    expect(data['geom'], isNull);
    expect(data['area_ha'], 2.5);
  });

  testWidgets('shows the map preview and the boundary button', (
    WidgetTester tester,
  ) async {
    await pumpPlotForm(tester);

    await tester.scrollUntilVisible(
      find.byKey(const Key('plot_boundary_button')),
      200,
      scrollable: find.byType(Scrollable).first,
    );

    expect(find.byKey(const Key('plot_map_preview')), findsOneWidget);
    expect(find.text('Tracer la parcelle'), findsOneWidget);
  });
}
