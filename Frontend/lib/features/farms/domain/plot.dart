enum SoilType {
  sandy('sandy', 'Sableux'),
  loam('loam', 'Limoneux'),
  clay('clay', 'Argileux'),
  laterite('laterite', 'Latéritique'),
  other('other', 'Autre');

  const SoilType(this.apiValue, this.label);

  final String apiValue;
  final String label;

  static SoilType? fromApi(Object? value) {
    for (final SoilType type in SoilType.values) {
      if (type.apiValue == value) {
        return type;
      }
    }
    return null;
  }
}

enum IrrigationType {
  rainfed('rainfed', 'Pluvial'),
  drip('drip', 'Goutte-à-goutte'),
  gravity('gravity', 'Gravitaire'),
  well('well', 'Puits'),
  other('other', 'Autre');

  const IrrigationType(this.apiValue, this.label);

  final String apiValue;
  final String label;

  static IrrigationType? fromApi(Object? value) {
    for (final IrrigationType type in IrrigationType.values) {
      if (type.apiValue == value) {
        return type;
      }
    }
    return null;
  }
}

class Plot {
  const Plot({
    required this.id,
    required this.farmId,
    required this.name,
    required this.createdAt,
    required this.updatedAt,
    this.areaHa,
    this.soilType,
    this.irrigation,
  });

  final String id;
  final String farmId;
  final String name;
  final double? areaHa;
  final SoilType? soilType;
  final IrrigationType? irrigation;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory Plot.fromJson(Map<String, dynamic> json) {
    return Plot(
      id: json['id'] as String? ?? '',
      farmId: json['farm_id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      areaHa: _area(json['area_ha']),
      soilType: SoilType.fromApi(json['soil_type']),
      irrigation: IrrigationType.fromApi(json['irrigation']),
      createdAt: _date(json['created_at']),
      updatedAt: _date(json['updated_at']),
    );
  }
}

double? _area(Object? value) {
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
