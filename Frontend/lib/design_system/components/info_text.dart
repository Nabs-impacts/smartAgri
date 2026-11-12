import 'package:flutter/material.dart';

import '../tokens.dart';
import '../app_palette.dart';

class InfoText extends StatelessWidget {
  const InfoText(this.label, {super.key});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: AppTextStyles.label.copyWith(color: context.palette.tertiary),
    );
  }
}
