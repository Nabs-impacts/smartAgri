import 'package:flutter/material.dart';

import '../app_palette.dart';
import '../tokens.dart';

class AppCard extends StatelessWidget {
  const AppCard({
    this.child,
    this.padding = const EdgeInsets.all(AppSpacing.lg),
    super.key,
  });

  final Widget? child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = context.palette;
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: palette.isDark ? palette.surfaceHigh : palette.surfaceRaised,
        borderRadius: AppRadii.cardBorder,
        border: Border.fromBorderSide(
          BorderSide(color: palette.line, width: AppSizes.border),
        ),
        boxShadow: palette.lowShadows,
      ),
      child: child,
    );
  }
}
