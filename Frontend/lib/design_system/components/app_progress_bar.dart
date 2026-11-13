import 'package:flutter/material.dart';

import '../app_palette.dart';
import '../tokens.dart';

class AppProgressBar extends StatelessWidget {
  const AppProgressBar({
    required this.value,
    this.color,
    this.label,
    super.key,
  });

  final double value;
  final Color? color;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = context.palette;
    return Semantics(
      label: label,
      value: '${(value.clamp(0, 1) * 100).round()} %',
      child: ClipRRect(
        borderRadius: AppRadii.pillBorder,
        child: LinearProgressIndicator(
          value: value.clamp(0, 1),
          minHeight: AppSizes.progress,
          color: color ?? palette.primary,
          backgroundColor: palette.line,
        ),
      ),
    );
  }
}
