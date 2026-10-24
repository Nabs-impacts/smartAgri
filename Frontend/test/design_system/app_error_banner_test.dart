import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartagri/design_system/components/app_error_banner.dart';
import 'package:smartagri/design_system/tokens.dart';

import 'test_app.dart';

void main() {
  testWidgets('renders the alert icon and message', (
    WidgetTester tester,
  ) async {
    await pumpComponent(
      tester,
      const AppErrorBanner(message: 'Une erreur est survenue.'),
    );

    expect(find.text('Une erreur est survenue.'), findsOneWidget);
    expect(find.byIcon(Icons.warning_amber_rounded), findsOneWidget);
  });

  testWidgets('uses a very light red rounded background', (
    WidgetTester tester,
  ) async {
    await pumpComponent(tester, const AppErrorBanner(message: 'Erreur'));

    final Container container = tester.widget<Container>(
      find.descendant(
        of: find.byType(AppErrorBanner),
        matching: find.byType(Container),
      ),
    );
    final BoxDecoration decoration = container.decoration! as BoxDecoration;
    expect(decoration.color, const Color(0xFFFFEBEE));
    expect(
      decoration.borderRadius,
      const BorderRadius.all(Radius.circular(12)),
    );
    final Text text = tester.widget<Text>(find.text('Erreur'));
    expect(text.style?.color, AppColors.danger);
  });

  testWidgets('exposes the alert semantic role', (WidgetTester tester) async {
    await pumpComponent(tester, const AppErrorBanner(message: 'Alerte'));

    final SemanticsNode node = tester.getSemantics(find.byType(AppErrorBanner));
    expect(node.getSemanticsData().role, SemanticsRole.alert);
    expect(node.getSemanticsData().label, contains('Alerte'));
  });
}
