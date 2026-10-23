import 'package:flutter/material.dart';

import '../tokens.dart';

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

  Color get _background {
    switch (variant) {
      case AppButtonVariant.primary:
        return AppColors.primary;
      case AppButtonVariant.secondary:
        return AppColors.surface;
      case AppButtonVariant.inverted:
        return AppColors.inverted;
      case AppButtonVariant.outlined:
        return AppColors.transparent;
    }
  }

  Color get _foreground {
    switch (variant) {
      case AppButtonVariant.primary:
      case AppButtonVariant.inverted:
        return AppColors.white;
      case AppButtonVariant.secondary:
      case AppButtonVariant.outlined:
        return AppColors.ink;
    }
  }

  BorderSide get _border {
    if (variant == AppButtonVariant.outlined) {
      return const BorderSide(color: AppColors.line);
    }
    return BorderSide.none;
  }

  @override
  Widget build(BuildContext context) {
    final double height = size == AppButtonSize.regular
        ? AppSizes.buttonRegular
        : AppSizes.buttonCompact;
    final double horizontal = size == AppButtonSize.regular
        ? AppSpacing.xl
        : AppSpacing.lg;
    final TextStyle textStyle = size == AppButtonSize.regular
        ? AppTextStyles.body.copyWith(
            color: _foreground,
            fontWeight: FontWeight.w700,
          )
        : AppTextStyles.label.copyWith(color: _foreground);

    final Widget content = loading
        ? SizedBox(
            width: AppSizes.loadingIndicator,
            height: AppSizes.loadingIndicator,
            child: CircularProgressIndicator(
              strokeWidth: AppSizes.loadingStroke,
              color: _foreground,
            ),
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              if (icon != null) ...<Widget>[
                IconTheme.merge(
                  data: IconThemeData(
                    color: _foreground,
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
          color: _background,
          shape: RoundedRectangleBorder(
            borderRadius: AppRadii.pillBorder,
            side: _border,
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: _enabled ? onPressed : null,
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
    );
  }
}
