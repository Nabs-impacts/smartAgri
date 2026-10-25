import 'package:flutter_test/flutter_test.dart';
import 'package:smartagri/features/admin/domain/overview.dart';
import 'package:smartagri/features/admin/domain/yield_cell.dart';
import 'package:smartagri/features/auth/domain/user_profile.dart';

Map<String, dynamic> regionJson(int id, String name) {
  return <String, dynamic>{'id': id, 'name_fr': name};
}

void main() {
  test('parses the overview response', () {
    final Overview overview = Overview.fromJson(<String, dynamic>{
      'active_users_30d': 1250,
      'diagnostics_30d': 340,
      'tracked_area_ha': 12500.5,
      'adoption': <Map<String, dynamic>>[
        <String, dynamic>{
          'region': regionJson(1, 'Niamey'),
          'masked': false,
          'users': 20,
          'plots': 40,
        },
        <String, dynamic>{'region': regionJson(2, 'Tahoua'), 'masked': true},
      ],
    });

    expect(overview.activeUsers30d, 1250);
    expect(overview.diagnostics30d, 340);
    expect(overview.trackedAreaHa, 12500.5);
    expect(overview.adoption, hasLength(2));
    expect(overview.adoption.first.regionId, 1);
    expect(overview.adoption.first.regionName, 'Niamey');
    expect(overview.adoption.first.masked, isFalse);
    expect(overview.adoption.first.users, 20);
    expect(overview.adoption.first.plots, 40);
    expect(overview.adoption.last.masked, isTrue);
    expect(overview.adoption.last.users, isNull);
    expect(overview.adoption.last.plots, isNull);
  });

  test('forces the masked adoption values to null', () {
    final RegionAdoption region = RegionAdoption.fromJson(<String, dynamic>{
      'region': regionJson(3, 'Dosso'),
      'masked': true,
      'users': 4,
      'plots': 9,
    });

    expect(region.masked, isTrue);
    expect(region.users, isNull);
    expect(region.plots, isNull);
  });

  test('parses a yield cell for each season', () {
    final YieldCell rainy = YieldCell.fromJson(<String, dynamic>{
      'crop': <String, dynamic>{'id': 1, 'code': 'MIL', 'name_fr': 'Mil'},
      'region': regionJson(1, 'Maradi'),
      'season_year': 2026,
      'season_type': 'rainy',
      'masked': false,
      'cycles': 12,
      'farmers': 5,
      'avg_yield_kg_per_ha': 1250.0,
      'min_yield_kg_per_ha': 900.0,
      'max_yield_kg_per_ha': 1600.0,
    });
    final YieldCell dry = YieldCell.fromJson(<String, dynamic>{
      'crop': <String, dynamic>{'id': 2, 'code': 'SOR', 'name_fr': 'Sorgho'},
      'region': regionJson(2, 'Dosso'),
      'season_year': 2025,
      'season_type': 'dry',
      'masked': false,
      'cycles': 6,
      'farmers': 4,
      'avg_yield_kg_per_ha': 800.0,
      'min_yield_kg_per_ha': 500.0,
      'max_yield_kg_per_ha': 1100.0,
    });

    expect(rainy.cropId, 1);
    expect(rainy.cropCode, 'MIL');
    expect(rainy.cropName, 'Mil');
    expect(rainy.regionId, 1);
    expect(rainy.regionName, 'Maradi');
    expect(rainy.seasonYear, 2026);
    expect(rainy.seasonType, SeasonType.rainy);
    expect(rainy.cycles, 12);
    expect(rainy.farmers, 5);
    expect(rainy.avgYieldKgPerHa, 1250.0);
    expect(rainy.minYieldKgPerHa, 900.0);
    expect(rainy.maxYieldKgPerHa, 1600.0);
    expect(dry.seasonType, SeasonType.dry);
    expect(dry.seasonYear, 2025);
  });

  test('forces every masked yield value to null', () {
    final YieldCell cell = YieldCell.fromJson(<String, dynamic>{
      'crop': <String, dynamic>{'id': 1, 'code': 'MIL', 'name_fr': 'Mil'},
      'region': regionJson(1, 'Maradi'),
      'season_year': 2026,
      'season_type': 'rainy',
      'masked': true,
      'cycles': 4,
      'farmers': 2,
      'avg_yield_kg_per_ha': 1250.0,
      'min_yield_kg_per_ha': 900.0,
      'max_yield_kg_per_ha': 1600.0,
    });

    expect(cell.masked, isTrue);
    expect(cell.cycles, isNull);
    expect(cell.farmers, isNull);
    expect(cell.avgYieldKgPerHa, isNull);
    expect(cell.minYieldKgPerHa, isNull);
    expect(cell.maxYieldKgPerHa, isNull);
    expect(cell.cropName, 'Mil');
    expect(cell.regionName, 'Maradi');
  });

  test('detects the administration roles', () {
    UserProfile user(String role) {
      return UserProfile(
        id: 'id',
        phone: '+22790203040',
        fullName: 'Amina Diallo',
        role: role,
      );
    }

    expect(user('gov_admin').isAdmin, isTrue);
    expect(user('super_admin').isAdmin, isTrue);
    expect(user('farmer').isAdmin, isFalse);
    expect(user('technician').isAdmin, isFalse);
  });
}
