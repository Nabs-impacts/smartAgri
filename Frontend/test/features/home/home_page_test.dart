import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:smartagri/core/i18n/app_language.dart';
import 'package:smartagri/core/i18n/language_controller.dart';
import 'package:smartagri/features/home/home_page.dart';

import '../app_test_utils.dart';

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
        path: '/diagnostic',
        builder: (_, _) => const Scaffold(body: Text('route diagnostic')),
      ),
    ],
  );
}

Future<(ProviderContainer, FakeMeRepository)> pumpHome(
  WidgetTester tester,
) async {
  final FakeMeRepository repository = FakeMeRepository(sampleMeData());
  final ProviderContainer container = await buildTestContainer(
    meRepository: repository,
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
}
