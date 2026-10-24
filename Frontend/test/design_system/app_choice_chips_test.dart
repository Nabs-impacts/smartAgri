import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartagri/design_system/components/app_choice_chips.dart';
import 'package:smartagri/design_system/tokens.dart';

import 'test_app.dart';

void main() {
  testWidgets('renders the options and returns the tapped value', (
    WidgetTester tester,
  ) async {
    String? changed;
    await pumpComponent(
      tester,
      AppChoiceChips<String>(
        options: const <AppChoiceOption<String>>[
          AppChoiceOption<String>(value: 'sandy', label: 'Sableux'),
          AppChoiceOption<String>(value: 'loam', label: 'Limoneux'),
        ],
        value: 'loam',
        onChanged: (String value) => changed = value,
      ),
    );

    expect(find.text('Sableux'), findsOneWidget);
    expect(find.text('Limoneux'), findsOneWidget);

    await tester.tap(find.text('Sableux'));
    await tester.pumpAndSettle();

    expect(changed, 'sandy');
  });

  testWidgets('uses the primary color for the selected chip only', (
    WidgetTester tester,
  ) async {
    await pumpComponent(
      tester,
      const AppChoiceChips<String>(
        options: <AppChoiceOption<String>>[
          AppChoiceOption<String>(value: 'sandy', label: 'Sableux'),
          AppChoiceOption<String>(value: 'loam', label: 'Limoneux'),
        ],
        value: 'loam',
        onChanged: _ignore,
      ),
    );

    final Material selected = tester.widget<Material>(
      find
          .ancestor(of: find.text('Limoneux'), matching: find.byType(Material))
          .first,
    );
    final Material unselected = tester.widget<Material>(
      find
          .ancestor(of: find.text('Sableux'), matching: find.byType(Material))
          .first,
    );
    final Text selectedText = tester.widget<Text>(find.text('Limoneux'));
    final Text unselectedText = tester.widget<Text>(find.text('Sableux'));

    expect(selected.color, AppColors.primary);
    expect(selectedText.style?.color, AppColors.white);
    expect(unselected.color, AppColors.surface);
    expect(unselectedText.style?.color, AppColors.ink);
  });

  testWidgets('uses a 48 dp touch target', (WidgetTester tester) async {
    await pumpComponent(
      tester,
      AppChoiceChips<String>(
        options: const <AppChoiceOption<String>>[
          AppChoiceOption<String>(value: 'sandy', label: 'Sableux'),
        ],
        value: 'sandy',
        onChanged: (String value) {},
      ),
    );

    final Size size = tester.getSize(find.text('Sableux'));
    final Size target = tester.getSize(
      find
          .ancestor(of: find.text('Sableux'), matching: find.byType(SizedBox))
          .first,
    );
    expect(size.height, lessThan(AppSizes.touchTarget));
    expect(target.height, AppSizes.touchTarget);
  });
}

void _ignore(String value) {}
