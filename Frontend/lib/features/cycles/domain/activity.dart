import 'activity_type.dart';

class Activity {
  const Activity({
    required this.id,
    required this.cycleId,
    required this.type,
    required this.performedOn,
    this.productName,
    this.quantity,
    this.unit,
    this.costXof,
    this.notes,
  });

  final String id;
  final String cycleId;
  final ActivityType type;
  final DateTime performedOn;
  final String? productName;
  final double? quantity;
  final String? unit;
  final int? costXof;
  final String? notes;
}
