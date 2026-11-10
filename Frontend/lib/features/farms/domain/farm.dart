class Farm {
  const Farm({
    required this.id,
    required this.name,
    this.village,
    this.adminAreaId,
    this.location,
    this.updatedAt,
  });

  final String id;
  final String name;
  final String? village;
  final int? adminAreaId;
  final Map<String, dynamic>? location;
  final DateTime? updatedAt;

  factory Farm.fromJson(Map<String, dynamic> json) {
    final Object? rawLocation = json['location'];
    return Farm(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      village: json['village'] as String?,
      adminAreaId: (json['admin_area_id'] as num?)?.toInt(),
      location: rawLocation is Map
          ? Map<String, dynamic>.from(rawLocation)
          : null,
      updatedAt: _date(json['updated_at']),
    );
  }
}

DateTime? _date(Object? value) {
  if (value is String) {
    return DateTime.tryParse(value);
  }
  return null;
}
