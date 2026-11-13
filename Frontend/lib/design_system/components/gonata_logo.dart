import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../tokens.dart';

class GonataLogo extends StatelessWidget {
  const GonataLogo({this.size = AppSizes.logo, super.key});

  final double size;

  static const String lightAsset = 'assets/logo/gonata_symbol.svg';
  static const String darkAsset = 'assets/logo/gonata_symbol_dark.svg';
  static const String semanticsLabel = 'GonaTa';

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    return Semantics(
      image: true,
      label: semanticsLabel,
      child: SvgPicture.asset(
        isDark ? darkAsset : lightAsset,
        width: size,
        height: size,
        excludeFromSemantics: true,
      ),
    );
  }
}
