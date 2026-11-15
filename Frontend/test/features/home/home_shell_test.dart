import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:smartagri/core/router/app_router.dart';
import 'package:smartagri/design_system/components/app_bottom_nav.dart';
import 'package:smartagri/features/diagnostics/presentation/diagnostic_new_page.dart';
import 'package:smartagri/features/farms/presentation/farms_page.dart';
import 'package:smartagri/features/home/home_page.dart';
import 'package:smartagri/features/more/presentation/more_page.dart';
import 'package:smartagri/features/tips/presentation/tips_page.dart';

import '../app_test_utils.dart';

Future<ProviderContainer> pumpShell(WidgetTester tester) async {
  final ProviderContainer container = await buildTestContainer(
    meRepository: FakeMeRepository(sampleMeData()),
  );
  final GoRouter router = container.read(routerProvider);
  await tester.pumpWidget(testRouterApp(container, router));
  await tester.pumpAndSettle();
  return container;
}

void main() {
  testWidgets('renders the four tabs and switches between them', (
    WidgetTester tester,
  ) async {
    await pumpShell(tester);

    final AppBottomNav nav = tester.widget<AppBottomNav>(
      find.byType(AppBottomNav),
    );
    expect(nav.items.map((AppNavItem item) => item.label), <String>[
      'Accueil',
      'Champs',
      'Conseils',
      'Plus',
    ]);
    expect(find.byType(HomePage), findsOneWidget);

    await tester.tap(find.byKey(const Key('app_bottom_nav_1')));
    await tester.pumpAndSettle();
    expect(find.byType(FarmsPage), findsOneWidget);

    await tester.tap(find.byKey(const Key('app_bottom_nav_2')));
    await tester.pumpAndSettle();
    expect(find.byType(TipsPage), findsOneWidget);
    expect(find.text('Vos recommandations'), findsOneWidget);

    await tester.tap(find.byKey(const Key('app_bottom_nav_3')));
    await tester.pumpAndSettle();
    expect(find.byType(MorePage), findsOneWidget);
    expect(find.text('Amina Diallo'), findsOneWidget);

    await tester.tap(find.byKey(const Key('app_bottom_nav_0')));
    await tester.pumpAndSettle();
    expect(find.byType(HomePage), findsOneWidget);
    expect(find.text('AMINA'), findsOneWidget);
  });

  testWidgets('the central scanner opens the diagnostic route', (
    WidgetTester tester,
  ) async {
    await pumpShell(tester);

    await tester.tap(find.byKey(const Key('app_bottom_nav_scan')));
    await tester.pumpAndSettle();

    expect(find.byType(DiagnosticNewPage), findsOneWidget);
  });

  testWidgets('the android back gesture returns to the home tab', (
    WidgetTester tester,
  ) async {
    final ProviderContainer container = await pumpShell(tester);
    final GoRouter router = container.read(routerProvider);

    await tester.tap(find.byKey(const Key('app_bottom_nav_1')));
    await tester.pumpAndSettle();
    expect(router.state.uri.path, '/farms');

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(router.state.uri.path, '/home');
    expect(find.byType(HomePage), findsOneWidget);
  });

  testWidgets('keeps the state of each branch', (WidgetTester tester) async {
    await pumpShell(tester);
    final Element homeBefore = tester.element(
      find.byType(HomePage, skipOffstage: false),
    );

    await tester.tap(find.byKey(const Key('app_bottom_nav_1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('app_bottom_nav_2')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('app_bottom_nav_3')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('app_bottom_nav_0')));
    await tester.pumpAndSettle();

    final Element homeAfter = tester.element(
      find.byType(HomePage, skipOffstage: false),
    );
    expect(identical(homeBefore, homeAfter), isTrue);
  });
}
