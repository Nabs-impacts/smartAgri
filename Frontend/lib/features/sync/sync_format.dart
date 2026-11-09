import '../../core/i18n/app_localizations.dart';

String formatLastSync(
  AppLocalizations strings,
  DateTime? lastSyncAt,
  DateTime now,
) {
  if (lastSyncAt == null) {
    return strings.syncNever;
  }
  final Duration difference = now.toUtc().difference(lastSyncAt.toUtc());
  if (difference.isNegative || difference.inMinutes < 1) {
    return strings.syncJustNow;
  }
  if (difference.inMinutes < 60) {
    return strings.syncMinutesAgo(difference.inMinutes);
  }
  if (difference.inHours < 24) {
    return strings.syncHoursAgo(difference.inHours);
  }
  if (difference.inHours < 48) {
    return strings.syncYesterday;
  }
  return strings.syncDaysAgo(difference.inDays);
}
