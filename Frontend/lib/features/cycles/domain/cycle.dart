import 'cycle_status.dart';

class Cycle {
  const Cycle({
    required this.id,
    required this.plotId,
    required this.cropId,
    required this.status,
    this.variety,
    this.season,
    this.sowingDate,
    this.expectedHarvestDate,
    this.harvestDate,
    this.notes,
  });

  final String id;
  final String plotId;
  final int cropId;
  final String? variety;
  final String? season;
  final DateTime? sowingDate;
  final DateTime? expectedHarvestDate;
  final DateTime? harvestDate;
  final CycleStatus status;
  final String? notes;
}
