import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartagri/design_system/components/app_status_chip.dart';

import 'test_app.dart';

void main() {
  testWidgets('renders every variant with its key and label', (
    WidgetTester tester,
  ) async {
    for (final AppStatusChipVariant variant in AppStatusChipVariant.values) {
      await pumpComponent(
        tester,
        AppStatusChip(label: 'Statut ${variant.name}', variant: variant),
      );

      expect(find.byKey(Key('status_chip_${variant.name}')), findsOneWidget);
      expect(find.text('Statut ${variant.name}'), findsOneWidget);
    }
  });

  testWidgets('defaults to the neutral variant', (WidgetTester tester) async {
    await pumpComponent(tester, const AppStatusChip(label: 'Neutre'));

    expect(find.byKey(const Key('status_chip_neutral')), findsOneWidget);
  });
}
