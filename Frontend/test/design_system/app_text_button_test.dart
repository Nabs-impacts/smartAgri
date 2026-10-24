import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartagri/design_system/components/app_text_button.dart';
import 'package:smartagri/design_system/tokens.dart';

import 'test_app.dart';

void main() {
  testWidgets('renders the primary variant and handles taps', (
    WidgetTester tester,
  ) async {
    int taps = 0;
    await pumpComponent(
      tester,
      AppTextButton(label: 'Créer un compte', onPressed: () => taps++),
    );

    final Text text = tester.widget<Text>(find.text('Créer un compte'));
    expect(text.style?.color, AppColors.primary);

    await tester.tap(find.byType(AppTextButton));
    await tester.pumpAndSettle();
    expect(taps, 1);
  });

  testWidgets('renders the muted variant', (WidgetTester tester) async {
    await pumpComponent(
      tester,
      AppTextButton(
        label: 'Mot de passe oublié',
        variant: AppTextButtonVariant.muted,
        onPressed: () {},
      ),
    );

    final Text text = tester.widget<Text>(find.text('Mot de passe oublié'));
    expect(text.style?.color, AppColors.muted);
  });

  testWidgets('is disabled when onPressed is null', (
    WidgetTester tester,
  ) async {
    await pumpComponent(
      tester,
      const AppTextButton(label: 'Désactivé', onPressed: null),
    );

    await tester.tap(find.byType(AppTextButton));
    await tester.pumpAndSettle();

    expect(find.text('Désactivé'), findsOneWidget);
  });
}
