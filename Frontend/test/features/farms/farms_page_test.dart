import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartagri/core/network/api_exception.dart';
import 'package:smartagri/features/farms/domain/farm.dart';
import 'package:smartagri/features/farms/presentation/farm_detail_page.dart';
import 'package:smartagri/features/farms/presentation/farm_form_page.dart';

import 'fake_farms_repository.dart';
import 'farms_test_app.dart';

void main() {
  testWidgets('lists farms with their village and region', (
    WidgetTester tester,
  ) async {
    await pumpFarmsApp(
      tester,
      farms: <Farm>[
        sampleFarm(),
        sampleFarm(id: 'farm-2', name: 'Ferme est', village: 'Dosso'),
      ],
    );

    expect(find.text('Ferme du fleuve'), findsOneWidget);
    expect(find.text('Saga'), findsOneWidget);
    expect(find.text('Niamey'), findsNWidgets(2));
    expect(find.text('Ferme est'), findsOneWidget);
    expect(find.text('Dosso'), findsWidgets);

    await tester.tap(find.byKey(const Key('farm_card_farm-1')));
    await tester.pumpAndSettle();

    expect(find.byType(FarmDetailPage), findsOneWidget);
  });

  testWidgets('opens the creation form from the primary button', (
    WidgetTester tester,
  ) async {
    await pumpFarmsApp(tester);

    await tester.tap(find.byKey(const Key('farms_add')));
    await tester.pumpAndSettle();

    expect(find.byType(FarmFormPage), findsOneWidget);
    expect(find.text('Nouvelle exploitation'), findsOneWidget);
  });

  testWidgets('shows the empty state', (WidgetTester tester) async {
    await pumpFarmsApp(tester);

    expect(find.text('Aucune exploitation pour le moment.'), findsOneWidget);
  });

  testWidgets('shows an error and retries', (WidgetTester tester) async {
    final FakeFarmsRepository repository = FakeFarmsRepository()
      ..listFarmsError = ApiException.network();
    final FarmsHarness harness = await pumpFarmsApp(
      tester,
      repository: repository,
    );

    expect(
      find.text(
        'Impossible de joindre le serveur. Vérifiez votre connexion internet.',
      ),
      findsOneWidget,
    );

    repository.listFarmsError = null;
    repository.farms = <Farm>[sampleFarm()];
    await tester.tap(find.byKey(const Key('farms_retry')));
    await tester.pumpAndSettle();

    expect(find.text('Ferme du fleuve'), findsOneWidget);
    expect(harness.container, isNotNull);
  });
}
