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

class FixedSessionController extends SessionController {
  FixedSessionController(this.fixedState);

  final SessionState fixedState;

  @override
  SessionState build() => fixedState;
}

Future<GoRouter> pumpRouter(WidgetTester tester, SessionState state) async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  final SharedPreferences preferences = await SharedPreferences.getInstance();
  final ProviderContainer container = ProviderContainer(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(preferences),
      sessionControllerProvider.overrideWith(
        () => FixedSessionController(state),
      ),
    ],
  );
  addTearDown(container.dispose);
  final GoRouter router = container.read(routerProvider);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(theme: AppTheme.light, routerConfig: router),
    ),
  );
  await tester.pumpAndSettle();
  return router;
}

void main() {
  testWidgets('unknown session stays on splash', (WidgetTester tester) async {
    await pumpRouter(tester, SessionState.unknown);

    expect(find.text('Chargement'), findsOneWidget);
    expect(find.text('Connexion'), findsNothing);
  });

  testWidgets('unauthenticated session is redirected to login', (
    WidgetTester tester,
  ) async {
    final GoRouter router = await pumpRouter(
      tester,
      SessionState.unauthenticated,
    );

    expect(find.text('Connexion'), findsOneWidget);

    router.go('/home');
    await tester.pumpAndSettle();
    expect(find.text('Connexion'), findsOneWidget);
    expect(find.text('Accueil'), findsNothing);
  });

  testWidgets('authenticated session is redirected to home', (
    WidgetTester tester,
  ) async {
    final GoRouter router = await pumpRouter(
      tester,
      SessionState.authenticated,
    );

    expect(find.text('Accueil'), findsOneWidget);
    expect(find.byType(AppBottomNav), findsOneWidget);

    router.go('/login');
    await tester.pumpAndSettle();
    expect(find.text('Accueil'), findsOneWidget);
    expect(find.text('Connexion'), findsNothing);
  });
}
