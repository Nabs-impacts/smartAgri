import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartagri/core/database/app_database.dart';
import 'package:smartagri/features/farms/domain/farm.dart';
import 'package:smartagri/features/farms/presentation/farm_form_page.dart';

import 'farms_test_app.dart';
import 'farms_test_data.dart';

Future<void> fillName(WidgetTester tester, String value) async {
  await tester.enterText(find.byKey(const Key('farm_name_field')), value);
}

Future<void> tapSave(WidgetTester tester) async {
  await tester.ensureVisible(find.byKey(const Key('farm_save')));
  await tester.tap(find.byKey(const Key('farm_save')));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('validates the name length', (WidgetTester tester) async {
    await pumpFarmsApp(tester, initialLocation: '/farms/new');

    await tapSave(tester);
    expect(
      find.text('Le nom doit contenir entre 2 et 120 caractères.'),
      findsOneWidget,
    );

    await fillName(tester, 'A');
    await tapSave(tester);
    expect(
      find.text('Le nom doit contenir entre 2 et 120 caractères.'),
      findsOneWidget,
    );

    await fillName(tester, 'AB');
    await tapSave(tester);
    expect(
      find.text('Le nom doit contenir entre 2 et 120 caractères.'),
      findsNothing,
    );
  });

  testWidgets('creates the farm locally and enqueues an upsert', (
    WidgetTester tester,
  ) async {
    final FarmsHarness harness = await pumpFarmsApp(
      tester,
      initialLocation: '/farms/new',
    );
    await fillName(tester, 'Ferme test');

    await tester.tap(find.byKey(const Key('farm_region_field')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Niamey'));
    await tester.pumpAndSettle();

    await tapSave(tester);

    final List<PendingChangeRow> outbox = await harness.database.getOutbox();
    expect(outbox, hasLength(1));
    expect(outbox.single.entity, 'farm');
    expect(outbox.single.op, 'upsert');
    final FarmRow? row = await harness.database.getFarm(outbox.single.id);
    expect(row?.name, 'Ferme test');
    expect(row?.adminAreaId, 1);
    expect(row?.updatedAt, isNull);
    final Map<String, dynamic> data =
        jsonDecode(outbox.single.payload) as Map<String, dynamic>;
    expect(data['name'], 'Ferme test');
    expect(data['admin_area_id'], 1);
    expect(data['village'], isNull);
    expect(data['location'], isNull);
    expect(find.byType(FarmFormPage), findsNothing);
  });

  testWidgets('prefills the edit form and updates the farm locally', (
    WidgetTester tester,
  ) async {
    final FarmsHarness harness = await pumpFarmsApp(
      tester,
      initialLocation: '/farms/farm-1/edit',
      farms: <Farm>[sampleFarm(name: 'Ancienne')],
    );

    expect(find.text('Ancienne'), findsOneWidget);

    await fillName(tester, 'Nouvelle');
    await tapSave(tester);

    final FarmRow? row = await harness.database.getFarm('farm-1');
    expect(row?.name, 'Nouvelle');
    expect(row?.updatedAt?.toUtc(), DateTime.utc(2026, 10, 20));
    final List<PendingChangeRow> outbox = await harness.database.getOutbox();
    expect(outbox.single.entity, 'farm');
    final Map<String, dynamic> data =
        jsonDecode(outbox.single.payload) as Map<String, dynamic>;
    expect(data['name'], 'Nouvelle');
  });
}
