import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:smartagri/design_system/app_palette.dart';
import 'package:smartagri/design_system/tokens.dart';

Map<String, Color> _roles(AppPalette palette) {
  return <String, Color>{
    'background': palette.background,
    'surface': palette.surface,
    'surfaceRaised': palette.surfaceRaised,
    'surfaceHigh': palette.surfaceHigh,
    'inputFill': palette.inputFill,
    'line': palette.line,
    'ink': palette.ink,
    'muted': palette.muted,
    'primary': palette.primary,
    'onPrimary': palette.onPrimary,
    'primaryContainer': palette.primaryContainer,
    'onPrimaryContainer': palette.onPrimaryContainer,
    'secondary': palette.secondary,
    'onSecondary': palette.onSecondary,
    'secondaryContainer': palette.secondaryContainer,
    'onSecondaryContainer': palette.onSecondaryContainer,
    'secondaryText': palette.secondaryText,
    'tertiary': palette.tertiary,
    'danger': palette.danger,
    'onDanger': palette.onDanger,
    'accent': palette.accent,
    'inverted': palette.inverted,
    'onInverted': palette.onInverted,
    'successContainer': palette.successContainer,
    'onSuccessContainer': palette.onSuccessContainer,
    'warningContainer': palette.warningContainer,
    'onWarningContainer': palette.onWarningContainer,
    'dangerContainer': palette.dangerContainer,
    'onDangerContainer': palette.onDangerContainer,
    'dangerChipContainer': palette.dangerChipContainer,
  };
}

List<List<String>> _textPairs() {
  return <List<String>>[
    for (final String background in <String>[
      'background',
      'surface',
      'surfaceRaised',
      'inputFill',
    ]) ...<List<String>>[
      <String>['ink', background],
      <String>['muted', background],
      <String>['secondaryText', background],
      <String>['primary', background],
      <String>['danger', background],
      <String>['tertiary', background],
      <String>['accent', background],
    ],
    <String>['onPrimary', 'primary'],
    <String>['onPrimaryContainer', 'primaryContainer'],
    <String>['onSecondary', 'secondary'],
    <String>['onSecondaryContainer', 'secondaryContainer'],
    <String>['onDanger', 'danger'],
    <String>['onInverted', 'inverted'],
    <String>['onSuccessContainer', 'successContainer'],
    <String>['onWarningContainer', 'warningContainer'],
    <String>['onDangerContainer', 'dangerContainer'],
    <String>['onDangerContainer', 'dangerChipContainer'],
    <String>['accent', 'secondaryContainer'],
  ];
}

void main() {
  test('the light palette uses the exact GonaTa brand colors', () {
    const AppPalette palette = AppPalette.light;

    expect(palette.background, const Color(0xFFFFFFFF));
    expect(palette.primary, const Color(0xFF006633));
    expect(palette.onPrimary, const Color(0xFFFFFFFF));
    expect(palette.secondary, const Color(0xFFE94E1B));
    expect(palette.ink, const Color(0xFF121411));
    expect(palette.inputFill, const Color(0xFFEBEBEB));
    expect(palette.secondaryText, const Color(0xFFBB4219));
    expect(palette.isDark, isFalse);
  });

  test('the dark palette derives its roles from the same hues', () {
    const AppPalette palette = AppPalette.dark;

    expect(palette.background, const Color(0xFF121411));
    expect(palette.primary, const Color(0xFF8BD08F));
    expect(palette.secondary, const Color(0xFFFF8A5C));
    expect(palette.isDark, isTrue);
  });

  test('the light secondaryText reaches AA on every light surface', () {
    const AppPalette palette = AppPalette.light;
    final List<Color> surfaces = <Color>[
      palette.background,
      palette.surface,
      palette.surfaceRaised,
      palette.inputFill,
    ];

    for (final Color surface in surfaces) {
      expect(
        contrastRatio(palette.secondaryText, surface),
        greaterThanOrEqualTo(4.5),
      );
    }
    expect(palette.secondaryText, AppColors.secondaryText);
  });

  test('every text pair passes WCAG AA in both themes', () {
    for (final AppPalette palette in <AppPalette>[
      AppPalette.light,
      AppPalette.dark,
    ]) {
      final Map<String, Color> roles = _roles(palette);
      for (final List<String> pair in _textPairs()) {
        expect(
          contrastRatio(roles[pair[0]]!, roles[pair[1]]!),
          greaterThanOrEqualTo(4.5),
          reason: '${palette.brightness.name}: ${pair[0]}/${pair[1]}',
        );
      }
    }
  });

  test('non text roles reach three to one in both themes', () {
    for (final AppPalette palette in <AppPalette>[
      AppPalette.light,
      AppPalette.dark,
    ]) {
      final List<Color> surfaces = <Color>[
        palette.background,
        palette.surface,
        palette.surfaceRaised,
        palette.inputFill,
      ];
      for (final Color background in surfaces) {
        for (final Color role in <Color>[
          palette.primary,
          palette.secondary,
          palette.secondaryText,
          palette.danger,
          palette.tertiary,
          palette.accent,
        ]) {
          expect(
            contrastRatio(role, background),
            greaterThanOrEqualTo(3),
            reason: '${palette.brightness.name}: $role/$background',
          );
        }
      }
    }
  });

  test('copyWith replaces only the requested roles', () {
    const AppPalette palette = AppPalette.light;
    const Color replacement = Color(0xFF010203);

    final AppPalette updated = palette.copyWith(primary: replacement);

    expect(updated.primary, replacement);
    expect(updated.background, palette.background);
    expect(updated.onPrimary, palette.onPrimary);
    expect(updated.secondaryText, palette.secondaryText);
    expect(updated.danger, palette.danger);
  });

  test('lerp interpolates between both palettes', () {
    const AppPalette start = AppPalette.light;
    const AppPalette end = AppPalette.dark;

    expect(start.lerp(end, 0).primary, start.primary);
    expect(start.lerp(end, 1).primary, end.primary);
    final AppPalette middle = start.lerp(end, 0.5);
    expect(
      middle.background,
      Color.lerp(start.background, end.background, 0.5),
    );
    expect(start.lerp(null, 0.5), start);
  });

  test('WCAG helpers use the expected thresholds', () {
    const Color black = Color(0xFF000000);
    const Color white = Color(0xFFFFFFFF);

    expect(contrastRatio(black, white), closeTo(21, 0.01));
    expect(meetsWcagAa(black, white), isTrue);
    expect(meetsWcagAa(black, white, text: false), isTrue);
  });
}
