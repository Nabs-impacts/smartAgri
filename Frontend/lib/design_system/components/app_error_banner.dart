import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

import '../tokens.dart';
import '../app_palette.dart';

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
        decoration: BoxDecoration(
          color: context.palette.dangerContainer,
          borderRadius: const BorderRadius.all(Radius.circular(12)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Icon(
              Icons.warning_amber_rounded,
              color: context.palette.danger,
              size: AppSizes.icon,
            ),
            const SizedBox(width: AppSpacing.sm),
            Flexible(
              child: Text(
                message,
                style: AppTextStyles.body.copyWith(
                  color: context.palette.danger,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
