const String _narrowNoBreakSpace = '\u202F';

const List<String> _frenchMonths = <String>[
  'janvier',
  'février',
  'mars',
  'avril',
  'mai',
  'juin',
  'juillet',
  'août',
  'septembre',
  'octobre',
  'novembre',
  'décembre',
];

String formatXof(num value) {
  final int rounded = value.round();
  final bool negative = rounded < 0;
  final String digits = rounded.abs().toString();
  final StringBuffer buffer = StringBuffer();
  for (int index = 0; index < digits.length; index++) {
    if (index > 0 && (digits.length - index) % 3 == 0) {
      buffer.write(_narrowNoBreakSpace);
    }
    buffer.write(digits[index]);
  }
  return '${negative ? '-' : ''}$buffer FCFA';
}

String formatKg(double value) {
  return '${_decimal(value)} kg';
}

String formatKgPerHa(double value) {
  return '${_decimal(value)} kg/ha';
}

String formatLongDate(DateTime value) {
  return '${value.day} ${monthName(value.month)} ${value.year}';
}

String formatShortDate(DateTime value) {
  final String day = value.day.toString().padLeft(2, '0');
  final String month = value.month.toString().padLeft(2, '0');
  return '$day/$month/${value.year}';
}

String formatMonthYear(DateTime value) {
  return '${monthName(value.month)} ${value.year}';
}

String monthName(int month) {
  if (month < 1 || month > 12) {
    return '';
  }
  return _frenchMonths[month - 1];
}

String formatDecimalInput(double value) {
  return _decimal(value);
}

String formatQuantity(double value, String? unit) {
  final String number = _decimal(value);
  if (unit == null || unit.trim().isEmpty) {
    return number;
  }
  return '$number ${unit.trim()}';
}

String _decimal(double value) {
  final double rounded = (value * 10).round() / 10;
  String text = rounded.toStringAsFixed(1);
  if (text.endsWith('.0')) {
    text = text.substring(0, text.length - 2);
  }
  return text.replaceAll('.', ',');
}
