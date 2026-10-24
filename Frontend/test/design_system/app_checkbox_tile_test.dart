import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartagri/design_system/components/app_checkbox_tile.dart';
import 'package:smartagri/design_system/tokens.dart';

import 'test_app.dart';

void main() {
  testWidgets('renders the label and toggles the value', (
    WidgetTester tester,
  ) async {
    bool? changed;
    await pumpComponent(
      tester,
      AppCheckboxTile(
        label: 'Se souvenir de moi',
        value: true,
        onChanged: (bool value) => changed = value,
      ),
    );

    expect(find.text('Se souvenir de moi'), findsOneWidget);
    expect(find.byIcon(Icons.check), findsOneWidget);

    await tester.tap(find.byType(AppCheckboxTile));
    await tester.pumpAndSettle();

    expect(changed, isFalse);
  });

  testWidgets('uses a 48 dp touch target and hides the check when unchecked', (
    WidgetTester tester,
  ) async {
    await pumpComponent(
      tester,
      AppCheckboxTile(
        label: 'Recherche',
        value: false,
        onChanged: (bool value) {},
      ),
    );

    final Size size = tester.getSize(find.byType(AppCheckboxTile));
    expect(size.height, AppSizes.touchTarget);
    expect(find.byIcon(Icons.check), findsNothing);
  });

  testWidgets('is inert when onChanged is null', (WidgetTester tester) async {
    await pumpComponent(
      tester,
      const AppCheckboxTile(label: 'Désactivé', value: true, onChanged: null),
    );

    await tester.tap(find.byType(AppCheckboxTile));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.check), findsOneWidget);
  });
}
