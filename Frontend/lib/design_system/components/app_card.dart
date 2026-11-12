import 'package:flutter/material.dart';

import '../tokens.dart';
import '../app_palette.dart';

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
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: context.palette.surfaceRaised,
        borderRadius: AppRadii.cardBorder,
        border: Border.fromBorderSide(
          BorderSide(color: context.palette.line, width: AppSizes.border),
        ),
        boxShadow: AppShadows.card,
      ),
      child: child,
    );
  }
}
