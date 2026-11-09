import 'harvest_quality.dart';

class Harvest {
  const Harvest({
    required this.id,
    required this.cycleId,
    required this.harvestedOn,
    required this.quantityKg,
    this.quality,
    this.soldKg = 0,
    this.avgPriceXofPerKg,
  });

  final String id;
  final String cycleId;
  final DateTime harvestedOn;
  final double quantityKg;
  final HarvestQuality? quality;
  final double soldKg;
  final double? avgPriceXofPerKg;
}
