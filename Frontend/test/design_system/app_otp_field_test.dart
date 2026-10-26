import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartagri/design_system/components/app_otp_field.dart';
import 'package:smartagri/design_system/theme.dart';
import 'package:smartagri/design_system/tokens.dart';

Future<void> pumpOtpField(
  WidgetTester tester, {
  ValueChanged<String>? onChanged,
  ValueChanged<String>? onCompleted,
  bool error = false,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light,
      home: Scaffold(
        body: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: AppOtpField(
            onChanged: onChanged,
            onCompleted: onCompleted,
            error: error,
          ),
        ),
      ),
    ),
  );
}

String digitText(WidgetTester tester, int index) {
  return tester
      .widget<EditableText>(
        find.descendant(
          of: find.byKey(Key('otp_digit_$index')),
          matching: find.byType(EditableText),
        ),
      )
      .controller
      .text;
}

bool digitHasFocus(WidgetTester tester, int index) {
  return tester
      .widget<TextField>(find.byKey(Key('otp_digit_$index')))
      .focusNode!
      .hasFocus;
}

BoxDecoration boxDecoration(WidgetTester tester, int index) {
  final AnimatedContainer container = tester.widget<AnimatedContainer>(
    find.ancestor(
      of: find.byKey(Key('otp_digit_$index')),
      matching: find.byType(AnimatedContainer),
    ),
  );
  return container.decoration! as BoxDecoration;
}

void main() {
  testWidgets('renders six digits and advances automatically', (
    WidgetTester tester,
  ) async {
    await pumpOtpField(tester);

    expect(find.byType(AppOtpField), findsOneWidget);
    for (int index = 0; index < 6; index++) {
      expect(find.byKey(Key('otp_digit_$index')), findsOneWidget);
    }

    await tester.enterText(find.byKey(const Key('otp_digit_0')), '1');
    await tester.pump();

    expect(digitText(tester, 0), '1');
    expect(digitHasFocus(tester, 1), isTrue);
  });

  testWidgets('backspace clears the box and returns to the previous one', (
    WidgetTester tester,
  ) async {
    await pumpOtpField(tester);

    await tester.enterText(find.byKey(const Key('otp_digit_0')), '1');
    await tester.pump();
    await tester.enterText(find.byKey(const Key('otp_digit_1')), '2');
    await tester.pump();

    await tester.enterText(find.byKey(const Key('otp_digit_1')), '');
    await tester.pump();

    expect(digitText(tester, 1), isEmpty);
    expect(digitHasFocus(tester, 0), isTrue);
  });

  testWidgets('accepts pasting a six digit code', (WidgetTester tester) async {
    final List<String> values = <String>[];
    await pumpOtpField(tester, onChanged: values.add);

    await tester.enterText(find.byKey(const Key('otp_digit_0')), '123456');
    await tester.pump();

    expect(
      <String>[
        digitText(tester, 0),
        digitText(tester, 1),
        digitText(tester, 2),
        digitText(tester, 3),
        digitText(tester, 4),
        digitText(tester, 5),
      ],
      <String>['1', '2', '3', '4', '5', '6'],
    );
    expect(values.last, '123456');
  });

  testWidgets('reports completion once the code is complete', (
    WidgetTester tester,
  ) async {
    final List<String> completed = <String>[];
    await pumpOtpField(tester, onCompleted: completed.add);

    await tester.enterText(find.byKey(const Key('otp_digit_0')), '123456');
    await tester.pump();

    expect(completed, <String>['123456']);
  });

  testWidgets('shows the primary border on the active box', (
    WidgetTester tester,
  ) async {
    await pumpOtpField(tester);

    await tester.tap(find.byKey(const Key('otp_digit_0')));
    await tester.pump();

    expect(boxDecoration(tester, 0).border!.top.color, AppColors.primary);
  });

  testWidgets('shows the danger border when in error', (
    WidgetTester tester,
  ) async {
    await pumpOtpField(tester, error: true);

    for (int index = 0; index < 6; index++) {
      expect(boxDecoration(tester, index).border!.top.color, AppColors.danger);
    }
  });

  testWidgets('exposes a semantics label', (WidgetTester tester) async {
    await pumpOtpField(tester);

    expect(
      tester.getSemantics(find.byType(AppOtpField)).label,
      contains('Code de vérification'),
    );
  });
}
