import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartagri/design_system/components/app_select_field.dart';
import 'package:smartagri/design_system/tokens.dart';

import 'test_app.dart';

void main() {
  testWidgets('opens the sheet and returns the selected option', (
    WidgetTester tester,
  ) async {
    String? changed;
    await pumpComponent(
      tester,
      AppSelectField<String>(
        hintText: 'Région',
        options: const <AppSelectOption<String>>[
          AppSelectOption<String>(value: 'niamey', label: 'Niamey'),
          AppSelectOption<String>(value: 'dosso', label: 'Dosso'),
        ],
        value: null,
        onChanged: (String? value) => changed = value,
      ),
    );

    expect(find.text('Région'), findsOneWidget);
    await tester.tap(find.byType(AppSelectField<String>));
    await tester.pumpAndSettle();

    expect(find.text('Niamey'), findsOneWidget);
    expect(find.text('Dosso'), findsOneWidget);
    await tester.tap(find.text('Dosso'));
    await tester.pumpAndSettle();

    expect(changed, 'dosso');
    expect(find.text('Dosso'), findsNothing);
  });

  testWidgets('shows the error state and supports an empty option', (
    WidgetTester tester,
  ) async {
    bool called = false;
    await pumpComponent(
      tester,
      AppSelectField<String>(
        hintText: 'Région',
        options: const <AppSelectOption<String>>[
          AppSelectOption<String>(value: 'niamey', label: 'Niamey'),
        ],
        value: 'niamey',
        allowEmpty: true,
        emptyLabel: 'Aucune région',
        errorText: 'Champ obligatoire.',
        onChanged: (String? value) => called = true,
      ),
    );

    expect(find.text('Niamey'), findsOneWidget);
    expect(find.text('Champ obligatoire.'), findsOneWidget);

    await tester.tap(find.byType(AppSelectField<String>));
    await tester.pumpAndSettle();
    expect(find.text('Aucune région'), findsOneWidget);
    await tester.tap(find.text('Aucune région'));
    await tester.pumpAndSettle();

    expect(called, isTrue);
  });

  testWidgets('is inert when onChanged is null', (WidgetTester tester) async {
    await pumpComponent(
      tester,
      const AppSelectField<String>(
        hintText: 'Région',
        options: <AppSelectOption<String>>[],
        value: null,
        onChanged: null,
      ),
    );

    await tester.tap(find.byType(AppSelectField<String>));
    await tester.pumpAndSettle();

    expect(find.byType(BottomSheet), findsNothing);
  });

  testWidgets('uses a 52 dp pill height', (WidgetTester tester) async {
    await pumpComponent(
      tester,
      const AppSelectField<String>(
        hintText: 'Région',
        options: <AppSelectOption<String>>[],
        value: null,
        onChanged: null,
      ),
    );

    final Size size = tester.getSize(find.byType(AppSelectField<String>));
    expect(size.height, AppSizes.fieldHeight);
  });
}
