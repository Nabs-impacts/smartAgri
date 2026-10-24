import 'package:flutter_test/flutter_test.dart';
import 'package:smartagri/core/i18n/app_language.dart';
import 'package:smartagri/features/catalog/domain/admin_area.dart';
import 'package:smartagri/features/catalog/domain/crop.dart';

void main() {
  test('a crop uses the requested translation', () {
    const Crop crop = Crop(
      id: 1,
      code: 'millet',
      nameFr: 'Mil',
      nameHa: 'Gero',
      nameDje: 'Zaarmaa',
      category: 'cereal',
      cycleDays: 90,
    );

    expect(crop.localizedName(AppLanguage.fr), 'Mil');
    expect(crop.localizedName(AppLanguage.ha), 'Gero');
    expect(crop.localizedName(AppLanguage.dje), 'Zaarmaa');
  });

  test('a crop falls back to French when a translation is missing', () {
    const Crop crop = Crop(
      id: 1,
      code: 'millet',
      nameFr: 'Mil',
      category: 'cereal',
    );

    expect(crop.localizedName(AppLanguage.ha), 'Mil');
    expect(crop.localizedName(AppLanguage.dje), 'Mil');
  });

  test('parses crops and admin areas from JSON', () {
    final Crop crop = Crop.fromJson(<String, dynamic>{
      'id': 1,
      'code': 'millet',
      'name_fr': 'Mil',
      'name_ha': null,
      'name_dje': 'Zaarmaa',
      'category': 'cereal',
      'cycle_days': 90,
    });
    final AdminArea area = AdminArea.fromJson(<String, dynamic>{
      'id': 8,
      'parent_id': 2,
      'level': 'department',
      'name': 'Dogondoutchi',
      'code': 'DOG',
    });

    expect(crop.cycleDays, 90);
    expect(crop.localizedName(AppLanguage.dje), 'Zaarmaa');
    expect(area.parentId, 2);
    expect(area.level, 'department');
    expect(area.name, 'Dogondoutchi');
    expect(area.code, 'DOG');
  });
}
