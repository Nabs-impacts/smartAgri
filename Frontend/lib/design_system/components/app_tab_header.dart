import 'package:flutter/material.dart';

import '../app_palette.dart';
import '../tokens.dart';

class AppTabHeader extends StatelessWidget {
  const AppTabHeader({required this.title, this.action, this.style, super.key});

  final String title;
  final Widget? action;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          Expanded(
            child: Text(
              title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: (style ?? AppTextStyles.display).copyWith(
                color: context.palette.ink,
              ),
            ),
          ),
          if (action != null) ...<Widget>[
            const SizedBox(width: AppSpacing.md),
            action!,
          ],
        ],
      ),
    );
  }
}
