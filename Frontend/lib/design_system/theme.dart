import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/router/app_page.dart';
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
    systemNavigationBarColor: Color(0xFF121411),
    systemNavigationBarIconBrightness: Brightness.light,
    systemNavigationBarDividerColor: Color(0xFF121411),
  );

  static ThemeData get light => _build(AppPalette.light);

  static ThemeData get dark => _build(AppPalette.dark);

  static ThemeData _build(AppPalette palette) {
    final ColorScheme colors = ColorScheme(
      brightness: palette.brightness,
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
      errorContainer: palette.dangerContainer,
      onErrorContainer: palette.onDangerContainer,
      surface: palette.background,
      onSurface: palette.ink,
      onSurfaceVariant: palette.muted,
      outline: palette.line,
      outlineVariant: palette.line,
      inverseSurface: palette.inverted,
      onInverseSurface: palette.onInverted,
      scrim: palette.scrim,
    );

    final TextTheme textTheme = TextTheme(
      displayLarge: AppTextStyles.display,
      displayMedium: AppTextStyles.display,
      displaySmall: AppTextStyles.headline,
      headlineLarge: AppTextStyles.headline,
      headlineMedium: AppTextStyles.headline,
      headlineSmall: AppTextStyles.title,
      titleLarge: AppTextStyles.title,
      titleMedium: AppTextStyles.subtitle,
      titleSmall: AppTextStyles.label,
      bodyLarge: AppTextStyles.body,
      bodyMedium: AppTextStyles.body,
      bodySmall: AppTextStyles.caption,
      labelLarge: AppTextStyles.label,
      labelMedium: AppTextStyles.label,
      labelSmall: AppTextStyles.caption,
    ).apply(bodyColor: palette.ink, displayColor: palette.ink);

    final RoundedRectangleBorder pill = RoundedRectangleBorder(
      borderRadius: AppRadii.pillBorder,
    );
    final RoundedRectangleBorder dialogShape = RoundedRectangleBorder(
      borderRadius: AppRadii.dialogBorder,
    );
    final RoundedRectangleBorder sheetShape = RoundedRectangleBorder(
      borderRadius: AppRadii.sheetTopBorder,
    );
    final RoundedRectangleBorder smallShape = RoundedRectangleBorder(
      borderRadius: AppRadii.smallBorder,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: palette.brightness,
      colorScheme: colors,
      fontFamily: AppTypography.fontFamily,
      scaffoldBackgroundColor: palette.background,
      canvasColor: palette.background,
      cardColor: palette.surfaceRaised,
      dividerColor: palette.line,
      splashColor: palette.primaryContainer,
      highlightColor: Colors.transparent,
      textTheme: textTheme,
      extensions: <ThemeExtension<dynamic>>[palette],
      pageTransitionsTheme: appPageTransitionsTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: palette.background,
        foregroundColor: palette.ink,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: AppTextStyles.title.copyWith(color: palette.ink),
        iconTheme: IconThemeData(color: palette.ink, size: AppSizes.icon),
        systemOverlayStyle: palette.isDark
            ? darkOverlayStyle
            : lightOverlayStyle,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: palette.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        height: AppSizes.navHeight,
        indicatorColor: palette.primaryContainer,
        indicatorShape: const StadiumBorder(),
        labelTextStyle: WidgetStateProperty.resolveWith<TextStyle>(
          (Set<WidgetState> states) => AppTextStyles.caption.copyWith(
            color: states.contains(WidgetState.selected)
                ? palette.primary
                : palette.muted,
            fontWeight: FontWeight.w700,
          ),
        ),
        iconTheme: WidgetStateProperty.resolveWith<IconThemeData>(
          (Set<WidgetState> states) => IconThemeData(
            color: states.contains(WidgetState.selected)
                ? palette.onPrimaryContainer
                : palette.muted,
            size: AppSizes.icon,
          ),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: palette.surfaceHigh,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: dialogShape,
        titleTextStyle: AppTextStyles.title.copyWith(color: palette.ink),
        contentTextStyle: AppTextStyles.body.copyWith(color: palette.ink),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: palette.surfaceHigh,
        modalBackgroundColor: palette.surfaceHigh,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        modalElevation: 0,
        showDragHandle: true,
        dragHandleColor: palette.line,
        shape: sheetShape,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: palette.inverted,
        contentTextStyle: AppTextStyles.body.copyWith(
          color: palette.onInverted,
        ),
        actionTextColor: palette.primary,
        shape: smallShape,
        elevation: 0,
        insetPadding: const EdgeInsets.all(AppSpacing.lg),
      ),
      datePickerTheme: DatePickerThemeData(
        backgroundColor: palette.surfaceHigh,
        surfaceTintColor: Colors.transparent,
        headerBackgroundColor: palette.primary,
        headerForegroundColor: palette.onPrimary,
        dividerColor: palette.line,
        shape: dialogShape,
        cancelButtonStyle: TextButton.styleFrom(
          foregroundColor: palette.muted,
          minimumSize: const Size(AppSizes.touchTarget, AppSizes.touchTarget),
        ),
        confirmButtonStyle: TextButton.styleFrom(
          foregroundColor: palette.primary,
          minimumSize: const Size(AppSizes.touchTarget, AppSizes.touchTarget),
        ),
      ),
      timePickerTheme: TimePickerThemeData(
        backgroundColor: palette.surfaceHigh,
        shape: dialogShape,
        dialBackgroundColor: palette.inputFill,
        dialHandColor: palette.primary,
        dialTextColor: palette.ink,
        hourMinuteColor: palette.inputFill,
        hourMinuteTextColor: palette.ink,
        entryModeIconColor: palette.muted,
        helpTextStyle: AppTextStyles.label.copyWith(color: palette.muted),
        cancelButtonStyle: TextButton.styleFrom(foregroundColor: palette.muted),
        confirmButtonStyle: TextButton.styleFrom(
          foregroundColor: palette.primary,
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith<Color>(
          (Set<WidgetState> states) => states.contains(WidgetState.selected)
              ? palette.onPrimary
              : palette.muted,
        ),
        trackColor: WidgetStateProperty.resolveWith<Color>(
          (Set<WidgetState> states) => states.contains(WidgetState.selected)
              ? palette.primary
              : palette.inputFill,
        ),
        trackOutlineColor: WidgetStateProperty.resolveWith<Color>(
          (Set<WidgetState> states) => states.contains(WidgetState.selected)
              ? palette.primary
              : palette.line,
        ),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith<Color>(
          (Set<WidgetState> states) => states.contains(WidgetState.selected)
              ? palette.primary
              : Colors.transparent,
        ),
        checkColor: WidgetStatePropertyAll<Color>(palette.onPrimary),
        side: BorderSide(color: palette.line, width: AppSizes.border),
        shape: smallShape,
        materialTapTargetSize: MaterialTapTargetSize.padded,
      ),
      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith<Color>(
          (Set<WidgetState> states) => states.contains(WidgetState.selected)
              ? palette.primary
              : palette.muted,
        ),
        materialTapTargetSize: MaterialTapTargetSize.padded,
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: palette.primary,
        linearTrackColor: palette.line,
        circularTrackColor: palette.line,
        refreshBackgroundColor: palette.surfaceHigh,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: palette.inputFill,
        selectedColor: palette.primary,
        disabledColor: palette.surface,
        labelStyle: AppTextStyles.label.copyWith(color: palette.ink),
        secondaryLabelStyle: AppTextStyles.label.copyWith(
          color: palette.onPrimary,
        ),
        side: BorderSide(color: palette.line, width: AppSizes.border),
        shape: const StadiumBorder(),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        deleteIconColor: palette.muted,
        checkmarkColor: palette.onPrimary,
        elevation: 0,
        pressElevation: 0,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: palette.inputFill,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.xl,
          vertical: AppSpacing.lg,
        ),
        hintStyle: AppTextStyles.body.copyWith(color: palette.muted),
        labelStyle: AppTextStyles.label.copyWith(color: palette.muted),
        floatingLabelStyle: AppTextStyles.label.copyWith(
          color: palette.primary,
        ),
        errorStyle: AppTextStyles.caption.copyWith(color: palette.danger),
        border: OutlineInputBorder(
          borderRadius: AppRadii.pillBorder,
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: AppRadii.pillBorder,
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: AppRadii.pillBorder,
          borderSide: BorderSide(
            color: palette.primary,
            width: AppSizes.focusBorder,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: AppRadii.pillBorder,
          borderSide: BorderSide(color: palette.danger),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: AppRadii.pillBorder,
          borderSide: BorderSide(
            color: palette.danger,
            width: AppSizes.focusBorder,
          ),
        ),
      ),
      listTileTheme: ListTileThemeData(
        textColor: palette.ink,
        iconColor: palette.ink,
        contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        minVerticalPadding: AppSpacing.md,
        shape: smallShape,
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: palette.surfaceHigh,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: dialogShape,
        textStyle: AppTextStyles.body.copyWith(color: palette.ink),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: palette.inverted,
          borderRadius: AppRadii.smallBorder,
        ),
        textStyle: AppTextStyles.caption.copyWith(color: palette.onInverted),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        waitDuration: AppDurations.fast,
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: palette.primary,
          minimumSize: const Size(AppSizes.touchTarget, AppSizes.touchTarget),
          shape: pill,
          textStyle: AppTextStyles.label,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: palette.primary,
          foregroundColor: palette.onPrimary,
          minimumSize: const Size(AppSizes.touchTarget, AppSizes.touchTarget),
          shape: pill,
          textStyle: AppTextStyles.label,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: palette.ink,
          side: BorderSide(color: palette.line, width: AppSizes.border),
          minimumSize: const Size(AppSizes.touchTarget, AppSizes.touchTarget),
          shape: pill,
          textStyle: AppTextStyles.label,
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: palette.ink,
          minimumSize: const Size(AppSizes.touchTarget, AppSizes.touchTarget),
        ),
      ),
      dividerTheme: DividerThemeData(color: palette.line),
      iconTheme: IconThemeData(color: palette.ink, size: AppSizes.icon),
    );
  }
}
