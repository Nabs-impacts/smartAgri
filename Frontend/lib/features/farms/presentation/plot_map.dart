import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/i18n/app_localizations.dart';
import '../../../core/i18n/strings_provider.dart';
import '../../../core/map/map_config.dart';
import '../../../design_system/tokens.dart';
import '../../../design_system/app_palette.dart';

const LatLng nigerCenter = LatLng(17.6078, 8.0817);

class PlotMap extends ConsumerStatefulWidget {
  const PlotMap({
    this.points = const <LatLng>[],
    this.markers = const <LatLng>[],
    this.interactive = false,
    this.fitPoints = true,
    this.height,
    this.onTap,
    this.mapController,
    super.key,
  });

  final List<LatLng> points;
  final List<LatLng> markers;
  final bool interactive;
  final bool fitPoints;
  final double? height;
  final ValueChanged<LatLng>? onTap;
  final MapController? mapController;

  @override
  ConsumerState<PlotMap> createState() => _PlotMapState();
}

class _PlotMapState extends ConsumerState<PlotMap> {
  bool _tileError = false;

  void _handleTileError() {
    if (_tileError) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(() => _tileError = true);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations strings = ref.watch(stringsProvider);
    final MapTileLayerBuilder tileLayer = ref.watch(
      mapTileLayerBuilderProvider,
    );
    final List<LatLng> points = widget.points;
    final CameraFit? fit = widget.fitPoints && points.length >= 2
        ? CameraFit.bounds(
            bounds: LatLngBounds.fromPoints(points),
            padding: const EdgeInsets.all(AppSpacing.xxl),
          )
        : null;
    final LatLng center = points.isEmpty ? nigerCenter : points.first;
    final double zoom = points.isEmpty ? 5 : 14;
    final Widget map = FlutterMap(
      mapController: widget.mapController,
      options: MapOptions(
        initialCenter: center,
        initialZoom: zoom,
        initialCameraFit: fit,
        maxZoom: MapConfig.maxZoom,
        backgroundColor: context.palette.surface,
        interactionOptions: InteractionOptions(
          flags: widget.interactive
              ? InteractiveFlag.all
              : InteractiveFlag.none,
        ),
        onTap: widget.onTap == null
            ? null
            : (TapPosition tapPosition, LatLng point) => widget.onTap!(point),
      ),
      children: <Widget>[
        tileLayer(onTileError: _handleTileError),
        if (points.length >= 3)
          PolygonLayer(
            polygons: <Polygon<Object>>[
              Polygon<Object>(
                points: points,
                color: context.palette.primary.withValues(alpha: 0.18),
                borderColor: context.palette.primary,
                borderStrokeWidth: 2,
              ),
            ],
          ),
        if (widget.markers.isNotEmpty)
          CircleLayer(
            circles: <CircleMarker<Object>>[
              for (final LatLng point in widget.markers)
                CircleMarker<Object>(
                  point: point,
                  radius: 7,
                  color: context.palette.secondary,
                  borderColor: Colors.white,
                  borderStrokeWidth: 2,
                ),
            ],
          ),
      ],
    );
    final Widget content = Stack(
      children: <Widget>[
        Positioned.fill(child: map),
        Positioned(
          right: AppSpacing.sm,
          bottom: AppSpacing.sm,
          child: IgnorePointer(
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm,
                vertical: AppSpacing.xs,
              ),
              decoration: BoxDecoration(
                color: context.palette.surfaceRaised,
                borderRadius: AppRadii.smallBorder,
              ),
              child: Text(
                strings.mapAttribution,
                key: const Key('map_attribution'),
                style: AppTextStyles.caption.copyWith(
                  color: context.palette.muted,
                ),
              ),
            ),
          ),
        ),
        if (_tileError)
          Positioned(
            left: AppSpacing.sm,
            right: AppSpacing.sm,
            top: AppSpacing.sm,
            child: IgnorePointer(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: AppSpacing.xs,
                ),
                decoration: BoxDecoration(
                  color: context.palette.surfaceRaised,
                  borderRadius: AppRadii.smallBorder,
                ),
                child: Text(
                  strings.mapOffline,
                  key: const Key('map_offline'),
                  textAlign: TextAlign.center,
                  style: AppTextStyles.caption.copyWith(
                    color: context.palette.muted,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
    if (widget.height == null) {
      return content;
    }
    return SizedBox(height: widget.height, child: content);
  }
}
