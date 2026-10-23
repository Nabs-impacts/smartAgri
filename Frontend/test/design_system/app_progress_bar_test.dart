import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartagri/design_system/components/app_progress_bar.dart';
import 'package:smartagri/design_system/tokens.dart';

import 'test_app.dart';

void main() {
  testWidgets('renders the given value and colour', (
    WidgetTester tester,
  ) async {
    await pumpComponent(
      tester,
      const AppProgressBar(value: 0.5, color: AppColors.secondary),
    );

    final LinearProgressIndicator indicator = tester
        .widget<LinearProgressIndicator>(find.byType(LinearProgressIndicator));
    expect(indicator.value, 0.5);
    expect(indicator.color, AppColors.secondary);
    expect(indicator.minHeight, AppSizes.progress);
  });

  testWidgets('clamps values outside zero and one', (
    WidgetTester tester,
  ) async {
    await pumpComponent(tester, const AppProgressBar(value: 2));

    final LinearProgressIndicator indicator = tester
        .widget<LinearProgressIndicator>(find.byType(LinearProgressIndicator));
    expect(indicator.value, 1);
  });
}
