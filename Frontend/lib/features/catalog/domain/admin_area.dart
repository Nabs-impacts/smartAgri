class AdminArea {
  const AdminArea({
    required this.id,
    required this.level,
    required this.name,
    required this.code,
    this.parentId,
  });

  final int id;
  final int? parentId;
  final String level;
  final String name;
  final String code;

  factory AdminArea.fromJson(Map<String, dynamic> json) {
    return AdminArea(
      id: (json['id'] as num?)?.toInt() ?? 0,
      parentId: (json['parent_id'] as num?)?.toInt(),
      level: json['level'] as String? ?? '',
      name: json['name'] as String? ?? '',
      code: json['code'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'parent_id': parentId,
      'level': level,
      'name': name,
      'code': code,
    };
  }
}
