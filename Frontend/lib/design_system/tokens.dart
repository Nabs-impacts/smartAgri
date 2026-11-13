import 'package:flutter/widgets.dart';

abstract final class AppColors {
  static const Color primary = Color(0xFF006633);
  static const Color onPrimary = Color(0xFFFFFFFF);
  static const Color secondary = Color(0xFFE94E1B);
  static const Color secondaryText = Color(0xFFBB4219);
  static const Color ink = Color(0xFF121411);
  static const Color muted = Color(0xFF575C53);
  static const Color line = Color(0xFFD6D9D1);
  static const Color background = Color(0xFFFFFFFF);
  static const Color surface = Color(0xFFF4F5F2);
  static const Color surfaceRaised = Color(0xFFFFFFFF);
  static const Color surfaceHigh = Color(0xFFFFFFFF);
  static const Color inputFill = Color(0xFFEBEBEB);
  static const Color primaryContainer = Color(0xFFD7F0E1);
  static const Color onPrimaryContainer = Color(0xFF07351C);
  static const Color secondaryContainer = Color(0xFFFCE4D9);
  static const Color onSecondaryContainer = Color(0xFF5A1B07);
  static const Color tertiary = Color(0xFF1E7743);
  static const Color danger = Color(0xFFB3261E);
  static const Color onDanger = Color(0xFFFFFFFF);
  static const Color accent = Color(0xFFB23F16);
  static const Color inverted = Color(0xFF121411);
  static const Color onInverted = Color(0xFFFFFFFF);
  static const Color successContainer = Color(0xFFD7F0E1);
  static const Color onSuccessContainer = Color(0xFF07351C);
  static const Color warningContainer = Color(0xFFFCE4D9);
  static const Color onWarningContainer = Color(0xFF7A2A0C);
  static const Color dangerContainer = Color(0xFFFCE4E4);
  static const Color onDangerContainer = Color(0xFF8C1D18);
  static const Color dangerChipContainer = Color(0xFFF8DADA);
  static const Color white = Color(0xFFFFFFFF);
  static const Color transparent = Color(0x00000000);
}

abstract final class AppSpacing {
  static const double none = 0;
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;
  static const double xxxl = 40;
}

abstract final class AppRadii {
  static const double pill = 999;
  static const double card = 24;
  static const double sheet = 28;
  static const double dialog = 28;
  static const double small = 12;
  static const BorderRadius pillBorder = BorderRadius.all(
    Radius.circular(pill),
  );
  static const BorderRadius cardBorder = BorderRadius.all(
    Radius.circular(card),
  );
  static const BorderRadius sheetBorder = BorderRadius.all(
    Radius.circular(sheet),
  );
  static const BorderRadius dialogBorder = BorderRadius.all(
    Radius.circular(dialog),
  );
  static const BorderRadius smallBorder = BorderRadius.all(
    Radius.circular(small),
  );
  static const BorderRadius sheetTopBorder = BorderRadius.vertical(
    top: Radius.circular(sheet),
  );
}

abstract final class AppSizes {
  static const double touchTarget = 48;
  static const double iconButton = 48;
  static const double border = 1;
  static const double focusBorder = 2;
  static const double icon = 20;
  static const double smallIcon = 16;
  static const double buttonIcon = 18;
  static const double loadingStroke = 2;
  static const double progress = 8;
  static const double navHeight = 72;
  static const double navIndicator = 48;
  static const double languagePill = 48;
  static const double logo = 48;
  static const double buttonRegular = 56;
  static const double buttonCompact = 48;
  static const double fieldHeight = 56;
  static const double fieldLabelGap = 6;
  static const double loadingIndicator = 20;
  static const double checkbox = 24;
  static const double otpBox = 56;
}

abstract final class AppOpacity {
  static const double disabled = 0.45;
}

abstract final class AppDurations {
  static const Duration fast = Duration(milliseconds: 150);
}

abstract final class AppElevation {
  static const List<BoxShadow> none = <BoxShadow>[];
  static const List<BoxShadow> low = <BoxShadow>[
    BoxShadow(color: Color(0x0F121411), blurRadius: 16, offset: Offset(0, 4)),
  ];
  static const List<BoxShadow> medium = <BoxShadow>[
    BoxShadow(color: Color(0x14121411), blurRadius: 24, offset: Offset(0, 8)),
  ];
  static const List<BoxShadow> high = <BoxShadow>[
    BoxShadow(color: Color(0x1A121411), blurRadius: 40, offset: Offset(0, 16)),
  ];
}

abstract final class AppTypography {
  static const String fontFamily = 'PlusJakartaSans';
  static const String accentFamily = 'Anton';
  static const List<String> accentFallback = <String>[fontFamily];
}

abstract final class AppTextStyles {
  static const TextStyle displayAccent = TextStyle(
    fontFamily: AppTypography.accentFamily,
    fontFamilyFallback: AppTypography.accentFallback,
    fontSize: 40,
    fontWeight: FontWeight.w800,
    height: 1.1,
    letterSpacing: 0.5,
  );
  static const TextStyle display = TextStyle(
    fontFamily: AppTypography.fontFamily,
    fontSize: 36,
    fontWeight: FontWeight.w800,
    height: 1.1,
  );
  static const TextStyle headline = TextStyle(
    fontFamily: AppTypography.fontFamily,
    fontSize: 24,
    fontWeight: FontWeight.w800,
    height: 1.2,
  );
  static const TextStyle title = TextStyle(
    fontFamily: AppTypography.fontFamily,
    fontSize: 20,
    fontWeight: FontWeight.w700,
    height: 1.25,
  );
  static const TextStyle subtitle = TextStyle(
    fontFamily: AppTypography.fontFamily,
    fontSize: 18,
    fontWeight: FontWeight.w700,
    height: 1.3,
  );
  static const TextStyle body = TextStyle(
    fontFamily: AppTypography.fontFamily,
    fontSize: 16,
    fontWeight: FontWeight.w400,
    height: 1.4,
  );
  static const TextStyle label = TextStyle(
    fontFamily: AppTypography.fontFamily,
    fontSize: 14,
    fontWeight: FontWeight.w600,
    height: 1.3,
  );
  static const TextStyle caption = TextStyle(
    fontFamily: AppTypography.fontFamily,
    fontSize: 12,
    fontWeight: FontWeight.w500,
    height: 1.3,
  );
}
