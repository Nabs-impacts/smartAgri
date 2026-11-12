import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:smartagri/design_system/app_palette.dart';
import 'package:smartagri/design_system/tokens.dart';

void main() {
  test('the light palette matches the original AppColors values', () {
    const AppPalette palette = AppPalette.light;

    expect(palette.background, AppColors.background);
    expect(palette.surface, AppColors.surface);
    expect(palette.surfaceRaised, AppColors.white);
    expect(palette.inputFill, AppColors.inputFill);
    expect(palette.line, AppColors.line);
    expect(palette.ink, AppColors.ink);
    expect(palette.muted, AppColors.muted);
    expect(palette.primary, AppColors.primary);
    expect(palette.onPrimary, AppColors.white);
    expect(palette.primaryContainer, AppColors.primaryContainer);
    expect(palette.onPrimaryContainer, AppColors.ink);
    expect(palette.secondary, AppColors.secondary);
    expect(palette.onSecondary, AppColors.white);
    expect(palette.secondaryContainer, AppColors.secondaryContainer);
    expect(palette.onSecondaryContainer, AppColors.ink);
    expect(palette.tertiary, AppColors.tertiary);
    expect(palette.danger, AppColors.danger);
    expect(palette.onDanger, AppColors.white);
    expect(palette.accent, AppColors.accentBrown);
    expect(palette.inverted, AppColors.inverted);
    expect(palette.onInverted, AppColors.white);
    expect(palette.successContainer, const Color(0xFFE3F2E4));
    expect(palette.onSuccessContainer, AppColors.primary);
    expect(palette.warningContainer, const Color(0xFFFFF0E0));
    expect(palette.onWarningContainer, AppColors.secondary);
    expect(palette.dangerContainer, const Color(0xFFFFEBEE));
    expect(palette.onDangerContainer, AppColors.danger);
    expect(palette.dangerChipContainer, const Color(0xFFFFE9E9));
  });

  test('the dark palette keeps WCAG AA text contrast', () {
    const AppPalette palette = AppPalette.dark;
    final Map<String, List<Color>> pairs = <String, List<Color>>{
      'ink/background': <Color>[palette.ink, palette.background],
      'ink/surface': <Color>[palette.ink, palette.surface],
      'ink/surfaceRaised': <Color>[palette.ink, palette.surfaceRaised],
      'ink/inputFill': <Color>[palette.ink, palette.inputFill],
      'muted/background': <Color>[palette.muted, palette.background],
      'muted/surface': <Color>[palette.muted, palette.surface],
      'muted/surfaceRaised': <Color>[palette.muted, palette.surfaceRaised],
      'muted/inputFill': <Color>[palette.muted, palette.inputFill],
      'onPrimary/primary': <Color>[palette.onPrimary, palette.primary],
      'onPrimaryContainer/primaryContainer': <Color>[
        palette.onPrimaryContainer,
        palette.primaryContainer,
      ],
      'onSecondary/secondary': <Color>[palette.onSecondary, palette.secondary],
      'onSecondaryContainer/secondaryContainer': <Color>[
        palette.onSecondaryContainer,
        palette.secondaryContainer,
      ],
      'onDanger/danger': <Color>[palette.onDanger, palette.danger],
      'onInverted/inverted': <Color>[palette.onInverted, palette.inverted],
      'onSuccessContainer/successContainer': <Color>[
        palette.onSuccessContainer,
        palette.successContainer,
      ],
      'onWarningContainer/warningContainer': <Color>[
        palette.onWarningContainer,
        palette.warningContainer,
      ],
      'onDangerContainer/dangerContainer': <Color>[
        palette.onDangerContainer,
        palette.dangerContainer,
      ],
      'onDangerContainer/dangerChipContainer': <Color>[
        palette.onDangerContainer,
        palette.dangerChipContainer,
      ],
      'accent/secondaryContainer': <Color>[
        palette.accent,
        palette.secondaryContainer,
      ],
    };

    for (final MapEntry<String, List<Color>> entry in pairs.entries) {
      expect(
        contrastRatio(entry.value[0], entry.value[1]),
        greaterThanOrEqualTo(4.5),
        reason: entry.key,
      );
    }
  });

  test('the dark palette keeps WCAG AA icon and border contrast', () {
    const AppPalette palette = AppPalette.dark;
    final List<Color> backgrounds = <Color>[
      palette.background,
      palette.surface,
      palette.surfaceRaised,
      palette.inputFill,
    ];

    for (final Color background in backgrounds) {
      expect(contrastRatio(palette.line, background), greaterThanOrEqualTo(3));
      expect(
        contrastRatio(palette.primary, background),
        greaterThanOrEqualTo(3),
      );
      expect(
        contrastRatio(palette.secondary, background),
        greaterThanOrEqualTo(3),
      );
      expect(
        contrastRatio(palette.danger, background),
        greaterThanOrEqualTo(3),
      );
      expect(
        contrastRatio(palette.tertiary, background),
        greaterThanOrEqualTo(3),
      );
      expect(
        contrastRatio(palette.accent, background),
        greaterThanOrEqualTo(3),
      );
    }
  });

  test('copyWith replaces only the requested roles', () {
    const AppPalette palette = AppPalette.light;
    const Color replacement = Color(0xFF010203);

    final AppPalette updated = palette.copyWith(primary: replacement);

    expect(updated.primary, replacement);
    expect(updated.background, palette.background);
    expect(updated.onPrimary, palette.onPrimary);
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
