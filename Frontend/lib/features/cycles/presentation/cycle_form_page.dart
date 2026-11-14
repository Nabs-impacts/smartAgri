import '../../../core/haptics/app_haptics.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../../../core/i18n/app_language.dart';
import '../../../core/i18n/app_localizations.dart';
import '../../../core/i18n/language_controller.dart';
import '../../../core/i18n/strings_provider.dart';
import '../../../design_system/components/app_button.dart';
import '../../../design_system/components/app_skeleton.dart';
import '../../../design_system/components/app_choice_chips.dart';
import '../../../design_system/components/app_date_field.dart';
import '../../../design_system/components/app_error_banner.dart';
import '../../../design_system/components/app_select_field.dart';
import '../../../design_system/components/app_text_button.dart';
import '../../../design_system/components/app_text_field.dart';
import '../../../design_system/tokens.dart';
import '../../../design_system/app_palette.dart';
import '../../catalog/data/catalog_repository.dart';
import '../../catalog/domain/crop.dart';
import '../data/cycles_providers.dart';
import '../domain/cycle.dart';
import '../domain/cycle_exception.dart';
import '../domain/cycle_status.dart';
import 'cycle_display.dart';

class CycleFormPage extends ConsumerWidget {
  const CycleFormPage({this.plotId, this.cycleId, super.key});

  final String? plotId;
  final String? cycleId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations strings = ref.watch(stringsProvider);
    if (cycleId == null) {
      return _CycleForm(strings: strings, plotId: plotId ?? '');
    }
    final AsyncValue<Cycle> cycle = ref.watch(cycleProvider(cycleId!));
    if (cycle.value != null) {
      return _CycleForm(
        strings: strings,
        plotId: cycle.value!.plotId,
        cycle: cycle.value,
      );
    }
    return Scaffold(
      backgroundColor: context.palette.background,
      appBar: AppBar(title: Text(strings.cycleEditTitle)),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: cycle.isLoading
                ? const SkeletonList(
                    count: 5,
                    itemHeight: 64,
                    tile: false,
                    keyPrefix: 'cycle_form_skeleton',
                  )
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Text(
                        cycle.hasError
                            ? strings.cycleNotFound
                            : strings.cycleNotFound,
                        key: const Key('cycle_form_not_found'),
                        style: AppTextStyles.body,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      AppTextButton(
                        key: const Key('cycle_form_back'),
                        label: strings.cycleBack,
                        onPressed: () => _goBack(context),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

class _CycleForm extends ConsumerStatefulWidget {
  const _CycleForm({required this.strings, required this.plotId, this.cycle});

  final AppLocalizations strings;
  final String plotId;
  final Cycle? cycle;

  @override
  ConsumerState<_CycleForm> createState() => _CycleFormState();
}

class _CycleFormState extends ConsumerState<_CycleForm> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _variety;
  late final TextEditingController _season;
  late final TextEditingController _notes;
  late final String _id;
  int? _cropId;
  DateTime? _sowingDate;
  DateTime? _expectedHarvestDate;
  CycleStatus _status = CycleStatus.planned;
  bool _saving = false;
  String? _error;
  String? _cropError;
  String? _dateError;

  bool get _editing => widget.cycle != null;

  @override
  void initState() {
    super.initState();
    final Cycle? cycle = widget.cycle;
    _id = cycle?.id ?? const Uuid().v4();
    _cropId = cycle?.cropId;
    _variety = TextEditingController(text: cycle?.variety ?? '');
    _season = TextEditingController(text: cycle?.season ?? '');
    _notes = TextEditingController(text: cycle?.notes ?? '');
    _sowingDate = cycle?.sowingDate;
    _expectedHarvestDate = cycle?.expectedHarvestDate;
    if (cycle?.status == CycleStatus.growing) {
      _status = CycleStatus.growing;
    }
  }

  @override
  void dispose() {
    _variety.dispose();
    _season.dispose();
    _notes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final List<Crop> crops = ref.watch(cropsProvider).value ?? const <Crop>[];
    final AppLanguage language = ref.watch(languageControllerProvider);
    final List<AppSelectOption<int>> options = crops
        .map(
          (Crop crop) => AppSelectOption<int>(
            value: crop.id,
            label: crop.localizedName(language),
          ),
        )
        .toList();
    final Cycle? cycle = widget.cycle;
    if (cycle != null &&
        !options.any(
          (AppSelectOption<int> option) => option.value == cycle.cropId,
        )) {
      final String? fallback = ref
          .watch(cultureNameProvider(cycle.cropId))
          .value;
      options.insert(
        0,
        AppSelectOption<int>(
          value: cycle.cropId,
          label: fallback ?? cycle.cropId.toString(),
        ),
      );
    }
    return Scaffold(
      backgroundColor: context.palette.background,
      appBar: AppBar(
        title: Text(
          _editing
              ? widget.strings.cycleEditTitle
              : widget.strings.cycleCreateTitle,
        ),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            key: const Key('cycle_form_scroll'),
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.xl,
              AppSpacing.lg,
              AppSpacing.xl,
              AppSpacing.xl,
            ),
            children: <Widget>[
              if (_error != null) ...<Widget>[
                AppErrorBanner(
                  key: const Key('cycle_form_error'),
                  message: _error!,
                ),
                const SizedBox(height: AppSpacing.lg),
              ],
              Text(widget.strings.cycleCropLabel, style: AppTextStyles.label),
              const SizedBox(height: AppSpacing.sm),
              AppSelectField<int>(
                key: const Key('cycle_crop_field'),
                hintText: widget.strings.cycleCropLabel,
                options: options,
                value: _cropId,
                errorText: _cropError,
                onChanged: _editing
                    ? null
                    : (int? value) => setState(() {
                        _cropId = value;
                        _cropError = null;
                      }),
              ),
              const SizedBox(height: AppSpacing.lg),
              AppTextField(
                key: const Key('cycle_variety_field'),
                controller: _variety,
                hintText: widget.strings.cycleVarietyLabel,
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: AppSpacing.md),
              AppTextField(
                key: const Key('cycle_season_field'),
                controller: _season,
                hintText: widget.strings.cycleSeasonLabel,
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                widget.strings.cycleSowingDateLabel,
                style: AppTextStyles.label,
              ),
              const SizedBox(height: AppSpacing.sm),
              AppDateField(
                key: const Key('cycle_sowing_date_field'),
                hintText: widget.strings.cycleDateHint,
                value: _sowingDate,
                allowClear: true,
                clearTooltip: widget.strings.cycleDateClear,
                onChanged: (DateTime? value) => setState(() {
                  _sowingDate = value;
                  _dateError = null;
                }),
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                widget.strings.cycleExpectedHarvestDateLabel,
                style: AppTextStyles.label,
              ),
              const SizedBox(height: AppSpacing.sm),
              AppDateField(
                key: const Key('cycle_expected_harvest_date_field'),
                hintText: widget.strings.cycleDateHint,
                value: _expectedHarvestDate,
                allowClear: true,
                clearTooltip: widget.strings.cycleDateClear,
                errorText: _dateError,
                onChanged: (DateTime? value) => setState(() {
                  _expectedHarvestDate = value;
                  _dateError = null;
                }),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                widget.strings.cycleExpectedHarvestHelp,
                style: AppTextStyles.caption.copyWith(
                  color: context.palette.muted,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              AppTextField(
                key: const Key('cycle_notes_field'),
                controller: _notes,
                hintText: widget.strings.cycleNotesLabel,
                maxLines: 3,
              ),
              if (!_editing) ...<Widget>[
                const SizedBox(height: AppSpacing.lg),
                Text(
                  widget.strings.cycleInitialStatusLabel,
                  style: AppTextStyles.label,
                ),
                const SizedBox(height: AppSpacing.sm),
                AppChoiceChips<CycleStatus>(
                  key: const Key('cycle_status_chips'),
                  value: _status,
                  options: <AppChoiceOption<CycleStatus>>[
                    AppChoiceOption<CycleStatus>(
                      value: CycleStatus.planned,
                      label: cycleStatusLabel(
                        widget.strings,
                        CycleStatus.planned,
                      ),
                    ),
                    AppChoiceOption<CycleStatus>(
                      value: CycleStatus.growing,
                      label: cycleStatusLabel(
                        widget.strings,
                        CycleStatus.growing,
                      ),
                    ),
                  ],
                  onChanged: (CycleStatus value) =>
                      setState(() => _status = value),
                ),
              ],
              const SizedBox(height: AppSpacing.xl),
              AppButton(
                key: const Key('cycle_save'),
                label: widget.strings.cycleSave,
                loading: _saving,
                onPressed: _saving ? null : _submit,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    final bool cropMissing = !_editing && _cropId == null;
    final String? dateError = _validateDates();
    setState(() {
      _cropError = cropMissing ? widget.strings.cycleCropRequired : null;
      _dateError = dateError;
    });
    if (cropMissing || dateError != null) {
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    final String? variety = _trimmedOrNull(_variety.text);
    final String? season = _trimmedOrNull(_season.text);
    final String? notes = _trimmedOrNull(_notes.text);
    try {
      if (_editing) {
        await ref
            .read(cycleProvider(widget.cycle!.id).notifier)
            .updateCycle(
              variety: variety,
              season: season,
              sowingDate: _sowingDate,
              expectedHarvestDate: _expectedHarvestDate,
              notes: notes,
            );
      } else {
        await ref
            .read(cyclesProvider(widget.plotId).notifier)
            .createCycle(
              _id,
              _cropId!,
              variety: variety,
              season: season,
              sowingDate: _sowingDate,
              expectedHarvestDate: _expectedHarvestDate,
              status: _status,
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

  String? _validateDates() {
    for (final DateTime? date in <DateTime?>[
      _sowingDate,
      _expectedHarvestDate,
    ]) {
      if (date != null && (date.year < 2000 || date.year > 2100)) {
        return widget.strings.cycleDateImplausible;
      }
    }
    final DateTime? sowing = _sowingDate;
    final DateTime? expected = _expectedHarvestDate;
    if (sowing != null && expected != null && expected.isBefore(sowing)) {
      return widget.strings.cycleDateInvalid;
    }
    return null;
  }

  String? _trimmedOrNull(String value) {
    final String trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }
}

void _goBack(BuildContext context) {
  if (context.canPop()) {
    context.pop();
  } else {
    context.go('/home');
  }
}
