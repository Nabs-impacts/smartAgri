import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartagri/design_system/components/app_text_field.dart';

import 'test_app.dart';

void main() {
  testWidgets('renders the hint and accepts text', (WidgetTester tester) async {
    final TextEditingController controller = TextEditingController();
    addTearDown(controller.dispose);
    await pumpComponent(
      tester,
      AppTextField(controller: controller, hintText: 'Numéro de téléphone'),
    );

    expect(find.text('Numéro de téléphone'), findsOneWidget);
    await tester.enterText(find.byType(TextFormField), '+22790000000');
    expect(controller.text, '+22790000000');
  });

  testWidgets('toggles password visibility', (WidgetTester tester) async {
    await pumpComponent(
      tester,
      const AppTextField(hintText: 'Mot de passe', obscure: true),
    );

    EditableText editable = tester.widget<EditableText>(
      find.byType(EditableText),
    );
    expect(editable.obscureText, isTrue);
    expect(find.byIcon(Icons.visibility_outlined), findsOneWidget);

    await tester.tap(find.byIcon(Icons.visibility_outlined));
    await tester.pumpAndSettle();

    editable = tester.widget<EditableText>(find.byType(EditableText));
    expect(editable.obscureText, isFalse);
    expect(find.byIcon(Icons.visibility_off_outlined), findsOneWidget);
  });

  testWidgets('shows the error message', (WidgetTester tester) async {
    await pumpComponent(
      tester,
      const AppTextField(hintText: 'Téléphone', errorText: 'Numéro invalide.'),
    );

    expect(find.text('Numéro invalide.'), findsOneWidget);
  });

  testWidgets('is disabled when enabled is false', (WidgetTester tester) async {
    await pumpComponent(
      tester,
      const AppTextField(hintText: 'Désactivé', enabled: false),
    );

    final TextFormField field = tester.widget<TextFormField>(
      find.byType(TextFormField),
    );
    expect(field.enabled, isFalse);
  });

  testWidgets('renders a custom suffix icon', (WidgetTester tester) async {
    await pumpComponent(
      tester,
      const AppTextField(hintText: 'Recherche', suffixIcon: Icon(Icons.clear)),
    );

    expect(find.byIcon(Icons.clear), findsOneWidget);
  });
}
