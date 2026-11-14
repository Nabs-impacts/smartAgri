import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../core/haptics/app_haptics.dart';
import '../app_icons.dart';
import '../app_palette.dart';
import '../tokens.dart';
import 'app_pressable.dart';

class AppPhotoTile extends StatelessWidget {
  const AppPhotoTile({
    this.image,
    this.bytes,
    this.onDelete,
    this.onAdd,
    this.loading = false,
    this.size = 104,
    super.key,
  });

  final ImageProvider? image;
  final Uint8List? bytes;
  final VoidCallback? onDelete;
  final VoidCallback? onAdd;
  final bool loading;
  final double size;

  bool get _isAdd => onAdd != null && image == null && bytes == null;

  ImageProvider? get _provider {
    if (image != null) {
      return image;
    }
    if (bytes != null) {
      return MemoryImage(bytes!);
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    if (_isAdd) {
      return Semantics(
        button: true,
        label: 'Ajouter une photo',
        child: SizedBox(
          key: const Key('photo_tile_add'),
          width: size,
          height: size,
          child: Material(
            color: context.palette.inputFill,
            borderRadius: AppRadii.cardBorder,
            clipBehavior: Clip.antiAlias,
            child: AppPressable(
              onTap: onAdd,
              borderRadius: AppRadii.cardBorder,
              haptics: AppHapticType.tap,
              semanticLabel: 'Ajouter une photo',
              child: CustomPaint(
                painter: _DashedBorderPainter(color: context.palette.line),
                child: Center(
                  child: Icon(
                    AppIcons.camera,
                    color: context.palette.primary,
                    size: AppSizes.icon,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }
    final ImageProvider? provider = _provider;
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        children: <Widget>[
          Positioned.fill(
            child: ClipRRect(
              borderRadius: AppRadii.cardBorder,
              child: Container(
                color: context.palette.surface,
                child: provider == null
                    ? Icon(
                        AppIcons.image,
                        color: context.palette.muted,
                        size: AppSizes.icon,
                      )
                    : Image(
                        image: provider,
                        fit: BoxFit.cover,
                        gaplessPlayback: true,
                        errorBuilder:
                            (
                              BuildContext context,
                              Object error,
                              StackTrace? stackTrace,
                            ) => Center(
                              child: Icon(
                                AppIcons.brokenImage,
                                color: context.palette.muted,
                                size: AppSizes.icon,
                              ),
                            ),
                      ),
              ),
            ),
          ),
          if (loading)
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: context.palette.ink.withValues(alpha: 0.35),
                  borderRadius: AppRadii.cardBorder,
                ),
                child: Center(
                  child: SizedBox(
                    width: AppSizes.loadingIndicator,
                    height: AppSizes.loadingIndicator,
                    child: CircularProgressIndicator(
                      strokeWidth: AppSizes.loadingStroke,
                      color: context.palette.onInverted,
                    ),
                  ),
                ),
              ),
            ),
          if (onDelete != null)
            Positioned(
              top: AppSpacing.xs,
              right: AppSpacing.xs,
              child: Material(
                color: context.palette.surfaceRaised,
                shape: const CircleBorder(),
                child: AppPressable(
                  key: const Key('photo_tile_delete'),
                  customBorder: const CircleBorder(),
                  haptics: AppHapticType.tap,
                  semanticLabel: 'Supprimer la photo',
                  onTap: onDelete,
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.xs),
                    child: Icon(
                      AppIcons.close,
                      color: context.palette.danger,
                      size: AppSizes.smallIcon,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _DashedBorderPainter extends CustomPainter {
  const _DashedBorderPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    final RRect border = RRect.fromRectAndRadius(
      Offset.zero & size,
      const Radius.circular(AppRadii.card),
    );
    final Path path = Path()..addRRect(border);
    for (final metric in path.computeMetrics()) {
      double distance = 0;
      while (distance < metric.length) {
        final double end = distance + 6;
        canvas.drawPath(metric.extractPath(distance, end), paint);
        distance = end + 4;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedBorderPainter oldDelegate) =>
      oldDelegate.color != color;
}
