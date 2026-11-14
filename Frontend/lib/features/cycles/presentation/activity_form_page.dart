import '../../../core/haptics/app_haptics.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../../../core/i18n/app_localizations.dart';
import '../../../core/i18n/strings_provider.dart';
import '../../../design_system/components/app_button.dart';
import '../../../design_system/components/app_skeleton.dart';
import '../../../design_system/components/app_choice_chips.dart';
import '../../../design_system/components/app_date_field.dart';
import '../../../design_system/components/app_error_banner.dart';
import '../../../design_system/components/app_text_button.dart';
import '../../../design_system/components/app_text_field.dart';
import '../../../design_system/tokens.dart';
import '../../../design_system/app_palette.dart';
import '../data/cycles_providers.dart';
import '../domain/activity.dart';
import '../domain/activity_type.dart';
import '../domain/cycle.dart';
import '../domain/cycle_exception.dart';
import 'cycle_display.dart';
import 'cycle_format.dart';

class ActivityFormPage extends ConsumerWidget {
  const ActivityFormPage({required this.cycleId, this.activityId, super.key});

  final String cycleId;
  final String? activityId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations strings = ref.watch(stringsProvider);
    final AsyncValue<Cycle> cycle = ref.watch(cycleProvider(cycleId));
    if (cycle.isLoading && !cycle.hasValue) {
      return _LoadingScaffold(strings: strings);
    }
    if (!cycle.hasValue) {
      return _NotFoundScaffold(
        strings: strings,
        message: strings.cycleNotFound,
        retryKey: const Key('activity_cycle_retry'),
        onRetry: () => ref.invalidate(cycleProvider(cycleId)),
      );
    }
    if (activityId == null) {
      return _ActivityForm(strings: strings, cycle: cycle.value!);
    }
    final AsyncValue<List<Activity>> activities = ref.watch(
      activitiesProvider(cycleId),
    );
    if (activities.isLoading && !activities.hasValue) {
      return _LoadingScaffold(strings: strings);
    }
    Activity? activity;
    for (final Activity item in activities.value ?? <Activity>[]) {
      if (item.id == activityId) {
        activity = item;
        break;
      }
    }
    if (activity == null) {
      return _NotFoundScaffold(
        strings: strings,
        message: strings.activityNotFound,
        retryKey: const Key('activity_not_found'),
        onRetry: () => ref.invalidate(activitiesProvider(cycleId)),
      );
    }
    return _ActivityForm(
      strings: strings,
      cycle: cycle.value!,
      activity: activity,
    );
  }
}

class _LoadingScaffold extends StatelessWidget {
  const _LoadingScaffold({required this.strings});

  final AppLocalizations strings;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.palette.background,
      appBar: AppBar(title: Text(strings.activityCreateTitle)),
      body: SafeArea(
        child: const Padding(
          padding: EdgeInsets.all(AppSpacing.xl),
          child: SkeletonList(
            count: 5,
            itemHeight: 64,
            tile: false,
            keyPrefix: 'activity_form_skeleton',
          ),
        ),
      ),
    );
  }
}

class _NotFoundScaffold extends StatelessWidget {
  const _NotFoundScaffold({
    required this.strings,
    required this.message,
    required this.retryKey,
    required this.onRetry,
  });

  final AppLocalizations strings;
  final String message;
  final Key retryKey;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.palette.background,
      appBar: AppBar(title: Text(strings.activityEditTitle)),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  message,
                  key: retryKey,
                  style: AppTextStyles.body,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.lg),
                AppTextButton(
                  key: const Key('activity_back'),
                  label: strings.cycleBack,
                  onPressed: () {
                    if (context.canPop()) {
                      context.pop();
                    } else {
                      context.go('/home');
                    }
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ActivityForm extends ConsumerStatefulWidget {
  const _ActivityForm({
    required this.strings,
    required this.cycle,
    this.activity,
  });

  final AppLocalizations strings;
  final Cycle cycle;
  final Activity? activity;

  @override
  ConsumerState<_ActivityForm> createState() => _ActivityFormState();
}

class _ActivityFormState extends ConsumerState<_ActivityForm> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _product;
  late final TextEditingController _quantity;
  late final TextEditingController _unit;
  late final TextEditingController _cost;
  late final TextEditingController _notes;
  late final String _id;
  late ActivityType _type;
  late DateTime _date;
  bool _saving = false;
  String? _error;

  bool get _editing => widget.activity != null;

  @override
  void initState() {
    super.initState();
    final Activity? activity = widget.activity;
    _id = activity?.id ?? const Uuid().v4();
    _type = activity?.type ?? ActivityType.other;
    _date = activity?.performedOn ?? _today();
    _product = TextEditingController(text: activity?.productName ?? '');
    _quantity = TextEditingController(
      text: activity?.quantity == null
          ? ''
          : formatDecimalInput(activity!.quantity!),
    );
    _unit = TextEditingController(text: activity?.unit ?? '');
    _cost = TextEditingController(
      text: activity?.costXof == null ? '' : activity!.costXof!.toString(),
    );
    _notes = TextEditingController(text: activity?.notes ?? '');
  }

  @override
  void dispose() {
    _product.dispose();
    _quantity.dispose();
    _unit.dispose();
    _cost.dispose();
    _notes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.palette.background,
      appBar: AppBar(
        title: Text(
          _editing
              ? widget.strings.activityEditTitle
              : widget.strings.activityCreateTitle,
        ),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            key: const Key('activity_form_scroll'),
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.xl,
              AppSpacing.lg,
              AppSpacing.xl,
              AppSpacing.xl,
            ),
            children: <Widget>[
              if (_error != null) ...<Widget>[
                AppErrorBanner(
                  key: const Key('activity_form_error'),
                  message: _error!,
                ),
                const SizedBox(height: AppSpacing.lg),
              ],
              Text(
                widget.strings.activityTypeLabel,
                style: AppTextStyles.label,
              ),
              const SizedBox(height: AppSpacing.sm),
              AppChoiceChips<ActivityType>(
                key: const Key('activity_type_chips'),
                value: _type,
                options: ActivityType.values
                    .map(
                      (ActivityType type) => AppChoiceOption<ActivityType>(
                        value: type,
                        label: activityTypeLabel(widget.strings, type),
                      ),
                    )
                    .toList(),
                onChanged: (ActivityType value) =>
                    setState(() => _type = value),
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                widget.strings.activityDateLabel,
                style: AppTextStyles.label,
              ),
              const SizedBox(height: AppSpacing.sm),
              AppDateField(
                key: const Key('activity_date_field'),
                hintText: widget.strings.cycleDateHint,
                value: _date,
                onChanged: (DateTime? value) {
                  if (value != null) {
                    setState(() => _date = value);
                  }
                },
              ),
              const SizedBox(height: AppSpacing.lg),
              AppTextField(
                key: const Key('activity_product_field'),
                controller: _product,
                hintText: widget.strings.activityProductLabel,
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: AppSpacing.md),
              AppTextField(
                key: const Key('activity_quantity_field'),
                controller: _quantity,
                hintText: widget.strings.activityQuantityLabel,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                textInputAction: TextInputAction.next,
                validator: _validQuantity,
              ),
              const SizedBox(height: AppSpacing.md),
              AppTextField(
                key: const Key('activity_unit_field'),
                controller: _unit,
                hintText: widget.strings.activityUnitLabel,
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: AppSpacing.md),
              AppTextField(
                key: const Key('activity_cost_field'),
                controller: _cost,
                hintText: widget.strings.activityCostLabel,
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.next,
                validator: _validCost,
              ),
              const SizedBox(height: AppSpacing.md),
              AppTextField(
                key: const Key('activity_notes_field'),
                controller: _notes,
                hintText: widget.strings.activityNotesLabel,
                maxLines: 3,
              ),
              const SizedBox(height: AppSpacing.xl),
              AppButton(
                key: const Key('activity_save'),
                label: widget.strings.activitySave,
                loading: _saving,
                onPressed: _saving ? null : _submit,
              ),
            ],
          ),
        ),
      ),
    );
  }

  String? _validQuantity(String? value) {
    final String text = value?.trim() ?? '';
    if (text.isEmpty) {
      return null;
    }
    final double? quantity = _parseDecimal(text);
    if (quantity == null || quantity < 0) {
      return widget.strings.activityQuantityInvalid;
    }
    return null;
  }

  String? _validCost(String? value) {
    final String text = value?.trim() ?? '';
    if (text.isEmpty) {
      return null;
    }
    final int? cost = _parseInt(text);
    if (cost == null || cost < 0) {
      return widget.strings.activityCostInvalid;
    }
    return null;
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    final String? product = _trimmedOrNull(_product.text);
    final String? quantityText = _trimmedOrNull(_quantity.text);
    final String? unit = _trimmedOrNull(_unit.text);
    final String? costText = _trimmedOrNull(_cost.text);
    final String? notes = _trimmedOrNull(_notes.text);
    try {
      final notifier = ref.read(activitiesProvider(widget.cycle.id).notifier);
      if (_editing) {
        await notifier.updateActivity(
          widget.activity!.id,
          type: _type,
          performedOn: _date,
          productName: product,
          quantity: quantityText == null ? null : _parseDecimal(quantityText),
          unit: unit,
          costXof: costText == null ? null : _parseInt(costText),
          notes: notes,
        );
      } else {
        await notifier.createActivity(
          _id,
          _type,
          _date,
          productName: product,
          quantity: quantityText == null ? null : _parseDecimal(quantityText),
          unit: unit,
          costXof: costText == null ? null : _parseInt(costText),
          notes: notes,
        );
      }
      if (mounted) {
        AppHaptics.trigger(AppHapticType.success);
        context.pop();
      }
    } on CycleDomainException catch (error) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = error.message;
        });
      }
    }
  }

  String? _trimmedOrNull(String value) {
    final String trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }
}

DateTime _today() {
  final DateTime now = DateTime.now();
  return DateTime(now.year, now.month, now.day);
}

double? _parseDecimal(String value) {
  return double.tryParse(value.replaceAll(',', '.'));
}

int? _parseInt(String value) {
  final String cleaned = value.replaceAll(RegExp(r'[\s\u202F]'), '');
  return int.tryParse(cleaned);
}
