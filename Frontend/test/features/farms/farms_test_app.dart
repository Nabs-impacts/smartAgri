import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:smartagri/core/database/app_database.dart';
import 'package:smartagri/core/sync/sync_providers.dart';
import 'package:smartagri/core/sync/sync_service.dart';
import 'package:smartagri/features/farms/domain/farm.dart';
import 'package:smartagri/features/farms/domain/plot.dart';
import 'package:smartagri/features/farms/presentation/farm_detail_page.dart';
import 'package:smartagri/features/farms/presentation/farm_form_page.dart';
import 'package:smartagri/features/farms/presentation/farms_page.dart';
import 'package:smartagri/features/farms/presentation/plot_detail_page.dart';
import 'package:smartagri/features/farms/presentation/plot_form_page.dart';

import '../app_test_utils.dart';
import 'farms_test_data.dart';

class FarmsHarness {
  FarmsHarness({
    required this.container,
    required this.database,
    required this.me,
    required this.router,
  });

  final ProviderContainer container;
  final AppDatabase database;
  final FakeMeRepository me;
  final GoRouter router;
}

GoRouter buildFarmsRouter() {
  return GoRouter(
    initialLocation: '/farms',
    routes: <RouteBase>[
      GoRoute(path: '/farms', builder: (_, _) => const FarmsPage()),
      GoRoute(path: '/farms/new', builder: (_, _) => const FarmFormPage()),
      GoRoute(
        path: '/farms/:farmId/edit',
        builder: (_, GoRouterState state) =>
            FarmFormPage(farmId: state.pathParameters['farmId']),
      ),
      GoRoute(
        path: '/farms/:farmId/plots/new',
        builder: (_, GoRouterState state) =>
            PlotFormPage(farmId: state.pathParameters['farmId']),
      ),
      GoRoute(
        path: '/farms/:farmId',
        builder: (_, GoRouterState state) =>
            FarmDetailPage(farmId: state.pathParameters['farmId'] ?? ''),
      ),
      GoRoute(
        path: '/plots/:plotId/edit',
        builder: (_, GoRouterState state) =>
            PlotFormPage(plotId: state.pathParameters['plotId']),
      ),
      GoRoute(
        path: '/plots/:plotId',
        builder: (_, GoRouterState state) =>
            PlotDetailPage(plotId: state.pathParameters['plotId'] ?? ''),
      ),
    ],
  );
}

Future<FarmsHarness> pumpFarmsApp(
  WidgetTester tester, {
  String initialLocation = '/farms',
  List<Farm>? farms,
  Map<String, List<Plot>>? plots,
  AppDatabase? database,
  FakeMeRepository? meRepository,
  SyncRunner? syncRunner,
  bool markSynced = true,
}) async {
  final AppDatabase appDatabase = database ?? inMemoryAppDatabase();
  if (database == null) {
    addTearDown(appDatabase.close);
  }
  for (final Farm farm in farms ?? const <Farm>[]) {
    await seedFarm(appDatabase, farm);
  }
  for (final List<Plot> items
      in (plots ?? const <String, List<Plot>>{}).values) {
    for (final Plot plot in items) {
      await seedPlot(appDatabase, plot);
    }
  }
  if (markSynced) {
    await appDatabase.writeMeta(
      SyncService.lastSyncAtKey,
      DateTime.utc(2026, 11, 8, 10).toIso8601String(),
    );
  }
  final FakeMeRepository me = meRepository ?? FakeMeRepository(sampleMeData());
  final ProviderContainer container = await buildTestContainer(
    meRepository: me,
    database: appDatabase,
    syncRunner: syncRunner,
  );
  final GoRouter router = buildFarmsRouter();
  await tester.pumpWidget(testRouterApp(container, router));
  await tester.pumpAndSettle();
  if (initialLocation != '/farms') {
    router.push(initialLocation);
    await tester.pumpAndSettle();
  }
  return FarmsHarness(
    container: container,
    database: appDatabase,
    me: me,
    router: router,
  );
}
