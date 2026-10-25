import 'diagnostic_status.dart';
import 'severity.dart';

class DiagnosticSummary {
  const DiagnosticSummary({
    required this.id,
    required this.status,
    required this.createdAt,
    this.confidence,
    this.severity,
    this.plotId,
    this.labelName,
    this.thumbnailUrl,
  });

  final String id;
  final DiagnosticStatus status;
  final DateTime createdAt;
  final double? confidence;
  final Severity? severity;
  final String? plotId;
  final String? labelName;
  final String? thumbnailUrl;

  factory DiagnosticSummary.fromJson(Map<String, dynamic> json) {
    return DiagnosticSummary(
      id: json['id'] as String? ?? '',
      status: DiagnosticStatus.fromApi(json['status']),
      createdAt: _date(json['created_at']),
      confidence: _double(json['confidence']),
      severity: Severity.fromApi(json['severity']),
      plotId: json['plot_id'] as String?,
      labelName: _labelName(json),
      thumbnailUrl: _thumbnailUrl(json),
    );
  }
}

class DiagnosticsPage {
  const DiagnosticsPage({required this.items, this.nextCursor});

  final List<DiagnosticSummary> items;
  final String? nextCursor;

  factory DiagnosticsPage.fromJson(Map<String, dynamic> json) {
    final Object? rawItems = json['items'];
    return DiagnosticsPage(
      items: rawItems is List
          ? rawItems
                .whereType<Map>()
                .map(
                  (Map item) => DiagnosticSummary.fromJson(
                    Map<String, dynamic>.from(item),
                  ),
                )
                .toList()
          : <DiagnosticSummary>[],
      nextCursor: json['next_cursor'] as String?,
    );
  }
}

String? _labelName(Map<String, dynamic> json) {
  final Object? direct = json['label_name'];
  if (direct is String && direct.trim().isNotEmpty) {
    return direct;
  }
  final Object? rawPredictions = json['predictions'];
  if (rawPredictions is List && rawPredictions.isNotEmpty) {
    final Object? first = rawPredictions.first;
    if (first is Map) {
      final Object? rawLabel = first['label'];
      if (rawLabel is Map) {
        final Object? name = rawLabel['name'];
        if (name is String && name.trim().isNotEmpty) {
          return name;
        }
      }
    }
  }
  final Object? rawLabel = json['label'];
  if (rawLabel is Map) {
    final Object? name = rawLabel['name'];
    if (name is String && name.trim().isNotEmpty) {
      return name;
    }
  }
  return null;
}

String? _thumbnailUrl(Map<String, dynamic> json) {
  final Object? direct = json['thumbnail_url'];
  if (direct is String && direct.trim().isNotEmpty) {
    return direct;
  }
  final Object? rawMedia = json['media'];
  if (rawMedia is List && rawMedia.isNotEmpty) {
    final Object? first = rawMedia.first;
    if (first is Map) {
      final Object? url = first['url'];
      if (url is String && url.trim().isNotEmpty) {
        return url;
      }
    }
  }
  return null;
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
  if (value is String) {
    return DateTime.tryParse(value) ?? DateTime.fromMillisecondsSinceEpoch(0);
  }
  return DateTime.fromMillisecondsSinceEpoch(0);
}
