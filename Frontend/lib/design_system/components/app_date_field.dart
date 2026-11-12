import 'package:flutter/material.dart';

import '../tokens.dart';
import '../app_palette.dart';

class AppDateField extends StatelessWidget {
  const AppDateField({
    required this.hintText,
    required this.value,
    required this.onChanged,
    this.errorText,
    this.enabled = true,
    this.allowClear = false,
    this.clearTooltip = 'Effacer',
    this.firstDate,
    this.lastDate,
    super.key,
  });

  final String hintText;
  final DateTime? value;
  final ValueChanged<DateTime?>? onChanged;
  final String? errorText;
  final bool enabled;
  final bool allowClear;
  final String clearTooltip;
  final DateTime? firstDate;
  final DateTime? lastDate;

  bool get _enabled => enabled && onChanged != null;

  @override
  Widget build(BuildContext context) {
    final bool hasError = errorText != null && errorText!.isNotEmpty;
    final DateTime? current = value;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Semantics(
          button: true,
          enabled: _enabled,
          label: current == null ? hintText : _format(current),
          child: Opacity(
            opacity: _enabled ? 1 : AppOpacity.disabled,
            child: Material(
              color: context.palette.inputFill,
              shape: RoundedRectangleBorder(
                borderRadius: AppRadii.pillBorder,
                side: hasError
                    ? BorderSide(color: context.palette.danger)
                    : BorderSide.none,
              ),
              clipBehavior: Clip.antiAlias,
              child: SizedBox(
                height: AppSizes.fieldHeight,
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: InkWell(
                        onTap: _enabled ? () => _open(context) : null,
                        child: Padding(
                          padding: const EdgeInsets.only(
                            left: AppSpacing.xl,
                            right: AppSpacing.sm,
                          ),
                          child: Row(
                            children: <Widget>[
                              Expanded(
                                child: Text(
                                  current == null ? hintText : _format(current),
                                  style: AppTextStyles.body.copyWith(
                                    color: current == null
                                        ? context.palette.muted
                                        : context.palette.ink,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Icon(
                                Icons.calendar_today_outlined,
                                color: context.palette.muted,
                                size: AppSizes.icon,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    if (allowClear && current != null)
                      IconButton(
                        tooltip: clearTooltip,
                        onPressed: _enabled ? () => onChanged!(null) : null,
                        icon: Icon(
                          Icons.close,
                          color: context.palette.muted,
                          size: AppSizes.icon,
                        ),
                      ),
                  ],
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
              style: AppTextStyles.caption.copyWith(
                color: context.palette.danger,
              ),
            ),
          ),
      ],
    );
  }

  Future<void> _open(BuildContext context) async {
    final DateTime now = DateTime.now();
    final DateTime first = firstDate ?? DateTime(2000);
    final DateTime last = lastDate ?? DateTime(2100);
    DateTime initial = value ?? now;
    if (initial.isBefore(first)) {
      initial = first;
    } else if (initial.isAfter(last)) {
      initial = last;
    }
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: first,
      lastDate: last,
    );
    if (picked != null) {
      onChanged?.call(picked);
    }
  }

  String _format(DateTime value) {
    final String day = value.day.toString().padLeft(2, '0');
    final String month = value.month.toString().padLeft(2, '0');
    return '$day/$month/${value.year}';
  }
}
