import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartagri/design_system/components/app_tab_header.dart';

import 'test_app.dart';

void main() {
  testWidgets('shows the title and the optional action', (
    WidgetTester tester,
  ) async {
    await pumpComponent(
      tester,
      const AppTabHeader(title: 'Conseils', action: Icon(Icons.add)),
    );

    expect(find.text('Conseils'), findsOneWidget);
    expect(find.byIcon(Icons.add), findsOneWidget);
  });

  testWidgets('supports a custom text style', (WidgetTester tester) async {
    await pumpComponent(
      tester,
      const AppTabHeader(title: 'Champs', style: TextStyle(fontSize: 18)),
    );

    final Text text = tester.widget<Text>(find.text('Champs'));
    expect(text.style?.fontSize, 18);
    expect(text.maxLines, 2);
  });
}
