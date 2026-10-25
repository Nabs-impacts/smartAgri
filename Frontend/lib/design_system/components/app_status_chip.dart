import 'package:flutter/material.dart';

import '../tokens.dart';

enum AppStatusChipVariant { success, warning, danger, neutral }

class AppStatusChip extends StatelessWidget {
  const AppStatusChip({
    required this.label,
    this.variant = AppStatusChipVariant.neutral,
    super.key,
  });

  final String label;
  final AppStatusChipVariant variant;

  Color get _background {
    switch (variant) {
      case AppStatusChipVariant.success:
        return const Color(0xFFE3F2E4);
      case AppStatusChipVariant.warning:
        return const Color(0xFFFFF0E0);
      case AppStatusChipVariant.danger:
        return const Color(0xFFFFE9E9);
      case AppStatusChipVariant.neutral:
        return AppColors.surface;
    }
  }

  Color get _foreground {
    switch (variant) {
      case AppStatusChipVariant.success:
        return AppColors.primary;
      case AppStatusChipVariant.warning:
        return AppColors.secondary;
      case AppStatusChipVariant.danger:
        return AppColors.danger;
      case AppStatusChipVariant.neutral:
        return AppColors.muted;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      key: Key('status_chip_${variant.name}'),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: _background,
        borderRadius: AppRadii.pillBorder,
      ),
      child: Text(
        label,
        style: AppTextStyles.label.copyWith(color: _foreground),
      ),
    );
  }
}
