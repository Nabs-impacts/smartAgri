import 'package:flutter/material.dart';

import '../app_palette.dart';
import '../tokens.dart';

class InfoText extends StatelessWidget {
  const InfoText(this.label, {super.key});

  final String label;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = context.palette;
    return Text(
      label,
      style: AppTextStyles.label.copyWith(color: palette.tertiary),
    );
  }
}
