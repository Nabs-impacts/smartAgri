import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:smartagri/core/database/app_database.dart';
import 'package:smartagri/core/router/app_router.dart';
import 'package:smartagri/core/sync/sync_service.dart';
import 'package:smartagri/features/sync/presentation/sync_failed_page.dart';

import '../app_test_utils.dart';

Future<void> seedChange(
  AppDatabase database, {
  required String entity,
  required String id,
  String op = 'upsert',
  String? error = 'Refusée par le serveur.',
  DateTime? createdAt,
}) {
  final DateTime at = createdAt ?? DateTime.utc(2026, 11, 8, 10);
  return database.putPendingChange(
    PendingChangesCompanion.insert(
      entity: entity,
      id: id,
      op: op,
      payload: '{}',
      clientUpdatedAt: at,
      status: const Value<String>('failed'),
      lastError: Value<String?>(error),
      createdAt: at,
    ),
  );
}

Future<ProviderContainer> pumpFailedPage(
  WidgetTester tester,
  AppDatabase database, {
  int Function()? onSync,
}) async {
  final ProviderContainer container = await buildTestContainer(
    meRepository: FakeMeRepository(sampleMeData()),
    database: database,
    syncRunner: () async {
      onSync?.call();
      return SyncResult.none;
    },
  );
  await tester.pumpWidget(testApp(container, const SyncFailedPage()));
  await tester.pumpAndSettle();
  return container;
}

void main() {
  testWidgets('lists failed changes with their readable details', (
    WidgetTester tester,
  ) async {
    final AppDatabase database = inMemoryAppDatabase();
    addTearDown(database.close);
    await database.upsertFarm('f1', 'Ferme du fleuve');
    await database.upsertPlot('p1', 'f1', 'Parcelle nord');
    await seedChange(database, entity: 'farm', id: 'f1');
    await seedChange(
      database,
      entity: 'plot',
      id: 'p1',
      op: 'delete',
      error: 'Cette ressource a été supprimée.',
    );

    await pumpFailedPage(tester, database);

    expect(find.text('Exploitation'), findsOneWidget);
    expect(find.text('Ferme du fleuve'), findsOneWidget);
    expect(find.text('Modification'), findsOneWidget);
    expect(find.text('Parcelle'), findsOneWidget);
    expect(find.text('Parcelle nord'), findsOneWidget);
    expect(find.text('Suppression'), findsOneWidget);
    expect(find.text('Cette ressource a été supprimée.'), findsOneWidget);
  });

  testWidgets('shows the empty state', (WidgetTester tester) async {
    final AppDatabase database = inMemoryAppDatabase();
    addTearDown(database.close);

    await pumpFailedPage(tester, database);

    expect(find.text('Aucune modification en échec.'), findsOneWidget);
  });

  testWidgets('retries one failed change and starts a sync', (
    WidgetTester tester,
  ) async {
    final AppDatabase database = inMemoryAppDatabase();
    addTearDown(database.close);
    await database.upsertFarm('f1', 'Ferme');
    await seedChange(database, entity: 'farm', id: 'f1');
    int syncs = 0;

    await pumpFailedPage(tester, database, onSync: () => syncs++);
    await tester.tap(find.byKey(const Key('sync_failed_retry_farm_f1')));
    await tester.pumpAndSettle();

    expect((await database.getPendingChange('farm', 'f1'))?.status, 'pending');
    expect(syncs, 1);
  });

  testWidgets('retries all failed changes', (WidgetTester tester) async {
    final AppDatabase database = inMemoryAppDatabase();
    addTearDown(database.close);
    await database.upsertFarm('f1', 'Ferme');
    await database.upsertPlot('p1', 'f1', 'Parcelle');
    await seedChange(database, entity: 'farm', id: 'f1');
    await seedChange(database, entity: 'plot', id: 'p1');
    int syncs = 0;

    await pumpFailedPage(tester, database, onSync: () => syncs++);
    await tester.tap(find.byKey(const Key('sync_failed_retry_all')));
    await tester.pumpAndSettle();

    expect((await database.getPendingChange('farm', 'f1'))?.status, 'pending');
    expect((await database.getPendingChange('plot', 'p1'))?.status, 'pending');
    expect(syncs, 1);
  });

  testWidgets('discards a confirmed change after confirmation', (
    WidgetTester tester,
  ) async {
    final AppDatabase database = inMemoryAppDatabase();
    addTearDown(database.close);
    await database.upsertFarm(
      'f1',
      'Ferme',
      updatedAt: DateTime.utc(2026, 11, 8, 9),
    );
    await seedChange(database, entity: 'farm', id: 'f1');
    await database.writeMeta(
      SyncService.cursorHistoryKey,
      '[{"cursor":"abc","savedAt":"2026-11-08T09:00:00Z"}]',
    );

    await pumpFailedPage(tester, database);
    await tester.tap(find.byKey(const Key('sync_failed_discard_farm_f1')));
    await tester.pumpAndSettle();

    expect(
      find.text(
        'La modification sera perdue et la version du serveur remplacera la version locale.',
      ),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const Key('sync_discard_confirm')));
    await tester.pumpAndSettle();

    expect(await database.getPendingChange('farm', 'f1'), isNull);
    expect(await database.readMeta(SyncService.cursorHistoryKey), isNull);
  });

  testWidgets('discards a never confirmed change and deletes it locally', (
    WidgetTester tester,
  ) async {
    final AppDatabase database = inMemoryAppDatabase();
    addTearDown(database.close);
    await database.upsertFarm('f1', 'Brouillon');
    await seedChange(database, entity: 'farm', id: 'f1');

    await pumpFailedPage(tester, database);
    await tester.tap(find.byKey(const Key('sync_failed_discard_farm_f1')));
    await tester.pumpAndSettle();

    expect(
      find.text("L'élément sera supprimé définitivement de cet appareil."),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const Key('sync_discard_confirm')));
    await tester.pumpAndSettle();

    expect(await database.getPendingChange('farm', 'f1'), isNull);
    expect(await database.getFarm('f1'), isNull);
  });

  testWidgets('redirects an administrator away from the failed page', (
    WidgetTester tester,
  ) async {
    final AppDatabase database = inMemoryAppDatabase();
    addTearDown(database.close);
    final ProviderContainer container = await buildTestContainer(
      meRepository: FakeMeRepository(sampleMeData(role: 'gov_admin')),
      database: database,
    );
    final GoRouter router = container.read(routerProvider);
    await tester.pumpWidget(testRouterApp(container, router));
    await tester.pumpAndSettle();

    router.go('/sync/failed');
    await tester.pumpAndSettle();

    expect(router.state.uri.path, '/admin/overview');
  });
}
