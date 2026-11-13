import 'package:flutter/material.dart';

import '../app_palette.dart';
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

  Color _background(AppPalette palette) {
    switch (variant) {
      case AppIconButtonVariant.square:
      case AppIconButtonVariant.primary:
        return palette.primary;
      case AppIconButtonVariant.accentBrown:
        return palette.accent;
      case AppIconButtonVariant.tertiary:
        return palette.tertiary;
      case AppIconButtonVariant.danger:
        return palette.danger;
      case AppIconButtonVariant.dangerOutline:
        return Colors.transparent;
    }
  }

  Color _foreground(AppPalette palette) {
    switch (variant) {
      case AppIconButtonVariant.danger:
        return palette.onDanger;
      case AppIconButtonVariant.dangerOutline:
        return palette.danger;
      case AppIconButtonVariant.square:
      case AppIconButtonVariant.primary:
      case AppIconButtonVariant.accentBrown:
      case AppIconButtonVariant.tertiary:
        return palette.onPrimary;
    }
  }

  ShapeBorder _shape(AppPalette palette) {
    if (variant == AppIconButtonVariant.square) {
      return const RoundedRectangleBorder(borderRadius: AppRadii.smallBorder);
    }
    if (variant == AppIconButtonVariant.dangerOutline) {
      return CircleBorder(
        side: BorderSide(color: palette.danger, width: AppSizes.border),
      );
    }
    return const CircleBorder();
  }

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = context.palette;
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
            color: _background(palette),
            shape: _shape(palette),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: onPressed,
              customBorder: _shape(palette),
              child: SizedBox(
                width: AppSizes.iconButton,
                height: AppSizes.iconButton,
                child: Icon(
                  icon,
                  color: _foreground(palette),
                  size: AppSizes.icon,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
