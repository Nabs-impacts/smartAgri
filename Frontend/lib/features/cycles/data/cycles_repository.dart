import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/network/network_providers.dart';
import '../../../core/sync/outbox.dart';
import '../domain/activity.dart';
import '../domain/activity_type.dart';
import '../domain/cycle.dart';
import '../domain/cycle_calculations.dart';
import '../domain/cycle_exception.dart';
import '../domain/cycle_status.dart';
import '../domain/cycle_summary.dart';
import '../domain/date_only.dart';
import '../domain/harvest.dart';
import '../domain/harvest_quality.dart';
import '../domain/timeline_entry.dart';

const Object cycleUnchanged = Object();

abstract interface class CyclesRepository {
  Future<List<Cycle>> listCycles(String plotId);

  Future<Cycle> getCycle(String id);

  Future<Cycle> createCycle(
    String id,
    String plotId,
    int cropId, {
    String? variety,
    String? season,
    DateTime? sowingDate,
    DateTime? expectedHarvestDate,
    DateTime? harvestDate,
    CycleStatus status,
    String? notes,
  });

  Future<Cycle> updateCycle(
    String id, {
    Object? variety = cycleUnchanged,
    Object? season = cycleUnchanged,
    Object? sowingDate = cycleUnchanged,
    Object? expectedHarvestDate = cycleUnchanged,
    Object? harvestDate = cycleUnchanged,
    Object? status = cycleUnchanged,
    Object? notes = cycleUnchanged,
  });

  Future<void> deleteCycle(String id);

  Future<List<Activity>> listActivities(String cycleId);

  Future<Activity> createActivity(
    String id,
    String cycleId,
    ActivityType type,
    DateTime performedOn, {
    String? productName,
    double? quantity,
    String? unit,
    int? costXof,
    String? notes,
  });

  Future<Activity> updateActivity(
    String id, {
    Object? type = cycleUnchanged,
    Object? performedOn = cycleUnchanged,
    Object? productName = cycleUnchanged,
    Object? quantity = cycleUnchanged,
    Object? unit = cycleUnchanged,
    Object? costXof = cycleUnchanged,
    Object? notes = cycleUnchanged,
  });

  Future<void> deleteActivity(String id);

  Future<List<Harvest>> listHarvests(String cycleId);

  Future<Harvest> createHarvest(
    String id,
    String cycleId,
    DateTime harvestedOn,
    double quantityKg, {
    HarvestQuality? quality,
    double soldKg,
    double? avgPriceXofPerKg,
    bool closeCycle,
  });

  Future<Harvest> updateHarvest(
    String id, {
    Object? harvestedOn = cycleUnchanged,
    Object? quantityKg = cycleUnchanged,
    Object? quality = cycleUnchanged,
    Object? soldKg = cycleUnchanged,
    Object? avgPriceXofPerKg = cycleUnchanged,
  });

  Future<void> deleteHarvest(String id);

  Stream<List<TimelineEntry>> watchPlotTimeline(String plotId);

  Future<CycleComparison?> fetchComparison(String cycleId);
}

Cycle cycleFromRow(CropCycleRow row) {
  return Cycle(
    id: row.id,
    plotId: row.plotId,
    cropId: row.cropId,
    variety: row.variety,
    season: row.season,
    sowingDate: parseDateOnly(row.sowingDate),
    expectedHarvestDate: parseDateOnly(row.expectedHarvestDate),
    harvestDate: parseDateOnly(row.harvestDate),
    status: CycleStatus.fromCode(row.status),
    notes: row.notes,
  );
}

Activity activityFromRow(FarmActivityRow row) {
  return Activity(
    id: row.id,
    cycleId: row.cropCycleId,
    type: ActivityType.fromCode(row.type),
    performedOn: parseDateOnly(row.performedOn) ?? DateTime.utc(1970),
    productName: row.productName,
    quantity: row.quantity,
    unit: row.unit,
    costXof: row.costXof,
    notes: row.notes,
  );
}

Harvest harvestFromRow(HarvestRow row) {
  return Harvest(
    id: row.id,
    cycleId: row.cropCycleId,
    harvestedOn: parseDateOnly(row.harvestedOn) ?? DateTime.utc(1970),
    quantityKg: row.quantityKg,
    quality: HarvestQuality.fromCode(row.quality),
    soldKg: row.soldKg,
    avgPriceXofPerKg: row.avgPriceXofPerKg,
  );
}

class LocalCyclesRepository implements CyclesRepository {
  LocalCyclesRepository({
    required this.database,
    required this.outbox,
    this.dio,
  });

  final AppDatabase database;
  final Outbox outbox;
  final Dio? dio;

  @override
  Future<List<Cycle>> listCycles(String plotId) async {
    final List<CropCycleRow> rows = await database.watchCycles(plotId).first;
    return rows.map(cycleFromRow).toList();
  }

  @override
  Future<Cycle> getCycle(String id) async {
    final CropCycleRow? row = await database.getCycle(id);
    if (row == null || row.deletedAt != null) {
      throw const CycleDomainException('not_found', 'Cycle introuvable.');
    }
    return cycleFromRow(row);
  }

  @override
  Future<Cycle> createCycle(
    String id,
    String plotId,
    int cropId, {
    String? variety,
    String? season,
    DateTime? sowingDate,
    DateTime? expectedHarvestDate,
    DateTime? harvestDate,
    CycleStatus status = CycleStatus.planned,
    String? notes,
  }) async {
    await database.transaction(() async {
      await database.upsertCycle(
        id,
        plotId,
        cropId,
        variety: variety,
        season: season,
        sowingDate: formatDateOnly(sowingDate),
        expectedHarvestDate: formatDateOnly(expectedHarvestDate),
        harvestDate: formatDateOnly(harvestDate),
        status: status.code,
        notes: notes,
      );
      final CropCycleRow? row = await database.getCycle(id);
      await outbox.enqueueUpsert('crop_cycle', id, _cycleData(row!));
    });
    final CropCycleRow? row = await database.getCycle(id);
    return cycleFromRow(row!);
  }

  @override
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
    final CropCycleRow current = await _requireCycle(id);
    final CycleStatus currentStatus = CycleStatus.fromCode(current.status);
    final CycleStatus nextStatus = identical(status, cycleUnchanged)
        ? currentStatus
        : status as CycleStatus;
    if (!currentStatus.canTransitionTo(nextStatus)) {
      throw const CycleDomainException(
        'invalid_transition',
        'Transition de statut non autorisée.',
      );
    }
    final String? nextVariety = identical(variety, cycleUnchanged)
        ? current.variety
        : variety as String?;
    final String? nextSeason = identical(season, cycleUnchanged)
        ? current.season
        : season as String?;
    final String? nextSowingDate = identical(sowingDate, cycleUnchanged)
        ? current.sowingDate
        : formatDateOnly(sowingDate as DateTime?);
    final String? nextExpectedHarvestDate =
        identical(expectedHarvestDate, cycleUnchanged)
        ? current.expectedHarvestDate
        : formatDateOnly(expectedHarvestDate as DateTime?);
    final String? nextHarvestDate = identical(harvestDate, cycleUnchanged)
        ? current.harvestDate
        : formatDateOnly(harvestDate as DateTime?);
    final String? nextNotes = identical(notes, cycleUnchanged)
        ? current.notes
        : notes as String?;
    await database.transaction(() async {
      await database.upsertCycle(
        id,
        current.plotId,
        current.cropId,
        variety: nextVariety,
        season: nextSeason,
        sowingDate: nextSowingDate,
        expectedHarvestDate: nextExpectedHarvestDate,
        harvestDate: nextHarvestDate,
        status: nextStatus.code,
        notes: nextNotes,
        updatedAt: current.updatedAt,
        deletedAt: current.deletedAt,
      );
      final CropCycleRow? row = await database.getCycle(id);
      await outbox.enqueueUpsert('crop_cycle', id, _cycleData(row!));
    });
    final CropCycleRow? row = await database.getCycle(id);
    return cycleFromRow(row!);
  }

  @override
  Future<void> deleteCycle(String id) async {
    final List<FarmActivityRow> activities = await database.getActiveActivities(
      id,
    );
    final List<HarvestRow> harvests = await database.getActiveHarvests(id);
    await database.transaction(() async {
      for (final HarvestRow harvest in harvests) {
        await outbox.enqueueDelete('harvest', harvest.id);
      }
      for (final FarmActivityRow activity in activities) {
        await outbox.enqueueDelete('farm_activity', activity.id);
      }
      await database.softDeleteCycle(id);
      await outbox.enqueueDelete('crop_cycle', id);
    });
  }

  @override
  Future<List<Activity>> listActivities(String cycleId) async {
    final List<FarmActivityRow> rows = await database
        .watchActivities(cycleId)
        .first;
    return rows.map(activityFromRow).toList();
  }

  @override
  Future<Activity> createActivity(
    String id,
    String cycleId,
    ActivityType type,
    DateTime performedOn, {
    String? productName,
    double? quantity,
    String? unit,
    int? costXof,
    String? notes,
  }) async {
    await _requireCycle(cycleId);
    await database.transaction(() async {
      await database.upsertActivity(
        id,
        cycleId,
        type.code,
        formatRequiredDate(performedOn),
        productName: productName,
        quantity: quantity,
        unit: unit,
        costXof: costXof,
        notes: notes,
      );
      final FarmActivityRow? row = await database.getActivity(id);
      await outbox.enqueueUpsert('farm_activity', id, _activityData(row!));
    });
    final FarmActivityRow? row = await database.getActivity(id);
    return activityFromRow(row!);
  }

  @override
  Future<Activity> updateActivity(
    String id, {
    Object? type = cycleUnchanged,
    Object? performedOn = cycleUnchanged,
    Object? productName = cycleUnchanged,
    Object? quantity = cycleUnchanged,
    Object? unit = cycleUnchanged,
    Object? costXof = cycleUnchanged,
    Object? notes = cycleUnchanged,
  }) async {
    final FarmActivityRow? current = await database.getActivity(id);
    if (current == null || current.deletedAt != null) {
      throw const CycleDomainException('not_found', 'Activité introuvable.');
    }
    final ActivityType nextType = identical(type, cycleUnchanged)
        ? ActivityType.fromCode(current.type)
        : type as ActivityType;
    final String nextPerformedOn = identical(performedOn, cycleUnchanged)
        ? current.performedOn
        : formatRequiredDate(performedOn as DateTime);
    final String? nextProductName = identical(productName, cycleUnchanged)
        ? current.productName
        : productName as String?;
    final double? nextQuantity = identical(quantity, cycleUnchanged)
        ? current.quantity
        : _doubleOrNull(quantity);
    final String? nextUnit = identical(unit, cycleUnchanged)
        ? current.unit
        : unit as String?;
    final int? nextCostXof = identical(costXof, cycleUnchanged)
        ? current.costXof
        : _intOrNull(costXof);
    final String? nextNotes = identical(notes, cycleUnchanged)
        ? current.notes
        : notes as String?;
    await database.transaction(() async {
      await database.upsertActivity(
        id,
        current.cropCycleId,
        nextType.code,
        nextPerformedOn,
        productName: nextProductName,
        quantity: nextQuantity,
        unit: nextUnit,
        costXof: nextCostXof,
        notes: nextNotes,
        updatedAt: current.updatedAt,
        deletedAt: current.deletedAt,
      );
      final FarmActivityRow? row = await database.getActivity(id);
      await outbox.enqueueUpsert('farm_activity', id, _activityData(row!));
    });
    final FarmActivityRow? row = await database.getActivity(id);
    return activityFromRow(row!);
  }

  @override
  Future<void> deleteActivity(String id) async {
    await database.transaction(() async {
      await database.softDeleteActivity(id);
      await outbox.enqueueDelete('farm_activity', id);
    });
  }

  @override
  Future<List<Harvest>> listHarvests(String cycleId) async {
    final List<HarvestRow> rows = await database.watchHarvests(cycleId).first;
    return rows.map(harvestFromRow).toList();
  }

  @override
  Future<Harvest> createHarvest(
    String id,
    String cycleId,
    DateTime harvestedOn,
    double quantityKg, {
    HarvestQuality? quality,
    double soldKg = 0,
    double? avgPriceXofPerKg,
    bool closeCycle = false,
  }) async {
    final CropCycleRow current = await _requireCycle(cycleId);
    if (closeCycle &&
        CycleStatus.fromCode(current.status) != CycleStatus.growing) {
      throw const CycleDomainException(
        'invalid_transition',
        'Transition de statut non autorisée.',
      );
    }
    final String harvestedOnText = formatRequiredDate(harvestedOn);
    await database.transaction(() async {
      if (closeCycle) {
        await database.upsertCycle(
          cycleId,
          current.plotId,
          current.cropId,
          variety: current.variety,
          season: current.season,
          sowingDate: current.sowingDate,
          expectedHarvestDate: current.expectedHarvestDate,
          harvestDate: harvestedOnText,
          status: CycleStatus.harvested.code,
          notes: current.notes,
          updatedAt: current.updatedAt,
          deletedAt: current.deletedAt,
        );
        final CropCycleRow? cycleRow = await database.getCycle(cycleId);
        await outbox.enqueueUpsert(
          'crop_cycle',
          cycleId,
          _cycleData(cycleRow!),
        );
      }
      await database.upsertHarvest(
        id,
        cycleId,
        harvestedOnText,
        quantityKg,
        quality: quality?.code,
        soldKg: soldKg,
        avgPriceXofPerKg: avgPriceXofPerKg,
      );
      final HarvestRow? row = await database.getHarvest(id);
      await outbox.enqueueUpsert('harvest', id, _harvestData(row!));
    });
    final HarvestRow? row = await database.getHarvest(id);
    return harvestFromRow(row!);
  }

  @override
  Future<Harvest> updateHarvest(
    String id, {
    Object? harvestedOn = cycleUnchanged,
    Object? quantityKg = cycleUnchanged,
    Object? quality = cycleUnchanged,
    Object? soldKg = cycleUnchanged,
    Object? avgPriceXofPerKg = cycleUnchanged,
  }) async {
    final HarvestRow? current = await database.getHarvest(id);
    if (current == null || current.deletedAt != null) {
      throw const CycleDomainException('not_found', 'Récolte introuvable.');
    }
    final String nextHarvestedOn = identical(harvestedOn, cycleUnchanged)
        ? current.harvestedOn
        : formatRequiredDate(harvestedOn as DateTime);
    final double nextQuantityKg = identical(quantityKg, cycleUnchanged)
        ? current.quantityKg
        : _doubleOrNull(quantityKg) ?? 0;
    final String? nextQuality = identical(quality, cycleUnchanged)
        ? current.quality
        : (quality as HarvestQuality?)?.code;
    final double nextSoldKg = identical(soldKg, cycleUnchanged)
        ? current.soldKg
        : _doubleOrNull(soldKg) ?? 0;
    final double? nextAvgPrice = identical(avgPriceXofPerKg, cycleUnchanged)
        ? current.avgPriceXofPerKg
        : _doubleOrNull(avgPriceXofPerKg);
    await database.transaction(() async {
      await database.upsertHarvest(
        id,
        current.cropCycleId,
        nextHarvestedOn,
        nextQuantityKg,
        quality: nextQuality,
        soldKg: nextSoldKg,
        avgPriceXofPerKg: nextAvgPrice,
        updatedAt: current.updatedAt,
        deletedAt: current.deletedAt,
      );
      final HarvestRow? row = await database.getHarvest(id);
      await outbox.enqueueUpsert('harvest', id, _harvestData(row!));
    });
    final HarvestRow? row = await database.getHarvest(id);
    return harvestFromRow(row!);
  }

  @override
  Future<void> deleteHarvest(String id) async {
    await database.transaction(() async {
      await database.softDeleteHarvest(id);
      await outbox.enqueueDelete('harvest', id);
    });
  }

  @override
  Stream<List<TimelineEntry>> watchPlotTimeline(String plotId) {
    late StreamController<List<TimelineEntry>> controller;
    late StreamSubscription<List<FarmActivityRow>> activitySubscription;
    late StreamSubscription<List<HarvestRow>> harvestSubscription;
    List<Activity>? activities;
    List<Harvest>? harvests;

    void emit() {
      if (activities != null && harvests != null) {
        controller.add(mergeTimeline(activities!, harvests!));
      }
    }

    controller = StreamController<List<TimelineEntry>>(
      onListen: () {
        activitySubscription = database.watchPlotActivities(plotId).listen((
          List<FarmActivityRow> rows,
        ) {
          activities = rows.map(activityFromRow).toList();
          emit();
        });
        harvestSubscription = database.watchPlotHarvests(plotId).listen((
          List<HarvestRow> rows,
        ) {
          harvests = rows.map(harvestFromRow).toList();
          emit();
        });
      },
      onCancel: () async {
        await activitySubscription.cancel();
        await harvestSubscription.cancel();
      },
    );
    return controller.stream;
  }

  @override
  Future<CycleComparison?> fetchComparison(String cycleId) async {
    final Dio? client = dio;
    if (client == null) {
      return null;
    }
    if (!await database.hasServerVersion('crop_cycle', cycleId)) {
      return null;
    }
    try {
      final Response<dynamic> response = await client.get<dynamic>(
        '/cycles/$cycleId/summary',
      );
      final Object? data = response.data;
      if (data is! Map) {
        return null;
      }
      final Object? comparison = data['comparison'];
      if (comparison is! Map) {
        return null;
      }
      return CycleComparison(
        sampleSize: _intOrNull(comparison['sample_size']) ?? 0,
        averageYieldKgPerHa: _doubleOrNull(
          comparison['average_yield_kg_per_ha'],
        ),
      );
    } catch (_) {
      return null;
    }
  }

  Future<CropCycleRow> _requireCycle(String id) async {
    final CropCycleRow? row = await database.getCycle(id);
    if (row == null || row.deletedAt != null) {
      throw const CycleDomainException('not_found', 'Cycle introuvable.');
    }
    return row;
  }

  Map<String, dynamic> _cycleData(CropCycleRow row) {
    return <String, dynamic>{
      'plot_id': row.plotId,
      'crop_id': row.cropId,
      'variety': row.variety,
      'season': row.season,
      'sowing_date': row.sowingDate,
      'expected_harvest_date': row.expectedHarvestDate,
      'harvest_date': row.harvestDate,
      'status': row.status,
      'notes': row.notes,
    };
  }

  Map<String, dynamic> _activityData(FarmActivityRow row) {
    return <String, dynamic>{
      'crop_cycle_id': row.cropCycleId,
      'type': row.type,
      'performed_on': row.performedOn,
      'product_name': row.productName,
      'quantity': row.quantity,
      'unit': row.unit,
      'cost_xof': row.costXof,
      'notes': row.notes,
    };
  }

  Map<String, dynamic> _harvestData(HarvestRow row) {
    return <String, dynamic>{
      'crop_cycle_id': row.cropCycleId,
      'harvested_on': row.harvestedOn,
      'quantity_kg': row.quantityKg,
      'quality': row.quality,
      'sold_kg': row.soldKg,
      'avg_price_xof_per_kg': row.avgPriceXofPerKg,
    };
  }
}

double? _doubleOrNull(Object? value) {
  if (value is num) {
    return value.toDouble();
  }
  if (value is String) {
    return double.tryParse(value.replaceAll(',', '.'));
  }
  return value as double?;
}

int? _intOrNull(Object? value) {
  if (value is num) {
    return value.toInt();
  }
  if (value is String) {
    return int.tryParse(value);
  }
  return value as int?;
}

final Provider<CyclesRepository> cyclesRepositoryProvider =
    Provider<CyclesRepository>((Ref ref) {
      return LocalCyclesRepository(
        database: ref.watch(appDatabaseProvider),
        outbox: ref.watch(outboxProvider),
        dio: ref.watch(apiClientProvider),
      );
    });
