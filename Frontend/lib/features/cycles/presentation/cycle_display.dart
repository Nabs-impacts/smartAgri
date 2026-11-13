import 'package:flutter/material.dart';

import '../../../core/i18n/app_localizations.dart';
import '../../../design_system/components/app_status_chip.dart';
import '../domain/activity.dart';
import '../domain/activity_type.dart';
import '../domain/cycle_status.dart';
import '../domain/harvest.dart';
import '../domain/timeline_entry.dart';
import 'cycle_format.dart';
import '../../../design_system/app_icons.dart';

String cycleStatusLabel(AppLocalizations strings, CycleStatus status) {
  return switch (status) {
    CycleStatus.planned => strings.cycleStatusPlanned,
    CycleStatus.growing => strings.cycleStatusGrowing,
    CycleStatus.harvested => strings.cycleStatusHarvested,
    CycleStatus.failed => strings.cycleStatusFailed,
  };
}

AppStatusChipVariant cycleStatusVariant(CycleStatus status) {
  return switch (status) {
    CycleStatus.planned => AppStatusChipVariant.neutral,
    CycleStatus.growing => AppStatusChipVariant.success,
    CycleStatus.harvested => AppStatusChipVariant.warning,
    CycleStatus.failed => AppStatusChipVariant.danger,
  };
}

String activityTypeLabel(AppLocalizations strings, ActivityType type) {
  return switch (type) {
    ActivityType.sowing => strings.activityTypeSowing,
    ActivityType.fertilizing => strings.activityTypeFertilizing,
    ActivityType.irrigation => strings.activityTypeIrrigation,
    ActivityType.weeding => strings.activityTypeWeeding,
    ActivityType.pesticide => strings.activityTypePesticide,
    ActivityType.harvest => strings.activityTypeHarvest,
    ActivityType.other => strings.activityTypeOther,
  };
}

IconData activityTypeIcon(ActivityType type) {
  return switch (type) {
    ActivityType.sowing => AppIcons.plant,
    ActivityType.fertilizing => AppIcons.leaf,
    ActivityType.irrigation => AppIcons.water,
    ActivityType.weeding => AppIcons.cut,
    ActivityType.pesticide => AppIcons.bug,
    ActivityType.harvest => AppIcons.harvest,
    ActivityType.other => AppIcons.note,
  };
}

IconData timelineEntryIcon(TimelineEntry entry) {
  if (entry is ActivityTimelineEntry) {
    return activityTypeIcon(entry.activity.type);
  }
  return AppIcons.harvest;
}

String timelineEntryTypeLabel(AppLocalizations strings, TimelineEntry entry) {
  if (entry is ActivityTimelineEntry) {
    return activityTypeLabel(strings, entry.activity.type);
  }
  return strings.activityTypeHarvest;
}

String timelineEntryCycleId(TimelineEntry entry) {
  if (entry is ActivityTimelineEntry) {
    return entry.activity.cycleId;
  }
  return (entry as HarvestTimelineEntry).harvest.cycleId;
}

List<String> timelineEntryDetails(
  AppLocalizations strings,
  TimelineEntry entry,
) {
  if (entry is ActivityTimelineEntry) {
    final Activity activity = entry.activity;
    return <String>[
      if (activity.productName != null && activity.productName!.isNotEmpty)
        activity.productName!,
      if (activity.quantity != null)
        formatQuantity(activity.quantity!, activity.unit),
      if (activity.costXof != null) formatXof(activity.costXof!),
    ];
  }
  final Harvest harvest = (entry as HarvestTimelineEntry).harvest;
  return <String>[
    formatKg(harvest.quantityKg),
    if (harvest.quality != null)
      '${strings.cycleQuality} : ${harvest.quality!.code}',
    if (harvest.soldKg > 0)
      '${strings.cycleSold} : ${formatKg(harvest.soldKg)}',
  ];
}
