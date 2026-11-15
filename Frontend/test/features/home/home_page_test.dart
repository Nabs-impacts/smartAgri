import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:smartagri/core/database/app_database.dart';
import 'package:smartagri/core/i18n/app_language.dart';
import 'package:smartagri/core/i18n/language_controller.dart';
import 'package:smartagri/core/network/api_exception.dart';
import 'package:smartagri/core/sync/sync_providers.dart';
import 'package:smartagri/core/sync/sync_service.dart';
import 'package:smartagri/core/sync/sync_status.dart';
import 'package:smartagri/design_system/theme.dart';
import 'package:smartagri/features/catalog/domain/crop.dart';
import 'package:smartagri/features/diagnostics/domain/diagnostic_summary.dart';
import 'package:smartagri/features/diagnostics/presentation/diagnostic_row.dart';
import 'package:smartagri/features/farms/domain/farm.dart';
import 'package:smartagri/features/farms/domain/plot.dart';
import 'package:smartagri/features/home/home_page.dart';

import '../app_test_utils.dart';
import '../diagnostics/fake_diagnostics_repository.dart';
import '../farms/farms_test_data.dart';

class CycleSeed {
  const CycleSeed({
    required this.id,
    this.plotId = 'plot-1',
    this.cropId = 1,
    this.status = 'growing',
    this.sowingDate,
    this.expectedHarvestDate,
  });

  final String id;
  final String plotId;
  final int cropId;
  final String status;
  final String? sowingDate;
  final String? expectedHarvestDate;
}

class ActivitySeed {
  const ActivitySeed({
    required this.id,
    required this.performedOn,
    this.cycleId = 'cycle-1',
    this.type = 'other',
    this.deleted = false,
  });

  final String id;
  final String cycleId;
  final String type;
  final String performedOn;
  final bool deleted;
}

typedef HomeHarness = ({
  ProviderContainer container,
  FakeMeRepository me,
  FakeDiagnosticsRepository diagnostics,
  AppDatabase database,
});

GoRouter buildRouter() {
  return GoRouter(
    initialLocation: '/home',
    routes: <RouteBase>[
      GoRoute(path: '/home', builder: (_, _) => const HomePage()),
      GoRoute(
        path: '/profile',
        builder: (_, _) => const Scaffold(body: Text('route profil')),
      ),
      GoRoute(
        path: '/diagnostic/new',
        builder: (_, _) => const Scaffold(body: Text('route diagnostic')),
      ),
      GoRoute(
        path: '/farms',
        builder: (_, _) => const Scaffold(body: Text('route champs')),
      ),
      GoRoute(
        path: '/farms/new',
        builder: (_, _) => const Scaffold(body: Text('route nouvelle')),
      ),
      GoRoute(
        path: '/diagnostics',
        builder: (_, _) => const Scaffold(body: Text('route diagnostics')),
      ),
      GoRoute(
        path: '/sync/failed',
        builder: (_, _) => const Scaffold(body: Text('route sync')),
      ),
      GoRoute(
        path: '/cycles/:cycleId',
        builder: (_, GoRouterState state) => Scaffold(
          body: Text('route cycle ${state.pathParameters['cycleId']}'),
        ),
      ),
      GoRoute(
        path: '/cycles/:cycleId/activities/new',
        builder: (_, GoRouterState state) => Scaffold(
          body: Text('route activité ${state.pathParameters['cycleId']}'),
        ),
      ),
      GoRoute(
        path: '/cycles/:cycleId/harvests/new',
        builder: (_, GoRouterState state) => Scaffold(
          body: Text('route récolte ${state.pathParameters['cycleId']}'),
        ),
      ),
    ],
  );
}

String cropsCache(List<Crop> crops) {
  return jsonEncode(<String, dynamic>{
    'cached_at': DateTime.utc(2026, 1, 1).toIso8601String(),
    'items': crops.map((Crop crop) => crop.toJson()).toList(),
  });
}

String isoDate(DateTime date) {
  final String month = date.month.toString().padLeft(2, '0');
  final String day = date.day.toString().padLeft(2, '0');
  return '${date.year}-$month-$day';
}

Future<HomeHarness> pumpHome(
  WidgetTester tester, {
  List<Farm> farms = const <Farm>[],
  List<Plot> plots = const <Plot>[],
  List<CycleSeed> cycles = const <CycleSeed>[],
  List<ActivitySeed> activities = const <ActivitySeed>[],
  FakeMeRepository? meRepository,
  FakeDiagnosticsRepository? diagnostics,
  AppDatabase? database,
  Map<String, Object> initialPreferences = const <String, Object>{},
  SyncRunner? syncRunner,
  SyncSnapshot? syncStatus,
  ThemeData? theme,
  Size size = const Size(800, 2400),
  double textScale = 1,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final FakeMeRepository me = meRepository ?? FakeMeRepository(sampleMeData());
  final FakeDiagnosticsRepository diagnosticsRepository =
      diagnostics ?? FakeDiagnosticsRepository();
  final AppDatabase appDatabase = database ?? inMemoryAppDatabase();
  if (database == null) {
    addTearDown(appDatabase.close);
  }
  for (final Farm farm in farms) {
    await seedFarm(appDatabase, farm);
  }
  for (final Plot plot in plots) {
    await seedPlot(appDatabase, plot);
  }
  for (final CycleSeed cycle in cycles) {
    await appDatabase.upsertCycle(
      cycle.id,
      cycle.plotId,
      cycle.cropId,
      status: cycle.status,
      sowingDate: cycle.sowingDate,
      expectedHarvestDate: cycle.expectedHarvestDate,
    );
  }
  for (final ActivitySeed activity in activities) {
    await appDatabase.upsertActivity(
      activity.id,
      activity.cycleId,
      activity.type,
      activity.performedOn,
    );
    if (activity.deleted) {
      await appDatabase.softDeleteActivity(activity.id);
    }
  }
  final ProviderContainer container = await buildTestContainer(
    meRepository: me,
    database: appDatabase,
    diagnosticsRepository: diagnosticsRepository,
    initialPreferences: initialPreferences,
    syncRunner: syncRunner,
    syncStatus: syncStatus,
  );
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(
        theme: theme ?? AppTheme.light,
        routerConfig: buildRouter(),
        builder: (BuildContext context, Widget? child) {
          return MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(textScale)),
            child: child ?? const SizedBox.shrink(),
          );
        },
      ),
    ),
  );
  await tester.pumpAndSettle();
  return (
    container: container,
    me: me,
    diagnostics: diagnosticsRepository,
    database: appDatabase,
  );
}

void main() {
  testWidgets('shows greeting weather diagnostic and profile', (
    WidgetTester tester,
  ) async {
    await pumpHome(tester);

    expect(find.text('Bonjour'), findsOneWidget);
    expect(find.text('AMINA'), findsOneWidget);
    expect(find.text('AD'), findsOneWidget);
    expect(find.text('34°'), findsOneWidget);
    expect(find.text('Pluie probable : 10 %'), findsOneWidget);
    expect(find.text('Vent 15 km/h'), findsOneWidget);
    expect(find.text('Sol propice'), findsOneWidget);
    expect(find.text('Données de démonstration'), findsOneWidget);
    expect(find.text('Diagnostic santé des plantes'), findsOneWidget);
    expect(
      find.textContaining('Identifiez maladies et ravageurs'),
      findsOneWidget,
    );
    expect(find.text('Analyser une plante'), findsOneWidget);
    expect(find.text('Il vous reste'), findsOneWidget);
    expect(find.text('7'), findsOneWidget);
    expect(find.text('diagnostics ce mois-ci'), findsOneWidget);
    expect(find.byKey(const Key('home_diagnostics_absent')), findsOneWidget);
    expect(find.text('Vos diagnostics apparaîtront ici'), findsNothing);
  });

  testWidgets('shows the profile and diagnostic routes', (
    WidgetTester tester,
  ) async {
    await pumpHome(tester);

    await tester.tap(find.byKey(const Key('home_profile')));
    await tester.pumpAndSettle();
    expect(find.text('route profil'), findsOneWidget);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('home_diagnostic')));
    await tester.pumpAndSettle();
    expect(find.text('route diagnostic'), findsOneWidget);
  });

  testWidgets('fits a long name at 320 with large text', (
    WidgetTester tester,
  ) async {
    await pumpHome(
      tester,
      meRepository: FakeMeRepository(
        sampleMeData(fullName: 'Aminatou Boulama Diallo'),
      ),
      size: const Size(320, 2400),
      textScale: 1.3,
    );

    expect(tester.takeException(), isNull);
    expect(find.text('AMINATOU'), findsOneWidget);
    expect(find.text('AD'), findsOneWidget);
  });

  final List<({String name, SyncSnapshot snapshot, String label, bool failed})>
  syncCases =
      <({String name, SyncSnapshot snapshot, String label, bool failed})>[
        (
          name: 'failed changes',
          snapshot: const SyncSnapshot(
            status: SyncStatus.error,
            pendingCount: 2,
            failedCount: 2,
          ),
          label: '2 refusées',
          failed: true,
        ),
        (
          name: 'offline',
          snapshot: const SyncSnapshot(
            status: SyncStatus.offline,
            pendingCount: 0,
            failedCount: 0,
          ),
          label: 'Hors connexion',
          failed: false,
        ),
        (
          name: 'syncing',
          snapshot: const SyncSnapshot(
            status: SyncStatus.syncing,
            pendingCount: 0,
            failedCount: 0,
          ),
          label: 'Synchronisation…',
          failed: false,
        ),
        (
          name: 'pending changes',
          snapshot: const SyncSnapshot(
            status: SyncStatus.idle,
            pendingCount: 3,
            failedCount: 0,
          ),
          label: '3 modifications en attente',
          failed: false,
        ),
        (
          name: 'up to date',
          snapshot: const SyncSnapshot(
            status: SyncStatus.idle,
            pendingCount: 0,
            failedCount: 0,
          ),
          label: 'À jour · jamais',
          failed: false,
        ),
      ];

  for (final ({String name, SyncSnapshot snapshot, String label, bool failed})
      syncCase
      in syncCases) {
    testWidgets('sync pill shows ${syncCase.name}', (
      WidgetTester tester,
    ) async {
      await pumpHome(tester, syncStatus: syncCase.snapshot);

      expect(find.text(syncCase.label), findsOneWidget);
      if (syncCase.failed) {
        await tester.tap(find.byKey(const Key('home_sync_pill')));
        await tester.pumpAndSettle();
        expect(find.text('route sync'), findsOneWidget);
      }
    });
  }

  testWidgets('shows active cycles with crop status and progress', (
    WidgetTester tester,
  ) async {
    final DateTime now = DateTime.now();
    final DateTime harvest = now.add(const Duration(days: 10));
    await pumpHome(
      tester,
      farms: <Farm>[sampleFarm()],
      plots: <Plot>[samplePlot()],
      cycles: <CycleSeed>[
        CycleSeed(
          id: 'cycle-1',
          cropId: 1,
          status: 'growing',
          expectedHarvestDate: isoDate(harvest),
        ),
        const CycleSeed(
          id: 'cycle-2',
          cropId: 2,
          status: 'planned',
          sowingDate: '2026-05-01',
        ),
      ],
      initialPreferences: <String, Object>{
        'catalog_crops_v1': cropsCache(sampleCrops),
      },
    );

    expect(find.text('Mes cultures en cours'), findsOneWidget);
    expect(find.text('Mil'), findsOneWidget);
    expect(find.text('Sorgho'), findsOneWidget);
    expect(find.text('En cours'), findsOneWidget);
    expect(find.text('Prévu'), findsOneWidget);
    expect(find.text('Récolte dans 10 jours'), findsOneWidget);
    expect(find.byKey(const Key('home_cycle_cycle-1')), findsOneWidget);
    expect(find.byKey(const Key('home_cycle_cycle-2')), findsOneWidget);

    await tester.tap(find.byKey(const Key('home_cycle_cycle-1')));
    await tester.pumpAndSettle();
    expect(find.text('route cycle cycle-1'), findsOneWidget);
  });

  testWidgets('uses a fallback crop name and handles missing dates', (
    WidgetTester tester,
  ) async {
    await pumpHome(
      tester,
      farms: <Farm>[sampleFarm()],
      plots: <Plot>[samplePlot()],
      cycles: <CycleSeed>[const CycleSeed(id: 'cycle-1', cropId: 9)],
    );

    expect(find.text('Culture 9'), findsOneWidget);
    expect(find.text('Dates à renseigner'), findsOneWidget);
  });

  testWidgets('shows the empty cycles card and opens farms', (
    WidgetTester tester,
  ) async {
    await pumpHome(
      tester,
      farms: <Farm>[sampleFarm()],
      plots: <Plot>[samplePlot()],
    );

    expect(find.byKey(const Key('home_cycles_empty')), findsOneWidget);
    await tester.tap(find.byKey(const Key('home_cycles_farms')));
    await tester.pumpAndSettle();
    expect(find.text('route champs'), findsOneWidget);
  });

  testWidgets('shows the welcome card without farms', (
    WidgetTester tester,
  ) async {
    await pumpHome(tester);

    expect(find.byKey(const Key('home_welcome')), findsOneWidget);
    expect(find.text('Bienvenue sur GonaTa'), findsOneWidget);
    expect(
      find.text('Commencez par créer votre première exploitation.'),
      findsOneWidget,
    );
    expect(find.byKey(const Key('home_active_cycles')), findsNothing);
    expect(find.byKey(const Key('home_shortcut_activity')), findsNothing);

    await tester.tap(find.byKey(const Key('home_start_farm')));
    await tester.pumpAndSettle();
    expect(find.text('route nouvelle'), findsOneWidget);
  });

  testWidgets('updates when the local database gains a cycle', (
    WidgetTester tester,
  ) async {
    final AppDatabase database = inMemoryAppDatabase();
    addTearDown(database.close);
    await pumpHome(tester, database: database);

    expect(find.byKey(const Key('home_welcome')), findsOneWidget);

    await seedFarm(database, sampleFarm());
    await seedPlot(database, samplePlot());
    await database.upsertCycle('cycle-1', 'plot-1', 1, status: 'growing');
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('home_welcome')), findsNothing);
    expect(find.byKey(const Key('home_cycle_cycle-1')), findsOneWidget);
    expect(find.text('Culture 1'), findsOneWidget);
  });

  testWidgets('shows five recent activities and opens the cycle', (
    WidgetTester tester,
  ) async {
    await pumpHome(
      tester,
      farms: <Farm>[sampleFarm()],
      plots: <Plot>[samplePlot()],
      cycles: <CycleSeed>[const CycleSeed(id: 'cycle-1', cropId: 1)],
      activities: <ActivitySeed>[
        const ActivitySeed(id: 'a1', performedOn: '2026-01-01'),
        const ActivitySeed(
          id: 'a2',
          performedOn: '2026-01-02',
          type: 'weeding',
        ),
        const ActivitySeed(id: 'a3', performedOn: '2026-01-03'),
        const ActivitySeed(id: 'a4', performedOn: '2026-01-04'),
        const ActivitySeed(id: 'a5', performedOn: '2026-01-05'),
        const ActivitySeed(
          id: 'a6',
          performedOn: '2026-01-06',
          type: 'harvest',
        ),
        const ActivitySeed(id: 'a7', performedOn: '2026-01-07', deleted: true),
      ],
    );

    expect(find.text('Dernières activités'), findsOneWidget);
    expect(find.byKey(const Key('home_activity_a1')), findsNothing);
    expect(find.byKey(const Key('home_activity_a2')), findsOneWidget);
    expect(find.byKey(const Key('home_activity_a6')), findsOneWidget);
    expect(find.byKey(const Key('home_activity_a7')), findsNothing);
    expect(find.text('Désherbage'), findsOneWidget);
    expect(find.text('Culture 1 · Parcelle nord'), findsWidgets);

    await tester.tap(find.byKey(const Key('home_activity_a6')));
    await tester.pumpAndSettle();
    expect(find.text('route cycle cycle-1'), findsOneWidget);
  });

  testWidgets('the activity shortcut opens the only cycle form', (
    WidgetTester tester,
  ) async {
    await pumpHome(
      tester,
      farms: <Farm>[sampleFarm()],
      plots: <Plot>[samplePlot()],
      cycles: <CycleSeed>[const CycleSeed(id: 'cycle-1')],
    );

    await tester.tap(find.byKey(const Key('home_shortcut_activity')));
    await tester.pumpAndSettle();
    expect(find.text('route activité cycle-1'), findsOneWidget);
  });

  testWidgets('the harvest shortcut opens the only cycle form', (
    WidgetTester tester,
  ) async {
    await pumpHome(
      tester,
      farms: <Farm>[sampleFarm()],
      plots: <Plot>[samplePlot()],
      cycles: <CycleSeed>[const CycleSeed(id: 'cycle-1')],
    );

    await tester.tap(find.byKey(const Key('home_shortcut_harvest')));
    await tester.pumpAndSettle();
    expect(find.text('route récolte cycle-1'), findsOneWidget);
  });

  testWidgets('the farm shortcut opens the creation form', (
    WidgetTester tester,
  ) async {
    await pumpHome(tester, farms: <Farm>[sampleFarm()]);

    await tester.tap(find.byKey(const Key('home_shortcut_farm')));
    await tester.pumpAndSettle();
    expect(find.text('route nouvelle'), findsOneWidget);
  });

  testWidgets('the activity shortcut explains the missing cycle', (
    WidgetTester tester,
  ) async {
    await pumpHome(
      tester,
      farms: <Farm>[sampleFarm()],
      plots: <Plot>[samplePlot()],
    );

    await tester.tap(find.byKey(const Key('home_shortcut_activity')));
    await tester.pumpAndSettle();
    expect(find.text('Aucun cycle en cours'), findsOneWidget);

    await tester.tap(find.byKey(const Key('home_no_cycle_farms')));
    await tester.pumpAndSettle();
    expect(find.text('route champs'), findsOneWidget);
  });

  testWidgets('the activity shortcut asks which cycle to use', (
    WidgetTester tester,
  ) async {
    await pumpHome(
      tester,
      farms: <Farm>[sampleFarm()],
      plots: <Plot>[samplePlot()],
      cycles: <CycleSeed>[
        const CycleSeed(id: 'cycle-1', cropId: 1),
        const CycleSeed(id: 'cycle-2', cropId: 2),
      ],
      initialPreferences: <String, Object>{
        'catalog_crops_v1': cropsCache(sampleCrops),
      },
    );

    await tester.tap(find.byKey(const Key('home_shortcut_activity')));
    await tester.pumpAndSettle();
    expect(find.text('Choisir un cycle'), findsOneWidget);

    await tester.tap(find.byKey(const Key('home_cycle_choice_cycle-2')));
    await tester.pumpAndSettle();
    expect(find.text('route activité cycle-2'), findsOneWidget);
  });

  testWidgets('shows two latest diagnostics and opens the history', (
    WidgetTester tester,
  ) async {
    final FakeDiagnosticsRepository diagnostics = FakeDiagnosticsRepository(
      items: <DiagnosticSummary>[
        sampleSummary(id: 'diag-1', labelName: 'Analyse 1'),
        sampleSummary(id: 'diag-2', labelName: 'Analyse 2'),
        sampleSummary(id: 'diag-3', labelName: 'Analyse 3'),
      ],
    );
    await pumpHome(tester, diagnostics: diagnostics);

    expect(find.text('Derniers diagnostics'), findsOneWidget);
    expect(find.byType(DiagnosticRow), findsNWidgets(2));
    expect(find.text('Analyse 1'), findsOneWidget);
    expect(find.text('Analyse 2'), findsOneWidget);
    expect(find.text('Analyse 3'), findsNothing);

    await tester.tap(find.byKey(const Key('home_diagnostics_see_all')));
    await tester.pumpAndSettle();
    expect(find.text('route diagnostics'), findsOneWidget);
  });

  testWidgets('retries the diagnostics error', (WidgetTester tester) async {
    final FakeDiagnosticsRepository diagnostics = FakeDiagnosticsRepository()
      ..listError = ApiException.network();
    await pumpHome(tester, diagnostics: diagnostics);

    expect(find.byKey(const Key('home_diagnostics_retry')), findsOneWidget);

    diagnostics.listError = null;
    diagnostics.items = <DiagnosticSummary>[
      sampleSummary(id: 'diag-1', labelName: 'Mildiou'),
    ];
    await tester.tap(find.byKey(const Key('home_diagnostics_retry')));
    await tester.pumpAndSettle();

    expect(find.text('Mildiou'), findsOneWidget);
  });

  testWidgets('pull to refresh syncs and reloads server data', (
    WidgetTester tester,
  ) async {
    final FakeMeRepository me = FakeMeRepository(sampleMeData());
    final FakeDiagnosticsRepository diagnostics = FakeDiagnosticsRepository();
    int syncCalls = 0;
    await pumpHome(
      tester,
      meRepository: me,
      diagnostics: diagnostics,
      syncRunner: () async {
        syncCalls++;
        return SyncResult.none;
      },
    );
    final int meCalls = me.getMeCalls;
    final int diagnosticCalls = diagnostics.listCalls;

    diagnostics.items = <DiagnosticSummary>[
      sampleSummary(id: 'diag-1', labelName: 'Mildiou'),
    ];
    final RefreshIndicator refresh = tester.widget<RefreshIndicator>(
      find.byType(RefreshIndicator),
    );
    await refresh.onRefresh();
    await tester.pumpAndSettle();

    expect(syncCalls, 1);
    expect(me.getMeCalls, greaterThan(meCalls));
    expect(diagnostics.listCalls, greaterThan(diagnosticCalls));
    expect(find.text('Mildiou'), findsOneWidget);
  });

  testWidgets('changing the language updates the app and the backend', (
    WidgetTester tester,
  ) async {
    final HomeHarness harness = await pumpHome(tester);

    await tester.tap(find.byKey(const Key('language_ha')));
    await tester.pumpAndSettle();

    expect(harness.container.read(languageControllerProvider), AppLanguage.ha);
    expect(harness.me.languages, contains(AppLanguage.ha));
  });

  for (final ThemeData theme in <ThemeData>[AppTheme.light, AppTheme.dark]) {
    testWidgets(
      'home layout fits at 320 in the ${theme.brightness.name} theme',
      (WidgetTester tester) async {
        await pumpHome(
          tester,
          theme: theme,
          size: const Size(320, 3000),
          textScale: 1.3,
          farms: <Farm>[sampleFarm()],
          plots: <Plot>[samplePlot()],
          cycles: <CycleSeed>[
            const CycleSeed(
              id: 'cycle-1',
              cropId: 1,
              sowingDate: '2026-05-01',
              expectedHarvestDate: '2026-08-01',
            ),
          ],
          activities: <ActivitySeed>[
            const ActivitySeed(
              id: 'a1',
              performedOn: '2026-06-01',
              type: 'weeding',
            ),
          ],
          diagnostics: FakeDiagnosticsRepository(
            items: <DiagnosticSummary>[
              sampleSummary(id: 'diag-1', labelName: 'Mildiou'),
            ],
          ),
          initialPreferences: <String, Object>{
            'catalog_crops_v1': cropsCache(sampleCrops),
          },
        );

        expect(tester.takeException(), isNull);
        expect(find.byKey(const Key('home_weather_card')), findsOneWidget);
        expect(find.byKey(const Key('home_recent_activities')), findsOneWidget);
        expect(find.byKey(const Key('home_diagnostics')), findsOneWidget);
      },
    );
  }
}
