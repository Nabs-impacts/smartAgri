enum SeasonType {
  rainy('rainy'),
  dry('dry');

  const SeasonType(this.apiCode);

  final String apiCode;

  static SeasonType fromApi(String? value) {
    for (final SeasonType type in SeasonType.values) {
      if (type.apiCode == value) {
        return type;
      }
    }
    return SeasonType.rainy;
  }
}

class YieldCell {
  const YieldCell({
    required this.cropId,
    required this.cropCode,
    required this.cropName,
    required this.regionId,
    required this.regionName,
    required this.seasonYear,
    required this.seasonType,
    required this.masked,
    this.cycles,
    this.farmers,
    this.avgYieldKgPerHa,
    this.minYieldKgPerHa,
    this.maxYieldKgPerHa,
  });

  final int cropId;
  final String cropCode;
  final String cropName;
  final int regionId;
  final String regionName;
  final int seasonYear;
  final SeasonType seasonType;
  final bool masked;
  final int? cycles;
  final int? farmers;
  final double? avgYieldKgPerHa;
  final double? minYieldKgPerHa;
  final double? maxYieldKgPerHa;

  factory YieldCell.fromJson(Map<String, dynamic> json) {
    final Map<String, dynamic> crop = _asMap(json['crop']);
    final Map<String, dynamic> region = _asMap(json['region']);
    final bool masked = json['masked'] == true;
    return YieldCell(
      cropId: _asInt(crop['id']),
      cropCode: _asString(crop['code']),
      cropName: _asString(crop['name_fr'] ?? crop['name']),
      regionId: _asInt(region['id']),
      regionName: _asString(region['name_fr'] ?? region['name']),
      seasonYear: _asInt(json['season_year']),
      seasonType: SeasonType.fromApi(json['season_type']?.toString()),
      masked: masked,
      cycles: masked ? null : _asNullableInt(json['cycles']),
      farmers: masked ? null : _asNullableInt(json['farmers']),
      avgYieldKgPerHa: masked
          ? null
          : _asNullableDouble(json['avg_yield_kg_per_ha']),
      minYieldKgPerHa: masked
          ? null
          : _asNullableDouble(json['min_yield_kg_per_ha']),
      maxYieldKgPerHa: masked
          ? null
          : _asNullableDouble(json['max_yield_kg_per_ha']),
    );
  }
}

Map<String, dynamic> _asMap(Object? value) {
  if (value is Map<String, dynamic>) {
    return value;
  }
  if (value is Map) {
    return Map<String, dynamic>.from(value);
  }
  return <String, dynamic>{};
}

int _asInt(Object? value) {
  if (value is num) {
    return value.toInt();
  }
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

int? _asNullableInt(Object? value) {
  if (value is num) {
    return value.toInt();
  }
  return int.tryParse(value?.toString() ?? '');
}

double? _asNullableDouble(Object? value) {
  if (value is num) {
    return value.toDouble();
  }
  return double.tryParse(value?.toString() ?? '');
}

String _asString(Object? value) => value?.toString() ?? '';
