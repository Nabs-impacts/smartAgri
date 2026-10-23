import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartagri/design_system/components/app_button.dart';
import 'package:smartagri/design_system/tokens.dart';

import 'test_app.dart';

void main() {
  testWidgets('renders the label and handles taps', (
    WidgetTester tester,
  ) async {
    int taps = 0;
    await pumpComponent(
      tester,
      AppButton(label: 'Valider', onPressed: () => taps++),
    );

    expect(find.text('Valider'), findsOneWidget);
    await tester.tap(find.byType(AppButton));
    expect(taps, 1);
  });

  testWidgets('renders every variant and size', (WidgetTester tester) async {
    for (final AppButtonVariant variant in AppButtonVariant.values) {
      await pumpComponent(
        tester,
        AppButton(label: variant.name, onPressed: () {}, variant: variant),
      );
      expect(find.text(variant.name), findsOneWidget);
    }
    await pumpComponent(
      tester,
      AppButton(
        label: 'Compact',
        onPressed: () {},
        size: AppButtonSize.compact,
      ),
    );
    expect(find.text('Compact'), findsOneWidget);
  });

  testWidgets('shows a loader and disables taps while loading', (
    WidgetTester tester,
  ) async {
    int taps = 0;
    await tester.pumpWidget(
      testApp(
        AppButton(label: 'Connexion', onPressed: () => taps++, loading: true),
      ),
    );
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Connexion'), findsNothing);
    await tester.tap(find.byType(AppButton));
    expect(taps, 0);
  });

  testWidgets('is disabled when onPressed is null', (
    WidgetTester tester,
  ) async {
    await pumpComponent(
      tester,
      const AppButton(label: 'Désactivé', onPressed: null),
    );

    expect(find.text('Désactivé'), findsOneWidget);
    final Finder opacity = find.ancestor(
      of: find.text('Désactivé'),
      matching: find.byType(Opacity),
    );
    expect(tester.widget<Opacity>(opacity.first).opacity, AppOpacity.disabled);
  });

  testWidgets('renders an optional leading icon', (WidgetTester tester) async {
    await pumpComponent(
      tester,
      AppButton(
        label: 'Ajouter',
        onPressed: () {},
        icon: const Icon(Icons.add),
      ),
    );

    expect(find.byIcon(Icons.add), findsOneWidget);
  });
}
