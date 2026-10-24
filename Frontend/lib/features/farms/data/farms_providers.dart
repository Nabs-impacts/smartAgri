import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../profile/data/me_repository.dart';
import '../domain/farm.dart';
import '../domain/plot.dart';
import 'farms_repository.dart';

class FarmsController extends AsyncNotifier<List<Farm>> {
  @override
  Future<List<Farm>> build() {
    return ref.watch(farmsRepositoryProvider).listFarms();
  }

  Future<Farm> createFarm(
    String id,
    String name, {
    String? village,
    int? adminAreaId,
  }) async {
    final Farm farm = await ref
        .read(farmsRepositoryProvider)
        .createFarm(id, name, village: village, adminAreaId: adminAreaId);
    await refresh();
    return farm;
  }

  Future<Farm> updateFarm(
    String id, {
    Object? name = unchanged,
    Object? village = unchanged,
    Object? adminAreaId = unchanged,
  }) async {
    final Farm farm = await ref
        .read(farmsRepositoryProvider)
        .updateFarm(id, name: name, village: village, adminAreaId: adminAreaId);
    await refresh();
    return farm;
  }

  Future<void> deleteFarm(String id) async {
    await ref.read(farmsRepositoryProvider).deleteFarm(id);
    await refresh();
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
  Future<List<Plot>> build() {
    return ref.watch(farmsRepositoryProvider).listPlots(farmId);
  }

  Future<Plot> createPlot(
    String id,
    String name, {
    double? areaHa,
    SoilType? soilType,
    IrrigationType? irrigation,
  }) async {
    final Plot plot = await ref
        .read(farmsRepositoryProvider)
        .createPlot(
          farmId,
          id,
          name,
          areaHa: areaHa,
          soilType: soilType,
          irrigation: irrigation,
        );
    await refresh();
    await ref.read(meProvider.notifier).refresh();
    return plot;
  }

  Future<Plot> updatePlot(
    String id, {
    Object? name = unchanged,
    Object? areaHa = unchanged,
    Object? soilType = unchanged,
    Object? irrigation = unchanged,
  }) async {
    final Plot plot = await ref
        .read(farmsRepositoryProvider)
        .updatePlot(
          id,
          name: name,
          areaHa: areaHa,
          soilType: soilType,
          irrigation: irrigation,
        );
    await refresh();
    ref.invalidate(plotProvider(id));
    return plot;
  }

  Future<void> deletePlot(String id) async {
    await ref.read(farmsRepositoryProvider).deletePlot(id);
    await refresh();
    ref.invalidate(plotProvider(id));
    await ref.read(meProvider.notifier).refresh();
  }

  Future<void> refresh() async {
    state = await AsyncValue.guard<List<Plot>>(
      () => ref.read(farmsRepositoryProvider).listPlots(farmId),
    );
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

final plotProvider = FutureProvider.family<Plot, String>(
  (Ref ref, String id) => ref.watch(farmsRepositoryProvider).getPlot(id),
  retry: (int retryCount, Object error) => null,
);
