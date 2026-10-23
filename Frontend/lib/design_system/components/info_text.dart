import 'package:flutter/material.dart';

import '../tokens.dart';

class InfoText extends StatelessWidget {
  const InfoText(this.label, {super.key});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: AppTextStyles.label.copyWith(color: AppColors.tertiary),
    );
  }
}
