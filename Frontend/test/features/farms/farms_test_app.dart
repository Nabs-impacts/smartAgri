import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:smartagri/features/farms/domain/farm.dart';
import 'package:smartagri/features/farms/domain/plot.dart';
import 'package:smartagri/features/farms/presentation/farm_detail_page.dart';
import 'package:smartagri/features/farms/presentation/farm_form_page.dart';
import 'package:smartagri/features/farms/presentation/farms_page.dart';
import 'package:smartagri/features/farms/presentation/plot_detail_page.dart';
import 'package:smartagri/features/farms/presentation/plot_form_page.dart';

import '../app_test_utils.dart';
import 'fake_farms_repository.dart';

class FarmsHarness {
  FarmsHarness({
    required this.container,
    required this.farms,
    required this.me,
    required this.router,
  });

  final ProviderContainer container;
  final FakeFarmsRepository farms;
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
  FakeFarmsRepository? repository,
  FakeMeRepository? meRepository,
}) async {
  final FakeFarmsRepository farmsRepository =
      repository ?? FakeFarmsRepository(farms: farms);
  if (plots != null) {
    farmsRepository.plots = plots;
  }
  final FakeMeRepository me = meRepository ?? FakeMeRepository(sampleMeData());
  final ProviderContainer container = await buildTestContainer(
    meRepository: me,
    farmsRepository: farmsRepository,
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
    farms: farmsRepository,
    me: me,
    router: router,
  );
}
