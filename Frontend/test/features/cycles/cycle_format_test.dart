import 'package:flutter_test/flutter_test.dart';
import 'package:smartagri/features/cycles/presentation/cycle_format.dart';

void main() {
  test('formats amounts in FCFA with narrow no-break spaces', () {
    expect(formatXof(12500), '12\u202F500 FCFA');
    expect(formatXof(0), '0 FCFA');
    expect(formatXof(1234567), '1\u202F234\u202F567 FCFA');
    expect(formatXof(-2500), '-2\u202F500 FCFA');
  });

  test('formats kilograms with at most one decimal', () {
    expect(formatKg(100), '100 kg');
    expect(formatKg(100.5), '100,5 kg');
    expect(formatKg(100.04), '100 kg');
    expect(formatKg(0), '0 kg');
    expect(formatKgPerHa(50), '50 kg/ha');
    expect(formatKgPerHa(12.34), '12,3 kg/ha');
  });

  test('formats long and short dates and month names', () {
    final DateTime date = DateTime(2026, 11, 3);
    expect(formatLongDate(date), '3 novembre 2026');
    expect(formatShortDate(date), '03/11/2026');
    expect(formatMonthYear(date), 'novembre 2026');
    expect(monthName(1), 'janvier');
    expect(monthName(8), 'août');
    expect(monthName(0), '');
  });

  test('formats quantities with an optional unit', () {
    expect(formatQuantity(2.5, 'kg'), '2,5 kg');
    expect(formatQuantity(2, null), '2');
    expect(formatDecimalInput(3.0), '3');
    expect(formatDecimalInput(3.25), '3,3');
  });
}
