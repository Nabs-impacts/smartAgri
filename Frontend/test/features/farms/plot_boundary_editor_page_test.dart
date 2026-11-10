import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:smartagri/core/location/location_service.dart';
import 'package:smartagri/features/farms/domain/plot_geometry.dart';

import '../../core/location/fake_location_service.dart';
import 'farms_test_app.dart';

void main() {
  testWidgets('adds a vertex from the current position', (
    WidgetTester tester,
  ) async {
    final FakeLocationService location = FakeLocationService(
      result: const LocationResult.success(
        LocationPosition(latitude: 13.5, longitude: 2.1, accuracyMeters: 8),
      ),
    );
    await pumpFarmsApp(
      tester,
      initialLocation: '/plots/boundary',
      locationService: location,
    );

    await tester.tap(find.byKey(const Key('boundary_add_position')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('location_explanation_continue')), findsOne);

    await tester.tap(find.byKey(const Key('location_explanation_continue')));
    await tester.pumpAndSettle();

    expect(location.positionCalls, 1);
    expect(find.text('1 sommet'), findsOneWidget);
    expect(find.byKey(const Key('boundary_accuracy')), findsOneWidget);
    expect(find.text('Précision : 8 m'), findsOneWidget);
  });

  testWidgets('builds a valid trace from positions and closes it', (
    WidgetTester tester,
  ) async {
    final FakeLocationService location = FakeLocationService(
      results: <LocationResult>[
        LocationResult.success(
          LocationPosition(latitude: 13.5, longitude: 2.1, accuracyMeters: 8),
        ),
        LocationResult.success(
          LocationPosition(latitude: 13.5, longitude: 2.101, accuracyMeters: 8),
        ),
        LocationResult.success(
          LocationPosition(
            latitude: 13.501,
            longitude: 2.101,
            accuracyMeters: 8,
          ),
        ),
      ],
    );
    await pumpFarmsApp(
      tester,
      initialLocation: '/plots/boundary',
      locationService: location,
    );

    await tester.tap(find.byKey(const Key('boundary_add_position')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('location_explanation_continue')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('boundary_add_position')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('boundary_add_position')));
    await tester.pumpAndSettle();

    expect(find.text('3 sommets'), findsOneWidget);
    expect(find.text('Tracé valide.'), findsOneWidget);
    expect(find.byKey(const Key('boundary_area')), findsOneWidget);

    await tester.tap(find.byKey(const Key('boundary_finish')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('boundary_map')), findsNothing);
  });

  testWidgets('shows a complex trace in read-only mode', (
    WidgetTester tester,
  ) async {
    final FarmsHarness harness = await pumpFarmsApp(tester);
    final PlotGeometry geometry = PlotGeometry(
      <LatLng>[
        const LatLng(13.4, 2.0),
        const LatLng(13.4, 2.4),
        const LatLng(13.8, 2.4),
        const LatLng(13.8, 2.0),
      ],
      holes: <List<LatLng>>[
        <LatLng>[
          const LatLng(13.5, 2.1),
          const LatLng(13.5, 2.2),
          const LatLng(13.6, 2.2),
        ],
      ],
    );

    harness.router.push('/plots/boundary', extra: geometry);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('boundary_read_only')), findsOneWidget);
    expect(find.byKey(const Key('boundary_read_only_close')), findsOneWidget);
    expect(find.byKey(const Key('boundary_add_position')), findsNothing);
    expect(find.byKey(const Key('boundary_finish')), findsNothing);
  });

  testWidgets('does not add a vertex when permission is denied', (
    WidgetTester tester,
  ) async {
    final FakeLocationService location = FakeLocationService(
      result: const LocationResult.failure(
        LocationOutcomeStatus.permissionDeniedForever,
      ),
    );
    await pumpFarmsApp(
      tester,
      initialLocation: '/plots/boundary',
      locationService: location,
    );

    await tester.tap(find.byKey(const Key('boundary_add_position')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('location_explanation_continue')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('boundary_location_error')), findsOneWidget);
    expect(find.byKey(const Key('boundary_open_settings')), findsOneWidget);
    expect(find.text('Aucun sommet'), findsOneWidget);

    await tester.tap(find.byKey(const Key('boundary_open_settings')));
    await tester.pumpAndSettle();

    expect(location.settingsCalls, 1);
  });
}
