import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartagri/core/i18n/app_language.dart';
import 'package:smartagri/design_system/components/language_switcher.dart';
import 'package:smartagri/design_system/tokens.dart';

import 'test_app.dart';

void main() {
  testWidgets('renders the three languages and changes selection', (
    WidgetTester tester,
  ) async {
    AppLanguage value = AppLanguage.fr;
    await pumpComponent(
      tester,
      StatefulBuilder(
        builder: (BuildContext context, StateSetter setState) {
          return LanguageSwitcher(
            value: value,
            onChanged: (AppLanguage language) =>
                setState(() => value = language),
          );
        },
      ),
    );

    expect(find.text('FR'), findsOneWidget);
    expect(find.text('HA'), findsOneWidget);
    expect(find.text('ZA'), findsOneWidget);

    await tester.tap(find.text('HA'));
    await tester.pumpAndSettle();
    expect(value, AppLanguage.ha);
    expect(tester.widget<Text>(find.text('HA')).style!.color, AppColors.white);
    expect(
      tester.widget<Text>(find.text('FR')).style!.color,
      AppColors.primary,
    );

    await tester.tap(find.text('ZA'));
    await tester.pumpAndSettle();
    expect(value, AppLanguage.dje);
  });
}
