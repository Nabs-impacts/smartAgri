import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/i18n/app_language.dart';
import '../../../core/i18n/language_controller.dart';
import '../../catalog/data/catalog_repository.dart';
import '../../cycles/domain/activity_type.dart';
import '../../cycles/domain/cycle_status.dart';
import '../domain/home_overview.dart';

const int homeRecentActivitiesLimit = 5;

String homeCropFallbackName(int cropId) => 'Culture $cropId';

final StreamProvider<List<ActiveCycleOverview>> activeCyclesOverviewProvider =
    StreamProvider<List<ActiveCycleOverview>>((Ref ref) {
      final AppDatabase database = ref.watch(appDatabaseProvider);
      final CatalogRepository catalog = ref.watch(catalogRepositoryProvider);
      final AppLanguage language = ref.watch(languageControllerProvider);
      final Map<int, String> names = <int, String>{};
      return database.watchActiveCycleOverview().asyncMap((
        List<ActiveCycleOverviewRow> rows,
      ) async {
        for (final ActiveCycleOverviewRow row in rows) {
          if (names.containsKey(row.cropId)) {
            continue;
          }
          final String? name = await catalog.cultureNameFor(
            row.cropId,
            language: language,
          );
          names[row.cropId] = name == null || name.trim().isEmpty
              ? homeCropFallbackName(row.cropId)
              : name;
        }
        return rows.map((ActiveCycleOverviewRow row) {
          return ActiveCycleOverview(
            cycleId: row.id,
            cropId: row.cropId,
            cropName: names[row.cropId] ?? homeCropFallbackName(row.cropId),
            plotName: row.plotName,
            farmName: row.farmName,
            status: CycleStatus.fromCode(row.status),
            sowingDate: _parseDate(row.sowingDate),
            expectedHarvestDate: _parseDate(row.expectedHarvestDate),
          );
        }).toList();
      });
    });

final StreamProvider<List<RecentActivityOverview>> recentActivitiesProvider =
    StreamProvider<List<RecentActivityOverview>>((Ref ref) {
      final AppDatabase database = ref.watch(appDatabaseProvider);
      final CatalogRepository catalog = ref.watch(catalogRepositoryProvider);
      final AppLanguage language = ref.watch(languageControllerProvider);
      final Map<int, String> names = <int, String>{};
      return database.watchRecentActivities(homeRecentActivitiesLimit).asyncMap(
        (List<RecentActivityOverviewRow> rows) async {
          for (final RecentActivityOverviewRow row in rows) {
            if (names.containsKey(row.cropId)) {
              continue;
            }
            final String? name = await catalog.cultureNameFor(
              row.cropId,
              language: language,
            );
            names[row.cropId] = name == null || name.trim().isEmpty
                ? homeCropFallbackName(row.cropId)
                : name;
          }
          return rows.map((RecentActivityOverviewRow row) {
            return RecentActivityOverview(
              activityId: row.id,
              cycleId: row.cropCycleId,
              type: ActivityType.fromCode(row.type),
              performedOn:
                  _parseDate(row.performedOn) ??
                  DateTime.fromMillisecondsSinceEpoch(0),
              cropName: names[row.cropId] ?? homeCropFallbackName(row.cropId),
              plotName: row.plotName,
            );
          }).toList();
        },
      );
    });

final StreamProvider<bool> hasFarmsProvider = StreamProvider<bool>((Ref ref) {
  return ref.watch(appDatabaseProvider).watchHasFarms();
});

DateTime? _parseDate(String? value) {
  if (value == null || value.trim().isEmpty) {
    return null;
  }
  return DateTime.tryParse(value);
}
