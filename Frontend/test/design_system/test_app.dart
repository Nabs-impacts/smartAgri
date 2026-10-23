import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartagri/design_system/theme.dart';

Widget testApp(Widget child) {
  return MaterialApp(
    theme: AppTheme.light,
    home: Scaffold(body: Center(child: child)),
  );
}

Future<void> pumpComponent(WidgetTester tester, Widget child) async {
  await tester.pumpWidget(testApp(child));
  await tester.pumpAndSettle();
}
