import 'plot_geometry.dart';

class FarmsDomainException implements Exception {
  const FarmsDomainException(this.code, this.message, {this.geometryError});

  final String code;
  final String message;
  final PlotGeometryError? geometryError;

  @override
  String toString() => message;
}
