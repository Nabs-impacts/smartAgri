import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:smartagri/core/network/api_exception.dart';
import 'package:smartagri/design_system/components/app_button.dart';
import 'package:smartagri/features/privacy/data/privacy_repository.dart';
import 'package:smartagri/features/privacy/presentation/delete_account_page.dart';

import '../app_test_utils.dart';
import 'fake_privacy_repository.dart';

Finder deleteField() {
  return find.descendant(
    of: find.byKey(const Key('privacy_delete_field')),
    matching: find.byType(TextFormField),
  );
}

AppButton deleteButton(WidgetTester tester) {
  return tester.widget<AppButton>(
    find.byKey(const Key('privacy_delete_confirm')),
  );
}

Future<GoRouter> pumpDelete(
  WidgetTester tester,
  FakePrivacyRepository repository,
) async {
  final ProviderContainer container = await buildTestContainer(
    meRepository: FakeMeRepository(sampleMeData()),
    privacyRepository: repository,
  );
  final GoRouter router = GoRouter(
    initialLocation: '/privacy/delete',
    routes: <RouteBase>[
      GoRoute(
        path: '/privacy/delete',
        builder: (_, _) => const DeleteAccountPage(),
      ),
      GoRoute(
        path: '/login',
        builder: (_, _) => const Scaffold(body: Text('connexion')),
      ),
    ],
  );
  await tester.pumpWidget(testRouterApp(container, router));
  await tester.pumpAndSettle();
  return router;
}

void main() {
  testWidgets('enables the button only for the exact confirmation', (
    WidgetTester tester,
  ) async {
    await pumpDelete(tester, FakePrivacyRepository());

    expect(deleteButton(tester).onPressed, isNull);

    await tester.enterText(deleteField(), 'SUPPRIMER MON COMPTE ');
    await tester.pump();

    expect(deleteButton(tester).onPressed, isNull);

    await tester.enterText(deleteField(), 'SUPPRIMER MON COMPTE');
    await tester.pump();

    expect(deleteButton(tester).onPressed, isNotNull);
  });

  testWidgets('success signs out and returns to the login page', (
    WidgetTester tester,
  ) async {
    final FakePrivacyRepository repository = FakePrivacyRepository();
    when(() => repository.deleteAccount(PrivacyRepository.deleteConfirmation))
        .thenAnswer((_) async {});
    final GoRouter router = await pumpDelete(tester, repository);

    await tester.enterText(deleteField(), 'SUPPRIMER MON COMPTE');
    await tester.pump();
    await tester.tap(find.byKey(const Key('privacy_delete_confirm')));
    await tester.pumpAndSettle();

    verify(() => repository.deleteAccount(PrivacyRepository.deleteConfirmation))
        .called(1);
    expect(router.state.uri.path, '/login');
    expect(find.text('connexion'), findsOneWidget);
    expect(find.text('Votre compte a été supprimé'), findsOneWidget);
  });

  testWidgets('shows the sole owner conflict message', (
    WidgetTester tester,
  ) async {
    final FakePrivacyRepository repository = FakePrivacyRepository();
    when(() => repository.deleteAccount(PrivacyRepository.deleteConfirmation))
        .thenThrow(
          const ApiException(
            statusCode: 409,
            code: PrivacyRepository.ownerConflictCode,
            message: PrivacyRepository.ownerConflictMessage,
          ),
        );
    final GoRouter router = await pumpDelete(tester, repository);

    await tester.enterText(deleteField(), 'SUPPRIMER MON COMPTE');
    await tester.pump();
    await tester.tap(find.byKey(const Key('privacy_delete_confirm')));
    await tester.pumpAndSettle();

    expect(router.state.uri.path, '/privacy/delete');
    expect(find.text(PrivacyRepository.ownerConflictMessage), findsOneWidget);
  });

  testWidgets('shows a readable error on failure', (WidgetTester tester) async {
    final FakePrivacyRepository repository = FakePrivacyRepository();
    when(() => repository.deleteAccount(PrivacyRepository.deleteConfirmation))
        .thenThrow(ApiException.network());
    final GoRouter router = await pumpDelete(tester, repository);

    await tester.enterText(deleteField(), 'SUPPRIMER MON COMPTE');
    await tester.pump();
    await tester.tap(find.byKey(const Key('privacy_delete_confirm')));
    await tester.pumpAndSettle();

    expect(router.state.uri.path, '/privacy/delete');
    expect(find.byKey(const Key('privacy_delete_error')), findsOneWidget);
    expect(
      find.text(
        'Impossible de joindre le serveur. Vérifiez votre connexion internet.',
      ),
      findsOneWidget,
    );
  });
}
