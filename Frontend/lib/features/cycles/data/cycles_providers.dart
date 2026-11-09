import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../domain/activity.dart';
import '../domain/activity_type.dart';
import '../domain/cycle.dart';
import '../domain/cycle_exception.dart';
import '../domain/cycle_status.dart';
import '../domain/harvest.dart';
import '../domain/harvest_quality.dart';
import '../domain/timeline_entry.dart';
import 'cycles_repository.dart';

class CyclesController extends AsyncNotifier<List<Cycle>> {
  CyclesController(this.plotId);

  final String plotId;

  @override
  Future<List<Cycle>> build() async {
    final AppDatabase database = ref.watch(appDatabaseProvider);
    final Stream<List<CropCycleRow>> stream = database.watchCycles(plotId);
    final subscription = stream.listen((List<CropCycleRow> rows) {
      if (ref.mounted) {
        state = AsyncData<List<Cycle>>(rows.map(cycleFromRow).toList());
      }
    });
    ref.onDispose(subscription.cancel);
    final List<CropCycleRow> rows = await stream.first;
    return rows.map(cycleFromRow).toList();
  }

  Future<Cycle> createCycle(
    String id,
    int cropId, {
    String? variety,
    String? season,
    DateTime? sowingDate,
    DateTime? expectedHarvestDate,
    DateTime? harvestDate,
    CycleStatus status = CycleStatus.planned,
    String? notes,
  }) {
    return ref
        .read(cyclesRepositoryProvider)
        .createCycle(
          id,
          plotId,
          cropId,
          variety: variety,
          season: season,
          sowingDate: sowingDate,
          expectedHarvestDate: expectedHarvestDate,
          harvestDate: harvestDate,
          status: status,
          notes: notes,
        );
  }

  Future<Cycle> updateCycle(
    String id, {
    Object? variety = cycleUnchanged,
    Object? season = cycleUnchanged,
    Object? sowingDate = cycleUnchanged,
    Object? expectedHarvestDate = cycleUnchanged,
    Object? harvestDate = cycleUnchanged,
    Object? status = cycleUnchanged,
    Object? notes = cycleUnchanged,
  }) async {
    final Cycle cycle = await ref
        .read(cyclesRepositoryProvider)
        .updateCycle(
          id,
          variety: variety,
          season: season,
          sowingDate: sowingDate,
          expectedHarvestDate: expectedHarvestDate,
          harvestDate: harvestDate,
          status: status,
          notes: notes,
        );
    ref.invalidate(cycleProvider(id));
    return cycle;
  }

  Future<void> deleteCycle(String id) async {
    await ref.read(cyclesRepositoryProvider).deleteCycle(id);
    ref.invalidate(cycleProvider(id));
  }

  Future<void> refresh() async {
    state = await AsyncValue.guard<List<Cycle>>(
      () => ref.read(cyclesRepositoryProvider).listCycles(plotId),
    );
  }
}

class CycleController extends AsyncNotifier<Cycle> {
  CycleController(this.cycleId);

  final String cycleId;

  @override
  Future<Cycle> build() async {
    final AppDatabase database = ref.watch(appDatabaseProvider);
    final Stream<CropCycleRow?> stream = database.watchCycle(cycleId);
    final subscription = stream.listen((CropCycleRow? row) {
      if (ref.mounted) {
        state = _stateFromRow(row);
      }
    });
    ref.onDispose(subscription.cancel);
    final CropCycleRow? row = await stream.first;
    if (row == null) {
      throw const CycleDomainException('not_found', 'Cycle introuvable.');
    }
    return cycleFromRow(row);
  }

  AsyncValue<Cycle> _stateFromRow(CropCycleRow? row) {
    if (row == null) {
      return AsyncError<Cycle>(
        const CycleDomainException('not_found', 'Cycle introuvable.'),
        StackTrace.current,
      );
    }
    return AsyncData<Cycle>(cycleFromRow(row));
  }

  Future<Cycle> updateCycle({
    Object? variety = cycleUnchanged,
    Object? season = cycleUnchanged,
    Object? sowingDate = cycleUnchanged,
    Object? expectedHarvestDate = cycleUnchanged,
    Object? harvestDate = cycleUnchanged,
    Object? status = cycleUnchanged,
    Object? notes = cycleUnchanged,
  }) {
    return ref
        .read(cyclesRepositoryProvider)
        .updateCycle(
          cycleId,
          variety: variety,
          season: season,
          sowingDate: sowingDate,
          expectedHarvestDate: expectedHarvestDate,
          harvestDate: harvestDate,
          status: status,
          notes: notes,
        );
  }

  Future<void> deleteCycle() {
    return ref.read(cyclesRepositoryProvider).deleteCycle(cycleId);
  }
}

class ActivitiesController extends AsyncNotifier<List<Activity>> {
  ActivitiesController(this.cycleId);

  final String cycleId;

  @override
  Future<List<Activity>> build() async {
    final AppDatabase database = ref.watch(appDatabaseProvider);
    final Stream<List<FarmActivityRow>> stream = database.watchActivities(
      cycleId,
    );
    final subscription = stream.listen((List<FarmActivityRow> rows) {
      if (ref.mounted) {
        state = AsyncData<List<Activity>>(rows.map(activityFromRow).toList());
      }
    });
    ref.onDispose(subscription.cancel);
    final List<FarmActivityRow> rows = await stream.first;
    return rows.map(activityFromRow).toList();
  }

  Future<Activity> createActivity(
    String id,
    ActivityType type,
    DateTime performedOn, {
    String? productName,
    double? quantity,
    String? unit,
    int? costXof,
    String? notes,
  }) {
    return ref
        .read(cyclesRepositoryProvider)
        .createActivity(
          id,
          cycleId,
          type,
          performedOn,
          productName: productName,
          quantity: quantity,
          unit: unit,
          costXof: costXof,
          notes: notes,
        );
  }

  Future<Activity> updateActivity(
    String id, {
    Object? type = cycleUnchanged,
    Object? performedOn = cycleUnchanged,
    Object? productName = cycleUnchanged,
    Object? quantity = cycleUnchanged,
    Object? unit = cycleUnchanged,
    Object? costXof = cycleUnchanged,
    Object? notes = cycleUnchanged,
  }) {
    return ref
        .read(cyclesRepositoryProvider)
        .updateActivity(
          id,
          type: type,
          performedOn: performedOn,
          productName: productName,
          quantity: quantity,
          unit: unit,
          costXof: costXof,
          notes: notes,
        );
  }

  Future<void> deleteActivity(String id) {
    return ref.read(cyclesRepositoryProvider).deleteActivity(id);
  }

  Future<void> refresh() async {
    state = await AsyncValue.guard<List<Activity>>(
      () => ref.read(cyclesRepositoryProvider).listActivities(cycleId),
    );
  }
}

class HarvestsController extends AsyncNotifier<List<Harvest>> {
  HarvestsController(this.cycleId);

  final String cycleId;

  @override
  Future<List<Harvest>> build() async {
    final AppDatabase database = ref.watch(appDatabaseProvider);
    final Stream<List<HarvestRow>> stream = database.watchHarvests(cycleId);
    final subscription = stream.listen((List<HarvestRow> rows) {
      if (ref.mounted) {
        state = AsyncData<List<Harvest>>(rows.map(harvestFromRow).toList());
      }
    });
    ref.onDispose(subscription.cancel);
    final List<HarvestRow> rows = await stream.first;
    return rows.map(harvestFromRow).toList();
  }

  Future<Harvest> createHarvest(
    String id,
    DateTime harvestedOn,
    double quantityKg, {
    HarvestQuality? quality,
    double soldKg = 0,
    double? avgPriceXofPerKg,
    bool closeCycle = false,
  }) async {
    final Harvest harvest = await ref
        .read(cyclesRepositoryProvider)
        .createHarvest(
          id,
          cycleId,
          harvestedOn,
          quantityKg,
          quality: quality,
          soldKg: soldKg,
          avgPriceXofPerKg: avgPriceXofPerKg,
          closeCycle: closeCycle,
        );
    if (closeCycle) {
      ref.invalidate(cycleProvider(cycleId));
    }
    return harvest;
  }

  Future<Harvest> updateHarvest(
    String id, {
    Object? harvestedOn = cycleUnchanged,
    Object? quantityKg = cycleUnchanged,
    Object? quality = cycleUnchanged,
    Object? soldKg = cycleUnchanged,
    Object? avgPriceXofPerKg = cycleUnchanged,
  }) {
    return ref
        .read(cyclesRepositoryProvider)
        .updateHarvest(
          id,
          harvestedOn: harvestedOn,
          quantityKg: quantityKg,
          quality: quality,
          soldKg: soldKg,
          avgPriceXofPerKg: avgPriceXofPerKg,
        );
  }

  Future<void> deleteHarvest(String id) {
    return ref.read(cyclesRepositoryProvider).deleteHarvest(id);
  }

  Future<void> refresh() async {
    state = await AsyncValue.guard<List<Harvest>>(
      () => ref.read(cyclesRepositoryProvider).listHarvests(cycleId),
    );
  }
}

class PlotTimelineController extends AsyncNotifier<List<TimelineEntry>> {
  PlotTimelineController(this.plotId);

  final String plotId;

  @override
  Future<List<TimelineEntry>> build() async {
    final Stream<List<TimelineEntry>> stream = ref
        .watch(cyclesRepositoryProvider)
        .watchPlotTimeline(plotId);
    final subscription = stream.listen((List<TimelineEntry> entries) {
      if (ref.mounted) {
        state = AsyncData<List<TimelineEntry>>(entries);
      }
    });
    ref.onDispose(subscription.cancel);
    return stream.first;
  }
}

final cyclesProvider =
    AsyncNotifierProvider.family<CyclesController, List<Cycle>, String>(
      CyclesController.new,
      retry: (int retryCount, Object error) => null,
    );

final cycleProvider =
    AsyncNotifierProvider.family<CycleController, Cycle, String>(
      CycleController.new,
      retry: (int retryCount, Object error) => null,
    );

final activitiesProvider =
    AsyncNotifierProvider.family<ActivitiesController, List<Activity>, String>(
      ActivitiesController.new,
      retry: (int retryCount, Object error) => null,
    );

final harvestsProvider =
    AsyncNotifierProvider.family<HarvestsController, List<Harvest>, String>(
      HarvestsController.new,
      retry: (int retryCount, Object error) => null,
    );

final plotTimelineProvider =
    AsyncNotifierProvider.family<
      PlotTimelineController,
      List<TimelineEntry>,
      String
    >(
      PlotTimelineController.new,
      retry: (int retryCount, Object error) => null,
    );
