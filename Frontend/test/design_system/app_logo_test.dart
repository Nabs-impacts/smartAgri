import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartagri/design_system/components/app_logo.dart';

import 'test_app.dart';

void main() {
  testWidgets('renders the green logo by default', (WidgetTester tester) async {
    await pumpComponent(tester, const AppLogo());

    final SvgPicture logo = tester.widget<SvgPicture>(find.byType(SvgPicture));
    expect(logo.width, 48);
    expect(logo.height, 48);
  });

  testWidgets('renders the lime logo with a custom size', (
    WidgetTester tester,
  ) async {
    await pumpComponent(
      tester,
      const AppLogo(variant: AppLogoVariant.lime, size: 64),
    );

    final SvgPicture logo = tester.widget<SvgPicture>(find.byType(SvgPicture));
    expect(logo.width, 64);
    expect(logo.height, 64);
  });
}
