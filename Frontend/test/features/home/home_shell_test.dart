import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:smartagri/core/router/app_router.dart';
import 'package:smartagri/design_system/components/app_bottom_nav.dart';
import 'package:smartagri/features/home/home_page.dart';
import 'package:smartagri/features/profile/profile_page.dart';
import 'package:smartagri/features/search/search_page.dart';

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
  testWidgets('renders the three tabs and switches between them', (
    WidgetTester tester,
  ) async {
    await pumpShell(tester);

    final AppBottomNav nav = tester.widget<AppBottomNav>(
      find.byType(AppBottomNav),
    );
    expect(nav.items.map((AppNavItem item) => item.label), <String>[
      'Accueil',
      'Recherche',
      'Profil',
    ]);
    expect(find.byType(HomePage), findsOneWidget);

    await tester.tap(find.byKey(const Key('app_bottom_nav_1')));
    await tester.pumpAndSettle();
    expect(find.byType(SearchPage), findsOneWidget);
    expect(find.text('Bientôt disponible'), findsOneWidget);

    await tester.tap(find.byKey(const Key('app_bottom_nav_2')));
    await tester.pumpAndSettle();
    expect(find.byType(ProfilePage), findsOneWidget);
    expect(find.text('Amina Diallo'), findsOneWidget);

    await tester.tap(find.byKey(const Key('app_bottom_nav_0')));
    await tester.pumpAndSettle();
    expect(find.byType(HomePage), findsOneWidget);
    expect(find.text('AMINA'), findsOneWidget);
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
    await tester.tap(find.byKey(const Key('app_bottom_nav_0')));
    await tester.pumpAndSettle();

    final Element homeAfter = tester.element(
      find.byType(HomePage, skipOffstage: false),
    );
    expect(identical(homeBefore, homeAfter), isTrue);
  });
}
