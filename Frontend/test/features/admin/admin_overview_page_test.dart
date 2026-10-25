import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartagri/core/network/api_exception.dart';
import 'package:smartagri/design_system/components/app_progress_bar.dart';
import 'package:smartagri/features/admin/domain/overview.dart';
import 'package:smartagri/features/admin/presentation/admin_format.dart';
import 'package:smartagri/features/admin/presentation/admin_overview_page.dart';

import '../app_test_utils.dart';
import 'fake_stats_repository.dart';

Future<FakeStatsRepository> pumpOverview(
  WidgetTester tester, {
  Overview? overview,
  Object? error,
}) async {
  tester.view.physicalSize = const Size(1200, 3000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final FakeStatsRepository repository = FakeStatsRepository(
    overview: overview,
    overviewError: error,
  );
  final container = await buildTestContainer(
    meRepository: FakeMeRepository(sampleMeData(role: 'gov_admin')),
    statsRepository: repository,
    crops: sampleCrops,
  );
  await tester.pumpWidget(testApp(container, const AdminOverviewPage()));
  await tester.pumpAndSettle();
  return repository;
}

Finder inCard(String key, Finder matching) {
  return find.descendant(of: find.byKey(Key(key)), matching: matching);
}

void main() {
  testWidgets('formats the numbers with the French separators', (
    WidgetTester tester,
  ) async {
    await pumpOverview(tester);

    expect(find.text('Tableau de bord'), findsOneWidget);
    expect(
      inCard('admin_kpi_active_users', find.text(formatAdminNumber(1250))),
      findsOneWidget,
    );
    expect(
      inCard('admin_kpi_diagnostics', find.text(formatAdminNumber(340))),
      findsOneWidget,
    );
    expect(
      inCard('admin_kpi_area', find.text('${formatAdminNumber(12500)} ha')),
      findsOneWidget,
    );
    expect(find.text('Utilisateurs actifs (30 jours)'), findsOneWidget);
    expect(find.text('Diagnostics (30 jours)'), findsOneWidget);
    expect(find.text('Surface suivie'), findsOneWidget);
  });

  testWidgets('draws the adoption rows and the relative bars', (
    WidgetTester tester,
  ) async {
    await pumpOverview(
      tester,
      overview: const Overview(
        activeUsers30d: 30,
        diagnostics30d: 2,
        trackedAreaHa: 10,
        adoption: <RegionAdoption>[
          RegionAdoption(
            regionId: 1,
            regionName: 'Niamey',
            masked: false,
            users: 20,
            plots: 40,
          ),
          RegionAdoption(
            regionId: 2,
            regionName: 'Dosso',
            masked: false,
            users: 10,
            plots: 12,
          ),
        ],
      ),
    );

    expect(find.text('Adoption par région'), findsOneWidget);
    expect(find.text('20 utilisateurs · 40 parcelles'), findsOneWidget);
    expect(find.text('10 utilisateurs · 12 parcelles'), findsOneWidget);

    final AppProgressBar first = tester.widget<AppProgressBar>(
      find.byKey(const Key('admin_adoption_bar_1')),
    );
    final AppProgressBar second = tester.widget<AppProgressBar>(
      find.byKey(const Key('admin_adoption_bar_2')),
    );
    expect(first.value, 1);
    expect(second.value, 0.5);
  });

  testWidgets('hides every number and bar of a masked region', (
    WidgetTester tester,
  ) async {
    await pumpOverview(
      tester,
      overview: const Overview(
        activeUsers30d: 30,
        diagnostics30d: 2,
        trackedAreaHa: 10,
        adoption: <RegionAdoption>[
          RegionAdoption(
            regionId: 1,
            regionName: 'Niamey',
            masked: false,
            users: 20,
            plots: 40,
          ),
          RegionAdoption(
            regionId: 3,
            regionName: 'Tahoua',
            masked: true,
            users: 4,
            plots: 9,
          ),
        ],
      ),
    );

    final Finder row = find.byKey(const Key('admin_adoption_3'));
    expect(row, findsOneWidget);
    expect(
      find.descendant(of: row, matching: find.byIcon(Icons.lock_outline)),
      findsOneWidget,
    );
    expect(
      find.descendant(of: row, matching: find.byType(AppProgressBar)),
      findsNothing,
    );
    expect(
      find.descendant(
        of: row,
        matching: find.text('4 utilisateurs · 9 parcelles'),
      ),
      findsNothing,
    );
    expect(
      find.descendant(of: row, matching: find.textContaining('4')),
      findsNothing,
    );
    expect(
      find.text('Données masquées (moins de 5 utilisateurs)'),
      findsOneWidget,
    );
  });

  testWidgets('shows the data protection card', (WidgetTester tester) async {
    await pumpOverview(tester);

    expect(find.text('Protection des données'), findsOneWidget);
    expect(
      find.text(
        'Les valeurs concernant moins de 5 cycles ou moins de 3 agriculteurs sont masquées automatiquement. Aucune donnée individuelle n\'est jamais affichée.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('shows the forbidden state without retry', (
    WidgetTester tester,
  ) async {
    await pumpOverview(
      tester,
      error: const ApiException(
        statusCode: 403,
        code: 'FORBIDDEN',
        message: 'Accès refusé.',
      ),
    );

    expect(find.text('Accès réservé à l\'administration.'), findsOneWidget);
    expect(find.byKey(const Key('admin_overview_retry')), findsNothing);
  });

  testWidgets('shows the error state and retries', (WidgetTester tester) async {
    final FakeStatsRepository repository = await pumpOverview(
      tester,
      error: ApiException.network(),
    );

    expect(find.byKey(const Key('admin_overview_retry')), findsOneWidget);

    repository.overviewError = null;
    await tester.tap(find.byKey(const Key('admin_overview_retry')));
    await tester.pumpAndSettle();

    expect(find.text(formatAdminNumber(1250)), findsOneWidget);
    expect(find.text('Tableau de bord'), findsOneWidget);
  });
}
