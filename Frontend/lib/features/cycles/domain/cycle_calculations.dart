import 'activity.dart';
import 'cycle.dart';
import 'cycle_summary.dart';
import 'harvest.dart';
import 'timeline_entry.dart';

CycleSummary computeSummary(
  Cycle cycle,
  double? areaHa,
  List<Activity> activities,
  List<Harvest> harvests,
) {
  double totalKg = 0;
  for (final Harvest harvest in harvests) {
    totalKg += harvest.quantityKg;
  }

  double? yieldKgPerHa;
  if (areaHa != null && areaHa != 0) {
    yieldKgPerHa = _roundToTenth(totalKg / areaHa);
  }

  int totalCostXof = 0;
  for (final Activity activity in activities) {
    totalCostXof += activity.costXof ?? 0;
  }

  double revenueXof = 0;
  for (final Harvest harvest in harvests) {
    final double? price = harvest.avgPriceXofPerKg;
    if (price != null) {
      revenueXof += harvest.soldKg * price;
    }
  }

  return CycleSummary(
    areaHa: areaHa,
    totalKg: totalKg,
    yieldKgPerHa: yieldKgPerHa,
    totalCostXof: totalCostXof,
    revenueXof: revenueXof,
    marginXof: revenueXof - totalCostXof,
  );
}

List<TimelineEntry> mergeTimeline(
  List<Activity> activities,
  List<Harvest> harvests,
) {
  final List<TimelineEntry> entries = <TimelineEntry>[
    ...activities.map(
      (Activity activity) => ActivityTimelineEntry(activity: activity),
    ),
    ...harvests.map(
      (Harvest harvest) => HarvestTimelineEntry(harvest: harvest),
    ),
  ];
  entries.sort((TimelineEntry first, TimelineEntry second) {
    final int byDate = second.date.compareTo(first.date);
    if (byDate != 0) {
      return byDate;
    }
    return second.id.compareTo(first.id);
  });
  return entries;
}

double _roundToTenth(double value) {
  return (value * 10).round() / 10;
}
