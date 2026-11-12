import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

import '../tokens.dart';
import '../app_palette.dart';

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

  Color _background(AppPalette palette) {
    switch (tone) {
      case AppStatusBannerTone.info:
        return palette.primaryContainer;
      case AppStatusBannerTone.warning:
        return palette.secondaryContainer;
      case AppStatusBannerTone.error:
        return palette.dangerContainer;
    }
  }

  Color _foreground(AppPalette palette) {
    switch (tone) {
      case AppStatusBannerTone.info:
        return palette.onPrimaryContainer;
      case AppStatusBannerTone.warning:
        return palette.accent;
      case AppStatusBannerTone.error:
        return palette.onDangerContainer;
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
    final AppPalette palette = context.palette;
    final Color foreground = _foreground(palette);
    final Widget content = Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      decoration: BoxDecoration(
        color: _background(palette),
        borderRadius: AppRadii.smallBorder,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          Icon(icon ?? _icon, color: foreground, size: AppSizes.icon),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              message,
              style: AppTextStyles.body.copyWith(color: foreground),
            ),
          ),
          if (actionLabel != null) ...<Widget>[
            const SizedBox(width: AppSpacing.sm),
            TextButton(
              onPressed: onAction,
              style: TextButton.styleFrom(foregroundColor: foreground),
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
