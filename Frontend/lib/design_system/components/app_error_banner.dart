import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

import '../../core/haptics/app_haptics.dart';
import '../app_icons.dart';
import '../app_palette.dart';
import '../tokens.dart';

class AppErrorBanner extends StatefulWidget {
  const AppErrorBanner({required this.message, super.key});

  final String message;

  @override
  State<AppErrorBanner> createState() => _AppErrorBannerState();
}

class _AppErrorBannerState extends State<AppErrorBanner> {
  @override
  void initState() {
    super.initState();
    AppHaptics.trigger(AppHapticType.error);
  }

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = context.palette;
    return Semantics(
      container: true,
      role: SemanticsRole.alert,
      label: widget.message,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
        decoration: BoxDecoration(
          color: palette.dangerContainer,
          borderRadius: AppRadii.smallBorder,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Icon(AppIcons.warning, color: palette.danger, size: AppSizes.icon),
            const SizedBox(width: AppSpacing.sm),
            Flexible(
              child: Text(
                widget.message,
                style: AppTextStyles.body.copyWith(color: palette.danger),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
