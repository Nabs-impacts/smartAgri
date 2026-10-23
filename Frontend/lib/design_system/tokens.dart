import 'package:flutter/widgets.dart';

abstract final class AppColors {
  static const Color primary = Color(0xFF1B5E20);
  static const Color secondary = Color(0xFFE65100);
  static const Color tertiary = Color(0xFF2E7D32);
  static const Color ink = Color(0xFF121411);
  static const Color muted = Color(0xFF5B6058);
  static const Color line = Color(0xFFD6D9D1);
  static const Color background = Color(0xFFF6F7F3);
  static const Color surface = Color(0xFFEEF0EA);
  static const Color inputFill = Color(0xFFE9EAE6);
  static const Color primaryContainer = Color(0xFFC5E1A5);
  static const Color secondaryContainer = Color(0xFFFFE0CC);
  static const Color danger = Color(0xFFC62828);
  static const Color accentBrown = Color(0xFFB23A0E);
  static const Color inverted = Color(0xFF2F312D);
  static const Color white = Color(0xFFFFFFFF);
  static const Color transparent = Color(0x00000000);
}

abstract final class AppSpacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;
}

abstract final class AppRadii {
  static const double pill = 999;
  static const double card = 16;
  static const double small = 8;
  static const BorderRadius pillBorder = BorderRadius.all(
    Radius.circular(pill),
  );
  static const BorderRadius cardBorder = BorderRadius.all(
    Radius.circular(card),
  );
  static const BorderRadius smallBorder = BorderRadius.all(
    Radius.circular(small),
  );
}

abstract final class AppSizes {
  static const double touchTarget = 48;
  static const double iconButton = 36;
  static const double border = 1;
  static const double focusBorder = 1.5;
  static const double icon = 20;
  static const double smallIcon = 16;
  static const double buttonIcon = 18;
  static const double loadingStroke = 2;
  static const double progress = 6;
  static const double navHeight = 64;
  static const double navCircle = 44;
  static const double languageCircle = 40;
  static const double logo = 48;
  static const double buttonRegular = 52;
  static const double buttonCompact = 48;
  static const double fieldHeight = 52;
  static const double loadingIndicator = 20;
}

abstract final class AppOpacity {
  static const double disabled = 0.45;
}

abstract final class AppDurations {
  static const Duration fast = Duration(milliseconds: 150);
}

abstract final class AppShadows {
  static const List<BoxShadow> card = <BoxShadow>[
    BoxShadow(color: Color(0x0A121411), blurRadius: 12, offset: Offset(0, 4)),
  ];
}

abstract final class AppTypography {
  static const String fontFamily = 'PlusJakartaSans';
}

abstract final class AppTextStyles {
  static const TextStyle headline = TextStyle(
    fontFamily: AppTypography.fontFamily,
    fontSize: 28,
    fontWeight: FontWeight.w800,
    color: AppColors.ink,
  );
  static const TextStyle title = TextStyle(
    fontFamily: AppTypography.fontFamily,
    fontSize: 20,
    fontWeight: FontWeight.w700,
    color: AppColors.ink,
  );
  static const TextStyle body = TextStyle(
    fontFamily: AppTypography.fontFamily,
    fontSize: 15,
    fontWeight: FontWeight.w400,
    color: AppColors.ink,
  );
  static const TextStyle label = TextStyle(
    fontFamily: AppTypography.fontFamily,
    fontSize: 13,
    fontWeight: FontWeight.w600,
    color: AppColors.ink,
  );
  static const TextStyle caption = TextStyle(
    fontFamily: AppTypography.fontFamily,
    fontSize: 12,
    fontWeight: FontWeight.w500,
    color: AppColors.ink,
  );
}
