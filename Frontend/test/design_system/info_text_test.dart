import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartagri/design_system/components/info_text.dart';
import 'package:smartagri/design_system/tokens.dart';

import 'test_app.dart';

void main() {
  testWidgets('renders green information text', (WidgetTester tester) async {
    await pumpComponent(tester, const InfoText('Sol propice'));

    final Text text = tester.widget<Text>(find.text('Sol propice'));
    expect(text.style!.color, AppColors.tertiary);
  });
}
