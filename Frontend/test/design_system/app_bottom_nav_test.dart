import 'dart:ui' show Tristate;

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartagri/design_system/app_icons.dart';
import 'package:smartagri/design_system/components/app_bottom_nav.dart';
import 'package:smartagri/design_system/tokens.dart';

import 'test_app.dart';

const List<AppNavItem> items = <AppNavItem>[
  AppNavItem(icon: AppIcons.home, label: 'Accueil'),
  AppNavItem(icon: AppIcons.farm, label: 'Champs'),
  AppNavItem(icon: AppIcons.tips, label: 'Conseils'),
  AppNavItem(icon: AppIcons.more, label: 'Plus'),
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
    expect(find.byIcon(AppIcons.farm), findsOneWidget);
    expect(find.byIcon(AppIcons.tips), findsOneWidget);
    expect(find.byIcon(AppIcons.more), findsOneWidget);
    expect(find.bySemanticsLabel('Champs'), findsOneWidget);
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

    await tester.tap(find.byKey(const ValueKey<String>('app_bottom_nav_3')));
    expect(selected, 3);
  });

  testWidgets('highlights the selected item', (WidgetTester tester) async {
    await pumpComponent(
      tester,
      AppBottomNav(items: items, selectedIndex: 1, onSelected: (_) {}),
    );

    final Icon farms = tester.widget<Icon>(find.byIcon(AppIcons.farm));
    final Icon home = tester.widget<Icon>(find.byIcon(AppIcons.home));
    expect(farms.color, AppColors.onPrimaryContainer);
    expect(home.color, AppColors.muted);
  });

  testWidgets('fits a 320pt screen with a 1.3 text scale', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(
          size: Size(320, 700),
          textScaler: TextScaler.linear(1.3),
        ),
        child: MaterialApp(
          home: Scaffold(
            body: Align(
              alignment: Alignment.bottomCenter,
              child: AppBottomNav(
                items: items,
                selectedIndex: 0,
                onSelected: (_) {},
                centralAction: AppNavAction(
                  icon: AppIcons.scan,
                  label: 'Scanner',
                  onPressed: () {},
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });

  testWidgets('marks the selected tab in semantics', (
    WidgetTester tester,
  ) async {
    await pumpComponent(
      tester,
      AppBottomNav(items: items, selectedIndex: 1, onSelected: (_) {}),
    );

    final SemanticsNode selected = tester.getSemantics(
      find.byKey(const ValueKey<String>('app_bottom_nav_1')),
    );
    final SemanticsNode other = tester.getSemantics(
      find.byKey(const ValueKey<String>('app_bottom_nav_0')),
    );
    expect(selected.flagsCollection.isSelected, Tristate.isTrue);
    expect(other.flagsCollection.isSelected, Tristate.isFalse);
  });

  testWidgets('exposes the central action outside the tabs', (
    WidgetTester tester,
  ) async {
    int scans = 0;
    await pumpComponent(
      tester,
      AppBottomNav(
        items: items,
        selectedIndex: 0,
        onSelected: (_) {},
        centralAction: AppNavAction(
          icon: AppIcons.scan,
          label: 'Scanner',
          onPressed: () => scans++,
        ),
      ),
    );

    expect(find.byKey(const ValueKey<String>('app_bottom_nav_scan')), findsOne);
    expect(find.bySemanticsLabel('Scanner'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey<String>('app_bottom_nav_scan')));
    expect(scans, 1);
  });
}
