import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:uuid/uuid.dart';

import '../../../core/i18n/app_localizations.dart';
import '../../../core/i18n/strings_provider.dart';
import '../../../core/location/location_messages.dart';
import '../../../core/location/location_service.dart';
import '../../../core/network/api_error_messages.dart';
import '../../../core/network/api_exception.dart';
import '../../../design_system/components/app_button.dart';
import '../../../design_system/components/app_error_banner.dart';
import '../../../design_system/components/app_select_field.dart';
import '../../../design_system/components/app_text_button.dart';
import '../../../design_system/components/app_text_field.dart';
import '../../../design_system/tokens.dart';
import '../../../design_system/app_palette.dart';
import '../../catalog/data/catalog_repository.dart';
import '../../catalog/domain/admin_area.dart';
import '../data/farms_providers.dart';
import '../data/farms_repository.dart';
import '../domain/farm.dart';
import '../domain/plot_geometry.dart';

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
      backgroundColor: context.palette.background,
      appBar: AppBar(title: Text(strings.farmEditTitle)),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: farms.isLoading
                ? CircularProgressIndicator(color: context.palette.primary)
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
  Map<String, dynamic>? _location;
  bool _locationChanged = false;
  bool _permissionExplained = false;
  bool _locating = false;
  String? _locationError;
  bool _canOpenSettings = false;
  double? _locationAccuracy;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _id = widget.farm?.id ?? const Uuid().v4();
    _name = TextEditingController(text: widget.farm?.name ?? '');
    _village = TextEditingController(text: widget.farm?.village ?? '');
    _adminAreaId = widget.farm?.adminAreaId;
    _location = widget.farm?.location;
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
              location: _location,
            );
      } else {
        await ref
            .read(farmsProvider.notifier)
            .updateFarm(
              _id,
              name: name,
              village: village.isEmpty ? null : village,
              adminAreaId: _adminAreaId,
              location: _locationChanged ? _location : unchanged,
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

  Future<bool> _confirmLocationExplanation() async {
    if (_permissionExplained) {
      return true;
    }
    final bool? proceed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Text(widget.strings.farmLocationLabel),
          content: Text(widget.strings.locationExplanation),
          actions: <Widget>[
            AppTextButton(
              key: const Key('farm_location_explanation_cancel'),
              label: widget.strings.cancel,
              variant: AppTextButtonVariant.muted,
              onPressed: () => Navigator.of(dialogContext).pop(false),
            ),
            AppTextButton(
              key: const Key('farm_location_explanation_continue'),
              label: widget.strings.locationContinue,
              onPressed: () => Navigator.of(dialogContext).pop(true),
            ),
          ],
        );
      },
    );
    if (proceed == true) {
      _permissionExplained = true;
      return true;
    }
    return false;
  }

  Future<void> _useCurrentLocation() async {
    if (!await _confirmLocationExplanation()) {
      return;
    }
    if (!mounted) {
      return;
    }
    setState(() {
      _locating = true;
      _locationError = null;
      _canOpenSettings = false;
    });
    final LocationService service = ref.read(locationServiceProvider);
    final LocationResult result = await service.currentPosition();
    if (!mounted) {
      return;
    }
    setState(() {
      _locating = false;
      _locationAccuracy = result.position?.accuracyMeters;
      _locationError = locationErrorMessage(widget.strings, result.status);
      _canOpenSettings =
          result.status == LocationOutcomeStatus.permissionDeniedForever;
      final LocationPosition? position = result.position;
      if (position != null) {
        _location = pointToGeoJson(
          LatLng(position.latitude, position.longitude),
        );
        _locationChanged = true;
      }
    });
  }

  Future<void> _openSettings() async {
    final LocationService service = ref.read(locationServiceProvider);
    final bool opened = await service.openAppSettings();
    if (!mounted) {
      return;
    }
    if (!opened) {
      setState(() {
        _locationError = widget.strings.locationSettingsUnavailable;
        _canOpenSettings = false;
      });
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
      backgroundColor: context.palette.background,
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
              Text(
                widget.strings.farmLocationLabel,
                style: AppTextStyles.label,
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                _location == null
                    ? widget.strings.farmLocationHelp
                    : widget.strings.farmLocationRegistered,
                key: const Key('farm_location_status'),
                style: AppTextStyles.body.copyWith(
                  color: _location == null
                      ? context.palette.muted
                      : context.palette.tertiary,
                ),
              ),
              if (_locationAccuracy != null) ...<Widget>[
                const SizedBox(height: AppSpacing.xs),
                Text(
                  widget.strings.locationAccuracy(
                    _locationAccuracy!.toStringAsFixed(0),
                  ),
                  style: AppTextStyles.caption.copyWith(
                    color: context.palette.muted,
                  ),
                ),
                if (_locationAccuracy! > 30) ...<Widget>[
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    widget.strings.locationAccuracyWarning,
                    style: AppTextStyles.caption.copyWith(
                      color: context.palette.accent,
                    ),
                  ),
                ],
              ],
              const SizedBox(height: AppSpacing.md),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: <Widget>[
                  AppButton(
                    key: const Key('farm_location_use'),
                    label: widget.strings.farmLocationUseCurrent,
                    size: AppButtonSize.compact,
                    variant: AppButtonVariant.secondary,
                    loading: _locating,
                    onPressed: _locating ? null : _useCurrentLocation,
                  ),
                  if (_location != null)
                    AppButton(
                      key: const Key('farm_location_clear'),
                      label: widget.strings.farmLocationClear,
                      size: AppButtonSize.compact,
                      variant: AppButtonVariant.outlined,
                      onPressed: () => setState(() {
                        _location = null;
                        _locationChanged = true;
                        _locationAccuracy = null;
                        _locationError = null;
                        _canOpenSettings = false;
                      }),
                    ),
                ],
              ),
              if (_locationError != null) ...<Widget>[
                const SizedBox(height: AppSpacing.md),
                AppErrorBanner(
                  key: const Key('farm_location_error'),
                  message: _locationError!,
                ),
              ],
              if (_canOpenSettings) ...<Widget>[
                Align(
                  alignment: Alignment.centerLeft,
                  child: AppTextButton(
                    key: const Key('farm_location_open_settings'),
                    label: widget.strings.locationOpenSettings,
                    onPressed: _openSettings,
                  ),
                ),
              ],
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
