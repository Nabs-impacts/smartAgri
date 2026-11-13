import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartagri/design_system/app_palette.dart';
import 'package:smartagri/design_system/theme.dart';
import 'package:smartagri/design_system/tokens.dart';

void main() {
  test('displayAccent uses Anton with a Plus Jakarta Sans fallback', () {
    expect(AppTextStyles.displayAccent.fontFamily, 'Anton');
    expect(
      AppTextStyles.displayAccent.fontFamilyFallback,
      contains('PlusJakartaSans'),
    );
    expect(AppTextStyles.displayAccent.fontWeight, FontWeight.w800);
  });

  test('the type scale stays within the agreed sizes', () {
    expect(AppTextStyles.displayAccent.fontSize, inInclusiveRange(32, 40));
    expect(AppTextStyles.display.fontSize, inInclusiveRange(32, 40));
    expect(AppTextStyles.headline.fontSize, 24);
    expect(AppTextStyles.title.fontSize, inInclusiveRange(18, 20));
    expect(AppTextStyles.subtitle.fontSize, inInclusiveRange(18, 20));
    expect(AppTextStyles.body.fontSize, 16);
    expect(AppTextStyles.label.fontSize, 14);
    expect(AppTextStyles.caption.fontSize, 12);
  });

  test('pubspec declares Anton and Plus Jakarta Sans', () {
    final String pubspec = File('pubspec.yaml').readAsStringSync();

    expect(pubspec, contains('family: Anton'));
    expect(pubspec, contains('assets/fonts/Anton-Regular.ttf'));
    expect(pubspec, contains('family: PlusJakartaSans'));
    expect(pubspec, contains('assets/fonts/PlusJakartaSans-ExtraBold.ttf'));
  });

  testWidgets('the theme reads text colors from the current palette', (
    WidgetTester tester,
  ) async {
    for (final AppPalette palette in <AppPalette>[
      AppPalette.light,
      AppPalette.dark,
    ]) {
      final ThemeData theme = palette.isDark ? AppTheme.dark : AppTheme.light;
      expect(theme.textTheme.bodyLarge?.color, palette.ink);
      expect(theme.textTheme.headlineLarge?.color, palette.ink);
      expect(theme.textTheme.labelLarge?.color, palette.ink);
      expect(theme.textTheme.bodyLarge?.fontFamily, AppTypography.fontFamily);
    }
  });
}
