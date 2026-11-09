import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:smartagri/core/database/app_database.dart';
import 'package:smartagri/core/router/app_router.dart';
import 'package:smartagri/core/sync/sync_providers.dart';
import 'package:smartagri/core/sync/sync_service.dart';
import 'package:smartagri/core/sync/sync_status.dart';
import 'package:smartagri/design_system/components/app_status_banner.dart';
import 'package:smartagri/features/admin/presentation/admin_overview_page.dart';
import 'package:smartagri/features/sync/presentation/sync_banner.dart';

import '../app_test_utils.dart';

Future<void> seedChange(
  AppDatabase database, {
  required String id,
  required String status,
}) {
  final DateTime now = DateTime.utc(2026, 11, 8, 10);
  return database.putPendingChange(
    PendingChangesCompanion.insert(
      entity: 'farm',
      id: id,
      op: 'upsert',
      payload: '{}',
      clientUpdatedAt: now,
      status: Value<String>(status),
      createdAt: now,
    ),
  );
}

Future<ProviderContainer> pumpBanner(
  WidgetTester tester, {
  SyncStatus status = SyncStatus.idle,
  int pending = 0,
  int failed = 0,
  SyncRunner? runner,
}) async {
  final AppDatabase database = inMemoryAppDatabase();
  addTearDown(database.close);
  for (int index = 0; index < pending; index++) {
    await seedChange(database, id: 'pending-$index', status: 'pending');
  }
  for (int index = 0; index < failed; index++) {
    await seedChange(database, id: 'failed-$index', status: 'failed');
  }
  final ProviderContainer container = await buildTestContainer(
    meRepository: FakeMeRepository(sampleMeData()),
    database: database,
    syncRunner: runner,
  );
  container.read(syncStatusControllerProvider.notifier).set(status);
  await tester.pumpWidget(
    testApp(container, const Scaffold(body: SyncBanner())),
  );
  await tester.pumpAndSettle();
  return container;
}

void main() {
  testWidgets('shows failures before every other state', (
    WidgetTester tester,
  ) async {
    await pumpBanner(tester, status: SyncStatus.offline, pending: 2, failed: 1);

    expect(find.byKey(const Key('sync_banner_failed')), findsOneWidget);
    expect(find.text('1 modification refusée par le serveur'), findsOneWidget);
    expect(find.text('Hors connexion'), findsNothing);
  });

  testWidgets('shows the offline state with the pending count', (
    WidgetTester tester,
  ) async {
    await pumpBanner(tester, status: SyncStatus.offline, pending: 3);

    expect(find.byKey(const Key('sync_banner_offline')), findsOneWidget);
    expect(find.textContaining('Hors connexion'), findsOneWidget);
    expect(
      find.textContaining('3 modifications en attente d\'envoi'),
      findsOneWidget,
    );
  });

  testWidgets(
    'shows the offline state without a count when nothing is pending',
    (WidgetTester tester) async {
      await pumpBanner(tester, status: SyncStatus.offline);

      expect(find.text('Hors connexion'), findsOneWidget);
    },
  );

  testWidgets('shows the sync error and retries', (WidgetTester tester) async {
    int calls = 0;
    await pumpBanner(
      tester,
      status: SyncStatus.error,
      runner: () async {
        calls++;
        return SyncResult.none;
      },
    );

    expect(
      find.text('La synchronisation a rencontré une erreur.'),
      findsOneWidget,
    );
    await tester.tap(find.text('Réessayer'));
    await tester.pumpAndSettle();

    expect(calls, 1);
  });

  testWidgets('shows the syncing state when changes are pending', (
    WidgetTester tester,
  ) async {
    await pumpBanner(tester, status: SyncStatus.syncing, pending: 2);

    expect(find.byKey(const Key('sync_banner_syncing')), findsOneWidget);
    expect(find.text('Synchronisation en cours…'), findsOneWidget);
  });

  testWidgets('shows the pending state with a correct plural', (
    WidgetTester tester,
  ) async {
    await pumpBanner(tester, pending: 1);

    expect(find.byKey(const Key('sync_banner_pending')), findsOneWidget);
    expect(find.text('1 modification en attente d\'envoi'), findsOneWidget);
  });

  testWidgets('shows nothing when everything is up to date', (
    WidgetTester tester,
  ) async {
    await pumpBanner(tester);

    expect(find.byType(AppStatusBanner), findsNothing);
  });

  testWidgets('never appears in the administrator shell', (
    WidgetTester tester,
  ) async {
    final AppDatabase database = inMemoryAppDatabase();
    addTearDown(database.close);
    await seedChange(database, id: 'failed-1', status: 'failed');
    final ProviderContainer container = await buildTestContainer(
      meRepository: FakeMeRepository(sampleMeData(role: 'gov_admin')),
      database: database,
    );
    final GoRouter router = container.read(routerProvider);
    await tester.pumpWidget(testRouterApp(container, router));
    await tester.pumpAndSettle();

    expect(find.byType(AdminOverviewPage), findsOneWidget);
    expect(find.byType(AppStatusBanner), findsNothing);
  });
}
