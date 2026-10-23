import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartagri/design_system/components/info_tile.dart';
import 'package:smartagri/design_system/tokens.dart';

import 'test_app.dart';

void main() {
  testWidgets('renders the label with its icon', (WidgetTester tester) async {
    await pumpComponent(tester, const InfoTile(label: 'Vent 15km/h'));

    expect(find.text('Vent 15km/h'), findsOneWidget);
    expect(find.byIcon(Icons.air), findsOneWidget);
    expect(
      tester.widget<Text>(find.text('Vent 15km/h')).style!.color,
      AppColors.muted,
    );
  });
}
