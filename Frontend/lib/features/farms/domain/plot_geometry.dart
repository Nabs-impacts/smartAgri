import 'dart:convert';
import 'dart:math' as math;

import 'package:latlong2/latlong.dart';

const double _authalicRadiusMeters = 6371007.180918475;
const double _hectareSquareMeters = 10000;
const int maxPlotVertices = 500;
const double maxPlotAreaHa = 10000;

enum PlotGeometryError {
  tooFewVertices,
  selfIntersection,
  tooManyVertices,
  zeroArea,
  areaTooLarge,
  coordinatesOutOfBounds,
}

class PlotGeometry {
  PlotGeometry(
    List<LatLng> ring, {
    List<List<LatLng>> holes = const <List<LatLng>>[],
    this.originalGeoJson,
  }) : ring = List<LatLng>.unmodifiable(ring),
       holes = List<List<LatLng>>.unmodifiable(
         holes.map((List<LatLng> hole) => List<LatLng>.unmodifiable(hole)),
       );

  final List<LatLng> ring;
  final List<List<LatLng>> holes;
  final Map<String, dynamic>? originalGeoJson;

  bool get hasHoles => holes.isNotEmpty;

  factory PlotGeometry.fromGeoJson(Map<String, dynamic> json) {
    if (json['type'] != 'Polygon') {
      throw const FormatException('La géométrie doit être un polygone.');
    }
    final Object? rawCoordinates = json['coordinates'];
    if (rawCoordinates is! List || rawCoordinates.isEmpty) {
      throw const FormatException('Coordonnées de polygone invalides.');
    }
    final List<LatLng> ring = _ringFromGeoJson(rawCoordinates.first);
    final List<List<LatLng>> holes = <List<LatLng>>[];
    for (int index = 1; index < rawCoordinates.length; index++) {
      holes.add(_ringFromGeoJson(rawCoordinates[index]));
    }
    return PlotGeometry(
      ring,
      holes: holes,
      originalGeoJson: holes.isEmpty ? null : _deepCopy(json),
    );
  }

  Map<String, dynamic> toGeoJson() {
    final Map<String, dynamic>? original = originalGeoJson;
    if (hasHoles && original != null) {
      return _deepCopy(original);
    }
    return <String, dynamic>{
      'type': 'Polygon',
      'coordinates': <dynamic>[
        _closedRing(ring),
        for (final List<LatLng> hole in holes) _closedRing(hole),
      ],
    };
  }

  double areaHectares() {
    final double hectares = _rawAreaHectares();
    return (hectares * 1000).roundToDouble() / 1000;
  }

  PlotGeometryError? validate() {
    final Set<String> distinct = <String>{
      for (final LatLng point in ring) _key(point),
    };
    if (distinct.length < 3) {
      return PlotGeometryError.tooFewVertices;
    }
    final int vertexCount =
        ring.length +
        holes.fold<int>(0, (int sum, List<LatLng> hole) => sum + hole.length);
    if (vertexCount > maxPlotVertices) {
      return PlotGeometryError.tooManyVertices;
    }
    for (final List<LatLng> points in <List<LatLng>>[ring, ...holes]) {
      for (final LatLng point in points) {
        if (!_inBounds(point)) {
          return PlotGeometryError.coordinatesOutOfBounds;
        }
      }
    }
    if (_selfIntersects(ring)) {
      return PlotGeometryError.selfIntersection;
    }
    final double area = _rawAreaHectares();
    if (area <= 0) {
      return PlotGeometryError.zeroArea;
    }
    if (area > maxPlotAreaHa) {
      return PlotGeometryError.areaTooLarge;
    }
    return null;
  }

  double _rawAreaHectares() {
    if (ring.length < 3) {
      return 0;
    }
    double total = 0;
    for (int index = 0; index < ring.length; index++) {
      final LatLng first = ring[index];
      final LatLng second = ring[(index + 1) % ring.length];
      final double longitude1 = _radians(first.longitude);
      final double longitude2 = _radians(second.longitude);
      final double latitude1 = _radians(first.latitude);
      final double latitude2 = _radians(second.latitude);
      double delta = longitude2 - longitude1;
      if (delta > math.pi) {
        delta -= 2 * math.pi;
      } else if (delta < -math.pi) {
        delta += 2 * math.pi;
      }
      total += delta * (2 + math.sin(latitude1) + math.sin(latitude2));
    }
    final double squareMeters =
        total.abs() * _authalicRadiusMeters * _authalicRadiusMeters / 2;
    return squareMeters / _hectareSquareMeters;
  }

  static List<LatLng> _ringFromGeoJson(Object? rawRing) {
    if (rawRing is! List) {
      throw const FormatException('Anneau de polygone invalide.');
    }
    final List<LatLng> points = <LatLng>[];
    for (final Object? rawPoint in rawRing) {
      if (rawPoint is! List || rawPoint.length < 2) {
        throw const FormatException('Coordonnées de polygone invalides.');
      }
      final Object? rawLongitude = rawPoint[0];
      final Object? rawLatitude = rawPoint[1];
      if (rawLongitude is! num || rawLatitude is! num) {
        throw const FormatException('Coordonnées de polygone invalides.');
      }
      points.add(LatLng(rawLatitude.toDouble(), rawLongitude.toDouble()));
    }
    if (points.length > 1) {
      final LatLng first = points.first;
      final LatLng last = points.last;
      if (first.latitude == last.latitude &&
          first.longitude == last.longitude) {
        points.removeLast();
      }
    }
    return points;
  }

  static List<List<double>> _closedRing(List<LatLng> points) {
    final List<List<double>> coordinates = <List<double>>[
      for (final LatLng point in points)
        <double>[point.longitude, point.latitude],
    ];
    if (points.isNotEmpty) {
      coordinates.add(<double>[points.first.longitude, points.first.latitude]);
    }
    return coordinates;
  }

  static bool _inBounds(LatLng point) {
    return point.longitude >= -180 &&
        point.longitude <= 180 &&
        point.latitude >= -90 &&
        point.latitude <= 90;
  }

  static bool _selfIntersects(List<LatLng> points) {
    final int count = points.length;
    if (count < 4) {
      return false;
    }
    for (int first = 0; first < count; first++) {
      final int firstNext = (first + 1) % count;
      for (int second = first + 1; second < count; second++) {
        final int secondNext = (second + 1) % count;
        if (second == firstNext || first == secondNext) {
          continue;
        }
        if (_segmentsIntersect(
          points[first],
          points[firstNext],
          points[second],
          points[secondNext],
        )) {
          return true;
        }
      }
    }
    return false;
  }

  static bool _segmentsIntersect(LatLng a, LatLng b, LatLng c, LatLng d) {
    final double first = _cross(c, d, a);
    final double second = _cross(c, d, b);
    final double third = _cross(a, b, c);
    final double fourth = _cross(a, b, d);
    if (((first > 0 && second < 0) || (first < 0 && second > 0)) &&
        ((third > 0 && fourth < 0) || (third < 0 && fourth > 0))) {
      return true;
    }
    if (first == 0 && _onSegment(c, d, a)) {
      return true;
    }
    if (second == 0 && _onSegment(c, d, b)) {
      return true;
    }
    if (third == 0 && _onSegment(a, b, c)) {
      return true;
    }
    if (fourth == 0 && _onSegment(a, b, d)) {
      return true;
    }
    return false;
  }

  static double _cross(LatLng a, LatLng b, LatLng point) {
    return (b.longitude - a.longitude) * (point.latitude - a.latitude) -
        (b.latitude - a.latitude) * (point.longitude - a.longitude);
  }

  static bool _onSegment(LatLng a, LatLng b, LatLng point) {
    return point.longitude >= math.min(a.longitude, b.longitude) &&
        point.longitude <= math.max(a.longitude, b.longitude) &&
        point.latitude >= math.min(a.latitude, b.latitude) &&
        point.latitude <= math.max(a.latitude, b.latitude);
  }

  static double _radians(double degrees) => degrees * math.pi / 180;

  static String _key(LatLng point) =>
      '${point.latitude.toStringAsFixed(7)},'
      '${point.longitude.toStringAsFixed(7)}';

  static Map<String, dynamic> _deepCopy(Map<String, dynamic> value) {
    return jsonDecode(jsonEncode(value)) as Map<String, dynamic>;
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    if (other is! PlotGeometry || other.ring.length != ring.length) {
      return false;
    }
    for (int index = 0; index < ring.length; index++) {
      if (ring[index] != other.ring[index]) {
        return false;
      }
    }
    return true;
  }

  @override
  int get hashCode => Object.hashAll(ring);
}

Map<String, dynamic> pointToGeoJson(LatLng point) {
  return <String, dynamic>{
    'type': 'Point',
    'coordinates': <double>[point.longitude, point.latitude],
  };
}

LatLng? pointFromGeoJson(Object? value) {
  Object? raw = value;
  if (raw is String) {
    try {
      raw = jsonDecode(raw);
    } catch (_) {
      return null;
    }
  }
  if (raw is! Map) {
    return null;
  }
  if (raw['type'] != 'Point') {
    return null;
  }
  final Object? coordinates = raw['coordinates'];
  if (coordinates is! List || coordinates.length < 2) {
    return null;
  }
  final Object? longitude = coordinates[0];
  final Object? latitude = coordinates[1];
  if (longitude is! num || latitude is! num) {
    return null;
  }
  return LatLng(latitude.toDouble(), longitude.toDouble());
}

bool pointInWgs84Bounds(LatLng point) {
  return point.longitude >= -180 &&
      point.longitude <= 180 &&
      point.latitude >= -90 &&
      point.latitude <= 90;
}
