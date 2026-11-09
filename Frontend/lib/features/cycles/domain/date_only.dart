String? formatDateOnly(DateTime? value) {
  if (value == null) {
    return null;
  }
  final String month = value.month.toString().padLeft(2, '0');
  final String day = value.day.toString().padLeft(2, '0');
  return '${value.year}-$month-$day';
}

DateTime? parseDateOnly(Object? value) {
  if (value is DateTime) {
    return DateTime.utc(value.year, value.month, value.day);
  }
  if (value is String) {
    final String trimmed = value.trim();
    if (trimmed.isEmpty) {
      return null;
    }
    final List<String> parts = trimmed.split('-');
    if (parts.length >= 3) {
      final int? year = int.tryParse(parts[0]);
      final int? month = int.tryParse(parts[1]);
      final int? day = int.tryParse(
        parts[2].length >= 2 ? parts[2].substring(0, 2) : parts[2],
      );
      if (year != null && month != null && day != null) {
        return DateTime.utc(year, month, day);
      }
    }
    return DateTime.tryParse(trimmed)?.toUtc();
  }
  return null;
}

String formatRequiredDate(DateTime value) {
  return formatDateOnly(value) ?? '';
}
