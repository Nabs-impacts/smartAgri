import 'activity.dart';
import 'harvest.dart';

sealed class TimelineEntry {
  const TimelineEntry({required this.id, required this.date});

  final String id;
  final DateTime date;
}

class ActivityTimelineEntry extends TimelineEntry {
  ActivityTimelineEntry({required this.activity})
    : super(id: activity.id, date: activity.performedOn);

  final Activity activity;
}

class HarvestTimelineEntry extends TimelineEntry {
  HarvestTimelineEntry({required this.harvest})
    : super(id: harvest.id, date: harvest.harvestedOn);

  final Harvest harvest;
}
