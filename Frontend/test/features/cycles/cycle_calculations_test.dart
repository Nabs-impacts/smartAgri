import 'package:flutter_test/flutter_test.dart';
import 'package:smartagri/features/cycles/domain/activity.dart';
import 'package:smartagri/features/cycles/domain/activity_type.dart';
import 'package:smartagri/features/cycles/domain/cycle.dart';
import 'package:smartagri/features/cycles/domain/cycle_calculations.dart';
import 'package:smartagri/features/cycles/domain/cycle_status.dart';
import 'package:smartagri/features/cycles/domain/cycle_summary.dart';
import 'package:smartagri/features/cycles/domain/harvest.dart';
import 'package:smartagri/features/cycles/domain/timeline_entry.dart';

Cycle sampleCycle() {
  return const Cycle(
    id: 'c1',
    plotId: 'p1',
    cropId: 1,
    status: CycleStatus.growing,
  );
}

Activity activity(String id, String date, {int? cost, double? quantity}) {
  return Activity(
    id: id,
    cycleId: 'c1',
    type: ActivityType.other,
    performedOn: DateTime.parse(date),
    quantity: quantity,
    costXof: cost,
  );
}

Harvest harvest(
  String id,
  String date, {
  double quantityKg = 0,
  double soldKg = 0,
  double? price,
}) {
  return Harvest(
    id: id,
    cycleId: 'c1',
    harvestedOn: DateTime.parse(date),
    quantityKg: quantityKg,
    soldKg: soldKg,
    avgPriceXofPerKg: price,
  );
}

void main() {
  test('computes yield cost revenue and margin for a normal cycle', () {
    final CycleSummary summary = computeSummary(
      sampleCycle(),
      2,
      <Activity>[activity('a1', '2026-05-01', cost: 5000)],
      <Harvest>[
        harvest('h1', '2026-09-01', quantityKg: 100, soldKg: 80, price: 250),
      ],
    );

    expect(summary.areaHa, 2);
    expect(summary.totalKg, 100);
    expect(summary.yieldKgPerHa, 50);
    expect(summary.totalCostXof, 5000);
    expect(summary.revenueXof, 20000);
    expect(summary.marginXof, 15000);
  });

  test('returns zero yield without harvest and keeps costs', () {
    final CycleSummary summary = computeSummary(sampleCycle(), 2, <Activity>[
      activity('a1', '2026-05-01', cost: 3000),
    ], <Harvest>[]);

    expect(summary.totalKg, 0);
    expect(summary.yieldKgPerHa, 0);
    expect(summary.totalCostXof, 3000);
    expect(summary.revenueXof, 0);
    expect(summary.marginXof, -3000);
  });

  test('ignores harvests without a price in the revenue', () {
    final CycleSummary summary = computeSummary(
      sampleCycle(),
      4,
      <Activity>[],
      <Harvest>[
        harvest('h1', '2026-09-01', quantityKg: 40, soldKg: 40),
        harvest('h2', '2026-09-02', quantityKg: 60, soldKg: 30, price: 100),
      ],
    );

    expect(summary.totalKg, 100);
    expect(summary.yieldKgPerHa, 25);
    expect(summary.revenueXof, 3000);
    expect(summary.marginXof, 3000);
    expect(summary.totalCostXof, 0);
  });

  test('treats a null or zero area as an unknown yield', () {
    final CycleSummary nullArea = computeSummary(
      sampleCycle(),
      null,
      <Activity>[],
      <Harvest>[harvest('h1', '2026-09-01', quantityKg: 10)],
    );
    final CycleSummary zeroArea = computeSummary(
      sampleCycle(),
      0,
      <Activity>[],
      <Harvest>[harvest('h1', '2026-09-01', quantityKg: 10)],
    );

    expect(nullArea.areaHa, isNull);
    expect(nullArea.yieldKgPerHa, isNull);
    expect(zeroArea.areaHa, 0);
    expect(zeroArea.yieldKgPerHa, isNull);
  });

  test('ignores null costs and rounds the yield to one decimal', () {
    final CycleSummary summary = computeSummary(
      sampleCycle(),
      3,
      <Activity>[
        activity('a1', '2026-05-01'),
        activity('a2', '2026-05-02', cost: 1000),
      ],
      <Harvest>[harvest('h1', '2026-09-01', quantityKg: 100)],
    );

    expect(summary.totalCostXof, 1000);
    expect(summary.yieldKgPerHa, 33.3);
  });

  test('merges and sorts the timeline by date then id descending', () {
    final List<TimelineEntry> entries = mergeTimeline(
      <Activity>[
        activity('a1', '2026-05-01'),
        activity('a2', '2026-05-01'),
        activity('a3', '2026-06-01'),
      ],
      <Harvest>[harvest('h1', '2026-09-01'), harvest('h2', '2026-05-01')],
    );

    expect(entries.map((TimelineEntry entry) => entry.id), <String>[
      'h1',
      'a3',
      'h2',
      'a2',
      'a1',
    ]);
    expect(entries.first, isA<HarvestTimelineEntry>());
    expect(entries[1], isA<ActivityTimelineEntry>());
  });
}
