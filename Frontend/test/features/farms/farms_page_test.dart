import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartagri/core/sync/sync_providers.dart';
import 'package:smartagri/core/sync/sync_service.dart';
import 'package:smartagri/core/sync/sync_status.dart';
import 'package:smartagri/features/farms/domain/farm.dart';
import 'package:smartagri/features/farms/presentation/farm_detail_page.dart';
import 'package:smartagri/features/farms/presentation/farm_form_page.dart';

import 'farms_test_app.dart';
import 'farms_test_data.dart';

void main() {
  testWidgets('lists farms with their village and region', (
    WidgetTester tester,
  ) async {
    await pumpFarmsApp(
      tester,
      farms: <Farm>[
        sampleFarm(),
        sampleFarm(id: 'farm-2', name: 'Ferme est', village: 'Dosso'),
      ],
    );

    expect(find.text('Ferme du fleuve'), findsOneWidget);
    expect(find.text('Saga'), findsOneWidget);
    expect(find.text('Niamey'), findsNWidgets(2));
    expect(find.text('Ferme est'), findsOneWidget);
    expect(find.text('Dosso'), findsWidgets);

    await tester.tap(find.byKey(const Key('farm_card_farm-1')));
    await tester.pumpAndSettle();

    expect(find.byType(FarmDetailPage), findsOneWidget);
  });

  testWidgets('opens the creation form from the primary button', (
    WidgetTester tester,
  ) async {
    await pumpFarmsApp(tester);

    await tester.tap(find.byKey(const Key('farms_add')));
    await tester.pumpAndSettle();

    expect(find.byType(FarmFormPage), findsOneWidget);
    expect(find.text('Nouvelle exploitation'), findsOneWidget);
  });

  testWidgets('shows the empty state after a first synchronization', (
    WidgetTester tester,
  ) async {
    await pumpFarmsApp(tester);

    expect(find.text('Aucune exploitation pour le moment.'), findsOneWidget);
  });

  testWidgets('shows the loading state before the first synchronization', (
    WidgetTester tester,
  ) async {
    final FarmsHarness harness = await pumpFarmsApp(tester, markSynced: false);

    expect(find.byKey(const Key('farms_skeleton_0')), findsOneWidget);
    expect(find.byKey(const Key('farms_empty')), findsNothing);

    await seedFarm(harness.database, sampleFarm());
    await harness.database.writeMeta(
      SyncService.lastSyncAtKey,
      DateTime.utc(2026, 11, 8, 10).toIso8601String(),
    );
    await tester.pumpAndSettle();

    expect(find.text('Ferme du fleuve'), findsOneWidget);
  });

  testWidgets('shows a simple empty list after an offline first sync', (
    WidgetTester tester,
  ) async {
    final FarmsHarness harness = await pumpFarmsApp(tester, markSynced: false);

    harness.container
        .read(syncStatusControllerProvider.notifier)
        .set(SyncStatus.offline);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('farms_empty')), findsOneWidget);
  });

  testWidgets('the refresh gesture runs a synchronization', (
    WidgetTester tester,
  ) async {
    int calls = 0;
    await pumpFarmsApp(
      tester,
      syncRunner: () async {
        calls++;
        return SyncResult.none;
      },
    );

    final RefreshIndicator refresh = tester.widget<RefreshIndicator>(
      find.byType(RefreshIndicator),
    );
    await refresh.onRefresh();
    await tester.pumpAndSettle();

    expect(calls, 1);
  });
}
