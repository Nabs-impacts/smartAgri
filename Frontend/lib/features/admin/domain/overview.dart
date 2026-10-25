class RegionAdoption {
  const RegionAdoption({
    required this.regionId,
    required this.regionName,
    required this.masked,
    this.users,
    this.plots,
  });

  final int regionId;
  final String regionName;
  final bool masked;
  final int? users;
  final int? plots;

  factory RegionAdoption.fromJson(Map<String, dynamic> json) {
    final Map<String, dynamic> region = _asMap(json['region']);
    final bool masked = json['masked'] == true;
    return RegionAdoption(
      regionId: _asInt(region['id']),
      regionName: _asString(region['name_fr'] ?? region['name']),
      masked: masked,
      users: masked ? null : _asNullableInt(json['users']),
      plots: masked ? null : _asNullableInt(json['plots']),
    );
  }
}

class Overview {
  const Overview({
    required this.activeUsers30d,
    required this.diagnostics30d,
    required this.trackedAreaHa,
    required this.adoption,
  });

  final int activeUsers30d;
  final int diagnostics30d;
  final double trackedAreaHa;
  final List<RegionAdoption> adoption;

  factory Overview.fromJson(Map<String, dynamic> json) {
    final Object? rawAdoption = json['adoption'];
    return Overview(
      activeUsers30d: _asInt(json['active_users_30d']),
      diagnostics30d: _asInt(json['diagnostics_30d']),
      trackedAreaHa: _asDouble(json['tracked_area_ha']),
      adoption: rawAdoption is List
          ? rawAdoption
                .whereType<Map>()
                .map(
                  (Map item) =>
                      RegionAdoption.fromJson(Map<String, dynamic>.from(item)),
                )
                .toList()
          : <RegionAdoption>[],
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

double _asDouble(Object? value) {
  if (value is num) {
    return value.toDouble();
  }
  return double.tryParse(value?.toString() ?? '') ?? 0;
}

String _asString(Object? value) => value?.toString() ?? '';
