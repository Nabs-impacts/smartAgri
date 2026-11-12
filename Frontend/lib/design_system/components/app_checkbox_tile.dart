import 'package:flutter/material.dart';

import '../tokens.dart';
import '../app_palette.dart';

class AppCheckboxTile extends StatelessWidget {
  const AppCheckboxTile({
    required this.label,
    required this.value,
    required this.onChanged,
    this.maxLines = 1,
    super.key,
  });

  final String label;
  final bool value;
  final ValueChanged<bool>? onChanged;
  final int maxLines;

  bool get _enabled => onChanged != null;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      checked: value,
      enabled: _enabled,
      label: label,
      child: InkWell(
        onTap: _enabled ? () => onChanged!(!value) : null,
        borderRadius: AppRadii.smallBorder,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: AppSizes.touchTarget),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                AnimatedContainer(
                  duration: AppDurations.fast,
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    color: value ? context.palette.primary : Colors.transparent,
                    borderRadius: AppRadii.smallBorder,
                    border: Border.all(
                      color: value
                          ? context.palette.primary
                          : context.palette.line,
                      width: AppSizes.border,
                    ),
                  ),
                  child: value
                      ? Icon(
                          Icons.check,
                          size: AppSizes.smallIcon,
                          color: context.palette.onPrimary,
                        )
                      : null,
                ),
                const SizedBox(width: AppSpacing.sm),
                Flexible(
                  child: Text(
                    label,
                    style: AppTextStyles.body.copyWith(
                      color: context.palette.ink,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: maxLines,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
