import '../../../core/i18n/app_language.dart';

class Crop {
  const Crop({
    required this.id,
    required this.code,
    required this.nameFr,
    required this.category,
    this.nameHa,
    this.nameDje,
    this.cycleDays,
  });

  final int id;
  final String code;
  final String nameFr;
  final String? nameHa;
  final String? nameDje;
  final String category;
  final int? cycleDays;

  String localizedName(AppLanguage language) {
    final String? candidate = switch (language) {
      AppLanguage.fr => nameFr,
      AppLanguage.ha => nameHa,
      AppLanguage.dje => nameDje,
    };
    if (candidate == null || candidate.trim().isEmpty) {
      return nameFr;
    }
    return candidate;
  }

  factory Crop.fromJson(Map<String, dynamic> json) {
    return Crop(
      id: (json['id'] as num?)?.toInt() ?? 0,
      code: json['code'] as String? ?? '',
      nameFr: json['name_fr'] as String? ?? '',
      nameHa: json['name_ha'] as String?,
      nameDje: json['name_dje'] as String?,
      category: json['category'] as String? ?? '',
      cycleDays: (json['cycle_days'] as num?)?.toInt(),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'code': code,
      'name_fr': nameFr,
      'name_ha': nameHa,
      'name_dje': nameDje,
      'category': category,
      'cycle_days': cycleDays,
    };
  }
}
