import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../tokens.dart';

enum GonataLogoVariant { symbol, full }

class GonataLogo extends StatelessWidget {
  const GonataLogo({this.size = AppSizes.logo, super.key})
    : variant = GonataLogoVariant.symbol,
      width = null;

  const GonataLogo.symbol({this.size = AppSizes.logo, super.key})
    : variant = GonataLogoVariant.symbol,
      width = null;

  const GonataLogo.full({this.width = 200, super.key})
    : variant = GonataLogoVariant.full,
      size = null;

  final GonataLogoVariant variant;
  final double? size;
  final double? width;

  static const String lightAsset = 'assets/logo/gonata_symbol.svg';
  static const String darkAsset = 'assets/logo/gonata_symbol_dark.svg';
  static const String lightFullAsset = 'assets/logo/gonata_logo.svg';
  static const String darkFullAsset = 'assets/logo/gonata_logo_dark.svg';
  static const String semanticsLabel = 'GonaTa';

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final bool symbol = variant == GonataLogoVariant.symbol;
    final String asset = symbol
        ? (isDark ? darkAsset : lightAsset)
        : (isDark ? darkFullAsset : lightFullAsset);
    return Semantics(
      image: true,
      label: semanticsLabel,
      child: SvgPicture.asset(
        asset,
        width: symbol ? size : width,
        height: symbol ? size : null,
        excludeFromSemantics: true,
      ),
    );
  }
}
