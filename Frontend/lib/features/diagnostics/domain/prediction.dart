class DiagnosticLabel {
  const DiagnosticLabel({
    required this.id,
    required this.code,
    required this.kind,
    required this.name,
  });

  final int id;
  final String code;
  final String kind;
  final String name;

  factory DiagnosticLabel.fromJson(Map<String, dynamic> json) {
    return DiagnosticLabel(
      id: (json['id'] as num?)?.toInt() ?? 0,
      code: json['code'] as String? ?? '',
      kind: json['kind'] as String? ?? '',
      name: json['name'] as String? ?? '',
    );
  }
}

class Prediction {
  const Prediction({
    required this.rank,
    required this.confidence,
    required this.label,
  });

  final int rank;
  final double confidence;
  final DiagnosticLabel label;

  factory Prediction.fromJson(Map<String, dynamic> json) {
    final Object? rawLabel = json['label'];
    return Prediction(
      rank: (json['rank'] as num?)?.toInt() ?? 0,
      confidence: _double(json['confidence']) ?? 0,
      label: DiagnosticLabel.fromJson(
        rawLabel is Map
            ? Map<String, dynamic>.from(rawLabel)
            : <String, dynamic>{},
      ),
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
