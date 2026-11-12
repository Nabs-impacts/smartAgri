import 'package:flutter/material.dart';

import '../tokens.dart';
import '../app_palette.dart';

enum AppStatusChipVariant { success, warning, danger, neutral }

class AppStatusChip extends StatelessWidget {
  const AppStatusChip({
    required this.label,
    this.variant = AppStatusChipVariant.neutral,
    super.key,
  });

  final String label;
  final AppStatusChipVariant variant;

  Color _background(AppPalette palette) {
    switch (variant) {
      case AppStatusChipVariant.success:
        return palette.successContainer;
      case AppStatusChipVariant.warning:
        return palette.warningContainer;
      case AppStatusChipVariant.danger:
        return palette.dangerChipContainer;
      case AppStatusChipVariant.neutral:
        return palette.surface;
    }
  }

  Color _foreground(AppPalette palette) {
    switch (variant) {
      case AppStatusChipVariant.success:
        return palette.onSuccessContainer;
      case AppStatusChipVariant.warning:
        return palette.onWarningContainer;
      case AppStatusChipVariant.danger:
        return palette.onDangerContainer;
      case AppStatusChipVariant.neutral:
        return palette.muted;
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = context.palette;
    return Container(
      key: Key('status_chip_${variant.name}'),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: _background(palette),
        borderRadius: AppRadii.pillBorder,
      ),
      child: Text(
        label,
        style: AppTextStyles.label.copyWith(color: _foreground(palette)),
      ),
    );
  }
}
