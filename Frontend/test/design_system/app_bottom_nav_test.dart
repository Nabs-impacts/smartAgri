import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartagri/design_system/components/app_bottom_nav.dart';
import 'package:smartagri/design_system/tokens.dart';

import 'test_app.dart';

const List<AppNavItem> items = <AppNavItem>[
  AppNavItem(icon: Icons.home_outlined, label: 'Accueil'),
  AppNavItem(icon: Icons.search, label: 'Recherche'),
  AppNavItem(icon: Icons.person_outline, label: 'Profil'),
];

void main() {
  testWidgets('renders every item with its semantic label', (
    WidgetTester tester,
  ) async {
    await pumpComponent(
      tester,
      AppBottomNav(items: items, selectedIndex: 0, onSelected: (_) {}),
    );

    expect(find.byIcon(Icons.home_outlined), findsOneWidget);
    expect(find.byIcon(Icons.search), findsOneWidget);
    expect(find.byIcon(Icons.person_outline), findsOneWidget);
    expect(find.bySemanticsLabel('Recherche'), findsOneWidget);
  });

  testWidgets('notifies selection changes', (WidgetTester tester) async {
    int selected = 0;
    await pumpComponent(
      tester,
      AppBottomNav(
        items: items,
        selectedIndex: selected,
        onSelected: (int index) => selected = index,
      ),
    );

    await tester.tap(find.byKey(const ValueKey<String>('app_bottom_nav_1')));
    expect(selected, 1);

    await tester.tap(find.byKey(const ValueKey<String>('app_bottom_nav_2')));
    expect(selected, 2);
  });

  testWidgets('highlights the selected item in white', (
    WidgetTester tester,
  ) async {
    await pumpComponent(
      tester,
      AppBottomNav(items: items, selectedIndex: 1, onSelected: (_) {}),
    );

    final Icon search = tester.widget<Icon>(find.byIcon(Icons.search));
    final Icon home = tester.widget<Icon>(find.byIcon(Icons.home_outlined));
    expect(search.color, AppColors.white);
    expect(home.color, AppColors.muted);
  });
}
