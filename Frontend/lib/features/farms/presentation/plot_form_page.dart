import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../../../core/i18n/app_localizations.dart';
import '../../../core/i18n/strings_provider.dart';
import '../../../core/network/api_error_messages.dart';
import '../../../core/network/api_exception.dart';
import '../../../design_system/components/app_button.dart';
import '../../../design_system/components/app_choice_chips.dart';
import '../../../design_system/components/app_error_banner.dart';
import '../../../design_system/components/app_text_button.dart';
import '../../../design_system/components/app_text_field.dart';
import '../../../design_system/tokens.dart';
import '../data/farms_providers.dart';
import '../domain/plot.dart';

class PlotFormPage extends ConsumerWidget {
  const PlotFormPage({this.farmId, this.plotId, super.key});

  final String? farmId;
  final String? plotId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations strings = ref.watch(stringsProvider);
    if (plotId == null) {
      return _PlotForm(strings: strings, farmId: farmId ?? '');
    }
    final AsyncValue<Plot> plot = ref.watch(plotProvider(plotId!));
    if (plot.value != null) {
      return _PlotForm(
        strings: strings,
        farmId: plot.value!.farmId,
        plot: plot.value,
      );
    }
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: Text(strings.plotEditTitle)),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: plot.isLoading
                ? const CircularProgressIndicator(color: AppColors.primary)
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Text(
                        plot.hasError
                            ? strings.errorGeneric
                            : strings.plotNotFound,
                        style: AppTextStyles.body,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      AppTextButton(
                        label: strings.retry,
                        onPressed: () => ref.invalidate(plotProvider(plotId!)),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

class _PlotForm extends ConsumerStatefulWidget {
  const _PlotForm({required this.strings, required this.farmId, this.plot});

  final AppLocalizations strings;
  final String farmId;
  final Plot? plot;

  @override
  ConsumerState<_PlotForm> createState() => _PlotFormState();
}

class _PlotFormState extends ConsumerState<_PlotForm> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _area;
  late final String _id;
  SoilType? _soilType;
  IrrigationType? _irrigation;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _id = widget.plot?.id ?? const Uuid().v4();
    _name = TextEditingController(text: widget.plot?.name ?? '');
    _area = TextEditingController(text: _areaText(widget.plot?.areaHa));
    _soilType = widget.plot?.soilType;
    _irrigation = widget.plot?.irrigation;
  }

  @override
  void dispose() {
    _name.dispose();
    _area.dispose();
    super.dispose();
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
    final String name = _name.text.trim();
    final String areaText = _area.text.trim();
    final double? areaHa = areaText.isEmpty
        ? null
        : double.parse(areaText.replaceAll(',', '.'));
    try {
      if (widget.plot == null) {
        await ref
            .read(farmPlotsProvider(widget.farmId).notifier)
            .createPlot(
              _id,
              name,
              areaHa: areaHa,
              soilType: _soilType,
              irrigation: _irrigation,
            );
      } else {
        await ref
            .read(farmPlotsProvider(widget.farmId).notifier)
            .updatePlot(
              _id,
              name: name,
              areaHa: areaHa,
              soilType: _soilType,
              irrigation: _irrigation,
            );
      }
      if (mounted) {
        context.pop();
      }
    } on ApiException catch (error) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = apiErrorMessage(error, widget.strings);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool editing = widget.plot != null;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          editing
              ? widget.strings.plotEditTitle
              : widget.strings.plotCreateTitle,
        ),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.xl,
              AppSpacing.lg,
              AppSpacing.xl,
              AppSpacing.xl,
            ),
            children: <Widget>[
              if (_error != null) ...<Widget>[
                AppErrorBanner(
                  key: const Key('plot_form_error'),
                  message: _error!,
                ),
                const SizedBox(height: AppSpacing.lg),
              ],
              AppTextField(
                key: const Key('plot_name_field'),
                controller: _name,
                hintText: widget.strings.plotNameLabel,
                textInputAction: TextInputAction.next,
                validator: (String? value) =>
                    _validName(value) ? null : widget.strings.plotNameLength,
              ),
              const SizedBox(height: AppSpacing.md),
              AppTextField(
                key: const Key('plot_area_field'),
                controller: _area,
                hintText: widget.strings.plotAreaHint,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                textInputAction: TextInputAction.done,
                validator: (String? value) =>
                    _validArea(value) ? null : widget.strings.plotAreaInvalid,
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                widget.strings.plotAreaLabel,
                style: AppTextStyles.caption.copyWith(color: AppColors.muted),
              ),
              const SizedBox(height: AppSpacing.xl),
              Text(widget.strings.plotSoilLabel, style: AppTextStyles.label),
              const SizedBox(height: AppSpacing.sm),
              AppChoiceChips<SoilType>(
                key: const Key('plot_soil_chips'),
                value: _soilType,
                options: SoilType.values
                    .map(
                      (SoilType type) => AppChoiceOption<SoilType>(
                        value: type,
                        label: type.label,
                      ),
                    )
                    .toList(),
                onChanged: (SoilType value) =>
                    setState(() => _soilType = value),
              ),
              const SizedBox(height: AppSpacing.xl),
              Text(
                widget.strings.plotIrrigationLabel,
                style: AppTextStyles.label,
              ),
              const SizedBox(height: AppSpacing.sm),
              AppChoiceChips<IrrigationType>(
                key: const Key('plot_irrigation_chips'),
                value: _irrigation,
                options: IrrigationType.values
                    .map(
                      (IrrigationType type) => AppChoiceOption<IrrigationType>(
                        value: type,
                        label: type.label,
                      ),
                    )
                    .toList(),
                onChanged: (IrrigationType value) =>
                    setState(() => _irrigation = value),
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                widget.strings.plotMapComingSoon,
                key: const Key('plot_map_coming_soon'),
                style: AppTextStyles.caption.copyWith(color: AppColors.muted),
              ),
              const SizedBox(height: AppSpacing.xl),
              AppButton(
                key: const Key('plot_save'),
                label: widget.strings.farmSave,
                loading: _saving,
                onPressed: _saving ? null : _submit,
              ),
            ],
          ),
        ),
      ),
    );
  }

  bool _validName(String? value) {
    final int length = value?.trim().length ?? 0;
    return length >= 2 && length <= 120;
  }

  bool _validArea(String? value) {
    final String text = value?.trim() ?? '';
    if (text.isEmpty) {
      return true;
    }
    final double? area = double.tryParse(text.replaceAll(',', '.'));
    return area != null && area > 0 && area <= 10000;
  }

  String _areaText(double? area) {
    if (area == null) {
      return '';
    }
    final String text = area == area.roundToDouble()
        ? area.toInt().toString()
        : area.toString();
    return text.replaceAll('.', ',');
  }
}
