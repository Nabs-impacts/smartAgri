import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/i18n/app_language.dart';
import '../../../core/i18n/app_localizations.dart';
import '../../../core/i18n/language_controller.dart';
import '../../../core/i18n/strings_provider.dart';
import '../../../core/network/api_error_messages.dart';
import '../../../design_system/components/app_button.dart';
import '../../../design_system/components/app_card.dart';
import '../../../design_system/components/app_error_banner.dart';
import '../../../design_system/components/app_photo_tile.dart';
import '../../../design_system/components/app_progress_bar.dart';
import '../../../design_system/components/app_select_field.dart';
import '../../../design_system/tokens.dart';
import '../../catalog/data/catalog_repository.dart';
import '../../catalog/domain/crop.dart';
import '../../farms/data/farms_providers.dart';
import '../../farms/domain/farm.dart';
import '../../farms/domain/plot.dart';
import '../../profile/data/me_repository.dart';
import 'diagnostic_flow_controller.dart';

typedef DiagnosticPhotoPicker = Future<Uint8List?> Function({
  required bool camera,
});

Future<Uint8List?> _pickFromDevice({required bool camera}) async {
  final bool mobile =
      defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS;
  final XFile? file = await ImagePicker().pickImage(
    source: camera && mobile ? ImageSource.camera : ImageSource.gallery,
  );
  if (file == null) {
    return null;
  }
  return file.readAsBytes();
}

final Provider<DiagnosticPhotoPicker> diagnosticPhotoPickerProvider =
    Provider<DiagnosticPhotoPicker>((Ref ref) => _pickFromDevice);

class DiagnosticNewPage extends ConsumerStatefulWidget {
  const DiagnosticNewPage({super.key});

  @override
  ConsumerState<DiagnosticNewPage> createState() => _DiagnosticNewPageState();
}

class _DiagnosticNewPageState extends ConsumerState<DiagnosticNewPage> {
  String? _pickerError;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations strings = ref.watch(stringsProvider);
    final DiagnosticFlowState state = ref.watch(diagnosticFlowProvider);
    final AsyncValue<MeData?> me = ref.watch(meProvider);
    final bool quotaExhausted =
        _quotaExhausted(me.value) || state.quotaExceeded;
    ref.listen<DiagnosticFlowState>(diagnosticFlowProvider, (
      DiagnosticFlowState? previous,
      DiagnosticFlowState next,
    ) {
      if (next.created != null && previous?.created == null) {
        unawaited(ref.read(meProvider.notifier).refresh());
        context.pushReplacement('/diagnostic/${next.created!.id}');
      }
    });
    final String? photoError = _photoError(state);
    final String? uploadError = state.error != null
        ? apiErrorMessage(state.error!, strings)
        : null;
    return PopScope(
      canPop: !state.submitting,
      onPopInvokedWithResult: (bool didPop, Object? result) {
        if (!didPop) {
          _confirmExit();
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(title: Text(strings.diagnosticNewTitle)),
        body: SafeArea(
          child: ListView(
            key: const Key('diagnostic_new_scroll'),
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.xl,
              AppSpacing.lg,
              AppSpacing.xl,
              AppSpacing.xl,
            ),
            children: <Widget>[
              _TipsCard(strings: strings),
              const SizedBox(height: AppSpacing.xl),
              _cultureField(strings),
              const SizedBox(height: AppSpacing.md),
              _plotField(strings),
              const SizedBox(height: AppSpacing.xl),
              Text(strings.diagnosticPhotosTitle, style: AppTextStyles.title),
              const SizedBox(height: AppSpacing.md),
              _photoGrid(state, strings),
              const SizedBox(height: AppSpacing.md),
              AppButton(
                key: const Key('diagnostic_take_photo'),
                label: strings.diagnosticTakePhoto,
                variant: AppButtonVariant.outlined,
                icon: const Icon(Icons.photo_camera_outlined),
                onPressed: state.submitting || !state.canAddPhoto
                    ? null
                    : () => _pick(camera: true),
              ),
              const SizedBox(height: AppSpacing.sm),
              AppButton(
                key: const Key('diagnostic_choose_gallery'),
                label: strings.diagnosticChooseGallery,
                variant: AppButtonVariant.outlined,
                icon: const Icon(Icons.photo_library_outlined),
                onPressed: state.submitting || !state.canAddPhoto
                    ? null
                    : () => _pick(camera: false),
              ),
              if (quotaExhausted) ...<Widget>[
                const SizedBox(height: AppSpacing.lg),
                AppErrorBanner(
                  key: const Key('diagnostic_quota_banner'),
                  message: strings.diagnosticQuotaReached,
                ),
              ],
              if (photoError != null) ...<Widget>[
                const SizedBox(height: AppSpacing.lg),
                AppErrorBanner(
                  key: const Key('diagnostic_photo_error'),
                  message: photoError,
                ),
              ],
              if (uploadError != null) ...<Widget>[
                const SizedBox(height: AppSpacing.lg),
                AppErrorBanner(
                  key: const Key('diagnostic_upload_error'),
                  message: uploadError,
                ),
              ],
              if (state.submitting) ...<Widget>[
                const SizedBox(height: AppSpacing.lg),
                AppProgressBar(
                  key: const Key('diagnostic_global_progress'),
                  value: state.globalProgress,
                  label: strings.diagnosticUploading,
                ),
              ],
              const SizedBox(height: AppSpacing.xl),
              AppButton(
                key: const Key('diagnostic_analyze'),
                label: strings.diagnosticAnalyze,
                loading: state.submitting,
                onPressed: state.canSubmit && !quotaExhausted
                    ? () => ref.read(diagnosticFlowProvider.notifier).submit()
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _cultureField(AppLocalizations strings) {
    final DiagnosticFlowState state = ref.watch(diagnosticFlowProvider);
    final AppLanguage language = ref.watch(languageControllerProvider);
    final List<Crop> crops = ref.watch(cropsProvider).value ?? <Crop>[];
    return AppSelectField<int>(
      key: const Key('diagnostic_crop_field'),
      hintText: strings.diagnosticCropLabel,
      options: crops
          .map(
            (Crop crop) => AppSelectOption<int>(
              value: crop.id,
              label: crop.localizedName(language),
            ),
          )
          .toList(),
      value: state.cropId,
      allowEmpty: true,
      emptyLabel: strings.cancel,
      enabled: !state.submitting,
      onChanged: state.submitting
          ? null
          : (int? value) =>
                ref.read(diagnosticFlowProvider.notifier).selectCrop(value),
    );
  }

  Widget _plotField(AppLocalizations strings) {
    final DiagnosticFlowState state = ref.watch(diagnosticFlowProvider);
    final List<Farm> farms = ref.watch(farmsProvider).value ?? <Farm>[];
    final List<AppSelectOption<String>> options = <AppSelectOption<String>>[];
    for (final Farm farm in farms) {
      final List<Plot> plots =
          ref.watch(farmPlotsProvider(farm.id)).value ?? <Plot>[];
      for (final Plot plot in plots) {
        options.add(
          AppSelectOption<String>(
            value: plot.id,
            label: '${plot.name} — ${farm.name}',
          ),
        );
      }
    }
    return AppSelectField<String>(
      key: const Key('diagnostic_plot_field'),
      hintText: strings.diagnosticPlotLabel,
      options: options,
      value: state.plotId,
      allowEmpty: true,
      emptyLabel: strings.cancel,
      enabled: !state.submitting,
      onChanged: state.submitting
          ? null
          : (String? value) =>
                ref.read(diagnosticFlowProvider.notifier).selectPlot(value),
    );
  }

  Widget _photoGrid(DiagnosticFlowState state, AppLocalizations strings) {
    return Wrap(
      spacing: AppSpacing.md,
      runSpacing: AppSpacing.md,
      children: <Widget>[
        for (final FlowPhoto photo in state.photos)
          Stack(
            children: <Widget>[
              AppPhotoTile(
                key: Key('diagnostic_photo_${photo.mediaId}'),
                bytes: photo.bytes,
                loading: photo.status == FlowPhotoStatus.compressing,
                onDelete: state.submitting
                    ? null
                    : () => ref
                          .read(diagnosticFlowProvider.notifier)
                          .removePhoto(photo.mediaId),
              ),
              if (photo.status == FlowPhotoStatus.uploaded)
                const Positioned(
                  left: AppSpacing.xs,
                  bottom: AppSpacing.xs,
                  child: Icon(
                    Icons.check_circle,
                    key: Key('diagnostic_photo_uploaded'),
                    color: AppColors.tertiary,
                    size: AppSizes.icon,
                  ),
                ),
            ],
          ),
        if (state.canAddPhoto && !state.submitting)
          AppPhotoTile(onAdd: () => _pick(camera: false)),
      ],
    );
  }

  Future<void> _pick({required bool camera}) async {
    final DiagnosticFlowState state = ref.read(diagnosticFlowProvider);
    if (!state.canAddPhoto || state.submitting) {
      return;
    }
    try {
      final Uint8List? bytes = await ref.read(diagnosticPhotoPickerProvider)(
        camera: camera,
      );
      if (bytes == null || !mounted) {
        return;
      }
      setState(() => _pickerError = null);
      await ref.read(diagnosticFlowProvider.notifier).addPhoto(bytes);
    } catch (_) {
      if (mounted) {
        setState(
          () => _pickerError = ref.read(stringsProvider).diagnosticPhotoError,
        );
      }
    }
  }

  String? _photoError(DiagnosticFlowState state) {
    if (_pickerError != null) {
      return _pickerError;
    }
    for (final FlowPhoto photo in state.photos) {
      final String? error = photo.error;
      if (error != null && error.isNotEmpty) {
        return error;
      }
    }
    return null;
  }

  bool _quotaExhausted(MeData? data) {
    if (data == null) {
      return false;
    }
    for (final Quota quota in data.quotas) {
      if (quota.metric == 'diagnostics_per_month') {
        return quota.limit >= 0 && quota.remaining <= 0;
      }
    }
    return false;
  }

  Future<void> _confirmExit() async {
    final AppLocalizations strings = ref.read(stringsProvider);
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Text(strings.diagnosticExitTitle),
          content: Text(strings.diagnosticExitMessage),
          actions: <Widget>[
            AppButton(
              key: const Key('diagnostic_exit_cancel'),
              label: strings.cancel,
              variant: AppButtonVariant.outlined,
              size: AppButtonSize.compact,
              onPressed: () => Navigator.of(dialogContext).pop(false),
            ),
            AppButton(
              key: const Key('diagnostic_exit_confirm'),
              label: strings.diagnosticExitConfirm,
              size: AppButtonSize.compact,
              onPressed: () => Navigator.of(dialogContext).pop(true),
            ),
          ],
        );
      },
    );
    if (confirmed == true && mounted) {
      ref.read(diagnosticFlowProvider.notifier).cancelUploads();
      context.pop();
    }
  }
}

class _TipsCard extends StatelessWidget {
  const _TipsCard({required this.strings});

  final AppLocalizations strings;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(strings.diagnosticTipsTitle, style: AppTextStyles.title),
          const SizedBox(height: AppSpacing.md),
          _Tip(text: strings.diagnosticTipClose),
          const SizedBox(height: AppSpacing.sm),
          _Tip(text: strings.diagnosticTipLight),
          const SizedBox(height: AppSpacing.sm),
          _Tip(text: strings.diagnosticTipOnePlant),
        ],
      ),
    );
  }
}

class _Tip extends StatelessWidget {
  const _Tip({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const Icon(
          Icons.check_circle_outline,
          color: AppColors.tertiary,
          size: AppSizes.icon,
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(child: Text(text, style: AppTextStyles.body)),
      ],
    );
  }
}
