import 'package:flutter/material.dart';

import '../../core/haptics/app_haptics.dart';
import '../app_palette.dart';
import '../tokens.dart';
import 'app_pressable.dart';

enum AppButtonVariant { primary, secondary, inverted, outlined }

enum AppButtonSize { regular, compact }

class AppButton extends StatelessWidget {
  const AppButton({
    required this.label,
    required this.onPressed,
    this.variant = AppButtonVariant.primary,
    this.size = AppButtonSize.regular,
    this.loading = false,
    this.icon,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;
  final AppButtonVariant variant;
  final AppButtonSize size;
  final bool loading;
  final Widget? icon;

  bool get _enabled => onPressed != null && !loading;

  Color _background(AppPalette palette) {
    switch (variant) {
      case AppButtonVariant.primary:
        return palette.primary;
      case AppButtonVariant.secondary:
        return palette.secondaryContainer;
      case AppButtonVariant.inverted:
        return palette.inverted;
      case AppButtonVariant.outlined:
        return Colors.transparent;
    }
  }

  Color _foreground(AppPalette palette) {
    switch (variant) {
      case AppButtonVariant.primary:
        return palette.onPrimary;
      case AppButtonVariant.secondary:
        return palette.onSecondaryContainer;
      case AppButtonVariant.inverted:
        return palette.onInverted;
      case AppButtonVariant.outlined:
        return palette.ink;
    }
  }

  BorderSide _border(AppPalette palette) {
    if (variant == AppButtonVariant.outlined) {
      return BorderSide(color: palette.line, width: AppSizes.border);
    }
    return BorderSide.none;
  }

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = context.palette;
    final Color foreground = _foreground(palette);
    final double height = size == AppButtonSize.regular
        ? AppSizes.buttonRegular
        : AppSizes.buttonCompact;
    final double horizontal = size == AppButtonSize.regular
        ? AppSpacing.xl
        : AppSpacing.lg;
    final TextStyle textStyle = size == AppButtonSize.regular
        ? AppTextStyles.body.copyWith(
            color: foreground,
            fontWeight: FontWeight.w700,
          )
        : AppTextStyles.label.copyWith(
            color: foreground,
            fontWeight: FontWeight.w700,
          );

    final Widget content = loading
        ? SizedBox(
            width: AppSizes.loadingIndicator,
            height: AppSizes.loadingIndicator,
            child: CircularProgressIndicator(
              strokeWidth: AppSizes.loadingStroke,
              color: foreground,
            ),
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              if (icon != null) ...<Widget>[
                IconTheme.merge(
                  data: IconThemeData(
                    color: foreground,
                    size: AppSizes.buttonIcon,
                  ),
                  child: icon!,
                ),
                const SizedBox(width: AppSpacing.sm),
              ],
              Flexible(
                child: Text(
                  label,
                  style: textStyle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          );

    return Semantics(
      button: true,
      enabled: _enabled,
      label: label,
      child: Opacity(
        opacity: _enabled || loading ? 1 : AppOpacity.disabled,
        child: Material(
          color: _background(palette),
          shape: RoundedRectangleBorder(
            borderRadius: AppRadii.pillBorder,
            side: _border(palette),
          ),
          clipBehavior: Clip.antiAlias,
          child: AppPressable(
            onTap: _enabled ? onPressed : null,
            enabled: _enabled,
            borderRadius: AppRadii.pillBorder,
            haptics:
                variant == AppButtonVariant.primary ||
                    variant == AppButtonVariant.inverted
                ? AppHapticType.confirm
                : AppHapticType.tap,
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: height),
              child: SizedBox(
                height: height,
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: horizontal),
                  child: Center(widthFactor: 1, child: content),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
