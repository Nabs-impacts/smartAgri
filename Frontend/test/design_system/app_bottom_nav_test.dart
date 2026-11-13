import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartagri/design_system/components/app_bottom_nav.dart';
import 'package:smartagri/design_system/tokens.dart';

import 'test_app.dart';

import 'package:smartagri/design_system/app_icons.dart';

const List<AppNavItem> items = <AppNavItem>[
  AppNavItem(icon: AppIcons.home, label: 'Accueil'),
  AppNavItem(icon: AppIcons.search, label: 'Recherche'),
  AppNavItem(icon: AppIcons.profile, label: 'Profil'),
];

void main() {
  testWidgets('renders every item with its semantic label', (
    WidgetTester tester,
  ) async {
    await pumpComponent(
      tester,
      AppBottomNav(items: items, selectedIndex: 0, onSelected: (_) {}),
    );

    expect(find.byIcon(AppIcons.home), findsOneWidget);
    expect(find.byIcon(AppIcons.search), findsOneWidget);
    expect(find.byIcon(AppIcons.profile), findsOneWidget);
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

    final Icon search = tester.widget<Icon>(find.byIcon(AppIcons.search));
    final Icon home = tester.widget<Icon>(find.byIcon(AppIcons.home));
    expect(search.color, AppColors.onPrimaryContainer);
    expect(home.color, AppColors.muted);
  });
}
