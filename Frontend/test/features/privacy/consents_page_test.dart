import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:smartagri/core/network/api_exception.dart';
import 'package:smartagri/features/auth/domain/consent_choice.dart';
import 'package:smartagri/features/privacy/data/privacy_repository.dart';
import 'package:smartagri/features/privacy/presentation/consents_page.dart';

import '../app_test_utils.dart';
import 'fake_privacy_repository.dart';

const List<ConsentRecord> records = <ConsentRecord>[
  ConsentRecord(type: ConsentType.terms, version: '1.0', accepted: true),
  ConsentRecord(type: ConsentType.privacy, version: '1.0', accepted: true),
  ConsentRecord(
    type: ConsentType.dataSharingGov,
    version: '1.0',
    accepted: false,
  ),
  ConsentRecord(type: ConsentType.research, version: '1.0', accepted: false),
];

Future<GoRouter> pumpConsents(
  WidgetTester tester,
  FakePrivacyRepository repository,
) async {
  final ProviderContainer container = await buildTestContainer(
    meRepository: FakeMeRepository(sampleMeData()),
    privacyRepository: repository,
  );
  final GoRouter router = GoRouter(
    initialLocation: '/privacy/consents',
    routes: <RouteBase>[
      GoRoute(
        path: '/privacy/consents',
        builder: (_, _) => const ConsentsPage(),
      ),
      GoRoute(
        path: '/legal/terms',
        builder: (_, _) => const Scaffold(body: Text('conditions')),
      ),
      GoRoute(
        path: '/legal/privacy',
        builder: (_, _) => const Scaffold(body: Text('politique')),
      ),
    ],
  );
  await tester.pumpWidget(testRouterApp(container, router));
  await tester.pumpAndSettle();
  return router;
}

void main() {
  setUpAll(() {
    registerFallbackValue(ConsentType.terms);
  });

  testWidgets('shows the four consent rows and their states', (
    WidgetTester tester,
  ) async {
    final FakePrivacyRepository repository = FakePrivacyRepository();
    when(repository.getConsents).thenAnswer((_) async => records);

    await pumpConsents(tester, repository);

    expect(find.text("Conditions d'utilisation"), findsOneWidget);
    expect(find.text('Politique de confidentialité'), findsOneWidget);
    expect(find.text('Accepté'), findsNWidgets(2));
    expect(
      find.text('Partage de données anonymisées avec l\'administration'),
      findsOneWidget,
    );
    expect(
      find.text('Utilisation de mes photos pour la recherche'),
      findsOneWidget,
    );
    expect(
      tester.widget<Switch>(find.byKey(const Key('privacy_data_switch'))).value,
      isFalse,
    );
    expect(
      tester
          .widget<Switch>(find.byKey(const Key('privacy_research_switch')))
          .value,
      isFalse,
    );
  });

  testWidgets('the read buttons open the legal documents', (
    WidgetTester tester,
  ) async {
    final FakePrivacyRepository repository = FakePrivacyRepository();
    when(repository.getConsents).thenAnswer((_) async => records);
    final GoRouter router = await pumpConsents(tester, repository);

    await tester.tap(find.byKey(const Key('privacy_terms_read')));
    await tester.pumpAndSettle();

    expect(router.state.uri.path, '/legal/terms');
    expect(find.text('conditions'), findsOneWidget);
  });

  testWidgets('toggling a consent calls the server and updates the switch', (
    WidgetTester tester,
  ) async {
    final FakePrivacyRepository repository = FakePrivacyRepository();
    when(repository.getConsents).thenAnswer((_) async => records);
    when(() => repository.setConsent(ConsentType.dataSharingGov, true))
        .thenAnswer((_) async {});

    await pumpConsents(tester, repository);
    await tester.tap(find.byKey(const Key('privacy_data_switch')));
    await tester.pumpAndSettle();

    expect(
      tester.widget<Switch>(find.byKey(const Key('privacy_data_switch'))).value,
      isTrue,
    );
    verify(() => repository.setConsent(ConsentType.dataSharingGov, true))
        .called(1);
  });

  testWidgets('a failed toggle restores the switch and shows an error', (
    WidgetTester tester,
  ) async {
    final FakePrivacyRepository repository = FakePrivacyRepository();
    when(repository.getConsents).thenAnswer((_) async => records);
    when(() => repository.setConsent(ConsentType.research, true))
        .thenThrow(ApiException.network());

    await pumpConsents(tester, repository);
    await tester.tap(find.byKey(const Key('privacy_research_switch')));
    await tester.pumpAndSettle();

    expect(
      tester
          .widget<Switch>(find.byKey(const Key('privacy_research_switch')))
          .value,
      isFalse,
    );
    expect(find.byKey(const Key('privacy_update_error')), findsOneWidget);
  });

  testWidgets('shows the load error and retries', (WidgetTester tester) async {
    final FakePrivacyRepository repository = FakePrivacyRepository();
    when(repository.getConsents).thenThrow(ApiException.network());

    await pumpConsents(tester, repository);

    expect(
      find.text('Impossible de charger vos consentements.'),
      findsOneWidget,
    );
    expect(find.text('Réessayer'), findsOneWidget);

    when(repository.getConsents).thenAnswer((_) async => records);
    await tester.tap(find.byKey(const Key('privacy_retry')));
    await tester.pumpAndSettle();

    expect(find.text("Conditions d'utilisation"), findsOneWidget);
  });
}
