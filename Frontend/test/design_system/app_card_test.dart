import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartagri/design_system/components/app_card.dart';
import 'package:smartagri/design_system/tokens.dart';

import 'test_app.dart';

void main() {
  testWidgets('renders its child with the card decoration', (
    WidgetTester tester,
  ) async {
    await pumpComponent(tester, const AppCard(child: Text('Contenu')));

    expect(find.text('Contenu'), findsOneWidget);
    final Container container = tester.widget<Container>(
      find.descendant(
        of: find.byType(AppCard),
        matching: find.byType(Container),
      ),
    );
    final BoxDecoration decoration = container.decoration! as BoxDecoration;
    expect(decoration.color, AppColors.white);
    expect(decoration.borderRadius, AppRadii.cardBorder);
  });
}
