import 'package:flutter/material.dart';

import '../../core/i18n/app_language.dart';
import '../app_palette.dart';
import '../tokens.dart';

class LanguageSwitcher extends StatelessWidget {
  const LanguageSwitcher({
    required this.value,
    required this.onChanged,
    super.key,
  });

  final AppLanguage value;
  final ValueChanged<AppLanguage> onChanged;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = context.palette;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: AppLanguage.values.map((AppLanguage language) {
        final bool selected = language == value;
        return Padding(
          padding: const EdgeInsets.only(right: AppSpacing.xs),
          child: Semantics(
            button: true,
            selected: selected,
            label: language.label,
            child: InkWell(
              key: ValueKey<String>('language_${language.apiCode}'),
              borderRadius: AppRadii.pillBorder,
              onTap: () => onChanged(language),
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  minWidth: AppSizes.languagePill,
                  minHeight: AppSizes.languagePill,
                ),
                child: Container(
                  alignment: Alignment.center,
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                  ),
                  decoration: BoxDecoration(
                    color: selected ? palette.primary : palette.inputFill,
                    borderRadius: AppRadii.pillBorder,
                  ),
                  child: Text(
                    language.label,
                    style: AppTextStyles.label.copyWith(
                      color: selected ? palette.onPrimary : palette.primary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
