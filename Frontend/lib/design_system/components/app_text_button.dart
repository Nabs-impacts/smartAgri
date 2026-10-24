import 'package:flutter/material.dart';

import '../tokens.dart';

enum AppTextButtonVariant { primary, muted }

class AppTextButton extends StatelessWidget {
  const AppTextButton({
    required this.label,
    required this.onPressed,
    this.variant = AppTextButtonVariant.primary,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;
  final AppTextButtonVariant variant;

  bool get _enabled => onPressed != null;

  Color get _color {
    switch (variant) {
      case AppTextButtonVariant.primary:
        return AppColors.primary;
      case AppTextButtonVariant.muted:
        return AppColors.muted;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      enabled: _enabled,
      label: label,
      child: Opacity(
        opacity: _enabled ? 1 : AppOpacity.disabled,
        child: InkWell(
          onTap: onPressed,
          borderRadius: AppRadii.smallBorder,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: AppSizes.touchTarget),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm,
                vertical: AppSpacing.md,
              ),
              child: Center(
                widthFactor: 1,
                child: Text(
                  label,
                  style: AppTextStyles.label.copyWith(color: _color),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
