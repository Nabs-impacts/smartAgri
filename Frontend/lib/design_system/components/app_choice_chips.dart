import 'package:flutter/material.dart';

import '../tokens.dart';

class AppChoiceOption<T> {
  const AppChoiceOption({required this.value, required this.label});

  final T value;
  final String label;
}

class AppChoiceChips<T> extends StatelessWidget {
  const AppChoiceChips({
    required this.options,
    required this.value,
    required this.onChanged,
    this.enabled = true,
    super.key,
  });

  final List<AppChoiceOption<T>> options;
  final T? value;
  final ValueChanged<T> onChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 1 : AppOpacity.disabled,
      child: Wrap(
        spacing: AppSpacing.sm,
        runSpacing: AppSpacing.sm,
        children: <Widget>[
          for (final AppChoiceOption<T> option in options)
            _ChoiceChip<T>(
              option: option,
              selected: option.value == value,
              enabled: enabled,
              onTap: () => onChanged(option.value),
            ),
        ],
      ),
    );
  }
}

class _ChoiceChip<T> extends StatelessWidget {
  const _ChoiceChip({
    required this.option,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  final AppChoiceOption<T> option;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final Color background = selected ? AppColors.primary : AppColors.surface;
    final Color foreground = selected ? AppColors.white : AppColors.ink;
    return Semantics(
      button: true,
      selected: selected,
      enabled: enabled,
      label: option.label,
      child: Material(
        color: background,
        shape: const StadiumBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: enabled ? onTap : null,
          child: SizedBox(
            height: AppSizes.touchTarget,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              child: Center(
                child: Text(
                  option.label,
                  style: AppTextStyles.label.copyWith(color: foreground),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
