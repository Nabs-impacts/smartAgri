import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartagri/design_system/components/app_icon_button.dart';

import 'test_app.dart';

void main() {
  testWidgets('renders a tooltip and handles taps', (
    WidgetTester tester,
  ) async {
    int taps = 0;
    await pumpComponent(
      tester,
      AppIconButton(
        icon: Icons.delete_outline,
        tooltip: 'Supprimer',
        onPressed: () => taps++,
        variant: AppIconButtonVariant.danger,
      ),
    );

    expect(find.byTooltip('Supprimer'), findsOneWidget);
    expect(find.byIcon(Icons.delete_outline), findsOneWidget);
    await tester.tap(find.byIcon(Icons.delete_outline));
    expect(taps, 1);
  });

  testWidgets('renders every variant', (WidgetTester tester) async {
    for (final AppIconButtonVariant variant in AppIconButtonVariant.values) {
      await pumpComponent(
        tester,
        AppIconButton(
          icon: Icons.tune,
          tooltip: variant.name,
          onPressed: () {},
          variant: variant,
        ),
      );
      expect(find.byTooltip(variant.name), findsOneWidget);
    }
  });

  testWidgets('is disabled when onPressed is null', (
    WidgetTester tester,
  ) async {
    int taps = 0;
    await pumpComponent(
      tester,
      AppIconButton(
        icon: Icons.lock_outline,
        tooltip: 'Verrouillé',
        onPressed: null,
      ),
    );

    await tester.tap(find.byIcon(Icons.lock_outline));
    expect(taps, 0);
  });
}
