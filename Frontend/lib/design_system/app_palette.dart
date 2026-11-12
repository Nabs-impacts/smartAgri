import 'package:flutter/material.dart';

import 'tokens.dart';

@immutable
class AppPalette extends ThemeExtension<AppPalette> {
  const AppPalette({
    required this.background,
    required this.surface,
    required this.surfaceRaised,
    required this.inputFill,
    required this.line,
    required this.ink,
    required this.muted,
    required this.primary,
    required this.onPrimary,
    required this.primaryContainer,
    required this.onPrimaryContainer,
    required this.secondary,
    required this.onSecondary,
    required this.secondaryContainer,
    required this.onSecondaryContainer,
    required this.tertiary,
    required this.danger,
    required this.onDanger,
    required this.accent,
    required this.inverted,
    required this.onInverted,
    required this.scrim,
    required this.successContainer,
    required this.onSuccessContainer,
    required this.warningContainer,
    required this.onWarningContainer,
    required this.dangerContainer,
    required this.onDangerContainer,
    required this.dangerChipContainer,
  });

  final Color background;
  final Color surface;
  final Color surfaceRaised;
  final Color inputFill;
  final Color line;
  final Color ink;
  final Color muted;
  final Color primary;
  final Color onPrimary;
  final Color primaryContainer;
  final Color onPrimaryContainer;
  final Color secondary;
  final Color onSecondary;
  final Color secondaryContainer;
  final Color onSecondaryContainer;
  final Color tertiary;
  final Color danger;
  final Color onDanger;
  final Color accent;
  final Color inverted;
  final Color onInverted;
  final Color scrim;
  final Color successContainer;
  final Color onSuccessContainer;
  final Color warningContainer;
  final Color onWarningContainer;
  final Color dangerContainer;
  final Color onDangerContainer;
  final Color dangerChipContainer;

  static const AppPalette light = AppPalette(
    background: AppColors.background,
    surface: AppColors.surface,
    surfaceRaised: AppColors.white,
    inputFill: AppColors.inputFill,
    line: AppColors.line,
    ink: AppColors.ink,
    muted: AppColors.muted,
    primary: AppColors.primary,
    onPrimary: AppColors.white,
    primaryContainer: AppColors.primaryContainer,
    onPrimaryContainer: AppColors.ink,
    secondary: AppColors.secondary,
    onSecondary: AppColors.white,
    secondaryContainer: AppColors.secondaryContainer,
    onSecondaryContainer: AppColors.ink,
    tertiary: AppColors.tertiary,
    danger: AppColors.danger,
    onDanger: AppColors.white,
    accent: AppColors.accentBrown,
    inverted: AppColors.inverted,
    onInverted: AppColors.white,
    scrim: Color(0x66000000),
    successContainer: Color(0xFFE3F2E4),
    onSuccessContainer: AppColors.primary,
    warningContainer: Color(0xFFFFF0E0),
    onWarningContainer: AppColors.secondary,
    dangerContainer: Color(0xFFFFEBEE),
    onDangerContainer: AppColors.danger,
    dangerChipContainer: Color(0xFFFFE9E9),
  );

  static const AppPalette dark = AppPalette(
    background: Color(0xFF161814),
    surface: Color(0xFF1F211C),
    surfaceRaised: Color(0xFF262922),
    inputFill: Color(0xFF2B2E27),
    line: Color(0xFF707868),
    ink: Color(0xFFF1F3ED),
    muted: Color(0xFFB4BAAC),
    primary: Color(0xFF8BD08F),
    onPrimary: Color(0xFF0E1B0F),
    primaryContainer: Color(0xFF2B4A2E),
    onPrimaryContainer: Color(0xFFE2F1DF),
    secondary: Color(0xFFFFB27A),
    onSecondary: Color(0xFF3B1A00),
    secondaryContainer: Color(0xFF4A2D1B),
    onSecondaryContainer: Color(0xFFFFE0CC),
    tertiary: Color(0xFF82D18D),
    danger: Color(0xFFFF8A80),
    onDanger: Color(0xFF3A0907),
    accent: Color(0xFFFFA07A),
    inverted: Color(0xFFE8EAE3),
    onInverted: Color(0xFF171914),
    scrim: Color(0x99000000),
    successContainer: Color(0xFF233A24),
    onSuccessContainer: Color(0xFF9BDD9F),
    warningContainer: Color(0xFF3B2C1C),
    onWarningContainer: Color(0xFFFFC08A),
    dangerContainer: Color(0xFF3E2020),
    onDangerContainer: Color(0xFFFFB4AB),
    dangerChipContainer: Color(0xFF3E2020),
  );

  @override
  AppPalette copyWith({
    Color? background,
    Color? surface,
    Color? surfaceRaised,
    Color? inputFill,
    Color? line,
    Color? ink,
    Color? muted,
    Color? primary,
    Color? onPrimary,
    Color? primaryContainer,
    Color? onPrimaryContainer,
    Color? secondary,
    Color? onSecondary,
    Color? secondaryContainer,
    Color? onSecondaryContainer,
    Color? tertiary,
    Color? danger,
    Color? onDanger,
    Color? accent,
    Color? inverted,
    Color? onInverted,
    Color? scrim,
    Color? successContainer,
    Color? onSuccessContainer,
    Color? warningContainer,
    Color? onWarningContainer,
    Color? dangerContainer,
    Color? onDangerContainer,
    Color? dangerChipContainer,
  }) {
    return AppPalette(
      background: background ?? this.background,
      surface: surface ?? this.surface,
      surfaceRaised: surfaceRaised ?? this.surfaceRaised,
      inputFill: inputFill ?? this.inputFill,
      line: line ?? this.line,
      ink: ink ?? this.ink,
      muted: muted ?? this.muted,
      primary: primary ?? this.primary,
      onPrimary: onPrimary ?? this.onPrimary,
      primaryContainer: primaryContainer ?? this.primaryContainer,
      onPrimaryContainer: onPrimaryContainer ?? this.onPrimaryContainer,
      secondary: secondary ?? this.secondary,
      onSecondary: onSecondary ?? this.onSecondary,
      secondaryContainer: secondaryContainer ?? this.secondaryContainer,
      onSecondaryContainer: onSecondaryContainer ?? this.onSecondaryContainer,
      tertiary: tertiary ?? this.tertiary,
      danger: danger ?? this.danger,
      onDanger: onDanger ?? this.onDanger,
      accent: accent ?? this.accent,
      inverted: inverted ?? this.inverted,
      onInverted: onInverted ?? this.onInverted,
      scrim: scrim ?? this.scrim,
      successContainer: successContainer ?? this.successContainer,
      onSuccessContainer: onSuccessContainer ?? this.onSuccessContainer,
      warningContainer: warningContainer ?? this.warningContainer,
      onWarningContainer: onWarningContainer ?? this.onWarningContainer,
      dangerContainer: dangerContainer ?? this.dangerContainer,
      onDangerContainer: onDangerContainer ?? this.onDangerContainer,
      dangerChipContainer: dangerChipContainer ?? this.dangerChipContainer,
    );
  }

  @override
  AppPalette lerp(covariant AppPalette? other, double t) {
    if (other == null) {
      return this;
    }
    return AppPalette(
      background: Color.lerp(background, other.background, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceRaised: Color.lerp(surfaceRaised, other.surfaceRaised, t)!,
      inputFill: Color.lerp(inputFill, other.inputFill, t)!,
      line: Color.lerp(line, other.line, t)!,
      ink: Color.lerp(ink, other.ink, t)!,
      muted: Color.lerp(muted, other.muted, t)!,
      primary: Color.lerp(primary, other.primary, t)!,
      onPrimary: Color.lerp(onPrimary, other.onPrimary, t)!,
      primaryContainer: Color.lerp(
        primaryContainer,
        other.primaryContainer,
        t,
      )!,
      onPrimaryContainer: Color.lerp(
        onPrimaryContainer,
        other.onPrimaryContainer,
        t,
      )!,
      secondary: Color.lerp(secondary, other.secondary, t)!,
      onSecondary: Color.lerp(onSecondary, other.onSecondary, t)!,
      secondaryContainer: Color.lerp(
        secondaryContainer,
        other.secondaryContainer,
        t,
      )!,
      onSecondaryContainer: Color.lerp(
        onSecondaryContainer,
        other.onSecondaryContainer,
        t,
      )!,
      tertiary: Color.lerp(tertiary, other.tertiary, t)!,
      danger: Color.lerp(danger, other.danger, t)!,
      onDanger: Color.lerp(onDanger, other.onDanger, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      inverted: Color.lerp(inverted, other.inverted, t)!,
      onInverted: Color.lerp(onInverted, other.onInverted, t)!,
      scrim: Color.lerp(scrim, other.scrim, t)!,
      successContainer: Color.lerp(
        successContainer,
        other.successContainer,
        t,
      )!,
      onSuccessContainer: Color.lerp(
        onSuccessContainer,
        other.onSuccessContainer,
        t,
      )!,
      warningContainer: Color.lerp(
        warningContainer,
        other.warningContainer,
        t,
      )!,
      onWarningContainer: Color.lerp(
        onWarningContainer,
        other.onWarningContainer,
        t,
      )!,
      dangerContainer: Color.lerp(dangerContainer, other.dangerContainer, t)!,
      onDangerContainer: Color.lerp(
        onDangerContainer,
        other.onDangerContainer,
        t,
      )!,
      dangerChipContainer: Color.lerp(
        dangerChipContainer,
        other.dangerChipContainer,
        t,
      )!,
    );
  }
}

extension AppPaletteContext on BuildContext {
  AppPalette get palette =>
      Theme.of(this).extension<AppPalette>() ?? AppPalette.light;
}

double contrastRatio(Color foreground, Color background) {
  final double first = foreground.computeLuminance();
  final double second = background.computeLuminance();
  final double lighter = first > second ? first : second;
  final double darker = first > second ? second : first;
  return (lighter + 0.05) / (darker + 0.05);
}

bool meetsWcagAa(Color foreground, Color background, {bool text = true}) {
  final double ratio = contrastRatio(foreground, background);
  return ratio >= (text ? 4.5 : 3);
}
