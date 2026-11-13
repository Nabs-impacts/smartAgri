import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app_icons.dart';
import '../app_palette.dart';
import '../tokens.dart';

class AppTextField extends StatefulWidget {
  const AppTextField({
    this.controller,
    this.hintText,
    this.obscure = false,
    this.suffixIcon,
    this.prefixText,
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
    this.inputFormatters,
    super.key,
  });

  final TextEditingController? controller;
  final String? hintText;
  final bool obscure;
  final Widget? suffixIcon;
  final String? prefixText;
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
  final List<TextInputFormatter>? inputFormatters;

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
          _obscured ? AppIcons.visibility : AppIcons.visibilityOff,
          color: context.palette.muted,
          size: AppSizes.icon,
        ),
      );
    }
    return widget.suffixIcon;
  }

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = context.palette;
    const OutlineInputBorder baseBorder = OutlineInputBorder(
      borderRadius: AppRadii.pillBorder,
      borderSide: BorderSide.none,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        if (widget.hintText != null)
          Padding(
            padding: const EdgeInsets.only(
              left: AppSpacing.lg,
              bottom: AppSizes.fieldLabelGap,
            ),
            child: Text(
              widget.hintText!,
              style: AppTextStyles.label.copyWith(color: palette.muted),
            ),
          ),
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
          inputFormatters: widget.inputFormatters,
          cursorColor: palette.primary,
          style: AppTextStyles.body.copyWith(color: palette.ink),
          decoration: InputDecoration(
            filled: true,
            fillColor: palette.inputFill,
            hintStyle: AppTextStyles.body.copyWith(color: palette.muted),
            prefixText: widget.prefixText,
            prefixStyle: AppTextStyles.body.copyWith(color: palette.muted),
            errorText: widget.errorText,
            errorStyle: AppTextStyles.caption.copyWith(color: palette.danger),
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
            focusedBorder: OutlineInputBorder(
              borderRadius: AppRadii.pillBorder,
              borderSide: BorderSide(
                color: palette.primary,
                width: AppSizes.focusBorder,
              ),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: AppRadii.pillBorder,
              borderSide: BorderSide(color: palette.danger),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: AppRadii.pillBorder,
              borderSide: BorderSide(
                color: palette.danger,
                width: AppSizes.focusBorder,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
