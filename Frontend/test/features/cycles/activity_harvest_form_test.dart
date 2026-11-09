import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartagri/core/database/app_database.dart';
import 'package:smartagri/design_system/components/app_choice_chips.dart';
import 'package:smartagri/features/cycles/domain/activity_type.dart';
import 'package:smartagri/features/cycles/domain/harvest_quality.dart';
import 'package:smartagri/features/cycles/presentation/cycle_format.dart';

import 'cycles_test_app.dart';

void main() {
  testWidgets('rejects negative activity quantities and costs', (
    WidgetTester tester,
  ) async {
    await pumpCyclesApp(
      tester,
      initialLocation: '/cycles/c1/activities/new',
      seed: (AppDatabase database) async {
        await seedFarmAndPlot(database);
        await seedCycle(database);
      },
    );

    await tester.enterText(
      find.byKey(const Key('activity_quantity_field')),
      '-1',
    );
    await tester.enterText(find.byKey(const Key('activity_cost_field')), '-5');
    await tester.tap(find.byKey(const Key('activity_save')));
    await tester.pumpAndSettle();

    expect(
      find.text('La quantité doit être positive ou nulle.'),
      findsOneWidget,
    );
    expect(find.text('Le coût doit être positif ou nul.'), findsOneWidget);
  });

  testWidgets('accepts comma decimals and saves an activity', (
    WidgetTester tester,
  ) async {
    final CyclesHarness harness = await pumpCyclesApp(
      tester,
      initialLocation: '/cycles/c1/activities/new',
      seed: (AppDatabase database) async {
        await seedFarmAndPlot(database);
        await seedCycle(database);
      },
    );

    await tester.enterText(
      find.byKey(const Key('activity_product_field')),
      'Engrais',
    );
    await tester.enterText(
      find.byKey(const Key('activity_quantity_field')),
      '2,5',
    );
    await tester.enterText(find.byKey(const Key('activity_unit_field')), 'kg');
    await tester.enterText(
      find.byKey(const Key('activity_cost_field')),
      '1 500',
    );
    await tester.tap(find.byKey(const Key('activity_save')));
    await tester.pumpAndSettle();

    final List<FarmActivityRow> rows = await harness.database
        .getActiveActivities('c1');
    expect(rows, hasLength(1));
    expect(rows.single.productName, 'Engrais');
    expect(rows.single.quantity, 2.5);
    expect(rows.single.unit, 'kg');
    expect(rows.single.costXof, 1500);
    expect(rows.single.performedOn, _todayText());
  });

  testWidgets('loads the initial values when editing an activity', (
    WidgetTester tester,
  ) async {
    await pumpCyclesApp(
      tester,
      initialLocation: '/cycles/c1/activities/a1/edit',
      seed: (AppDatabase database) async {
        await seedFarmAndPlot(database);
        await seedCycle(database);
        await seedActivity(database);
      },
    );

    expect(find.text('Urée'), findsOneWidget);
    expect(find.text('2,5'), findsOneWidget);
    expect(find.text('kg'), findsOneWidget);
    expect(find.text('5000'), findsOneWidget);
    final AppChoiceChips<ActivityType> chips = tester
        .widget<AppChoiceChips<ActivityType>>(
          find.byKey(const Key('activity_type_chips')),
        );
    expect(chips.value, ActivityType.fertilizing);
  });

  testWidgets('refuses a sold quantity above the harvested quantity', (
    WidgetTester tester,
  ) async {
    await pumpCyclesApp(
      tester,
      initialLocation: '/cycles/c1/harvests/new',
      seed: (AppDatabase database) async {
        await seedFarmAndPlot(database);
        await seedCycle(database, status: 'growing');
      },
    );

    await tester.enterText(
      find.byKey(const Key('harvest_quantity_field')),
      '10,5',
    );
    await tester.enterText(find.byKey(const Key('harvest_sold_field')), '12');
    await tester.tap(find.byKey(const Key('harvest_save')));
    await tester.pumpAndSettle();

    expect(
      find.text(
        'La quantité vendue ne peut pas dépasser la quantité récoltée.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('shows the live estimated revenue and saves comma numbers', (
    WidgetTester tester,
  ) async {
    final CyclesHarness harness = await pumpCyclesApp(
      tester,
      initialLocation: '/cycles/c1/harvests/new',
      seed: (AppDatabase database) async {
        await seedFarmAndPlot(database);
        await seedCycle(database, status: 'growing');
      },
    );

    await tester.enterText(
      find.byKey(const Key('harvest_quantity_field')),
      '10,5',
    );
    await tester.enterText(find.byKey(const Key('harvest_sold_field')), '5,5');
    await tester.enterText(find.byKey(const Key('harvest_price_field')), '250');
    await tester.pump();

    expect(find.text('Revenu estimé : ${formatXof(1375)}'), findsOneWidget);

    await tester.tap(find.byKey(const Key('harvest_save')));
    await tester.pumpAndSettle();

    final List<HarvestRow> rows = await harness.database.getActiveHarvests(
      'c1',
    );
    expect(rows, hasLength(1));
    expect(rows.single.quantityKg, 10.5);
    expect(rows.single.soldKg, 5.5);
    expect(rows.single.avgPriceXofPerKg, 250);
  });

  testWidgets('closes a growing cycle when the box is checked', (
    WidgetTester tester,
  ) async {
    final CyclesHarness harness = await pumpCyclesApp(
      tester,
      initialLocation: '/cycles/c1/harvests/new',
      seed: (AppDatabase database) async {
        await seedFarmAndPlot(database);
        await seedCycle(database, status: 'growing');
      },
    );

    expect(find.byKey(const Key('harvest_close_cycle')), findsOneWidget);
    await tester.enterText(
      find.byKey(const Key('harvest_quantity_field')),
      '10',
    );
    await tester.tap(find.byKey(const Key('harvest_close_cycle')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('harvest_save')));
    await tester.pumpAndSettle();

    final CropCycleRow? cycle = await harness.database.getCycle('c1');
    expect(cycle?.status, 'harvested');
    expect(cycle?.harvestDate, _todayText());
  });

  testWidgets('hides the close box for a planned cycle', (
    WidgetTester tester,
  ) async {
    await pumpCyclesApp(
      tester,
      initialLocation: '/cycles/c1/harvests/new',
      seed: (AppDatabase database) async {
        await seedFarmAndPlot(database);
        await seedCycle(database, status: 'planned');
      },
    );

    expect(find.byKey(const Key('harvest_close_cycle')), findsNothing);
  });

  testWidgets('loads the initial values when editing a harvest', (
    WidgetTester tester,
  ) async {
    await pumpCyclesApp(
      tester,
      initialLocation: '/cycles/c1/harvests/h1/edit',
      seed: (AppDatabase database) async {
        await seedFarmAndPlot(database);
        await seedCycle(database, status: 'growing');
        await seedHarvest(database);
      },
    );

    expect(find.text('100'), findsOneWidget);
    expect(find.text('80'), findsOneWidget);
    expect(find.text('250'), findsOneWidget);
    final AppChoiceChips<HarvestQuality> chips = tester
        .widget<AppChoiceChips<HarvestQuality>>(
          find.byKey(const Key('harvest_quality_chips')),
        );
    expect(chips.value, HarvestQuality.a);
    expect(find.byKey(const Key('harvest_close_cycle')), findsNothing);
  });

  testWidgets('shows a not found state for a missing activity', (
    WidgetTester tester,
  ) async {
    await pumpCyclesApp(
      tester,
      initialLocation: '/cycles/c1/activities/missing/edit',
      seed: (AppDatabase database) async {
        await seedFarmAndPlot(database);
        await seedCycle(database);
      },
    );

    expect(find.text('Activité introuvable.'), findsOneWidget);
  });

  testWidgets('shows a not found state for a missing harvest', (
    WidgetTester tester,
  ) async {
    await pumpCyclesApp(
      tester,
      initialLocation: '/cycles/c1/harvests/missing/edit',
      seed: (AppDatabase database) async {
        await seedFarmAndPlot(database);
        await seedCycle(database);
      },
    );

    expect(find.text('Récolte introuvable.'), findsOneWidget);
  });
}

String _todayText() {
  final DateTime now = DateTime.now();
  final String month = now.month.toString().padLeft(2, '0');
  final String day = now.day.toString().padLeft(2, '0');
  return '${now.year}-$month-$day';
}
