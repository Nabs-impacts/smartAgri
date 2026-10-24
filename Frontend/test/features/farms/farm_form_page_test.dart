import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartagri/core/network/api_exception.dart';
import 'package:smartagri/features/farms/domain/farm.dart';
import 'package:smartagri/features/farms/presentation/farm_form_page.dart';

import 'fake_farms_repository.dart';
import 'farms_test_app.dart';

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

  testWidgets('sends the generated id, the region and the name', (
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

    expect(harness.farms.lastFarmId, isNotNull);
    expect(harness.farms.lastFarmName, 'Ferme test');
    expect(harness.farms.lastAdminAreaId, 1);
    expect(harness.farms.lastVillage, isNull);
  });

  testWidgets('reuses the same id after a failed attempt', (
    WidgetTester tester,
  ) async {
    final FakeFarmsRepository repository = FakeFarmsRepository()
      ..createFarmError = ApiException.network();
    final FarmsHarness harness = await pumpFarmsApp(
      tester,
      initialLocation: '/farms/new',
      repository: repository,
    );
    await fillName(tester, 'Ferme test');

    await tapSave(tester);
    final String? firstId = repository.lastFarmId;

    expect(find.byKey(const Key('farm_form_error')), findsOneWidget);
    expect(find.byType(FarmFormPage), findsOneWidget);

    repository.createFarmError = null;
    await tapSave(tester);
    final String? secondId = repository.lastFarmId;

    expect(firstId, isNotNull);
    expect(secondId, firstId);
    expect(harness.container, isNotNull);
  });

  testWidgets('prefills the edit form and patches the farm', (
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

    expect(harness.farms.lastUpdatedFarmId, 'farm-1');
    expect(harness.farms.lastUpdatedName, 'Nouvelle');
  });
}
