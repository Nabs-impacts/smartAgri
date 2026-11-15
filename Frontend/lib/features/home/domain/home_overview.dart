import '../../../core/i18n/app_localizations.dart';
import '../../cycles/domain/activity_type.dart';
import '../../cycles/domain/cycle_status.dart';

class ActiveCycleOverview {
  const ActiveCycleOverview({
    required this.cycleId,
    required this.cropId,
    required this.cropName,
    required this.plotName,
    required this.farmName,
    required this.status,
    this.sowingDate,
    this.expectedHarvestDate,
  });

  final String cycleId;
  final int cropId;
  final String cropName;
  final String plotName;
  final String farmName;
  final CycleStatus status;
  final DateTime? sowingDate;
  final DateTime? expectedHarvestDate;
}

class RecentActivityOverview {
  const RecentActivityOverview({
    required this.activityId,
    required this.cycleId,
    required this.type,
    required this.performedOn,
    required this.cropName,
    required this.plotName,
  });

  final String activityId;
  final String cycleId;
  final ActivityType type;
  final DateTime performedOn;
  final String cropName;
  final String plotName;
}

enum CycleProgressKind {
  sownAgo,
  sownToday,
  sowingIn,
  sowingToday,
  harvestIn,
  harvestToday,
  harvestLate,
  noDates,
}

class CycleProgress {
  const CycleProgress(this.kind, this.days);

  final CycleProgressKind kind;
  final int days;
}

CycleProgress cycleProgress({
  DateTime? sowingDate,
  DateTime? expectedHarvestDate,
  required DateTime today,
}) {
  final DateTime current = _dateOnly(today);
  final DateTime? harvest = _optionalDateOnly(expectedHarvestDate);
  if (harvest != null) {
    final int remaining = harvest.difference(current).inDays;
    if (remaining > 0) {
      return CycleProgress(CycleProgressKind.harvestIn, remaining);
    }
    if (remaining == 0) {
      return const CycleProgress(CycleProgressKind.harvestToday, 0);
    }
    return CycleProgress(CycleProgressKind.harvestLate, -remaining);
  }
  final DateTime? sowing = _optionalDateOnly(sowingDate);
  if (sowing != null) {
    final int elapsed = current.difference(sowing).inDays;
    if (elapsed > 0) {
      return CycleProgress(CycleProgressKind.sownAgo, elapsed);
    }
    if (elapsed == 0) {
      return const CycleProgress(CycleProgressKind.sownToday, 0);
    }
    return CycleProgress(CycleProgressKind.sowingIn, -elapsed);
  }
  return const CycleProgress(CycleProgressKind.noDates, 0);
}

String cycleProgressText(
  AppLocalizations strings, {
  DateTime? sowingDate,
  DateTime? expectedHarvestDate,
  required DateTime today,
}) {
  final CycleProgress progress = cycleProgress(
    sowingDate: sowingDate,
    expectedHarvestDate: expectedHarvestDate,
    today: today,
  );
  return switch (progress.kind) {
    CycleProgressKind.sownAgo => strings.homeCycleSownAgo(progress.days),
    CycleProgressKind.sownToday => strings.homeCycleSownToday,
    CycleProgressKind.sowingIn => strings.homeCycleSowingIn(progress.days),
    CycleProgressKind.sowingToday => strings.homeCycleSowingToday,
    CycleProgressKind.harvestIn => strings.homeCycleHarvestIn(progress.days),
    CycleProgressKind.harvestToday => strings.homeCycleHarvestToday,
    CycleProgressKind.harvestLate => strings.homeCycleHarvestLate(
      progress.days,
    ),
    CycleProgressKind.noDates => strings.homeCycleDatesMissing,
  };
}

double cycleProgressFraction({
  DateTime? sowingDate,
  DateTime? expectedHarvestDate,
  required DateTime today,
}) {
  final DateTime? sowing = _optionalDateOnly(sowingDate);
  final DateTime? harvest = _optionalDateOnly(expectedHarvestDate);
  if (sowing == null || harvest == null) {
    return 0;
  }
  final int total = harvest.difference(sowing).inDays;
  if (total <= 0) {
    return 0;
  }
  final int elapsed = _dateOnly(today).difference(sowing).inDays;
  if (elapsed <= 0) {
    return 0;
  }
  if (elapsed >= total) {
    return 1;
  }
  return elapsed / total;
}

String firstNameFromFullName(String? fullName, {required String fallback}) {
  if (fullName == null) {
    return fallback;
  }
  final String trimmed = fullName.trim();
  if (trimmed.isEmpty) {
    return fallback;
  }
  final String first = trimmed.split(RegExp(r'\s+')).first;
  return first.toUpperCase();
}

DateTime _dateOnly(DateTime value) {
  return DateTime.utc(value.year, value.month, value.day);
}

DateTime? _optionalDateOnly(DateTime? value) {
  if (value == null) {
    return null;
  }
  return _dateOnly(value);
}
