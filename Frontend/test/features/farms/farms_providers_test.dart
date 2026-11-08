import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartagri/core/database/app_database.dart';
import 'package:smartagri/features/farms/data/farms_providers.dart';
import 'package:smartagri/features/farms/domain/farm.dart';
import 'package:smartagri/features/farms/domain/plot.dart';
import 'package:smartagri/features/profile/data/me_repository.dart';

import '../app_test_utils.dart';
import 'farms_test_data.dart';

void main() {
  test('creates and deletes a farm while updating the list', () async {
    final AppDatabase database = inMemoryAppDatabase();
    addTearDown(database.close);
    final ProviderContainer container = await buildTestContainer(
      meRepository: FakeMeRepository(sampleMeData()),
      database: database,
    );
    await container.read(farmsProvider.future);

    await container
        .read(farmsProvider.notifier)
        .createFarm('farm-1', 'Ferme', village: 'Saga', adminAreaId: 1);
    await pumpEventQueue();

    expect(container.read(farmsProvider).value, hasLength(1));
    expect((await database.getFarm('farm-1'))?.updatedAt, isNull);

    await container.read(farmsProvider.notifier).deleteFarm('farm-1');
    await pumpEventQueue();

    expect(container.read(farmsProvider).value, isEmpty);
  });

  test('updates the farms list when the database receives a pull', () async {
    final AppDatabase database = inMemoryAppDatabase();
    addTearDown(database.close);
    final ProviderContainer container = await buildTestContainer(
      meRepository: FakeMeRepository(sampleMeData()),
      database: database,
    );
    await container.read(farmsProvider.future);
    expect(container.read(farmsProvider).value, isEmpty);

    await database.upsertFarm(
      'farm-1',
      'Ferme distante',
      updatedAt: DateTime.utc(2026, 11, 8, 9),
    );
    await pumpEventQueue();

    expect(container.read(farmsProvider).value, hasLength(1));
    expect(container.read(farmsProvider).value?.single.name, 'Ferme distante');
  });

  test('creates and deletes a plot without refreshing the profile', () async {
    final AppDatabase database = inMemoryAppDatabase();
    addTearDown(database.close);
    final FakeMeRepository me = FakeMeRepository(sampleMeData());
    final ProviderContainer container = await buildTestContainer(
      meRepository: me,
      database: database,
    );
    await database.upsertFarm(
      'farm-1',
      'Ferme',
      updatedAt: DateTime.utc(2026, 11, 8, 9),
    );
    await container.read(farmPlotsProvider('farm-1').future);
    await container.read(meProvider.future);
    final int before = me.getMeCalls;

    await container
        .read(farmPlotsProvider('farm-1').notifier)
        .createPlot('plot-1', 'Nord', areaHa: 2.5);
    await pumpEventQueue();

    expect(me.getMeCalls, before);
    expect(container.read(farmPlotsProvider('farm-1')).value, hasLength(1));

    await container
        .read(farmPlotsProvider('farm-1').notifier)
        .deletePlot('plot-1');
    await pumpEventQueue();

    expect(me.getMeCalls, before);
    expect(container.read(farmPlotsProvider('farm-1')).value, isEmpty);
  });

  test('updates the plot list when the database receives a pull', () async {
    final AppDatabase database = inMemoryAppDatabase();
    addTearDown(database.close);
    final ProviderContainer container = await buildTestContainer(
      meRepository: FakeMeRepository(sampleMeData()),
      database: database,
    );
    await database.upsertFarm(
      'farm-1',
      'Ferme',
      updatedAt: DateTime.utc(2026, 11, 8, 9),
    );
    await container.read(farmPlotsProvider('farm-1').future);
    expect(container.read(farmPlotsProvider('farm-1')).value, isEmpty);

    await database.upsertPlot(
      'plot-1',
      'farm-1',
      'Parcelle distante',
      updatedAt: DateTime.utc(2026, 11, 8, 9),
    );
    await pumpEventQueue();

    final List<Plot>? plots = container.read(farmPlotsProvider('farm-1')).value;
    expect(plots, hasLength(1));
    expect(plots?.single.name, 'Parcelle distante');
  });

  test('watches a plot and its farm through the local database', () async {
    final AppDatabase database = inMemoryAppDatabase();
    addTearDown(database.close);
    final ProviderContainer container = await buildTestContainer(
      meRepository: FakeMeRepository(sampleMeData()),
      database: database,
    );
    await seedFarm(database, sampleFarm());
    await seedPlot(database, samplePlot());
    final Farm? farm = await container
        .read(farmsProvider.future)
        .then((List<Farm> farms) => farms.single);
    final Plot plot = await container.read(plotProvider('plot-1').future);

    expect(farm?.name, 'Ferme du fleuve');
    expect(plot.name, 'Parcelle nord');
  });
}
