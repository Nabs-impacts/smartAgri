import 'package:flutter/material.dart';

import '../tokens.dart';
import '../app_palette.dart';

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

  Color _color(AppPalette palette) {
    switch (variant) {
      case AppTextButtonVariant.primary:
        return palette.primary;
      case AppTextButtonVariant.muted:
        return palette.muted;
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = context.palette;
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
                  style: AppTextStyles.label.copyWith(color: _color(palette)),
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
