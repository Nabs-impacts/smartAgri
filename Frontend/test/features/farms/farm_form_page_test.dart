import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:smartagri/core/database/app_database.dart';
import 'package:smartagri/core/location/location_service.dart';
import 'package:smartagri/features/farms/domain/farm.dart';
import 'package:smartagri/features/farms/domain/plot_geometry.dart';
import 'package:smartagri/features/farms/presentation/farm_form_page.dart';

import '../../core/location/fake_location_service.dart';
import 'farms_test_app.dart';
import 'farms_test_data.dart';

Future<void> fillName(WidgetTester tester, String value) async {
  await tester.enterText(find.byKey(const Key('farm_name_field')), value);
}

Future<void> tapSave(WidgetTester tester) async {
  await tester.ensureVisible(find.byKey(const Key('farm_save')));
  await tester.tap(find.byKey(const Key('farm_save')));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('validates the name length', (WidgetTester tester) async {
    await pumpFarmsApp(tester, initialLocation: '/farms/new');

    await tapSave(tester);
    expect(
      find.text('Le nom doit contenir entre 2 et 120 caractères.'),
      findsOneWidget,
    );

    await fillName(tester, 'A');
    await tapSave(tester);
    expect(
      find.text('Le nom doit contenir entre 2 et 120 caractères.'),
      findsOneWidget,
    );

    await fillName(tester, 'AB');
    await tapSave(tester);
    expect(
      find.text('Le nom doit contenir entre 2 et 120 caractères.'),
      findsNothing,
    );
  });

  testWidgets('creates the farm locally and enqueues an upsert', (
    WidgetTester tester,
  ) async {
    final FarmsHarness harness = await pumpFarmsApp(
      tester,
      initialLocation: '/farms/new',
    );
    await fillName(tester, 'Ferme test');

    await tester.tap(find.byKey(const Key('farm_region_field')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Niamey'));
    await tester.pumpAndSettle();

    await tapSave(tester);

    final List<PendingChangeRow> outbox = await harness.database.getOutbox();
    expect(outbox, hasLength(1));
    expect(outbox.single.entity, 'farm');
    expect(outbox.single.op, 'upsert');
    final FarmRow? row = await harness.database.getFarm(outbox.single.id);
    expect(row?.name, 'Ferme test');
    expect(row?.adminAreaId, 1);
    expect(row?.updatedAt, isNull);
    final Map<String, dynamic> data =
        jsonDecode(outbox.single.payload) as Map<String, dynamic>;
    expect(data['name'], 'Ferme test');
    expect(data['admin_area_id'], 1);
    expect(data['village'], isNull);
    expect(data['location'], isNull);
    expect(find.byType(FarmFormPage), findsNothing);
  });

  testWidgets('prefills the edit form and updates the farm locally', (
    WidgetTester tester,
  ) async {
    final FarmsHarness harness = await pumpFarmsApp(
      tester,
      initialLocation: '/farms/farm-1/edit',
      farms: <Farm>[sampleFarm(name: 'Ancienne')],
    );

    expect(find.text('Ancienne'), findsOneWidget);

    await fillName(tester, 'Nouvelle');
    await tapSave(tester);

    final FarmRow? row = await harness.database.getFarm('farm-1');
    expect(row?.name, 'Nouvelle');
    expect(row?.updatedAt?.toUtc(), DateTime.utc(2026, 10, 20));
    final List<PendingChangeRow> outbox = await harness.database.getOutbox();
    expect(outbox.single.entity, 'farm');
    final Map<String, dynamic> data =
        jsonDecode(outbox.single.payload) as Map<String, dynamic>;
    expect(data['name'], 'Nouvelle');
  });

  testWidgets('saves the current position after the explanation', (
    WidgetTester tester,
  ) async {
    final FakeLocationService location = FakeLocationService(
      result: const LocationResult.success(
        LocationPosition(latitude: 13.5, longitude: 2.1, accuracyMeters: 12),
      ),
    );
    final FarmsHarness harness = await pumpFarmsApp(
      tester,
      initialLocation: '/farms/new',
      locationService: location,
    );
    await fillName(tester, 'Ferme test');

    await tester.ensureVisible(find.byKey(const Key('farm_location_use')));
    await tester.tap(find.byKey(const Key('farm_location_use')));
    await tester.pumpAndSettle();
    expect(
      find.text(
        'GonaTa utilise votre position uniquement pour enregistrer les limites de votre parcelle.',
      ),
      findsOneWidget,
    );

    await tester.tap(
      find.byKey(const Key('farm_location_explanation_continue')),
    );
    await tester.pumpAndSettle();

    expect(location.positionCalls, 1);
    expect(find.text('Position enregistrée'), findsOneWidget);
    expect(find.text('Précision : 12 m'), findsOneWidget);

    await tapSave(tester);

    final List<PendingChangeRow> outbox = await harness.database.getOutbox();
    final Map<String, dynamic> data =
        jsonDecode(outbox.single.payload) as Map<String, dynamic>;
    expect(data['location'], pointToGeoJson(const LatLng(13.5, 2.1)));
    final FarmRow? row = await harness.database.getFarm(outbox.single.id);
    expect(row?.location, isNotNull);
  });

  testWidgets('clears an existing position', (WidgetTester tester) async {
    final FarmsHarness harness = await pumpFarmsApp(
      tester,
      initialLocation: '/farms/farm-1/edit',
      farms: <Farm>[
        sampleFarm(
          name: 'Ancienne',
          location: pointToGeoJson(const LatLng(13.5, 2.1)),
        ),
      ],
    );

    expect(find.text('Position enregistrée'), findsOneWidget);

    await tester.ensureVisible(find.byKey(const Key('farm_location_clear')));
    await tester.tap(find.byKey(const Key('farm_location_clear')));
    await tester.pumpAndSettle();
    expect(
      find.text("Position facultative, utilisée pour situer l'exploitation."),
      findsOneWidget,
    );

    await tapSave(tester);

    final List<PendingChangeRow> outbox = await harness.database.getOutbox();
    final Map<String, dynamic> data =
        jsonDecode(outbox.single.payload) as Map<String, dynamic>;
    expect(data['location'], isNull);
    final FarmRow? row = await harness.database.getFarm('farm-1');
    expect(row?.location, isNull);
  });

  testWidgets('offers the app settings after a permanent denial', (
    WidgetTester tester,
  ) async {
    final FakeLocationService location = FakeLocationService(
      result: const LocationResult.failure(
        LocationOutcomeStatus.permissionDeniedForever,
      ),
    );
    await pumpFarmsApp(
      tester,
      initialLocation: '/farms/new',
      locationService: location,
    );

    await tester.ensureVisible(find.byKey(const Key('farm_location_use')));
    await tester.tap(find.byKey(const Key('farm_location_use')));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const Key('farm_location_explanation_continue')),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('farm_location_error')), findsOneWidget);
    expect(
      find.byKey(const Key('farm_location_open_settings')),
      findsOneWidget,
    );
    expect(find.text('Position enregistrée'), findsNothing);

    await tester.ensureVisible(
      find.byKey(const Key('farm_location_open_settings')),
    );
    await tester.pump();
    await tester.tap(find.byKey(const Key('farm_location_open_settings')));
    await tester.pumpAndSettle();

    expect(location.settingsCalls, 1);
  });
}
