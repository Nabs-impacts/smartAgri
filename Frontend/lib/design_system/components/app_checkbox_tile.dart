import 'package:flutter/material.dart';

import '../../core/haptics/app_haptics.dart';
import '../app_icons.dart';
import '../app_palette.dart';
import '../tokens.dart';
import 'app_pressable.dart';

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
    final AppPalette palette = context.palette;
    return Semantics(
      checked: value,
      enabled: _enabled,
      label: label,
      child: AppPressable(
        onTap: () => onChanged!(!value),
        enabled: _enabled,
        borderRadius: AppRadii.smallBorder,
        haptics: AppHapticType.tap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: AppSizes.touchTarget),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                AnimatedContainer(
                  duration: AppDurations.fast,
                  width: AppSizes.checkbox,
                  height: AppSizes.checkbox,
                  decoration: BoxDecoration(
                    color: value ? palette.primary : Colors.transparent,
                    borderRadius: AppRadii.smallBorder,
                    border: Border.all(
                      color: value ? palette.primary : palette.line,
                      width: AppSizes.border,
                    ),
                  ),
                  child: value
                      ? Icon(
                          AppIcons.check,
                          size: AppSizes.smallIcon,
                          color: palette.onPrimary,
                        )
                      : null,
                ),
                const SizedBox(width: AppSpacing.md),
                Flexible(
                  child: Text(
                    label,
                    style: AppTextStyles.body.copyWith(
                      color: palette.ink,
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
