import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartagri/core/network/api_exception.dart';
import 'package:smartagri/features/farms/domain/farm.dart';
import 'package:smartagri/features/farms/domain/plot.dart';

import 'fake_farms_repository.dart';
import 'farms_test_app.dart';

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
  FakeFarmsRepository? repository,
}) async {
  await tester.binding.setSurfaceSize(const Size(900, 1600));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  return pumpFarmsApp(
    tester,
    initialLocation: '/farms/farm-1/plots/new',
    farms: <Farm>[sampleFarm()],
    repository: repository,
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

    expect(harness.farms.lastPlotAreaHa, 10000);
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

    expect(harness.farms.lastPlotAreaHa, 2.5);
    expect(harness.farms.lastPlotSoilType, SoilType.sandy);
    expect(harness.farms.lastPlotIrrigation, IrrigationType.rainfed);
    expect(harness.farms.lastPlotId, isNotNull);
  });

  testWidgets('accepts a decimal point', (WidgetTester tester) async {
    final FarmsHarness harness = await pumpPlotForm(tester);
    await enterName(tester, 'Parcelle test');
    await enterArea(tester, '3.25');
    await tapSave(tester);

    expect(harness.farms.lastPlotAreaHa, 3.25);
  });

  testWidgets('shows the plan limit when the quota is exceeded', (
    WidgetTester tester,
  ) async {
    final FakeFarmsRepository repository = FakeFarmsRepository()
      ..createPlotError = const ApiException(
        statusCode: 403,
        code: 'QUOTA_EXCEEDED',
        message: 'Quota dépassé',
        details: <String, dynamic>{'metric': 'plots', 'limit': 3, 'used': 3},
      );
    await pumpPlotForm(tester, repository: repository);
    await enterName(tester, 'Parcelle test');
    await enterArea(tester, '2');

    await tapSave(tester);
    await scrollUpTo(tester, find.byKey(const Key('plot_form_error')));

    expect(
      find.text('Vous avez atteint la limite de votre formule (3 parcelles).'),
      findsOneWidget,
    );
  });

  testWidgets('shows the map coming soon note', (WidgetTester tester) async {
    await pumpPlotForm(tester);

    await tester.scrollUntilVisible(
      find.byKey(const Key('plot_map_coming_soon')),
      200,
      scrollable: find.byType(Scrollable).first,
    );

    expect(
      find.text('Le tracé de la parcelle sur la carte arrivera plus tard'),
      findsOneWidget,
    );
  });
}
