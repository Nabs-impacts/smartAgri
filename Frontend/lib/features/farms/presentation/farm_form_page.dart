import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../../../core/i18n/app_localizations.dart';
import '../../../core/i18n/strings_provider.dart';
import '../../../core/network/api_error_messages.dart';
import '../../../core/network/api_exception.dart';
import '../../../design_system/components/app_button.dart';
import '../../../design_system/components/app_error_banner.dart';
import '../../../design_system/components/app_select_field.dart';
import '../../../design_system/components/app_text_button.dart';
import '../../../design_system/components/app_text_field.dart';
import '../../../design_system/tokens.dart';
import '../../catalog/data/catalog_repository.dart';
import '../../catalog/domain/admin_area.dart';
import '../data/farms_providers.dart';
import '../domain/farm.dart';

class FarmFormPage extends ConsumerWidget {
  const FarmFormPage({this.farmId, super.key});

  final String? farmId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations strings = ref.watch(stringsProvider);
    if (farmId == null) {
      return _FarmForm(strings: strings);
    }
    final AsyncValue<List<Farm>> farms = ref.watch(farmsProvider);
    Farm? farm;
    for (final Farm item in farms.value ?? <Farm>[]) {
      if (item.id == farmId) {
        farm = item;
        break;
      }
    }
    if (farm != null) {
      return _FarmForm(strings: strings, farm: farm);
    }
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: Text(strings.farmEditTitle)),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: farms.isLoading
                ? const CircularProgressIndicator(color: AppColors.primary)
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Text(
                        farms.hasError
                            ? strings.errorGeneric
                            : strings.farmNotFound,
                        style: AppTextStyles.body,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      AppTextButton(
                        label: strings.retry,
                        onPressed: () =>
                            ref.read(farmsProvider.notifier).refresh(),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

class _FarmForm extends ConsumerStatefulWidget {
  const _FarmForm({required this.strings, this.farm});

  final AppLocalizations strings;
  final Farm? farm;

  @override
  ConsumerState<_FarmForm> createState() => _FarmFormState();
}

class _FarmFormState extends ConsumerState<_FarmForm> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _village;
  late final String _id;
  int? _adminAreaId;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _id = widget.farm?.id ?? const Uuid().v4();
    _name = TextEditingController(text: widget.farm?.name ?? '');
    _village = TextEditingController(text: widget.farm?.village ?? '');
    _adminAreaId = widget.farm?.adminAreaId;
  }

  @override
  void dispose() {
    _name.dispose();
    _village.dispose();
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
    final String village = _village.text.trim();
    try {
      if (widget.farm == null) {
        await ref
            .read(farmsProvider.notifier)
            .createFarm(
              _id,
              name,
              village: village.isEmpty ? null : village,
              adminAreaId: _adminAreaId,
            );
      } else {
        await ref
            .read(farmsProvider.notifier)
            .updateFarm(
              _id,
              name: name,
              village: village.isEmpty ? null : village,
              adminAreaId: _adminAreaId,
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
    final List<AdminArea> areas =
        ref.watch(adminAreasProvider).value ?? <AdminArea>[];
    final List<AppSelectOption<int>> regions = areas
        .where((AdminArea area) => area.level == 'region')
        .map(
          (AdminArea area) =>
              AppSelectOption<int>(value: area.id, label: area.name),
        )
        .toList();
    final bool editing = widget.farm != null;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          editing
              ? widget.strings.farmEditTitle
              : widget.strings.farmCreateTitle,
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
                  key: const Key('farm_form_error'),
                  message: _error!,
                ),
                const SizedBox(height: AppSpacing.lg),
              ],
              AppTextField(
                key: const Key('farm_name_field'),
                controller: _name,
                hintText: widget.strings.farmNameLabel,
                textInputAction: TextInputAction.next,
                validator: (String? value) =>
                    _validName(value) ? null : widget.strings.farmNameLength,
              ),
              const SizedBox(height: AppSpacing.md),
              AppTextField(
                key: const Key('farm_village_field'),
                controller: _village,
                hintText: widget.strings.farmVillageLabel,
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: AppSpacing.md),
              AppSelectField<int>(
                key: const Key('farm_region_field'),
                hintText: widget.strings.farmRegionLabel,
                options: regions,
                value: _adminAreaId,
                allowEmpty: true,
                emptyLabel: widget.strings.farmRegionNone,
                onChanged: (int? value) => setState(() => _adminAreaId = value),
              ),
              const SizedBox(height: AppSpacing.xl),
              AppButton(
                key: const Key('farm_save'),
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
}
