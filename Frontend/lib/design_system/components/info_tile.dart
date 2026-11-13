import 'package:flutter/material.dart';

import '../app_icons.dart';
import '../app_palette.dart';
import '../tokens.dart';

class InfoTile extends StatelessWidget {
  const InfoTile({required this.label, this.icon = AppIcons.wind, super.key});

  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = context.palette;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: palette.inputFill,
        borderRadius: AppRadii.pillBorder,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: AppSizes.smallIcon, color: palette.muted),
          const SizedBox(width: AppSpacing.xs),
          Text(
            label,
            style: AppTextStyles.caption.copyWith(color: palette.muted),
          ),
        ],
      ),
    );
  }
}
