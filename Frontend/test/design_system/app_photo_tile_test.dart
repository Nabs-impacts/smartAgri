import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:smartagri/design_system/components/app_photo_tile.dart';

import 'test_app.dart';

Uint8List sampleBytes() {
  final img.Image image = img.Image(width: 12, height: 8);
  img.fill(image, color: img.ColorRgb8(10, 120, 60));
  return Uint8List.fromList(img.encodePng(image));
}

void main() {
  testWidgets('renders the add tile and calls onAdd', (
    WidgetTester tester,
  ) async {
    int adds = 0;
    await pumpComponent(tester, AppPhotoTile(onAdd: () => adds++));

    expect(find.byKey(const Key('photo_tile_add')), findsOneWidget);
    expect(find.byIcon(Icons.photo_camera_outlined), findsOneWidget);

    await tester.tap(find.byKey(const Key('photo_tile_add')));
    expect(adds, 1);
  });

  testWidgets('renders bytes, the delete button and the loading overlay', (
    WidgetTester tester,
  ) async {
    int deletes = 0;
    await tester.pumpWidget(
      testApp(
        AppPhotoTile(
          bytes: sampleBytes(),
          loading: true,
          onDelete: () => deletes++,
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(Image), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.byKey(const Key('photo_tile_delete')), findsOneWidget);

    await tester.tap(find.byKey(const Key('photo_tile_delete')));
    expect(deletes, 1);
  });

  testWidgets('shows a placeholder without image or add callback', (
    WidgetTester tester,
  ) async {
    await pumpComponent(tester, const AppPhotoTile());

    expect(find.byIcon(Icons.image_outlined), findsOneWidget);
    expect(find.byKey(const Key('photo_tile_add')), findsNothing);
    expect(find.byKey(const Key('photo_tile_delete')), findsNothing);
  });
}
