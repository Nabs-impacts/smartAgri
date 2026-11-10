import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:smartagri/features/farms/domain/plot_geometry.dart';

List<LatLng> squareMeters(double latitude, double side) {
  final double latitudeDelta = side / 111320;
  final double longitudeDelta =
      side / (111320 * math.cos(latitude * math.pi / 180));
  return <LatLng>[
    LatLng(latitude, 2.1),
    LatLng(latitude, 2.1 + longitudeDelta),
    LatLng(latitude + latitudeDelta, 2.1 + longitudeDelta),
    LatLng(latitude + latitudeDelta, 2.1),
  ];
}

List<LatLng> circle(int count) {
  return List<LatLng>.generate(count, (int index) {
    final double angle = 2 * math.pi * index / count;
    return LatLng(13.5 + 0.01 * math.sin(angle), 2.1 + 0.01 * math.cos(angle));
  });
}

void main() {
  test('estimates the area of a 100 m square at Niamey', () {
    final PlotGeometry geometry = PlotGeometry(squareMeters(13.5, 100));

    expect(geometry.areaHectares(), closeTo(1, 0.005));
  });

  test('closes the ring and writes longitude before latitude', () {
    final PlotGeometry geometry = PlotGeometry(<LatLng>[
      const LatLng(13.5, 2.1),
      const LatLng(13.5, 2.2),
      const LatLng(13.6, 2.2),
    ]);

    final Map<String, dynamic> json = geometry.toGeoJson();
    final List<dynamic> coordinates = json['coordinates'] as List<dynamic>;
    final List<dynamic> ring = coordinates.first as List<dynamic>;
    expect(ring, hasLength(4));
    expect(ring.first, <double>[2.1, 13.5]);
    expect(ring.last, <double>[2.1, 13.5]);
  });

  test('round trips through GeoJSON', () {
    const Map<String, dynamic> json = <String, dynamic>{
      'type': 'Polygon',
      'coordinates': <dynamic>[
        <dynamic>[
          <dynamic>[2.1, 13.5],
          <dynamic>[2.2, 13.5],
          <dynamic>[2.2, 13.6],
          <dynamic>[2.1, 13.5],
        ],
      ],
    };

    final PlotGeometry geometry = PlotGeometry.fromGeoJson(json);

    expect(geometry.ring, hasLength(3));
    expect(geometry.toGeoJson(), json);
  });

  test('detects and preserves interior rings', () {
    const Map<String, dynamic> json = <String, dynamic>{
      'type': 'Polygon',
      'coordinates': <dynamic>[
        <dynamic>[
          <dynamic>[2.0, 13.4],
          <dynamic>[2.4, 13.4],
          <dynamic>[2.4, 13.8],
          <dynamic>[2.0, 13.8],
          <dynamic>[2.0, 13.4],
        ],
        <dynamic>[
          <dynamic>[2.1, 13.5],
          <dynamic>[2.2, 13.5],
          <dynamic>[2.2, 13.6],
          <dynamic>[2.1, 13.5],
        ],
      ],
    };

    final PlotGeometry geometry = PlotGeometry.fromGeoJson(json);

    expect(geometry.hasHoles, isTrue);
    expect(geometry.holes, hasLength(1));
    expect(geometry.toGeoJson(), json);
  });

  test('rejects fewer than three distinct vertices', () {
    final PlotGeometry geometry = PlotGeometry(<LatLng>[
      const LatLng(13.5, 2.1),
      const LatLng(13.5, 2.1),
    ]);

    expect(geometry.validate(), PlotGeometryError.tooFewVertices);
  });

  test('rejects a self-intersecting ring', () {
    final PlotGeometry geometry = PlotGeometry(<LatLng>[
      const LatLng(13.5, 2.1),
      const LatLng(13.6, 2.2),
      const LatLng(13.5, 2.2),
      const LatLng(13.6, 2.1),
    ]);

    expect(geometry.validate(), PlotGeometryError.selfIntersection);
  });

  test('rejects more than 500 vertices', () {
    final PlotGeometry geometry = PlotGeometry(circle(501));

    expect(geometry.validate(), PlotGeometryError.tooManyVertices);
  });

  test('rejects a null area', () {
    final PlotGeometry geometry = PlotGeometry(<LatLng>[
      const LatLng(13.5, 2.1),
      const LatLng(13.5, 2.2),
      const LatLng(13.5, 2.3),
    ]);

    expect(geometry.validate(), PlotGeometryError.zeroArea);
  });

  test('rejects an area above 10000 hectares', () {
    final PlotGeometry geometry = PlotGeometry(<LatLng>[
      const LatLng(13.5, 2.1),
      const LatLng(13.5, 2.3),
      const LatLng(13.7, 2.3),
      const LatLng(13.7, 2.1),
    ]);

    expect(geometry.validate(), PlotGeometryError.areaTooLarge);
  });

  test('rejects coordinates outside WGS84 bounds', () {
    final PlotGeometry geometry = PlotGeometry(<LatLng>[
      const LatLng(13.5, 200),
      const LatLng(13.6, 2.2),
      const LatLng(13.7, 2.1),
    ]);

    expect(geometry.validate(), PlotGeometryError.coordinatesOutOfBounds);
  });
}
