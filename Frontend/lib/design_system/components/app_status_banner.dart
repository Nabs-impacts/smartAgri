import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

import '../tokens.dart';

enum AppStatusBannerTone { info, warning, error }

class AppStatusBanner extends StatelessWidget {
  const AppStatusBanner({
    required this.message,
    this.tone = AppStatusBannerTone.info,
    this.icon,
    this.onTap,
    this.actionLabel,
    this.onAction,
    super.key,
  });

  final String message;
  final AppStatusBannerTone tone;
  final IconData? icon;
  final VoidCallback? onTap;
  final String? actionLabel;
  final VoidCallback? onAction;

  Color get _background {
    switch (tone) {
      case AppStatusBannerTone.info:
        return AppColors.primaryContainer;
      case AppStatusBannerTone.warning:
        return AppColors.secondaryContainer;
      case AppStatusBannerTone.error:
        return const Color(0xFFFFEBEE);
    }
  }

  Color get _foreground {
    switch (tone) {
      case AppStatusBannerTone.info:
        return AppColors.ink;
      case AppStatusBannerTone.warning:
        return AppColors.accentBrown;
      case AppStatusBannerTone.error:
        return AppColors.danger;
    }
  }

  IconData get _icon {
    switch (tone) {
      case AppStatusBannerTone.info:
        return Icons.sync;
      case AppStatusBannerTone.warning:
        return Icons.cloud_off_outlined;
      case AppStatusBannerTone.error:
        return Icons.warning_amber_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final Widget content = Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      decoration: BoxDecoration(
        color: _background,
        borderRadius: AppRadii.smallBorder,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          Icon(icon ?? _icon, color: _foreground, size: AppSizes.icon),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              message,
              style: AppTextStyles.body.copyWith(color: _foreground),
            ),
          ),
          if (actionLabel != null) ...<Widget>[
            const SizedBox(width: AppSpacing.sm),
            TextButton(
              onPressed: onAction,
              style: TextButton.styleFrom(foregroundColor: _foreground),
              child: Text(actionLabel!),
            ),
          ],
        ],
      ),
    );
    return Semantics(
      container: true,
      role: tone == AppStatusBannerTone.error
          ? SemanticsRole.alert
          : SemanticsRole.status,
      label: message,
      button: onTap != null,
      child: onTap == null
          ? content
          : InkWell(
              borderRadius: AppRadii.smallBorder,
              onTap: onTap,
              child: content,
            ),
    );
  }
}
