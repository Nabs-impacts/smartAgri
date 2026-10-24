import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

import '../tokens.dart';

class AppErrorBanner extends StatelessWidget {
  const AppErrorBanner({required this.message, super.key});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      role: SemanticsRole.alert,
      label: message,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
        decoration: const BoxDecoration(
          color: Color(0xFFFFEBEE),
          borderRadius: BorderRadius.all(Radius.circular(12)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Icon(
              Icons.warning_amber_rounded,
              color: AppColors.danger,
              size: AppSizes.icon,
            ),
            const SizedBox(width: AppSpacing.sm),
            Flexible(
              child: Text(
                message,
                style: AppTextStyles.body.copyWith(color: AppColors.danger),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
