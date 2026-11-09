import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartagri/core/i18n/app_localizations.dart';
import 'package:smartagri/features/sync/sync_format.dart';

void main() {
  final AppLocalizations strings = lookupAppLocalizations(const Locale('fr'));
  final DateTime now = DateTime.utc(2026, 11, 8, 12);

  test('formats a missing sync date as never', () {
    expect(formatLastSync(strings, null, now), 'jamais');
  });

  test('formats a recent sync in minutes', () {
    expect(
      formatLastSync(strings, now.subtract(const Duration(minutes: 5)), now),
      'il y a 5 min',
    );
  });

  test('formats a sync from yesterday', () {
    expect(
      formatLastSync(strings, now.subtract(const Duration(hours: 30)), now),
      'hier',
    );
  });

  test('formats a sync in hours and days', () {
    expect(
      formatLastSync(strings, now.subtract(const Duration(hours: 3)), now),
      'il y a 3 h',
    );
    expect(
      formatLastSync(strings, now.subtract(const Duration(days: 3)), now),
      'il y a 3 jours',
    );
  });
}
