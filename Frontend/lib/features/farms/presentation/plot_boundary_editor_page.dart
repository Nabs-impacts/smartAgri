import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/i18n/app_localizations.dart';
import '../../../core/i18n/strings_provider.dart';
import '../../../core/location/location_messages.dart';
import '../../../core/location/location_service.dart';
import '../../../design_system/components/app_button.dart';
import '../../../design_system/components/app_error_banner.dart';
import '../../../design_system/components/app_status_banner.dart';
import '../../../design_system/components/app_text_button.dart';
import '../../../design_system/tokens.dart';
import '../domain/plot_geometry.dart';
import 'boundary_editor_controller.dart';
import 'farm_display.dart';
import 'plot_map.dart';

const Object boundaryUnchanged = Object();

class PlotBoundaryEditorPage extends ConsumerStatefulWidget {
  const PlotBoundaryEditorPage({this.initialGeometry, super.key});

  final PlotGeometry? initialGeometry;

  @override
  ConsumerState<PlotBoundaryEditorPage> createState() =>
      _PlotBoundaryEditorPageState();
}

class _PlotBoundaryEditorPageState
    extends ConsumerState<PlotBoundaryEditorPage> {
  late final BoundaryEditorController _controller;
  final MapController _mapController = MapController();
  bool _permissionExplained = false;
  bool _locating = false;
  bool _closing = false;
  LocationPosition? _position;
  String? _locationMessage;
  bool _canOpenSettings = false;

  @override
  void initState() {
    super.initState();
    _controller = BoundaryEditorController(initial: widget.initialGeometry);
    _controller.addListener(_onControllerChanged);
  }

  @override
  void dispose() {
    _controller.removeListener(_onControllerChanged);
    _controller.dispose();
    super.dispose();
  }

  void _onControllerChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  void _close(Object? result) {
    if (_closing) {
      return;
    }
    _closing = true;
    Navigator.of(context).pop(result);
  }

  Future<bool> _confirmLocationExplanation() async {
    if (_permissionExplained) {
      return true;
    }
    final AppLocalizations strings = ref.read(stringsProvider);
    final bool? proceed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Text(strings.farmLocationLabel),
          content: Text(strings.locationExplanation),
          actions: <Widget>[
            AppTextButton(
              key: const Key('location_explanation_cancel'),
              label: strings.cancel,
              variant: AppTextButtonVariant.muted,
              onPressed: () => Navigator.of(dialogContext).pop(false),
            ),
            AppTextButton(
              key: const Key('location_explanation_continue'),
              label: strings.locationContinue,
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

  Future<void> _locate({required bool addVertex}) async {
    if (!await _confirmLocationExplanation()) {
      return;
    }
    if (!mounted) {
      return;
    }
    setState(() {
      _locating = true;
      _locationMessage = null;
      _canOpenSettings = false;
    });
    final LocationService service = ref.read(locationServiceProvider);
    final LocationResult result = await service.currentPosition();
    if (!mounted) {
      return;
    }
    setState(() {
      _locating = false;
      _position = result.position;
      _locationMessage = locationErrorMessage(
        ref.read(stringsProvider),
        result.status,
      );
      _canOpenSettings =
          result.status == LocationOutcomeStatus.permissionDeniedForever;
    });
    final LocationPosition? position = result.position;
    if (position == null) {
      return;
    }
    final LatLng point = LatLng(position.latitude, position.longitude);
    if (addVertex) {
      _controller.addVertex(point);
    }
    _mapController.move(point, 16);
  }

  Future<void> _openSettings() async {
    final LocationService service = ref.read(locationServiceProvider);
    final bool opened = await service.openAppSettings();
    if (!mounted) {
      return;
    }
    if (!opened) {
      setState(() {
        _locationMessage = ref
            .read(stringsProvider)
            .locationSettingsUnavailable;
        _canOpenSettings = false;
      });
    }
  }

  String? _validationMessage(AppLocalizations strings) {
    switch (_controller.validationError) {
      case null:
        return null;
      case PlotGeometryError.tooFewVertices:
        return strings.plotBoundaryTooFew;
      case PlotGeometryError.selfIntersection:
        return strings.plotBoundarySelfIntersection;
      case PlotGeometryError.tooManyVertices:
        return strings.plotBoundaryTooMany;
      case PlotGeometryError.zeroArea:
        return strings.plotBoundaryZeroArea;
      case PlotGeometryError.areaTooLarge:
        return strings.plotBoundaryAreaTooLarge;
      case PlotGeometryError.coordinatesOutOfBounds:
        return strings.plotBoundaryOutOfBounds;
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations strings = ref.watch(stringsProvider);
    final bool readOnly = _controller.readOnly;
    final String? validation = _validationMessage(strings);
    final String? area = _controller.areaHectares == null
        ? null
        : formatAreaHa(_controller.areaHectares!);
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, Object? result) {
        if (!didPop) {
          _close(boundaryUnchanged);
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          automaticallyImplyLeading: false,
          leading: IconButton(
            key: const Key('boundary_close'),
            tooltip: strings.cancel,
            onPressed: () => _close(boundaryUnchanged),
            icon: const Icon(Icons.close),
          ),
          title: Text(
            widget.initialGeometry == null
                ? strings.plotBoundaryTitle
                : strings.plotBoundaryEditTitle,
          ),
        ),
        body: SafeArea(
          child: Column(
            children: <Widget>[
              Expanded(
                child: PlotMap(
                  key: const Key('boundary_map'),
                  points: _controller.ring,
                  markers: _controller.markers,
                  interactive: !readOnly,
                  mapController: _mapController,
                  onTap: readOnly
                      ? null
                      : (LatLng point) => _controller.addVertex(point),
                ),
              ),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppSpacing.lg),
                decoration: const BoxDecoration(
                  color: AppColors.white,
                  border: Border(top: BorderSide(color: AppColors.line)),
                ),
                child: readOnly
                    ? Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: <Widget>[
                          AppStatusBanner(
                            key: const Key('boundary_read_only'),
                            message: strings.plotBoundaryComplexLimit,
                            tone: AppStatusBannerTone.warning,
                          ),
                          const SizedBox(height: AppSpacing.lg),
                          AppButton(
                            key: const Key('boundary_read_only_close'),
                            label: strings.back,
                            onPressed: () => _close(boundaryUnchanged),
                          ),
                        ],
                      )
                    : Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: <Widget>[
                          Row(
                            children: <Widget>[
                              Expanded(
                                child: Text(
                                  strings.plotBoundaryVertexCount(
                                    _controller.vertexCount,
                                  ),
                                  key: const Key('boundary_vertex_count'),
                                  style: AppTextStyles.label,
                                ),
                              ),
                              if (area != null)
                                Text(
                                  strings.plotBoundaryArea(area),
                                  key: const Key('boundary_area'),
                                  style: AppTextStyles.label,
                                ),
                            ],
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          Text(
                            validation ?? strings.plotBoundaryValid,
                            key: const Key('boundary_validation'),
                            style: AppTextStyles.caption.copyWith(
                              color: validation == null
                                  ? AppColors.tertiary
                                  : AppColors.danger,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          Text(
                            strings.plotBoundaryHint,
                            style: AppTextStyles.caption.copyWith(
                              color: AppColors.muted,
                            ),
                          ),
                          if (_position != null) ...<Widget>[
                            const SizedBox(height: AppSpacing.sm),
                            Text(
                              strings.locationAccuracy(
                                _position!.accuracyMeters.toStringAsFixed(0),
                              ),
                              key: const Key('boundary_accuracy'),
                              style: AppTextStyles.caption,
                            ),
                            if (_position!.accuracyMeters > 30) ...<Widget>[
                              const SizedBox(height: AppSpacing.xs),
                              Text(
                                strings.locationAccuracyWarning,
                                key: const Key('boundary_accuracy_warning'),
                                style: AppTextStyles.caption.copyWith(
                                  color: AppColors.accentBrown,
                                ),
                              ),
                            ],
                          ],
                          if (_locationMessage != null) ...<Widget>[
                            const SizedBox(height: AppSpacing.sm),
                            AppErrorBanner(
                              key: const Key('boundary_location_error'),
                              message: _locationMessage!,
                            ),
                          ],
                          if (_canOpenSettings) ...<Widget>[
                            Align(
                              alignment: Alignment.centerLeft,
                              child: AppTextButton(
                                key: const Key('boundary_open_settings'),
                                label: strings.locationOpenSettings,
                                onPressed: _openSettings,
                              ),
                            ),
                          ],
                          const SizedBox(height: AppSpacing.md),
                          Wrap(
                            spacing: AppSpacing.sm,
                            runSpacing: AppSpacing.sm,
                            children: <Widget>[
                              AppButton(
                                key: const Key('boundary_add_position'),
                                label: strings.plotBoundaryAddPosition,
                                size: AppButtonSize.compact,
                                variant: AppButtonVariant.secondary,
                                loading: _locating,
                                onPressed: _locating
                                    ? null
                                    : () => _locate(addVertex: true),
                              ),
                              AppButton(
                                key: const Key('boundary_center'),
                                label: strings.plotBoundaryCenterPosition,
                                size: AppButtonSize.compact,
                                variant: AppButtonVariant.outlined,
                                onPressed: _locating
                                    ? null
                                    : () => _locate(addVertex: false),
                              ),
                              AppButton(
                                key: const Key('boundary_undo'),
                                label: strings.plotBoundaryUndo,
                                size: AppButtonSize.compact,
                                variant: AppButtonVariant.outlined,
                                onPressed: _controller.vertexCount == 0
                                    ? null
                                    : _controller.removeLast,
                              ),
                              AppButton(
                                key: const Key('boundary_clear'),
                                label: strings.plotBoundaryClear,
                                size: AppButtonSize.compact,
                                variant: AppButtonVariant.outlined,
                                onPressed: _controller.vertexCount == 0
                                    ? null
                                    : _controller.clear,
                              ),
                            ],
                          ),
                          const SizedBox(height: AppSpacing.md),
                          AppButton(
                            key: const Key('boundary_finish'),
                            label: strings.plotBoundaryFinish,
                            onPressed: _controller.isValid
                                ? () => _close(_controller.geometry)
                                : null,
                          ),
                          if (_controller.hadBoundary) ...<Widget>[
                            const SizedBox(height: AppSpacing.sm),
                            AppButton(
                              key: const Key('boundary_delete'),
                              label: strings.plotBoundaryDelete,
                              variant: AppButtonVariant.outlined,
                              onPressed: () => _close(null),
                            ),
                          ],
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
