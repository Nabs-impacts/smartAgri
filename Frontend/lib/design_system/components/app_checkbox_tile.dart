import 'package:flutter/material.dart';

import '../tokens.dart';

class AppCheckboxTile extends StatelessWidget {
  const AppCheckboxTile({
    required this.label,
    required this.value,
    required this.onChanged,
    super.key,
  });

  final String label;
  final bool value;
  final ValueChanged<bool>? onChanged;

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
        child: SizedBox(
          height: AppSizes.touchTarget,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              AnimatedContainer(
                duration: AppDurations.fast,
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color: value ? AppColors.primary : AppColors.transparent,
                  borderRadius: AppRadii.smallBorder,
                  border: Border.all(
                    color: value ? AppColors.primary : AppColors.line,
                    width: AppSizes.border,
                  ),
                ),
                child: value
                    ? const Icon(
                        Icons.check,
                        size: AppSizes.smallIcon,
                        color: AppColors.white,
                      )
                    : null,
              ),
              const SizedBox(width: AppSpacing.sm),
              Flexible(
                child: Text(
                  label,
                  style: AppTextStyles.body.copyWith(
                    color: AppColors.ink,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
