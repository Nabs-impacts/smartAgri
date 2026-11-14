import 'package:flutter/widgets.dart';

abstract final class AppMotion {
  static const Duration fast = Duration(milliseconds: 120);
  static const Duration medium = Duration(milliseconds: 220);
  static const Duration slow = Duration(milliseconds: 320);
  static const Curve enter = Curves.easeOutCubic;
  static const Curve exit = Curves.easeInCubic;
  static const Curve press = Curves.easeOutBack;

  static bool animationsDisabled(BuildContext context) {
    return MediaQuery.maybeDisableAnimationsOf(context) ?? false;
  }

  static Duration duration(BuildContext context, Duration base) {
    return animationsDisabled(context) ? Duration.zero : base;
  }

  static Duration fastFor(BuildContext context) => duration(context, fast);

  static Duration mediumFor(BuildContext context) => duration(context, medium);

  static Duration slowFor(BuildContext context) => duration(context, slow);
}
