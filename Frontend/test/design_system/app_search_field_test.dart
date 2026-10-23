import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartagri/design_system/components/app_search_field.dart';

import 'test_app.dart';

void main() {
  testWidgets('renders the search icon and hint', (WidgetTester tester) async {
    await pumpComponent(tester, const AppSearchField());

    expect(find.byIcon(Icons.search), findsOneWidget);
    expect(find.text('Rechercher'), findsOneWidget);
  });

  testWidgets('reports the typed text', (WidgetTester tester) async {
    String value = '';
    await pumpComponent(
      tester,
      AppSearchField(onChanged: (String text) => value = text),
    );

    await tester.enterText(find.byType(TextField), 'maïs');
    expect(value, 'maïs');
  });
}
