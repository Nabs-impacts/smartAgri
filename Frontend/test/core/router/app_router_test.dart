import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smartagri/core/i18n/language_controller.dart';
import 'package:smartagri/core/router/app_router.dart';
import 'package:smartagri/core/session/session_controller.dart';
import 'package:smartagri/core/session/session_state.dart';
import 'package:smartagri/design_system/components/app_bottom_nav.dart';
import 'package:smartagri/design_system/theme.dart';
import 'package:smartagri/features/admin/data/stats_repository.dart';
import 'package:smartagri/features/admin/presentation/admin_overview_page.dart';
import 'package:smartagri/features/admin/presentation/admin_yields_page.dart';
import 'package:smartagri/features/auth/presentation/login_page.dart';
import 'package:smartagri/features/catalog/data/catalog_repository.dart';
import 'package:smartagri/features/dev_gallery/design_gallery_page.dart';
import 'package:smartagri/features/diagnostics/data/diagnostics_repository.dart';
import 'package:smartagri/features/diagnostics/presentation/diagnostic_new_page.dart';
import 'package:smartagri/features/farms/data/farms_repository.dart';
import 'package:smartagri/features/home/home_page.dart';
import 'package:smartagri/features/profile/data/me_repository.dart';

import '../../features/admin/fake_stats_repository.dart';
import '../../features/app_test_utils.dart';
import '../../features/diagnostics/fake_diagnostics_repository.dart';
import '../../features/farms/fake_farms_repository.dart';

class FixedSessionController extends SessionController {
  FixedSessionController(this.fixedState);

  final SessionState fixedState;

  @override
  SessionState build() => fixedState;
}

class TestSessionController extends SessionController {
  @override
  SessionState build() => SessionState.unknown;

  void update(SessionState value) => state = value;
}

Future<ProviderContainer> buildContainer(
  SessionController controller, {
  String? startRoute,
  MeRepository? meRepository,
}) async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  final SharedPreferences preferences = await SharedPreferences.getInstance();
  final ProviderContainer container = ProviderContainer(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(preferences),
      sessionControllerProvider.overrideWith(() => controller),
      meRepositoryProvider.overrideWithValue(
        meRepository ?? FakeMeRepository(sampleMeData()),
      ),
      statsRepositoryProvider.overrideWithValue(FakeStatsRepository()),
      farmsRepositoryProvider.overrideWithValue(FakeFarmsRepository()),
      diagnosticsRepositoryProvider.overrideWithValue(
        FakeDiagnosticsRepository(),
      ),
      adminAreasProvider.overrideWith(
        () => FixedAdminAreasController(sampleAdminAreas),
      ),
      if (startRoute != null) startRouteProvider.overrideWithValue(startRoute),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

Future<GoRouter> pumpContainer(
  WidgetTester tester,
  ProviderContainer container,
) async {
  final GoRouter router = container.read(routerProvider);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(theme: AppTheme.light, routerConfig: router),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
  return router;
}

Future<GoRouter> pumpRouter(
  WidgetTester tester,
  SessionState state, {
  String? startRoute,
}) async {
  final ProviderContainer container = await buildContainer(
    FixedSessionController(state),
    startRoute: startRoute,
  );
  return pumpContainer(tester, container);
}

void main() {
  testWidgets('the router instance survives session changes', (
    WidgetTester tester,
  ) async {
    final TestSessionController controller = TestSessionController();
    final ProviderContainer container = await buildContainer(controller);
    final GoRouter router = await pumpContainer(tester, container);

    controller.update(SessionState.authenticated);
    await tester.pumpAndSettle();
    controller.update(SessionState.unauthenticated);
    await tester.pumpAndSettle();
    controller.update(SessionState.authenticated);
    await tester.pumpAndSettle();

    expect(identical(container.read(routerProvider), router), isTrue);
  });

  testWidgets('unknown session stays on splash', (WidgetTester tester) async {
    await pumpRouter(tester, SessionState.unknown);

    expect(find.text('Chargement'), findsOneWidget);
    expect(find.byType(LoginPage), findsNothing);
  });

  testWidgets('unauthenticated session is redirected to login', (
    WidgetTester tester,
  ) async {
    final GoRouter router = await pumpRouter(
      tester,
      SessionState.unauthenticated,
    );

    expect(find.byType(LoginPage), findsOneWidget);

    router.go('/home');
    await tester.pumpAndSettle();
    expect(find.byType(LoginPage), findsOneWidget);
    expect(find.byType(HomePage), findsNothing);
  });

  testWidgets('authenticated session is redirected to home', (
    WidgetTester tester,
  ) async {
    final GoRouter router = await pumpRouter(
      tester,
      SessionState.authenticated,
    );

    expect(find.byType(HomePage), findsOneWidget);
    expect(find.byType(AppBottomNav), findsOneWidget);

    router.go('/login');
    await tester.pumpAndSettle();
    expect(find.byType(HomePage), findsOneWidget);
    expect(find.byType(LoginPage), findsNothing);
  });

  testWidgets('the diagnostic route redirects to the new diagnosis page', (
    WidgetTester tester,
  ) async {
    final GoRouter router = await pumpRouter(
      tester,
      SessionState.authenticated,
    );

    router.go('/diagnostic');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(router.state.uri.path, '/diagnostic/new');
    expect(find.byType(DiagnosticNewPage), findsOneWidget);
  });

  testWidgets('starts on the gallery when the debug start route is set', (
    WidgetTester tester,
  ) async {
    await pumpRouter(tester, SessionState.unknown, startRoute: '/dev/gallery');

    expect(find.byType(DesignGalleryPage), findsOneWidget);
    expect(find.text('Galerie du design system'), findsOneWidget);
  });

  testWidgets('the gallery is reachable in every session state', (
    WidgetTester tester,
  ) async {
    for (final SessionState state in SessionState.values) {
      final ProviderContainer container = await buildContainer(
        FixedSessionController(state),
      );
      final GoRouter router = await pumpContainer(tester, container);

      router.go('/dev/gallery');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(
        find.byType(DesignGalleryPage),
        findsOneWidget,
        reason: 'session $state',
      );
    }
  });

  testWidgets('an administrator is redirected to the admin overview', (
    WidgetTester tester,
  ) async {
    final FakeMeRepository me = FakeMeRepository(
      sampleMeData(role: 'gov_admin'),
    );
    final ProviderContainer container = await buildContainer(
      FixedSessionController(SessionState.authenticated),
      meRepository: me,
      startRoute: '/home',
    );
    final GoRouter router = await pumpContainer(tester, container);
    await tester.pumpAndSettle();

    expect(router.state.uri.path, '/admin/overview');
    expect(find.byType(AdminOverviewPage), findsOneWidget);
    final AppBottomNav nav = tester.widget<AppBottomNav>(
      find.byType(AppBottomNav),
    );
    expect(nav.items.map((AppNavItem item) => item.label), <String>[
      'Tableau de bord',
      'Rendements',
      'Profil',
    ]);

    await tester.tap(find.byKey(const Key('app_bottom_nav_1')));
    await tester.pumpAndSettle();
    expect(find.byType(AdminYieldsPage), findsOneWidget);

    await tester.tap(find.byKey(const Key('app_bottom_nav_2')));
    await tester.pumpAndSettle();
    expect(find.text('Mon utilisation'), findsNothing);
    expect(find.text('Mes diagnostics'), findsNothing);
  });

  testWidgets('the login redirect sends an administrator to the overview', (
    WidgetTester tester,
  ) async {
    final ProviderContainer container = await buildContainer(
      FixedSessionController(SessionState.authenticated),
      meRepository: FakeMeRepository(sampleMeData(role: 'super_admin')),
      startRoute: '/login',
    );
    final GoRouter router = await pumpContainer(tester, container);
    await tester.pumpAndSettle();

    expect(router.state.uri.path, '/admin/overview');
    expect(find.byType(AdminOverviewPage), findsOneWidget);
    expect(find.byType(LoginPage), findsNothing);
  });

  testWidgets('a farmer is redirected away from the admin routes', (
    WidgetTester tester,
  ) async {
    final ProviderContainer container = await buildContainer(
      FixedSessionController(SessionState.authenticated),
      startRoute: '/home',
    );
    final GoRouter router = await pumpContainer(tester, container);
    await tester.pumpAndSettle();

    router.go('/admin/yields');
    await tester.pumpAndSettle();

    expect(router.state.uri.path, '/home');
    expect(find.byType(HomePage), findsOneWidget);
    expect(find.byType(AdminYieldsPage), findsNothing);
  });

  testWidgets('waits for the profile before redirecting an administrator', (
    WidgetTester tester,
  ) async {
    final FakeMeRepository me = FakeMeRepository(
      sampleMeData(role: 'gov_admin'),
    )..completer = Completer<MeData>();
    final ProviderContainer container = await buildContainer(
      FixedSessionController(SessionState.authenticated),
      meRepository: me,
      startRoute: '/home',
    );
    final GoRouter router = await pumpContainer(tester, container);

    expect(router.state.uri.path, '/home');
    expect(find.byType(AdminOverviewPage), findsNothing);

    me.completer!.complete(sampleMeData(role: 'gov_admin'));
    await tester.pumpAndSettle();

    expect(router.state.uri.path, '/admin/overview');
    expect(find.byType(AdminOverviewPage), findsOneWidget);
  });
}
