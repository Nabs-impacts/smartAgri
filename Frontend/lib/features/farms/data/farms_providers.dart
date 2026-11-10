import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/network/api_exception.dart';
import '../domain/farm.dart';
import '../domain/plot.dart';
import 'farms_repository.dart';

class FarmsController extends AsyncNotifier<List<Farm>> {
  @override
  Future<List<Farm>> build() async {
    final AppDatabase database = ref.watch(appDatabaseProvider);
    final Stream<List<FarmRow>> stream = database.watchFarms();
    final subscription = stream.listen((List<FarmRow> rows) {
      if (ref.mounted) {
        state = AsyncData<List<Farm>>(rows.map(farmFromRow).toList());
      }
    });
    ref.onDispose(subscription.cancel);
    final List<FarmRow> rows = await stream.first;
    return rows.map(farmFromRow).toList();
  }

  Future<Farm> createFarm(
    String id,
    String name, {
    String? village,
    int? adminAreaId,
    Object? location = unchanged,
  }) async {
    return ref
        .read(farmsRepositoryProvider)
        .createFarm(
          id,
          name,
          village: village,
          adminAreaId: adminAreaId,
          location: location,
        );
  }

  Future<Farm> updateFarm(
    String id, {
    Object? name = unchanged,
    Object? village = unchanged,
    Object? adminAreaId = unchanged,
    Object? location = unchanged,
  }) async {
    return ref
        .read(farmsRepositoryProvider)
        .updateFarm(
          id,
          name: name,
          village: village,
          adminAreaId: adminAreaId,
          location: location,
        );
  }

  Future<void> deleteFarm(String id) async {
    await ref.read(farmsRepositoryProvider).deleteFarm(id);
  }

  Future<void> refresh() async {
    state = await AsyncValue.guard<List<Farm>>(
      ref.read(farmsRepositoryProvider).listFarms,
    );
  }
}

class FarmPlotsController extends AsyncNotifier<List<Plot>> {
  FarmPlotsController(this.farmId);

  final String farmId;

  @override
  Future<List<Plot>> build() async {
    final AppDatabase database = ref.watch(appDatabaseProvider);
    final Stream<List<PlotRow>> stream = database.watchPlots(farmId);
    final subscription = stream.listen((List<PlotRow> rows) {
      if (ref.mounted) {
        state = AsyncData<List<Plot>>(rows.map(plotFromRow).toList());
      }
    });
    ref.onDispose(subscription.cancel);
    final List<PlotRow> rows = await stream.first;
    return rows.map(plotFromRow).toList();
  }

  Future<Plot> createPlot(
    String id,
    String name, {
    double? areaHa,
    SoilType? soilType,
    IrrigationType? irrigation,
    Object? geometry = unchanged,
  }) async {
    return ref
        .read(farmsRepositoryProvider)
        .createPlot(
          farmId,
          id,
          name,
          areaHa: areaHa,
          soilType: soilType,
          irrigation: irrigation,
          geometry: geometry,
        );
  }

  Future<Plot> updatePlot(
    String id, {
    Object? name = unchanged,
    Object? areaHa = unchanged,
    Object? soilType = unchanged,
    Object? irrigation = unchanged,
    Object? geometry = unchanged,
  }) async {
    final Plot plot = await ref
        .read(farmsRepositoryProvider)
        .updatePlot(
          id,
          name: name,
          areaHa: areaHa,
          soilType: soilType,
          irrigation: irrigation,
          geometry: geometry,
        );
    ref.invalidate(plotProvider(id));
    return plot;
  }

  Future<void> deletePlot(String id) async {
    await ref.read(farmsRepositoryProvider).deletePlot(id);
    ref.invalidate(plotProvider(id));
  }

  Future<void> refresh() async {
    state = await AsyncValue.guard<List<Plot>>(
      () => ref.read(farmsRepositoryProvider).listPlots(farmId),
    );
  }
}

class PlotController extends AsyncNotifier<Plot> {
  PlotController(this.plotId);

  final String plotId;

  @override
  Future<Plot> build() async {
    final AppDatabase database = ref.watch(appDatabaseProvider);
    final Stream<PlotRow?> stream = database.watchPlot(plotId);
    final subscription = stream.listen((PlotRow? row) {
      if (ref.mounted) {
        state = _stateFromRow(row);
      }
    });
    ref.onDispose(subscription.cancel);
    final PlotRow? row = await stream.first;
    if (row == null || row.deletedAt != null) {
      throw const ApiException(code: 'NOT_FOUND', message: 'Introuvable');
    }
    return plotFromRow(row);
  }

  AsyncValue<Plot> _stateFromRow(PlotRow? row) {
    if (row == null || row.deletedAt != null) {
      return AsyncError<Plot>(
        const ApiException(code: 'NOT_FOUND', message: 'Introuvable'),
        StackTrace.current,
      );
    }
    return AsyncData<Plot>(plotFromRow(row));
  }
}

final AsyncNotifierProvider<FarmsController, List<Farm>> farmsProvider =
    AsyncNotifierProvider<FarmsController, List<Farm>>(
      FarmsController.new,
      retry: (int retryCount, Object error) => null,
    );

final farmPlotsProvider =
    AsyncNotifierProvider.family<FarmPlotsController, List<Plot>, String>(
      FarmPlotsController.new,
      retry: (int retryCount, Object error) => null,
    );

final plotProvider = AsyncNotifierProvider.family<PlotController, Plot, String>(
  PlotController.new,
  retry: (int retryCount, Object error) => null,
);
