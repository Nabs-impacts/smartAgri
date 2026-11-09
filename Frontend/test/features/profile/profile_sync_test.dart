import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartagri/core/database/app_database.dart';
import 'package:smartagri/core/sync/sync_providers.dart';
import 'package:smartagri/core/sync/sync_service.dart';
import 'package:smartagri/core/sync/sync_status.dart';
import 'package:smartagri/design_system/components/app_button.dart';
import 'package:smartagri/features/profile/profile_page.dart';

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

Future<ProviderContainer> pumpProfile(
  WidgetTester tester, {
  String role = 'farmer',
  SyncStatus status = SyncStatus.idle,
  int pending = 0,
  int failed = 0,
  DateTime? lastSyncAt,
}) async {
  final AppDatabase database = inMemoryAppDatabase();
  addTearDown(database.close);
  for (int index = 0; index < pending; index++) {
    await seedChange(database, id: 'pending-$index', status: 'pending');
  }
  for (int index = 0; index < failed; index++) {
    await seedChange(database, id: 'failed-$index', status: 'failed');
  }
  if (lastSyncAt != null) {
    await database.writeMeta(
      SyncService.lastSyncAtKey,
      lastSyncAt.toUtc().toIso8601String(),
    );
  }
  final ProviderContainer container = await buildTestContainer(
    meRepository: FakeMeRepository(sampleMeData(role: role)),
    database: database,
  );
  container.read(syncStatusControllerProvider.notifier).set(status);
  await tester.pumpWidget(testApp(container, const ProfilePage()));
  await tester.pumpAndSettle();
  return container;
}

Future<void> scrollToSync(WidgetTester tester) async {
  await tester.scrollUntilVisible(
    find.byKey(const Key('profile_sync_now')),
    500,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.pump();
}

void main() {
  testWidgets('shows the sync section with never and no pending changes', (
    WidgetTester tester,
  ) async {
    await pumpProfile(tester);
    await scrollToSync(tester);

    expect(find.text('Synchronisation'), findsOneWidget);
    expect(find.text('Dernière synchronisation'), findsOneWidget);
    expect(find.text('jamais'), findsOneWidget);
    expect(find.text('Aucune modification en attente'), findsOneWidget);
    expect(find.text('Aucune modification en échec'), findsOneWidget);
  });

  testWidgets('shows a relative last sync time', (WidgetTester tester) async {
    await pumpProfile(
      tester,
      lastSyncAt: DateTime.now().toUtc().subtract(const Duration(minutes: 5)),
    );
    await scrollToSync(tester);

    expect(find.text('il y a 5 min'), findsOneWidget);
  });

  testWidgets('shows the pending and failed counters', (
    WidgetTester tester,
  ) async {
    await pumpProfile(tester, pending: 2, failed: 1);
    await scrollToSync(tester);

    expect(find.text('2 modifications en attente'), findsOneWidget);
    expect(find.text('1 modification en échec'), findsOneWidget);
  });

  testWidgets('disables the button during a synchronization', (
    WidgetTester tester,
  ) async {
    final ProviderContainer container = await pumpProfile(tester, pending: 1);
    container
        .read(syncStatusControllerProvider.notifier)
        .set(SyncStatus.syncing);
    await tester.pump();
    await scrollToSync(tester);

    final AppButton button = tester.widget<AppButton>(
      find.byKey(const Key('profile_sync_now')),
    );
    expect(button.onPressed, isNull);
  });

  testWidgets('hides the sync section from an administrator', (
    WidgetTester tester,
  ) async {
    await pumpProfile(tester, role: 'gov_admin');

    expect(find.text('Synchronisation'), findsNothing);
    expect(find.byKey(const Key('profile_sync_now')), findsNothing);
  });
}
