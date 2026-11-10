import 'package:flutter/widgets.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

abstract final class MapConfig {
  static const String tileUrl = String.fromEnvironment(
    'MAP_TILE_URL',
    defaultValue: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
  );
  static const String userAgentPackageName = 'com.smartagri.app';
  static const double maxZoom = 19;
}

typedef MapTileLayerBuilder = Widget Function({
  required VoidCallback onTileError,
});

final Provider<MapTileLayerBuilder> mapTileLayerBuilderProvider =
    Provider<MapTileLayerBuilder>((Ref ref) {
      return ({required VoidCallback onTileError}) {
        return TileLayer(
          urlTemplate: MapConfig.tileUrl,
          userAgentPackageName: MapConfig.userAgentPackageName,
          maxNativeZoom: MapConfig.maxZoom.toInt(),
          maxZoom: MapConfig.maxZoom,
          errorTileCallback: (TileImage tile, Object error, StackTrace? stack) {
            onTileError();
          },
        );
      };
    });
