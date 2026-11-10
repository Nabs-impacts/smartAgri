import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';

import '../domain/plot_geometry.dart';

class BoundaryEditorController extends ChangeNotifier {
  BoundaryEditorController({PlotGeometry? initial})
    : _initial = initial,
      _ring = List<LatLng>.of(initial?.ring ?? const <LatLng>[]),
      _readOnly = initial?.hasHoles ?? false;

  final PlotGeometry? _initial;
  final List<LatLng> _ring;
  final bool _readOnly;
  bool _deleted = false;

  List<LatLng> get ring => List<LatLng>.unmodifiable(_ring);

  List<LatLng> get markers => ring;

  int get vertexCount => _ring.length;

  bool get readOnly => _readOnly;

  bool get hasHoles => _readOnly;

  bool get hadBoundary => _initial != null;

  bool get isDeleted => _deleted;

  PlotGeometry? get geometry {
    if (_deleted || _ring.length < 3) {
      return null;
    }
    if (_readOnly && _initial != null) {
      return _initial;
    }
    return PlotGeometry(_ring);
  }

  PlotGeometryError? get validationError {
    if (_readOnly) {
      return null;
    }
    return PlotGeometry(_ring).validate();
  }

  bool get isValid => !_deleted && validationError == null;

  double? get areaHectares {
    if (_ring.length < 3) {
      return null;
    }
    return PlotGeometry(_ring).areaHectares();
  }

  void addVertex(LatLng point) {
    if (_readOnly || _deleted) {
      return;
    }
    _ring.add(point);
    notifyListeners();
  }

  void removeLast() {
    if (_readOnly || _ring.isEmpty) {
      return;
    }
    _ring.removeLast();
    notifyListeners();
  }

  void clear() {
    if (_readOnly || _ring.isEmpty) {
      return;
    }
    _ring.clear();
    notifyListeners();
  }

  void deleteBoundary() {
    if (!hadBoundary || _readOnly) {
      return;
    }
    _deleted = true;
    _ring.clear();
    notifyListeners();
  }
}
