import 'package:flutter/material.dart';

import '../tokens.dart';

class AppSelectOption<T> {
  const AppSelectOption({required this.value, required this.label});

  final T value;
  final String label;
}

class AppSelectField<T> extends StatelessWidget {
  const AppSelectField({
    required this.hintText,
    required this.options,
    required this.value,
    required this.onChanged,
    this.errorText,
    this.allowEmpty = false,
    this.emptyLabel = 'Aucune',
    this.enabled = true,
    super.key,
  });

  final String hintText;
  final List<AppSelectOption<T>> options;
  final T? value;
  final ValueChanged<T?>? onChanged;
  final String? errorText;
  final bool allowEmpty;
  final String emptyLabel;
  final bool enabled;

  bool get _enabled => enabled && onChanged != null;

  AppSelectOption<T>? get _selected {
    for (final AppSelectOption<T> option in options) {
      if (option.value == value) {
        return option;
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final bool hasError = errorText != null && errorText!.isNotEmpty;
    final AppSelectOption<T>? selected = _selected;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Semantics(
          button: true,
          enabled: _enabled,
          label: selected?.label ?? hintText,
          child: Opacity(
            opacity: _enabled ? 1 : AppOpacity.disabled,
            child: Material(
              color: AppColors.inputFill,
              shape: RoundedRectangleBorder(
                borderRadius: AppRadii.pillBorder,
                side: hasError
                    ? const BorderSide(color: AppColors.danger)
                    : BorderSide.none,
              ),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: _enabled ? () => _open(context) : null,
                child: SizedBox(
                  height: AppSizes.fieldHeight,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.xl,
                    ),
                    child: Row(
                      children: <Widget>[
                        Expanded(
                          child: Text(
                            selected?.label ?? hintText,
                            style: AppTextStyles.body.copyWith(
                              color: selected == null
                                  ? AppColors.muted
                                  : AppColors.ink,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        const Icon(
                          Icons.keyboard_arrow_down,
                          color: AppColors.muted,
                          size: AppSizes.icon,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        if (hasError)
          Padding(
            padding: const EdgeInsets.only(
              top: AppSpacing.xs,
              left: AppSpacing.lg,
            ),
            child: Text(
              errorText!,
              style: AppTextStyles.caption.copyWith(color: AppColors.danger),
            ),
          ),
      ],
    );
  }

  Future<void> _open(BuildContext context) async {
    final _SelectResult<T>? result =
        await showModalBottomSheet<_SelectResult<T>>(
          context: context,
          backgroundColor: AppColors.white,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(AppRadii.card),
            ),
          ),
          builder: (BuildContext context) {
            return SafeArea(
              child: ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
                children: <Widget>[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.xl,
                      AppSpacing.sm,
                      AppSpacing.xl,
                      AppSpacing.md,
                    ),
                    child: Text(hintText, style: AppTextStyles.title),
                  ),
                  if (allowEmpty)
                    _OptionTile<T>(
                      label: emptyLabel,
                      selected: value == null,
                      onTap: () =>
                          Navigator.of(context)
                              .pop(const _SelectResult<Never>(null)),
                    ),
                  for (final AppSelectOption<T> option in options)
                    _OptionTile<T>(
                      label: option.label,
                      selected: option.value == value,
                      onTap: () =>
                          Navigator.of(context)
                              .pop(_SelectResult<T>(option.value)),
                    ),
                ],
              ),
            );
          },
        );
    if (result != null) {
      onChanged?.call(result.value);
    }
  }
}

class _OptionTile<T> extends StatelessWidget {
  const _OptionTile({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      selected: selected,
      button: true,
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: AppSizes.touchTarget),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.xl,
              vertical: AppSpacing.sm,
            ),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    label,
                    style: AppTextStyles.body.copyWith(
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
                      color: selected ? AppColors.primary : AppColors.ink,
                    ),
                  ),
                ),
                if (selected)
                  const Icon(
                    Icons.check,
                    color: AppColors.primary,
                    size: AppSizes.icon,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SelectResult<T> {
  const _SelectResult(this.value);

  final T? value;
}
