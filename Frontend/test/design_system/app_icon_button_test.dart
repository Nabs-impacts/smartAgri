import 'package:flutter_test/flutter_test.dart';
import 'package:smartagri/design_system/components/app_icon_button.dart';

import 'package:smartagri/design_system/app_icons.dart';

import 'test_app.dart';

void main() {
  testWidgets('renders a tooltip and handles taps', (
    WidgetTester tester,
  ) async {
    int taps = 0;
    await pumpComponent(
      tester,
      AppIconButton(
        icon: AppIcons.delete,
        tooltip: 'Supprimer',
        onPressed: () => taps++,
        variant: AppIconButtonVariant.danger,
      ),
    );

    expect(find.byTooltip('Supprimer'), findsOneWidget);
    expect(find.byIcon(AppIcons.delete), findsOneWidget);
    await tester.tap(find.byIcon(AppIcons.delete));
    expect(taps, 1);
  });

  testWidgets('renders every variant', (WidgetTester tester) async {
    for (final AppIconButtonVariant variant in AppIconButtonVariant.values) {
      await pumpComponent(
        tester,
        AppIconButton(
          icon: AppIcons.settings,
          tooltip: variant.name,
          onPressed: () {},
          variant: variant,
        ),
      );
      expect(find.byTooltip(variant.name), findsOneWidget);
    }
  });

  testWidgets('is disabled when onPressed is null', (
    WidgetTester tester,
  ) async {
    int taps = 0;
    await pumpComponent(
      tester,
      AppIconButton(
        icon: AppIcons.lock,
        tooltip: 'Verrouillé',
        onPressed: null,
      ),
    );

    await tester.tap(find.byIcon(AppIcons.lock));
    expect(taps, 0);
  });
}
