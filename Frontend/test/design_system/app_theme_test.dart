import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartagri/design_system/app_palette.dart';
import 'package:smartagri/design_system/theme.dart';
import 'package:smartagri/design_system/tokens.dart';

void main() {
  for (final AppPalette palette in <AppPalette>[
    AppPalette.light,
    AppPalette.dark,
  ]) {
    final ThemeData theme = palette.isDark ? AppTheme.dark : AppTheme.light;
    final String label = palette.brightness.name;

    test('$label theme defines every system component theme', () {
      expect(theme.dialogTheme.shape, isNotNull);
      expect(theme.bottomSheetTheme.shape, isNotNull);
      expect(theme.snackBarTheme.behavior, SnackBarBehavior.floating);
      expect(theme.snackBarTheme.shape, isNotNull);
      expect(theme.datePickerTheme.backgroundColor, palette.surfaceHigh);
      expect(theme.timePickerTheme.backgroundColor, palette.surfaceHigh);
      expect(theme.switchTheme.thumbColor, isNotNull);
      expect(theme.switchTheme.trackColor, isNotNull);
      expect(theme.checkboxTheme.fillColor, isNotNull);
      expect(theme.checkboxTheme.checkColor, isNotNull);
      expect(theme.radioTheme.fillColor, isNotNull);
      expect(theme.progressIndicatorTheme.color, palette.primary);
      expect(theme.chipTheme.shape, isNotNull);
      expect(theme.inputDecorationTheme.filled, isTrue);
      expect(theme.inputDecorationTheme.fillColor, palette.inputFill);
      expect(theme.listTileTheme.textColor, palette.ink);
      expect(theme.popupMenuTheme.color, palette.surfaceHigh);
      expect(theme.tooltipTheme.decoration, isNotNull);
      expect(theme.textButtonTheme.style, isNotNull);
      expect(theme.filledButtonTheme.style, isNotNull);
      expect(theme.outlinedButtonTheme.style, isNotNull);
      expect(theme.appBarTheme.backgroundColor, palette.background);
      expect(theme.navigationBarTheme.indicatorShape, isNotNull);
      expect(theme.extension<AppPalette>(), palette);
    });

    test('$label dialogs and sheets use the 28 radius token', () {
      final RoundedRectangleBorder dialog =
          theme.dialogTheme.shape! as RoundedRectangleBorder;
      final RoundedRectangleBorder sheet =
          theme.bottomSheetTheme.shape! as RoundedRectangleBorder;

      expect(dialog.borderRadius, AppRadii.dialogBorder);
      expect(sheet.borderRadius, AppRadii.sheetTopBorder);
    });
  }
}
