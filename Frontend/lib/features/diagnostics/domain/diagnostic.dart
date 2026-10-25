import 'diagnostic_media.dart';
import 'diagnostic_status.dart';
import 'prediction.dart';
import 'recommendation_info.dart';
import 'severity.dart';

class Diagnostic {
  const Diagnostic({
    required this.id,
    required this.status,
    required this.createdAt,
    this.error,
    this.confidence,
    this.severity,
    this.cropId,
    this.plotId,
    this.completedAt,
    this.medias = const <DiagnosticMedia>[],
    this.predictions = const <Prediction>[],
    this.onDevicePrediction,
    this.recommendation,
  });

  final String id;
  final DiagnosticStatus status;
  final String? error;
  final double? confidence;
  final Severity? severity;
  final int? cropId;
  final String? plotId;
  final DateTime createdAt;
  final DateTime? completedAt;
  final List<DiagnosticMedia> medias;
  final List<Prediction> predictions;
  final Prediction? onDevicePrediction;
  final RecommendationInfo? recommendation;

  factory Diagnostic.fromJson(Map<String, dynamic> json) {
    final Object? rawMedias = json['media'];
    final Object? rawPredictions = json['predictions'];
    final Object? rawOnDevice = json['on_device_prediction'];
    final Object? rawRecommendation = json['recommendation'];
    return Diagnostic(
      id: json['id'] as String? ?? '',
      status: DiagnosticStatus.fromApi(json['status']),
      error: json['error'] as String?,
      confidence: _double(json['confidence']),
      severity: Severity.fromApi(json['severity']),
      cropId: (json['crop_id'] as num?)?.toInt(),
      plotId: json['plot_id'] as String?,
      createdAt: _date(json['created_at']),
      completedAt: _nullableDate(json['completed_at']),
      medias: rawMedias is List
          ? rawMedias
                .whereType<Map>()
                .map(
                  (Map item) =>
                      DiagnosticMedia.fromJson(Map<String, dynamic>.from(item)),
                )
                .toList()
          : <DiagnosticMedia>[],
      predictions: rawPredictions is List
          ? rawPredictions
                .whereType<Map>()
                .map(
                  (Map item) =>
                      Prediction.fromJson(Map<String, dynamic>.from(item)),
                )
                .toList()
          : <Prediction>[],
      onDevicePrediction: rawOnDevice is Map
          ? Prediction.fromJson(Map<String, dynamic>.from(rawOnDevice))
          : null,
      recommendation: rawRecommendation is Map
          ? RecommendationInfo.fromJson(
              Map<String, dynamic>.from(rawRecommendation),
            )
          : null,
    );
  }
}

double? _double(Object? value) {
  if (value is num) {
    return value.toDouble();
  }
  if (value is String) {
    return double.tryParse(value.replaceAll(',', '.'));
  }
  return null;
}

DateTime _date(Object? value) {
  return _nullableDate(value) ?? DateTime.fromMillisecondsSinceEpoch(0);
}

DateTime? _nullableDate(Object? value) {
  if (value is String) {
    return DateTime.tryParse(value);
  }
  return null;
}
