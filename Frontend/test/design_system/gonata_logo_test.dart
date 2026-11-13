import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartagri/design_system/components/gonata_logo.dart';
import 'package:smartagri/design_system/theme.dart';

Future<void> _pump(
  WidgetTester tester,
  ThemeData theme, {
  double size = 48,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: theme,
      home: Center(child: GonataLogo(size: size)),
    ),
  );
  await tester.pump();
}

void main() {
  testWidgets('uses the light symbol in the light theme', (
    WidgetTester tester,
  ) async {
    await _pump(tester, AppTheme.light);

    final SvgPicture svg = tester.widget<SvgPicture>(find.byType(SvgPicture));
    final SvgAssetLoader loader = svg.bytesLoader as SvgAssetLoader;
    expect(loader.assetName, GonataLogo.lightAsset);
    expect(svg.width, 48);
    expect(svg.height, 48);
  });

  testWidgets('uses the dark symbol in the dark theme', (
    WidgetTester tester,
  ) async {
    await _pump(tester, AppTheme.dark, size: 64);

    final SvgPicture svg = tester.widget<SvgPicture>(find.byType(SvgPicture));
    final SvgAssetLoader loader = svg.bytesLoader as SvgAssetLoader;
    expect(loader.assetName, GonataLogo.darkAsset);
    expect(svg.width, 64);
    expect(svg.height, 64);
  });

  testWidgets('exposes the GonaTa accessibility label', (
    WidgetTester tester,
  ) async {
    final SemanticsHandle handle = tester.ensureSemantics();
    await _pump(tester, AppTheme.light);

    expect(find.bySemanticsLabel('GonaTa'), findsOneWidget);
    handle.dispose();
  });
}
