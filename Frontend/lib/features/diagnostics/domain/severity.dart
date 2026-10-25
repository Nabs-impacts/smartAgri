enum Severity {
  low('low'),
  medium('medium'),
  high('high');

  const Severity(this.apiValue);

  final String apiValue;

  static Severity? fromApi(Object? value) {
    for (final Severity severity in Severity.values) {
      if (severity.apiValue == value) {
        return severity;
      }
    }
    return null;
  }
}
