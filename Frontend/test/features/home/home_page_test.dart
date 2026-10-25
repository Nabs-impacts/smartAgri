import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:smartagri/core/i18n/app_language.dart';
import 'package:smartagri/core/i18n/language_controller.dart';
import 'package:smartagri/core/network/api_exception.dart';
import 'package:smartagri/features/farms/domain/farm.dart';
import 'package:smartagri/features/home/home_page.dart';

import '../app_test_utils.dart';
import '../farms/fake_farms_repository.dart';

GoRouter buildRouter() {
  return GoRouter(
    initialLocation: '/home',
    routes: <RouteBase>[
      GoRoute(path: '/home', builder: (_, _) => const HomePage()),
      GoRoute(
        path: '/profile',
        builder: (_, _) => const Scaffold(body: Text('route profil')),
      ),
      GoRoute(
        path: '/diagnostic/new',
        builder: (_, _) => const Scaffold(body: Text('route diagnostic')),
      ),
      GoRoute(
        path: '/farms',
        builder: (_, _) => const Scaffold(body: Text('route exploitations')),
      ),
      GoRoute(
        path: '/farms/new',
        builder: (_, _) => const Scaffold(body: Text('route nouvelle')),
      ),
      GoRoute(
        path: '/farms/:farmId',
        builder: (_, _) => const Scaffold(body: Text('route exploitation')),
      ),
    ],
  );
}

Future<(ProviderContainer, FakeMeRepository)> pumpHome(
  WidgetTester tester, {
  FakeFarmsRepository? farms,
}) async {
  final FakeMeRepository repository = FakeMeRepository(sampleMeData());
  final ProviderContainer container = await buildTestContainer(
    meRepository: repository,
    farmsRepository: farms,
  );
  await tester.pumpWidget(testRouterApp(container, buildRouter()));
  await tester.pumpAndSettle();
  return (container, repository);
}

void main() {
  testWidgets('shows the uppercase first name and the weather card', (
    WidgetTester tester,
  ) async {
    await pumpHome(tester);

    expect(find.text('Bonjour'), findsOneWidget);
    expect(find.text('AMINA'), findsOneWidget);
    expect(find.text('34°'), findsOneWidget);
    expect(find.text('Risque de pluie (10%)'), findsOneWidget);
    expect(find.text('Vent 15km/h'), findsOneWidget);
    expect(find.text('Sol propice'), findsOneWidget);
    expect(find.text('Données de démonstration'), findsOneWidget);
  });

  testWidgets('the diagnostic button opens the diagnostic route', (
    WidgetTester tester,
  ) async {
    await pumpHome(tester);

    await tester.tap(find.byKey(const Key('home_diagnostic')));
    await tester.pumpAndSettle();

    expect(find.text('route diagnostic'), findsOneWidget);
  });

  testWidgets('the profile icon opens the profile route', (
    WidgetTester tester,
  ) async {
    await pumpHome(tester);

    await tester.tap(find.byKey(const Key('home_profile')));
    await tester.pumpAndSettle();

    expect(find.text('route profil'), findsOneWidget);
  });

  testWidgets('changing the language updates the app and the backend', (
    WidgetTester tester,
  ) async {
    final (ProviderContainer container, FakeMeRepository repository) =
        await pumpHome(tester);

    await tester.tap(find.byKey(const Key('language_ha')));
    await tester.pumpAndSettle();

    expect(container.read(languageControllerProvider), AppLanguage.ha);
    expect(repository.languages, contains(AppLanguage.ha));
  });

  testWidgets('shows the empty farms section and opens the creation form', (
    WidgetTester tester,
  ) async {
    await pumpHome(tester);

    expect(find.text('Mes exploitations'), findsOneWidget);
    expect(find.text('Ajoutez votre première exploitation'), findsOneWidget);

    await tester.tap(find.byKey(const Key('home_farms_add')));
    await tester.pumpAndSettle();

    expect(find.text('route nouvelle'), findsOneWidget);
  });

  testWidgets('shows at most three farms with their region', (
    WidgetTester tester,
  ) async {
    await pumpHome(
      tester,
      farms: FakeFarmsRepository(
        farms: <Farm>[
          sampleFarm(id: 'farm-1', name: 'Ferme 1'),
          sampleFarm(id: 'farm-2', name: 'Ferme 2'),
          sampleFarm(id: 'farm-3', name: 'Ferme 3'),
          sampleFarm(id: 'farm-4', name: 'Ferme 4'),
        ],
      ),
    );

    expect(find.text('Ferme 1'), findsOneWidget);
    expect(find.text('Ferme 2'), findsOneWidget);
    expect(find.text('Ferme 3'), findsOneWidget);
    expect(find.text('Ferme 4'), findsNothing);
    expect(find.text('Niamey'), findsWidgets);

    await tester.tap(find.byKey(const Key('home_farms_see_all')));
    await tester.pumpAndSettle();

    expect(find.text('route exploitations'), findsOneWidget);
  });

  testWidgets('shows the farms error and retries', (WidgetTester tester) async {
    final FakeFarmsRepository farms = FakeFarmsRepository()
      ..listFarmsError = ApiException.network();
    await pumpHome(tester, farms: farms);

    expect(
      find.text(
        'Impossible de joindre le serveur. Vérifiez votre connexion internet.',
      ),
      findsOneWidget,
    );

    farms.listFarmsError = null;
    farms.farms = <Farm>[sampleFarm(name: 'Ferme revenue')];
    await tester.tap(find.byKey(const Key('home_farms_retry')));
    await tester.pumpAndSettle();

    expect(find.text('Ferme revenue'), findsOneWidget);
  });
}
