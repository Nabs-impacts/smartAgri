class CycleSummary {
  const CycleSummary({
    required this.areaHa,
    required this.totalKg,
    required this.yieldKgPerHa,
    required this.totalCostXof,
    required this.revenueXof,
    required this.marginXof,
  });

  final double? areaHa;
  final double totalKg;
  final double? yieldKgPerHa;
  final int totalCostXof;
  final double revenueXof;
  final double marginXof;
}

class CycleComparison {
  const CycleComparison({
    required this.sampleSize,
    required this.averageYieldKgPerHa,
  });

  final int sampleSize;
  final double? averageYieldKgPerHa;
}
