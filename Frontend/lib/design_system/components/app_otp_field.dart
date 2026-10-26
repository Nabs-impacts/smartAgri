import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../tokens.dart';

class AppOtpField extends StatefulWidget {
  const AppOtpField({
    this.length = 6,
    this.onChanged,
    this.onCompleted,
    this.error = false,
    this.semanticLabel = 'Code de vérification',
    this.autofocus = false,
    super.key,
  });

  final int length;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onCompleted;
  final bool error;
  final String semanticLabel;
  final bool autofocus;

  @override
  State<AppOtpField> createState() => AppOtpFieldState();
}

class AppOtpFieldState extends State<AppOtpField> {
  late final List<TextEditingController> _controllers;
  late final List<FocusNode> _focusNodes;
  bool _updating = false;

  String get value => _controllers
      .map((TextEditingController controller) => controller.text)
      .join();

  @override
  void initState() {
    super.initState();
    _controllers = List<TextEditingController>.generate(
      widget.length,
      (int index) => TextEditingController(),
    );
    _focusNodes = List<FocusNode>.generate(
      widget.length,
      (int index) => FocusNode()..addListener(_onFocusChanged),
    );
    if (widget.autofocus) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _focusNodes.first.requestFocus();
        }
      });
    }
  }

  @override
  void dispose() {
    for (final TextEditingController controller in _controllers) {
      controller.dispose();
    }
    for (final FocusNode node in _focusNodes) {
      node.dispose();
    }
    super.dispose();
  }

  void clear() {
    _updating = true;
    for (final TextEditingController controller in _controllers) {
      controller.clear();
    }
    _updating = false;
    if (_focusNodes.isNotEmpty) {
      _focusNodes.first.requestFocus();
    }
    setState(() {});
    _notify();
  }

  void _onFocusChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  void _handleChanged(int index, String text) {
    if (_updating) {
      return;
    }
    final String digits = text.replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) {
      _notify();
      if (index > 0) {
        _focusNodes[index - 1].requestFocus();
      }
      return;
    }
    _updating = true;
    if (digits.length > 1) {
      int cursor = index;
      for (int offset = 0; offset < digits.length; offset++) {
        if (cursor >= widget.length) {
          break;
        }
        _controllers[cursor].text = digits[offset];
        cursor++;
      }
      final int target = cursor >= widget.length ? widget.length - 1 : cursor;
      _focusNodes[target].requestFocus();
    } else {
      _controllers[index].text = digits;
      _controllers[index].selection = TextSelection.collapsed(
        offset: digits.length,
      );
      if (index < widget.length - 1) {
        _focusNodes[index + 1].requestFocus();
      }
    }
    _updating = false;
    setState(() {});
    _notify();
  }

  void _notify() {
    final String current = value;
    widget.onChanged?.call(current);
    if (current.length == widget.length) {
      widget.onCompleted?.call(current);
    }
  }

  void _selectAll(int index) {
    final TextEditingController controller = _controllers[index];
    controller.selection = TextSelection(
      baseOffset: 0,
      extentOffset: controller.text.length,
    );
  }

  Widget _buildBox(int index) {
    final bool focused = _focusNodes[index].hasFocus;
    final Color borderColor = widget.error
        ? AppColors.danger
        : focused
        ? AppColors.primary
        : AppColors.transparent;
    final double borderWidth = focused || widget.error
        ? AppSizes.focusBorder
        : AppSizes.border;

    return Expanded(
      child: AnimatedContainer(
        duration: AppDurations.fast,
        height: 56,
        decoration: BoxDecoration(
          color: AppColors.inputFill,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: borderColor, width: borderWidth),
        ),
        alignment: Alignment.center,
        child: TextField(
          key: ValueKey<String>('otp_digit_$index'),
          controller: _controllers[index],
          focusNode: _focusNodes[index],
          keyboardType: TextInputType.number,
          textInputAction: index == widget.length - 1
              ? TextInputAction.done
              : TextInputAction.next,
          textAlign: TextAlign.center,
          style: AppTextStyles.title,
          cursorColor: AppColors.primary,
          autofillHints: index == 0
              ? const <String>[AutofillHints.oneTimeCode]
              : null,
          inputFormatters: <TextInputFormatter>[
            FilteringTextInputFormatter.digitsOnly,
          ],
          onChanged: (String text) => _handleChanged(index, text),
          onTap: () => _selectAll(index),
          decoration: const InputDecoration(
            border: InputBorder.none,
            isCollapsed: true,
            counterText: '',
            contentPadding: EdgeInsets.zero,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label: widget.semanticLabel,
      value: value,
      child: AutofillGroup(
        child: Row(
          children: <Widget>[
            for (int index = 0; index < widget.length; index++) ...<Widget>[
              _buildBox(index),
              if (index < widget.length - 1)
                const SizedBox(width: AppSpacing.sm),
            ],
          ],
        ),
      ),
    );
  }
}
