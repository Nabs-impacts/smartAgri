import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

import '../app_icons.dart';
import '../app_palette.dart';
import '../tokens.dart';

class AppErrorBanner extends StatelessWidget {
  const AppErrorBanner({required this.message, super.key});

  final String message;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = context.palette;
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
          color: palette.dangerContainer,
          borderRadius: AppRadii.smallBorder,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Icon(AppIcons.warning, color: palette.danger, size: AppSizes.icon),
            const SizedBox(width: AppSpacing.sm),
            Flexible(
              child: Text(
                message,
                style: AppTextStyles.body.copyWith(color: palette.danger),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
