import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:smartagri/core/sync/sync_providers.dart';
import 'package:smartagri/core/sync/sync_service.dart';
import 'package:smartagri/core/sync/sync_status.dart';
import 'package:smartagri/features/more/presentation/more_page.dart';

import '../app_test_utils.dart';

GoRouter moreRouter() {
  return GoRouter(
    initialLocation: '/more',
    routes: <RouteBase>[
      GoRoute(path: '/more', builder: (_, _) => const MorePage()),
      GoRoute(
        path: '/profile',
        builder: (_, _) => const Scaffold(body: Text('route profile')),
      ),
      GoRoute(
        path: '/diagnostics',
        builder: (_, _) => const Scaffold(body: Text('route diagnostics')),
      ),
      GoRoute(
        path: '/sync/failed',
        builder: (_, _) => const Scaffold(body: Text('route sync failed')),
      ),
      GoRoute(
        path: '/privacy/consents',
        builder: (_, _) => const Scaffold(body: Text('route consents')),
      ),
      GoRoute(
        path: '/legal/terms',
        builder: (_, _) => const Scaffold(body: Text('route terms')),
      ),
      GoRoute(
        path: '/legal/privacy',
        builder: (_, _) => const Scaffold(body: Text('route privacy')),
      ),
    ],
  );
}

Future<void> pumpMore(
  WidgetTester tester, {
  SyncSnapshot syncStatus = const SyncSnapshot(
    status: SyncStatus.idle,
    pendingCount: 0,
    failedCount: 0,
  ),
  SyncRunner? syncRunner,
  RecordingAuthRepository? authRepository,
}) async {
  final ProviderContainer container = await buildTestContainer(
    meRepository: FakeMeRepository(sampleMeData()),
    syncStatus: syncStatus,
    syncRunner: syncRunner,
    authRepository: authRepository,
  );
  await tester.pumpWidget(testRouterApp(container, moreRouter()));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('shows the account card with initials and a masked phone', (
    WidgetTester tester,
  ) async {
    await pumpMore(tester);

    expect(find.text('AD'), findsOneWidget);
    expect(find.text('Amina Diallo'), findsOneWidget);
    expect(find.textContaining('••'), findsOneWidget);

    await tester.tap(find.byKey(const Key('more_account')));
    await tester.pumpAndSettle();
    expect(find.text('route profile'), findsOneWidget);
  });

  testWidgets('shows the live sync state and runs a sync', (
    WidgetTester tester,
  ) async {
    int runs = 0;
    await pumpMore(
      tester,
      syncStatus: const SyncSnapshot(
        status: SyncStatus.idle,
        pendingCount: 3,
        failedCount: 0,
      ),
      syncRunner: () async {
        runs++;
        return SyncResult.none;
      },
    );

    expect(find.text('3 modifications en attente'), findsOneWidget);

    await tester.tap(find.byKey(const Key('more_sync')));
    await tester.pumpAndSettle();
    expect(runs, 1);
  });

  testWidgets('shows up to date when nothing is pending', (
    WidgetTester tester,
  ) async {
    await pumpMore(tester);
    expect(find.text('À jour'), findsOneWidget);
  });

  testWidgets('failed changes open the sync failure page', (
    WidgetTester tester,
  ) async {
    int runs = 0;
    await pumpMore(
      tester,
      syncStatus: const SyncSnapshot(
        status: SyncStatus.error,
        pendingCount: 0,
        failedCount: 2,
      ),
      syncRunner: () async {
        runs++;
        return SyncResult.none;
      },
    );

    expect(find.text('2 refusées'), findsOneWidget);

    await tester.tap(find.byKey(const Key('more_sync')));
    await tester.pumpAndSettle();
    expect(find.text('route sync failed'), findsOneWidget);
    expect(runs, 0);
  });

  testWidgets('offline state is displayed', (WidgetTester tester) async {
    await pumpMore(
      tester,
      syncStatus: const SyncSnapshot(
        status: SyncStatus.offline,
        pendingCount: 0,
        failedCount: 0,
      ),
    );

    expect(find.text('Hors connexion'), findsOneWidget);
  });

  testWidgets('each row opens its page', (WidgetTester tester) async {
    await pumpMore(tester);

    await tester.tap(find.byKey(const Key('more_diagnostics')));
    await tester.pumpAndSettle();
    expect(find.text('route diagnostics'), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('more_privacy')));
    await tester.pumpAndSettle();
    expect(find.text('route consents'), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('more_terms')));
    await tester.pumpAndSettle();
    expect(find.text('route terms'), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.byKey(const Key('more_privacy_policy')),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.byKey(const Key('more_privacy_policy')));
    await tester.pumpAndSettle();
    expect(find.text('route privacy'), findsOneWidget);
  });

  testWidgets('logout asks for confirmation and calls the repository', (
    WidgetTester tester,
  ) async {
    final RecordingAuthRepository auth = RecordingAuthRepository();
    await pumpMore(tester, authRepository: auth);

    await tester.scrollUntilVisible(
      find.byKey(const Key('more_logout')),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.byKey(const Key('more_logout')));
    await tester.pumpAndSettle();

    expect(
      find.text('Voulez-vous vraiment vous déconnecter ?'),
      findsOneWidget,
    );
    expect(auth.logoutCalls, 0);

    await tester.tap(find.byKey(const Key('profile_logout_confirm')));
    await tester.pumpAndSettle();
    expect(auth.logoutCalls, 1);
  });
}
