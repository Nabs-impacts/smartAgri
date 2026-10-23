import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../tokens.dart';

enum AppLogoVariant {
  green('assets/logo/logo_leaf_green.svg'),
  lime('assets/logo/logo_leaf_lime.svg');

  const AppLogoVariant(this.asset);

  final String asset;
}

class AppLogo extends StatelessWidget {
  const AppLogo({
    this.variant = AppLogoVariant.green,
    this.size = AppSizes.logo,
    super.key,
  });

  final AppLogoVariant variant;
  final double size;

  @override
  Widget build(BuildContext context) {
    return SvgPicture.asset(
      variant.asset,
      width: size,
      height: size,
      semanticsLabel: 'SmartAgri',
    );
  }
}
