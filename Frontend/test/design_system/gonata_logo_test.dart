import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartagri/design_system/components/gonata_logo.dart';
import 'package:smartagri/design_system/theme.dart';

Future<void> _pump(
  WidgetTester tester,
  ThemeData theme, {
  Widget logo = const GonataLogo(),
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: theme,
      home: Center(child: logo),
    ),
  );
  await tester.pump();
}

SvgAssetLoader _loader(WidgetTester tester) {
  final SvgPicture svg = tester.widget<SvgPicture>(find.byType(SvgPicture));
  return svg.bytesLoader as SvgAssetLoader;
}

void main() {
  testWidgets('uses the light symbol in the light theme', (
    WidgetTester tester,
  ) async {
    await _pump(tester, AppTheme.light, logo: const GonataLogo(size: 48));

    final SvgPicture svg = tester.widget<SvgPicture>(find.byType(SvgPicture));
    expect(_loader(tester).assetName, GonataLogo.lightAsset);
    expect(svg.width, 48);
    expect(svg.height, 48);
  });

  testWidgets('uses the dark symbol in the dark theme', (
    WidgetTester tester,
  ) async {
    await _pump(tester, AppTheme.dark, logo: const GonataLogo.symbol(size: 64));

    final SvgPicture svg = tester.widget<SvgPicture>(find.byType(SvgPicture));
    expect(_loader(tester).assetName, GonataLogo.darkAsset);
    expect(svg.width, 64);
    expect(svg.height, 64);
  });

  testWidgets('uses the full light logo with a width', (
    WidgetTester tester,
  ) async {
    await _pump(
      tester,
      AppTheme.light,
      logo: const GonataLogo.full(width: 196),
    );

    final SvgPicture svg = tester.widget<SvgPicture>(find.byType(SvgPicture));
    expect(_loader(tester).assetName, GonataLogo.lightFullAsset);
    expect(svg.width, 196);
    expect(svg.height, isNull);
  });

  testWidgets('uses the full dark logo with a width', (
    WidgetTester tester,
  ) async {
    await _pump(tester, AppTheme.dark, logo: const GonataLogo.full(width: 132));

    final SvgPicture svg = tester.widget<SvgPicture>(find.byType(SvgPicture));
    expect(_loader(tester).assetName, GonataLogo.darkFullAsset);
    expect(svg.width, 132);
    expect(svg.height, isNull);
  });

  testWidgets('exposes the GonaTa accessibility label for both variants', (
    WidgetTester tester,
  ) async {
    final SemanticsHandle handle = tester.ensureSemantics();
    await _pump(tester, AppTheme.light);

    expect(find.bySemanticsLabel('GonaTa'), findsOneWidget);

    await _pump(
      tester,
      AppTheme.light,
      logo: const GonataLogo.full(width: 196),
    );

    expect(find.bySemanticsLabel('GonaTa'), findsOneWidget);
    handle.dispose();
  });
}
