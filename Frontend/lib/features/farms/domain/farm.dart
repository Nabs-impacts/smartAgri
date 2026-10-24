class Farm {
  const Farm({
    required this.id,
    required this.name,
    required this.createdAt,
    required this.updatedAt,
    this.village,
    this.adminAreaId,
  });

  final String id;
  final String name;
  final String? village;
  final int? adminAreaId;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory Farm.fromJson(Map<String, dynamic> json) {
    return Farm(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      village: json['village'] as String?,
      adminAreaId: (json['admin_area_id'] as num?)?.toInt(),
      createdAt: _date(json['created_at']),
      updatedAt: _date(json['updated_at']),
    );
  }
}

DateTime _date(Object? value) {
  if (value is String) {
    return DateTime.tryParse(value) ?? DateTime.fromMillisecondsSinceEpoch(0);
  }
  return DateTime.fromMillisecondsSinceEpoch(0);
}
