import 'package:flutter/material.dart';

import '../tokens.dart';
import '../app_palette.dart';

class InfoTile extends StatelessWidget {
  const InfoTile({required this.label, this.icon = Icons.air, super.key});

  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: context.palette.inputFill,
        borderRadius: AppRadii.pillBorder,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: AppSizes.smallIcon, color: context.palette.muted),
          const SizedBox(width: AppSpacing.xs),
          Text(
            label,
            style: AppTextStyles.caption.copyWith(color: context.palette.muted),
          ),
        ],
      ),
    );
  }
}
