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
import 'package:smartagri/features/auth/presentation/login_page.dart';
import 'package:smartagri/features/dev_gallery/design_gallery_page.dart';
import 'package:smartagri/features/home/home_page.dart';
import 'package:smartagri/features/profile/data/me_repository.dart';

import '../../features/app_test_utils.dart';

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
}) async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  final SharedPreferences preferences = await SharedPreferences.getInstance();
  final ProviderContainer container = ProviderContainer(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(preferences),
      sessionControllerProvider.overrideWith(() => controller),
      meRepositoryProvider.overrideWithValue(FakeMeRepository(sampleMeData())),
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
}
