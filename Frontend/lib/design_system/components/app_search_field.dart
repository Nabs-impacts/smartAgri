import 'package:flutter/material.dart';

import '../tokens.dart';
import '../app_palette.dart';

class AppSearchField extends StatelessWidget {
  const AppSearchField({
    this.controller,
    this.hintText = 'Rechercher',
    this.onChanged,
    this.onSubmitted,
    super.key,
  });

  final TextEditingController? controller;
  final String hintText;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      onChanged: onChanged,
      onSubmitted: onSubmitted,
      textInputAction: TextInputAction.search,
      style: AppTextStyles.body.copyWith(color: context.palette.ink),
      cursorColor: context.palette.primary,
      decoration: InputDecoration(
        filled: true,
        fillColor: context.palette.surface,
        hintText: hintText,
        hintStyle: AppTextStyles.body.copyWith(color: context.palette.muted),
        prefixIcon: Icon(
          Icons.search,
          color: context.palette.muted,
          size: AppSizes.icon,
        ),
        prefixIconConstraints: const BoxConstraints(
          minWidth: AppSizes.touchTarget,
          minHeight: AppSizes.touchTarget,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.lg,
        ),
        border: const OutlineInputBorder(
          borderRadius: AppRadii.pillBorder,
          borderSide: BorderSide.none,
        ),
        enabledBorder: const OutlineInputBorder(
          borderRadius: AppRadii.pillBorder,
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: AppRadii.pillBorder,
          borderSide: BorderSide(
            color: context.palette.primary,
            width: AppSizes.focusBorder,
          ),
        ),
      ),
    );
  }
}
