enum SoilStatus {
  good('good'),
  dry('dry'),
  wet('wet');

  const SoilStatus(this.apiValue);

  final String apiValue;

  static SoilStatus fromApi(String value) {
    return SoilStatus.values.firstWhere(
      (SoilStatus status) => status.apiValue == value,
      orElse: () => SoilStatus.good,
    );
  }
}

class Weather {
  const Weather({
    required this.temperatureC,
    required this.rainRiskPercent,
    required this.windKmh,
    required this.soilStatus,
  });

  final double temperatureC;
  final int rainRiskPercent;
  final int windKmh;
  final SoilStatus soilStatus;
}
