import 'package:flutter/material.dart';

import '../tokens.dart';

class AppProgressBar extends StatelessWidget {
  const AppProgressBar({
    required this.value,
    this.color = AppColors.primary,
    this.label,
    super.key,
  });

  final double value;
  final Color color;
  final String? label;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: label,
      value: '${(value.clamp(0, 1) * 100).round()} %',
      child: ClipRRect(
        borderRadius: AppRadii.pillBorder,
        child: LinearProgressIndicator(
          value: value.clamp(0, 1),
          minHeight: AppSizes.progress,
          color: color,
          backgroundColor: AppColors.line,
        ),
      ),
    );
  }
}
