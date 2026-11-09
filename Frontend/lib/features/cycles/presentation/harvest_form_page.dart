import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../../../core/i18n/app_localizations.dart';
import '../../../core/i18n/strings_provider.dart';
import '../../../design_system/components/app_button.dart';
import '../../../design_system/components/app_checkbox_tile.dart';
import '../../../design_system/components/app_choice_chips.dart';
import '../../../design_system/components/app_date_field.dart';
import '../../../design_system/components/app_error_banner.dart';
import '../../../design_system/components/app_text_button.dart';
import '../../../design_system/components/app_text_field.dart';
import '../../../design_system/tokens.dart';
import '../data/cycles_providers.dart';
import '../domain/cycle.dart';
import '../domain/cycle_exception.dart';
import '../domain/cycle_status.dart';
import '../domain/harvest.dart';
import '../domain/harvest_quality.dart';
import 'cycle_format.dart';

class HarvestFormPage extends ConsumerWidget {
  const HarvestFormPage({required this.cycleId, this.harvestId, super.key});

  final String cycleId;
  final String? harvestId;

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
        messageKey: const Key('harvest_cycle_not_found'),
        onRetry: () => ref.invalidate(cycleProvider(cycleId)),
      );
    }
    if (harvestId == null) {
      return _HarvestForm(strings: strings, cycle: cycle.value!);
    }
    final AsyncValue<List<Harvest>> harvests = ref.watch(
      harvestsProvider(cycleId),
    );
    if (harvests.isLoading && !harvests.hasValue) {
      return _LoadingScaffold(strings: strings);
    }
    Harvest? harvest;
    for (final Harvest item in harvests.value ?? <Harvest>[]) {
      if (item.id == harvestId) {
        harvest = item;
        break;
      }
    }
    if (harvest == null) {
      return _NotFoundScaffold(
        strings: strings,
        message: strings.harvestNotFound,
        messageKey: const Key('harvest_not_found'),
        onRetry: () => ref.invalidate(harvestsProvider(cycleId)),
      );
    }
    return _HarvestForm(
      strings: strings,
      cycle: cycle.value!,
      harvest: harvest,
    );
  }
}

class _LoadingScaffold extends StatelessWidget {
  const _LoadingScaffold({required this.strings});

  final AppLocalizations strings;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: Text(strings.harvestCreateTitle)),
      body: const SafeArea(
        child: Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      ),
    );
  }
}

class _NotFoundScaffold extends StatelessWidget {
  const _NotFoundScaffold({
    required this.strings,
    required this.message,
    required this.messageKey,
    required this.onRetry,
  });

  final AppLocalizations strings;
  final String message;
  final Key messageKey;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: Text(strings.harvestEditTitle)),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  message,
                  key: messageKey,
                  style: AppTextStyles.body,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.lg),
                AppTextButton(
                  key: const Key('harvest_back'),
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

class _HarvestForm extends ConsumerStatefulWidget {
  const _HarvestForm({
    required this.strings,
    required this.cycle,
    this.harvest,
  });

  final AppLocalizations strings;
  final Cycle cycle;
  final Harvest? harvest;

  @override
  ConsumerState<_HarvestForm> createState() => _HarvestFormState();
}

class _HarvestFormState extends ConsumerState<_HarvestForm> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _quantity;
  late final TextEditingController _sold;
  late final TextEditingController _price;
  late final String _id;
  late DateTime _date;
  HarvestQuality? _quality;
  bool _closeCycle = false;
  bool _saving = false;
  String? _error;

  bool get _editing => widget.harvest != null;

  bool get _canCloseCycle =>
      !_editing && widget.cycle.status == CycleStatus.growing;

  @override
  void initState() {
    super.initState();
    final Harvest? harvest = widget.harvest;
    _id = harvest?.id ?? const Uuid().v4();
    _date = harvest?.harvestedOn ?? _today();
    _quantity = TextEditingController(
      text: harvest == null ? '' : formatDecimalInput(harvest.quantityKg),
    );
    _sold = TextEditingController(
      text: harvest == null ? '0' : formatDecimalInput(harvest.soldKg),
    );
    _price = TextEditingController(
      text: harvest?.avgPriceXofPerKg == null
          ? ''
          : formatDecimalInput(harvest!.avgPriceXofPerKg!),
    );
    _quality = harvest?.quality;
  }

  @override
  void dispose() {
    _quantity.dispose();
    _sold.dispose();
    _price.dispose();
    super.dispose();
  }

  double get _estimatedRevenue {
    final double sold = _parseDecimal(_sold.text.trim()) ?? 0;
    final double price = _parseDecimal(_price.text.trim()) ?? 0;
    return sold * price;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          _editing
              ? widget.strings.harvestEditTitle
              : widget.strings.harvestCreateTitle,
        ),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            key: const Key('harvest_form_scroll'),
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.xl,
              AppSpacing.lg,
              AppSpacing.xl,
              AppSpacing.xl,
            ),
            children: <Widget>[
              if (_error != null) ...<Widget>[
                AppErrorBanner(
                  key: const Key('harvest_form_error'),
                  message: _error!,
                ),
                const SizedBox(height: AppSpacing.lg),
              ],
              Text(widget.strings.harvestDateLabel, style: AppTextStyles.label),
              const SizedBox(height: AppSpacing.sm),
              AppDateField(
                key: const Key('harvest_date_field'),
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
                key: const Key('harvest_quantity_field'),
                controller: _quantity,
                hintText: widget.strings.harvestQuantityLabel,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                textInputAction: TextInputAction.next,
                validator: _validQuantity,
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                widget.strings.harvestQualityLabel,
                style: AppTextStyles.label,
              ),
              const SizedBox(height: AppSpacing.sm),
              AppChoiceChips<HarvestQuality>(
                key: const Key('harvest_quality_chips'),
                value: _quality,
                options: HarvestQuality.values
                    .map(
                      (HarvestQuality quality) =>
                          AppChoiceOption<HarvestQuality>(
                            value: quality,
                            label: quality.code,
                          ),
                    )
                    .toList(),
                onChanged: (HarvestQuality value) =>
                    setState(() => _quality = value),
              ),
              const SizedBox(height: AppSpacing.lg),
              AppTextField(
                key: const Key('harvest_sold_field'),
                controller: _sold,
                hintText: widget.strings.harvestSoldLabel,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                textInputAction: TextInputAction.next,
                validator: _validSold,
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: AppSpacing.md),
              AppTextField(
                key: const Key('harvest_price_field'),
                controller: _price,
                hintText: widget.strings.harvestPriceLabel,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                textInputAction: TextInputAction.done,
                validator: _validPrice,
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                widget.strings.harvestEstimatedRevenue(
                  formatXof(_estimatedRevenue),
                ),
                key: const Key('harvest_revenue'),
                style: AppTextStyles.label.copyWith(color: AppColors.tertiary),
              ),
              if (_canCloseCycle) ...<Widget>[
                const SizedBox(height: AppSpacing.lg),
                AppCheckboxTile(
                  key: const Key('harvest_close_cycle'),
                  label: widget.strings.harvestCloseCycle,
                  value: _closeCycle,
                  onChanged: (bool value) =>
                      setState(() => _closeCycle = value),
                ),
              ],
              const SizedBox(height: AppSpacing.xl),
              AppButton(
                key: const Key('harvest_save'),
                label: widget.strings.harvestSave,
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
    final double? quantity = _parseDecimal(text);
    if (quantity == null || quantity <= 0) {
      return widget.strings.harvestQuantityInvalid;
    }
    return null;
  }

  String? _validSold(String? value) {
    final String text = value?.trim() ?? '';
    if (text.isEmpty) {
      return null;
    }
    final double? sold = _parseDecimal(text);
    if (sold == null || sold < 0) {
      return widget.strings.harvestSoldInvalid;
    }
    final double? quantity = _parseDecimal(_quantity.text.trim());
    if (quantity != null && sold > quantity) {
      return widget.strings.harvestSoldInvalid;
    }
    return null;
  }

  String? _validPrice(String? value) {
    final String text = value?.trim() ?? '';
    if (text.isEmpty) {
      return null;
    }
    final double? price = _parseDecimal(text);
    if (price == null || price < 0) {
      return widget.strings.harvestPriceInvalid;
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
    final double quantity = _parseDecimal(_quantity.text.trim()) ?? 0;
    final String soldText = _sold.text.trim();
    final double sold = soldText.isEmpty ? 0 : _parseDecimal(soldText) ?? 0;
    final String priceText = _price.text.trim();
    final double? price = priceText.isEmpty ? null : _parseDecimal(priceText);
    try {
      final notifier = ref.read(harvestsProvider(widget.cycle.id).notifier);
      if (_editing) {
        await notifier.updateHarvest(
          widget.harvest!.id,
          harvestedOn: _date,
          quantityKg: quantity,
          quality: _quality,
          soldKg: sold,
          avgPriceXofPerKg: price,
        );
      } else {
        await notifier.createHarvest(
          _id,
          _date,
          quantity,
          quality: _quality,
          soldKg: sold,
          avgPriceXofPerKg: price,
          closeCycle: _closeCycle && _canCloseCycle,
        );
      }
      if (mounted) {
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
}

DateTime _today() {
  final DateTime now = DateTime.now();
  return DateTime(now.year, now.month, now.day);
}

double? _parseDecimal(String value) {
  return double.tryParse(value.replaceAll(',', '.'));
}
