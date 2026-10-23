import 'package:flutter/material.dart';

import '../tokens.dart';

class AppTextField extends StatefulWidget {
  const AppTextField({
    this.controller,
    this.hintText,
    this.obscure = false,
    this.suffixIcon,
    this.errorText,
    this.keyboardType,
    this.textInputAction,
    this.validator,
    this.onChanged,
    this.onSubmitted,
    this.enabled = true,
    this.autofillHints,
    this.focusNode,
    this.maxLines = 1,
    super.key,
  });

  final TextEditingController? controller;
  final String? hintText;
  final bool obscure;
  final Widget? suffixIcon;
  final String? errorText;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final String? Function(String?)? validator;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final bool enabled;
  final Iterable<String>? autofillHints;
  final FocusNode? focusNode;
  final int maxLines;

  @override
  State<AppTextField> createState() => _AppTextFieldState();
}

class _AppTextFieldState extends State<AppTextField> {
  late bool _obscured;

  @override
  void initState() {
    super.initState();
    _obscured = widget.obscure;
  }

  @override
  void didUpdateWidget(covariant AppTextField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.obscure != widget.obscure) {
      _obscured = widget.obscure;
    }
  }

  Widget? get _suffix {
    if (widget.obscure) {
      return IconButton(
        tooltip: _obscured
            ? 'Afficher le mot de passe'
            : 'Masquer le mot de passe',
        onPressed: () => setState(() => _obscured = !_obscured),
        icon: Icon(
          _obscured ? Icons.visibility_outlined : Icons.visibility_off_outlined,
          color: AppColors.muted,
          size: AppSizes.icon,
        ),
      );
    }
    return widget.suffixIcon;
  }

  @override
  Widget build(BuildContext context) {
    const OutlineInputBorder baseBorder = OutlineInputBorder(
      borderRadius: AppRadii.pillBorder,
      borderSide: BorderSide.none,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        TextFormField(
          controller: widget.controller,
          focusNode: widget.focusNode,
          obscureText: widget.obscure && _obscured,
          enabled: widget.enabled,
          keyboardType: widget.keyboardType,
          textInputAction: widget.textInputAction,
          validator: widget.validator,
          onChanged: widget.onChanged,
          onFieldSubmitted: widget.onSubmitted,
          autofillHints: widget.autofillHints,
          maxLines: widget.maxLines,
          cursorColor: AppColors.primary,
          style: AppTextStyles.body,
          decoration: InputDecoration(
            filled: true,
            fillColor: AppColors.inputFill,
            hintText: widget.hintText,
            hintStyle: AppTextStyles.body.copyWith(color: AppColors.muted),
            errorText: widget.errorText,
            errorStyle: AppTextStyles.caption.copyWith(color: AppColors.danger),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.xl,
              vertical: AppSpacing.lg,
            ),
            suffixIcon: _suffix,
            suffixIconConstraints: const BoxConstraints(
              minWidth: AppSizes.touchTarget,
              minHeight: AppSizes.touchTarget,
            ),
            border: baseBorder,
            enabledBorder: baseBorder,
            disabledBorder: baseBorder,
            focusedBorder: const OutlineInputBorder(
              borderRadius: AppRadii.pillBorder,
              borderSide: BorderSide(
                color: AppColors.primary,
                width: AppSizes.focusBorder,
              ),
            ),
            errorBorder: const OutlineInputBorder(
              borderRadius: AppRadii.pillBorder,
              borderSide: BorderSide(color: AppColors.danger),
            ),
            focusedErrorBorder: const OutlineInputBorder(
              borderRadius: AppRadii.pillBorder,
              borderSide: BorderSide(
                color: AppColors.danger,
                width: AppSizes.focusBorder,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
