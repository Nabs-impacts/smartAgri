import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:smartagri/features/farms/domain/plot_geometry.dart';
import 'package:smartagri/features/farms/presentation/boundary_editor_controller.dart';

final LatLng a = const LatLng(13.5, 2.1);
final LatLng b = const LatLng(13.5, 2.101);
final LatLng c = const LatLng(13.501, 2.101);

void main() {
  test('adds vertices and computes the area', () {
    final BoundaryEditorController controller = BoundaryEditorController();

    controller
      ..addVertex(a)
      ..addVertex(b)
      ..addVertex(c);

    expect(controller.vertexCount, 3);
    expect(controller.areaHectares, closeTo(0.6, 0.01));
    expect(controller.isValid, isTrue);
    expect(controller.geometry, isNotNull);
  });

  test('removes the last vertex and clears the trace', () {
    final BoundaryEditorController controller = BoundaryEditorController();

    controller
      ..addVertex(a)
      ..addVertex(b)
      ..addVertex(c)
      ..removeLast();

    expect(controller.vertexCount, 2);
    expect(controller.isValid, isFalse);

    controller.clear();

    expect(controller.vertexCount, 0);
    expect(controller.geometry, isNull);
  });

  test('deletes an existing trace', () {
    final BoundaryEditorController controller = BoundaryEditorController(
      initial: PlotGeometry(<LatLng>[a, b, c]),
    );

    controller.deleteBoundary();

    expect(controller.isDeleted, isTrue);
    expect(controller.geometry, isNull);
    expect(controller.isValid, isFalse);
  });

  test('keeps a trace with holes in read-only mode', () {
    final PlotGeometry geometry = PlotGeometry(
      <LatLng>[
        const LatLng(13.4, 2.0),
        const LatLng(13.4, 2.4),
        const LatLng(13.8, 2.4),
        const LatLng(13.8, 2.0),
      ],
      holes: <List<LatLng>>[
        <LatLng>[a, b, c],
      ],
    );
    final BoundaryEditorController controller = BoundaryEditorController(
      initial: geometry,
    );

    controller
      ..addVertex(const LatLng(14, 3))
      ..removeLast()
      ..clear()
      ..deleteBoundary();

    expect(controller.readOnly, isTrue);
    expect(controller.hasHoles, isTrue);
    expect(controller.vertexCount, 4);
    expect(identical(controller.geometry, geometry), isTrue);
    expect(controller.validationError, isNull);
    expect(controller.isValid, isTrue);
  });
}
