import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../tokens.dart';

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
            color: AppColors.inputFill,
            borderRadius: AppRadii.cardBorder,
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: onAdd,
              child: CustomPaint(
                painter: const _DashedBorderPainter(),
                child: const Center(
                  child: Icon(
                    Icons.photo_camera_outlined,
                    color: AppColors.primary,
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
                color: AppColors.surface,
                child: provider == null
                    ? const Icon(
                        Icons.image_outlined,
                        color: AppColors.muted,
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
                            ) => const Center(
                              child: Icon(
                                Icons.broken_image_outlined,
                                color: AppColors.muted,
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
                  color: AppColors.ink.withValues(alpha: 0.35),
                  borderRadius: AppRadii.cardBorder,
                ),
                child: const Center(
                  child: SizedBox(
                    width: AppSizes.loadingIndicator,
                    height: AppSizes.loadingIndicator,
                    child: CircularProgressIndicator(
                      strokeWidth: AppSizes.loadingStroke,
                      color: AppColors.white,
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
                color: AppColors.white,
                shape: const CircleBorder(),
                child: InkWell(
                  key: const Key('photo_tile_delete'),
                  customBorder: const CircleBorder(),
                  onTap: onDelete,
                  child: const Padding(
                    padding: EdgeInsets.all(AppSpacing.xs),
                    child: Icon(
                      Icons.close,
                      color: AppColors.danger,
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
  const _DashedBorderPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..color = AppColors.line
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
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
