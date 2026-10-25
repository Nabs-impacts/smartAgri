import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartagri/core/network/api_exception.dart';
import 'package:smartagri/design_system/components/app_progress_bar.dart';
import 'package:smartagri/features/admin/domain/yield_cell.dart';
import 'package:smartagri/features/admin/presentation/admin_format.dart';
import 'package:smartagri/features/admin/presentation/admin_yields_page.dart';

import '../app_test_utils.dart';
import 'fake_stats_repository.dart';

Future<FakeStatsRepository> pumpYields(
  WidgetTester tester, {
  List<YieldCell>? yields,
  Object? error,
}) async {
  tester.view.physicalSize = const Size(1200, 3000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final FakeStatsRepository repository = FakeStatsRepository(
    yields: yields,
    yieldsError: error,
  );
  final container = await buildTestContainer(
    meRepository: FakeMeRepository(sampleMeData(role: 'gov_admin')),
    statsRepository: repository,
    crops: sampleCrops,
    adminAreas: sampleAdminAreas,
  );
  await tester.pumpWidget(testApp(container, const AdminYieldsPage()));
  await tester.pumpAndSettle();
  return repository;
}

void main() {
  testWidgets('renders the yield cell and the available filters', (
    WidgetTester tester,
  ) async {
    await pumpYields(tester, yields: <YieldCell>[sampleYieldCell()]);

    expect(find.text('Rendements'), findsOneWidget);
    expect(find.text('Culture'), findsOneWidget);
    expect(find.text('Région'), findsOneWidget);
    expect(find.text('Saison'), findsOneWidget);
    expect(find.text('Année'), findsOneWidget);
    expect(find.text('Toutes'), findsNWidgets(4));
    expect(find.text('Mil · Maradi'), findsOneWidget);
    expect(find.text('Saison des pluies 2026'), findsOneWidget);
    expect(find.text('${formatAdminNumber(1250)} kg/ha'), findsOneWidget);
    expect(
      find.text(
        'min ${formatAdminNumber(900)} · max ${formatAdminNumber(1600)} kg/ha',
      ),
      findsOneWidget,
    );
    expect(find.text('12 cycles · 5 agriculteurs'), findsOneWidget);
  });

  testWidgets('sends every selected filter to the request', (
    WidgetTester tester,
  ) async {
    final FakeStatsRepository repository = await pumpYields(
      tester,
      yields: <YieldCell>[sampleYieldCell()],
    );

    expect(repository.yieldsCalls.first.cropId, isNull);
    expect(repository.yieldsCalls.first.regionId, isNull);
    expect(repository.yieldsCalls.first.seasonYear, isNull);
    expect(repository.yieldsCalls.first.seasonType, isNull);

    await tester.tap(find.byKey(const Key('admin_yields_crop')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Mil'));
    await tester.pumpAndSettle();
    expect(repository.yieldsCalls.last.cropId, 1);

    await tester.tap(find.byKey(const Key('admin_yields_region')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Dosso'));
    await tester.pumpAndSettle();
    expect(repository.yieldsCalls.last.regionId, 2);

    await tester.tap(find.text('Saison sèche'));
    await tester.pumpAndSettle();
    expect(repository.yieldsCalls.last.seasonType, SeasonType.dry);

    final int currentYear = DateTime.now().year;
    await tester.tap(find.byKey(const Key('admin_yields_year')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('$currentYear').last);
    await tester.pumpAndSettle();
    expect(repository.yieldsCalls.last.seasonYear, currentYear);
  });

  testWidgets('draws the bars relative to the same crop maximum', (
    WidgetTester tester,
  ) async {
    await pumpYields(
      tester,
      yields: <YieldCell>[
        sampleYieldCell(avg: 1000),
        sampleYieldCell(regionId: 2, regionName: 'Dosso', avg: 2000),
        sampleYieldCell(
          cropId: 2,
          cropName: 'Sorgho',
          regionId: 2,
          regionName: 'Dosso',
          avg: 100,
        ),
      ],
    );

    final AppProgressBar first = tester.widget<AppProgressBar>(
      find.byKey(const Key('admin_yield_bar_1_1_2026_rainy')),
    );
    final AppProgressBar second = tester.widget<AppProgressBar>(
      find.byKey(const Key('admin_yield_bar_1_2_2026_rainy')),
    );
    final AppProgressBar otherCrop = tester.widget<AppProgressBar>(
      find.byKey(const Key('admin_yield_bar_2_2_2026_rainy')),
    );
    expect(first.value, 0.5);
    expect(second.value, 1);
    expect(otherCrop.value, 1);
  });

  testWidgets('a masked cell exposes no value at all', (
    WidgetTester tester,
  ) async {
    await pumpYields(
      tester,
      yields: <YieldCell>[
        sampleYieldCell(
          masked: true,
          cycles: 4,
          farmers: 2,
          avg: 1250,
          min: 900,
          max: 1600,
        ),
      ],
    );

    expect(find.byIcon(Icons.lock_outline), findsOneWidget);
    expect(
      find.text(
        'Données masquées : échantillon trop petit pour protéger les agriculteurs',
      ),
      findsOneWidget,
    );
    expect(find.byType(AppProgressBar), findsNothing);
    expect(find.text('${formatAdminNumber(1250)} kg/ha'), findsNothing);
    expect(
      find.text(
        'min ${formatAdminNumber(900)} · max ${formatAdminNumber(1600)} kg/ha',
      ),
      findsNothing,
    );
    expect(find.text('4 cycles · 2 agriculteurs'), findsNothing);
    expect(find.textContaining(RegExp(r'\d')), findsNothing);
  });

  testWidgets('shows the empty state', (WidgetTester tester) async {
    await pumpYields(tester, yields: <YieldCell>[]);

    expect(find.text('Aucune donnée pour ces filtres'), findsOneWidget);
  });

  testWidgets('shows the error state and retries', (WidgetTester tester) async {
    final FakeStatsRepository repository = await pumpYields(
      tester,
      error: ApiException.network(),
    );

    expect(find.byKey(const Key('admin_yields_retry')), findsOneWidget);

    repository.yieldsError = null;
    repository.yields = <YieldCell>[sampleYieldCell()];
    await tester.tap(find.byKey(const Key('admin_yields_retry')));
    await tester.pumpAndSettle();

    expect(find.text('Mil · Maradi'), findsOneWidget);
  });
}
