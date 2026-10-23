import 'package:flutter/material.dart';

import '../../core/i18n/app_language.dart';
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
              child: selected
                  ? Container(
                      width: AppSizes.languageCircle,
                      height: AppSizes.languageCircle,
                      alignment: Alignment.center,
                      decoration: const BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        language.label,
                        style: AppTextStyles.label.copyWith(
                          color: AppColors.white,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    )
                  : Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md,
                        vertical: AppSpacing.sm,
                      ),
                      decoration: const BoxDecoration(
                        color: AppColors.inputFill,
                        borderRadius: AppRadii.pillBorder,
                      ),
                      child: Text(
                        language.label,
                        style: AppTextStyles.label.copyWith(
                          color: AppColors.primary,
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
