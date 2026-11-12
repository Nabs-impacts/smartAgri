import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_palette.dart';
import 'tokens.dart';

abstract final class AppTheme {
  static const SystemUiOverlayStyle lightOverlayStyle = SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
    statusBarBrightness: Brightness.light,
    systemNavigationBarColor: AppColors.background,
    systemNavigationBarIconBrightness: Brightness.dark,
    systemNavigationBarDividerColor: AppColors.background,
  );

  static const SystemUiOverlayStyle darkOverlayStyle = SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    statusBarBrightness: Brightness.dark,
    systemNavigationBarColor: Color(0xFF161814),
    systemNavigationBarIconBrightness: Brightness.light,
    systemNavigationBarDividerColor: Color(0xFF161814),
  );

  static ThemeData get light => _build(AppPalette.light, Brightness.light);

  static ThemeData get dark => _build(AppPalette.dark, Brightness.dark);

  static ThemeData _build(AppPalette palette, Brightness brightness) {
    final bool isDark = brightness == Brightness.dark;
    final ColorScheme colors = isDark
        ? ColorScheme.dark(
            primary: palette.primary,
            onPrimary: palette.onPrimary,
            primaryContainer: palette.primaryContainer,
            onPrimaryContainer: palette.onPrimaryContainer,
            secondary: palette.secondary,
            onSecondary: palette.onSecondary,
            secondaryContainer: palette.secondaryContainer,
            onSecondaryContainer: palette.onSecondaryContainer,
            tertiary: palette.tertiary,
            onTertiary: palette.onPrimary,
            error: palette.danger,
            onError: palette.onDanger,
            surface: palette.surface,
            onSurface: palette.ink,
            outline: palette.line,
            outlineVariant: palette.line,
            inverseSurface: palette.inverted,
            onInverseSurface: palette.onInverted,
            scrim: palette.scrim,
          )
        : const ColorScheme.light(
            primary: AppColors.primary,
            onPrimary: AppColors.white,
            primaryContainer: AppColors.primaryContainer,
            onPrimaryContainer: AppColors.ink,
            secondary: AppColors.secondary,
            onSecondary: AppColors.white,
            secondaryContainer: AppColors.secondaryContainer,
            onSecondaryContainer: AppColors.ink,
            tertiary: AppColors.tertiary,
            onTertiary: AppColors.white,
            error: AppColors.danger,
            onError: AppColors.white,
            surface: AppColors.surface,
            onSurface: AppColors.ink,
          );

    final ThemeData base = ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colors,
      fontFamily: AppTypography.fontFamily,
      scaffoldBackgroundColor: palette.background,
      textTheme: TextTheme(
        headlineLarge: AppTextStyles.headline,
        headlineMedium: AppTextStyles.title,
        titleLarge: AppTextStyles.title,
        titleMedium: AppTextStyles.label,
        bodyLarge: AppTextStyles.body,
        bodyMedium: AppTextStyles.body,
        bodySmall: AppTextStyles.caption,
        labelLarge: AppTextStyles.label,
        labelMedium: AppTextStyles.label,
        labelSmall: AppTextStyles.caption,
      ).apply(bodyColor: palette.ink, displayColor: palette.ink),
      appBarTheme: AppBarTheme(
        backgroundColor: palette.background,
        foregroundColor: palette.ink,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: AppTextStyles.title.copyWith(color: palette.ink),
        systemOverlayStyle: isDark ? darkOverlayStyle : lightOverlayStyle,
      ),
      dividerColor: palette.line,
      splashColor: palette.primaryContainer,
      highlightColor: Colors.transparent,
      extensions: <ThemeExtension<dynamic>>[palette],
    );

    if (!isDark) {
      return base;
    }
    return base.copyWith(
      dialogTheme: DialogThemeData(
        backgroundColor: palette.surfaceRaised,
        titleTextStyle: AppTextStyles.title.copyWith(color: palette.ink),
        contentTextStyle: AppTextStyles.body.copyWith(color: palette.ink),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: palette.surfaceRaised,
        modalBackgroundColor: palette.surfaceRaised,
        surfaceTintColor: Colors.transparent,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: palette.inverted,
        contentTextStyle: AppTextStyles.body.copyWith(
          color: palette.onInverted,
        ),
        actionTextColor: palette.primary,
      ),
      dividerTheme: DividerThemeData(color: palette.line),
      iconTheme: IconThemeData(color: palette.ink),
    );
  }
}
