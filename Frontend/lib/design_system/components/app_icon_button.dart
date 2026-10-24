import 'package:flutter/material.dart';

import '../tokens.dart';

enum AppIconButtonVariant {
  square,
  primary,
  accentBrown,
  tertiary,
  danger,
  dangerOutline,
}

class AppIconButton extends StatelessWidget {
  const AppIconButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.variant = AppIconButtonVariant.primary,
    super.key,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final AppIconButtonVariant variant;

  Color get _background {
    switch (variant) {
      case AppIconButtonVariant.square:
      case AppIconButtonVariant.primary:
        return AppColors.primary;
      case AppIconButtonVariant.accentBrown:
        return AppColors.accentBrown;
      case AppIconButtonVariant.tertiary:
        return AppColors.tertiary;
      case AppIconButtonVariant.danger:
        return AppColors.danger;
      case AppIconButtonVariant.dangerOutline:
        return AppColors.transparent;
    }
  }

  Color get _foreground {
    if (variant == AppIconButtonVariant.dangerOutline) {
      return AppColors.danger;
    }
    return AppColors.white;
  }

  ShapeBorder get _shape {
    if (variant == AppIconButtonVariant.square) {
      return const RoundedRectangleBorder(borderRadius: AppRadii.smallBorder);
    }
    if (variant == AppIconButtonVariant.dangerOutline) {
      return const CircleBorder(
        side: BorderSide(color: AppColors.danger, width: AppSizes.border),
      );
    }
    return const CircleBorder();
  }

  @override
  Widget build(BuildContext context) {
    final bool enabled = onPressed != null;
    return Tooltip(
      message: tooltip,
      child: Semantics(
        button: true,
        enabled: enabled,
        label: tooltip,
        child: Opacity(
          opacity: enabled ? 1 : AppOpacity.disabled,
          child: Material(
            color: _background,
            shape: _shape,
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: onPressed,
              customBorder: _shape,
              child: SizedBox(
                width: AppSizes.iconButton,
                height: AppSizes.iconButton,
                child: Icon(icon, color: _foreground, size: AppSizes.icon),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
