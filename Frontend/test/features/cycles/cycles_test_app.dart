import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:smartagri/core/database/app_database.dart';
import 'package:smartagri/core/sync/outbox.dart';
import 'package:smartagri/features/catalog/data/catalog_repository.dart';
import 'package:smartagri/features/catalog/domain/crop.dart';
import 'package:smartagri/features/cycles/data/cycles_repository.dart';
import 'package:smartagri/features/cycles/domain/cycle.dart';
import 'package:smartagri/features/cycles/domain/cycle_exception.dart';
import 'package:smartagri/features/cycles/domain/cycle_summary.dart';
import 'package:smartagri/features/cycles/presentation/activity_form_page.dart';
import 'package:smartagri/features/cycles/presentation/cycle_detail_page.dart';
import 'package:smartagri/features/cycles/presentation/cycle_form_page.dart';
import 'package:smartagri/features/cycles/presentation/harvest_form_page.dart';
import 'package:smartagri/features/cycles/presentation/plot_timeline_page.dart';
import 'package:smartagri/features/farms/presentation/plot_detail_page.dart';

import '../app_test_utils.dart';

class CyclesHarness {
  CyclesHarness({
    required this.container,
    required this.database,
    required this.outbox,
    required this.repository,
    required this.router,
    required this.me,
  });

  final ProviderContainer container;
  final AppDatabase database;
  final Outbox outbox;
  final FakeCyclesRepository repository;
  final GoRouter router;
  final FakeMeRepository me;
}

class FakeCyclesRepository extends LocalCyclesRepository {
  FakeCyclesRepository({
    required super.database,
    required super.outbox,
    this.comparison,
    this.comparisonError,
    this.updateError,
  });

  CycleComparison? comparison;
  Object? comparisonError;
  CycleDomainException? updateError;
  int comparisonCalls = 0;

  @override
  Future<CycleComparison?> fetchComparison(String cycleId) async {
    comparisonCalls++;
    if (comparisonError != null) {
      throw comparisonError!;
    }
    return comparison;
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
  }) {
    if (updateError != null) {
      throw updateError!;
    }
    return super.updateCycle(
      id,
      variety: variety,
      season: season,
      sowingDate: sowingDate,
      expectedHarvestDate: expectedHarvestDate,
      harvestDate: harvestDate,
      status: status,
      notes: notes,
    );
  }
}

class _HomePage extends StatelessWidget {
  const _HomePage();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Text('home'));
  }
}

GoRouter buildCyclesRouter() {
  return GoRouter(
    initialLocation: '/plots/plot-1',
    routes: <RouteBase>[
      GoRoute(path: '/home', builder: (_, _) => const _HomePage()),
      GoRoute(
        path: '/plots/:plotId',
        builder: (_, GoRouterState state) =>
            PlotDetailPage(plotId: state.pathParameters['plotId'] ?? ''),
      ),
      GoRoute(
        path: '/plots/:plotId/cycles/new',
        builder: (_, GoRouterState state) =>
            CycleFormPage(plotId: state.pathParameters['plotId']),
      ),
      GoRoute(
        path: '/plots/:plotId/timeline',
        builder: (_, GoRouterState state) =>
            PlotTimelinePage(plotId: state.pathParameters['plotId'] ?? ''),
      ),
      GoRoute(
        path: '/cycles/:cycleId/edit',
        builder: (_, GoRouterState state) =>
            CycleFormPage(cycleId: state.pathParameters['cycleId']),
      ),
      GoRoute(
        path: '/cycles/:cycleId/activities/new',
        builder: (_, GoRouterState state) =>
            ActivityFormPage(cycleId: state.pathParameters['cycleId'] ?? ''),
      ),
      GoRoute(
        path: '/cycles/:cycleId/activities/:activityId/edit',
        builder: (_, GoRouterState state) => ActivityFormPage(
          cycleId: state.pathParameters['cycleId'] ?? '',
          activityId: state.pathParameters['activityId'],
        ),
      ),
      GoRoute(
        path: '/cycles/:cycleId/harvests/new',
        builder: (_, GoRouterState state) =>
            HarvestFormPage(cycleId: state.pathParameters['cycleId'] ?? ''),
      ),
      GoRoute(
        path: '/cycles/:cycleId/harvests/:harvestId/edit',
        builder: (_, GoRouterState state) => HarvestFormPage(
          cycleId: state.pathParameters['cycleId'] ?? '',
          harvestId: state.pathParameters['harvestId'],
        ),
      ),
      GoRoute(
        path: '/cycles/:cycleId',
        builder: (_, GoRouterState state) =>
            CycleDetailPage(cycleId: state.pathParameters['cycleId'] ?? ''),
      ),
    ],
  );
}

String cropsCache(List<Crop> crops) {
  return jsonEncode(<String, dynamic>{
    'cached_at': '2026-11-08T10:00:00Z',
    'items': crops.map((Crop crop) => crop.toJson()).toList(),
  });
}

Future<CyclesHarness> pumpCyclesApp(
  WidgetTester tester, {
  String initialLocation = '/plots/plot-1',
  AppDatabase? database,
  List<Crop> crops = sampleCrops,
  CycleComparison? comparison,
  Object? comparisonError,
  CycleDomainException? updateError,
  Future<void> Function(AppDatabase database)? seed,
}) async {
  final AppDatabase appDatabase = database ?? inMemoryAppDatabase();
  if (database == null) {
    addTearDown(appDatabase.close);
  }
  if (seed != null) {
    await seed(appDatabase);
  }
  final Outbox outbox = Outbox(appDatabase);
  addTearDown(outbox.dispose);
  final FakeCyclesRepository repository = FakeCyclesRepository(
    database: appDatabase,
    outbox: outbox,
    comparison: comparison,
    comparisonError: comparisonError,
    updateError: updateError,
  );
  final FakeMeRepository me = FakeMeRepository(sampleMeData());
  final ProviderContainer container = await buildTestContainer(
    meRepository: me,
    database: appDatabase,
    cyclesRepository: repository,
    crops: crops,
    initialPreferences: <String, Object>{
      CatalogRepository.cropsKey: cropsCache(crops),
    },
  );
  final GoRouter router = buildCyclesRouter();
  tester.view.physicalSize = const Size(800, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(testRouterApp(container, router));
  await tester.pumpAndSettle();
  if (initialLocation != '/plots/plot-1') {
    router.push(initialLocation);
    await tester.pumpAndSettle();
  }
  return CyclesHarness(
    container: container,
    database: appDatabase,
    outbox: outbox,
    repository: repository,
    router: router,
    me: me,
  );
}

Future<void> seedFarmAndPlot(AppDatabase database) async {
  final DateTime serverAt = DateTime.utc(2026, 11, 8, 9);
  await database.upsertFarm('farm-1', 'Ferme du fleuve', updatedAt: serverAt);
  await database.upsertPlot(
    'plot-1',
    'farm-1',
    'Parcelle nord',
    areaHa: 2.5,
    updatedAt: serverAt,
  );
}

Future<void> seedCycle(
  AppDatabase database, {
  String id = 'c1',
  String plotId = 'plot-1',
  int cropId = 1,
  String status = 'planned',
  String? variety = 'Variété locale',
  String? season = 'Saison des pluies',
  String? sowingDate = '2026-06-01',
  String? expectedHarvestDate = '2026-10-01',
  String? harvestDate,
  String? notes,
  DateTime? updatedAt,
}) {
  return database.upsertCycle(
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
    updatedAt: updatedAt,
  );
}

Future<void> seedActivity(
  AppDatabase database, {
  String id = 'a1',
  String cycleId = 'c1',
  String type = 'fertilizing',
  String performedOn = '2026-06-10',
  String? productName = 'Urée',
  double? quantity = 2.5,
  String? unit = 'kg',
  int? costXof = 5000,
  String? notes,
}) {
  return database.upsertActivity(
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

Future<void> seedHarvest(
  AppDatabase database, {
  String id = 'h1',
  String cycleId = 'c1',
  String harvestedOn = '2026-10-05',
  double quantityKg = 100,
  String? quality = 'A',
  double soldKg = 80,
  double? avgPriceXofPerKg = 250,
}) {
  return database.upsertHarvest(
    id,
    cycleId,
    harvestedOn,
    quantityKg,
    quality: quality,
    soldKg: soldKg,
    avgPriceXofPerKg: avgPriceXofPerKg,
  );
}
