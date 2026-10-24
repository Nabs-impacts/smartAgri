import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartagri/features/farms/data/farms_providers.dart';
import 'package:smartagri/features/farms/domain/farm.dart';
import 'package:smartagri/features/farms/domain/plot.dart';
import 'package:smartagri/features/profile/data/me_repository.dart';

import '../app_test_utils.dart';
import 'fake_farms_repository.dart';

void main() {
  test('refreshes me after creating a plot', () async {
    final FakeFarmsRepository farms = FakeFarmsRepository(
      farms: <Farm>[sampleFarm()],
      plots: <String, List<Plot>>{'farm-1': <Plot>[]},
    );
    final FakeMeRepository me = FakeMeRepository(sampleMeData());
    final ProviderContainer container = await buildTestContainer(
      meRepository: me,
      farmsRepository: farms,
    );
    await container.read(farmPlotsProvider('farm-1').future);
    await container.read(meProvider.future);
    final int before = me.getMeCalls;

    await container
        .read(farmPlotsProvider('farm-1').notifier)
        .createPlot('plot-1', 'Nord', areaHa: 2.5);

    expect(me.getMeCalls, before + 1);
    expect(container.read(farmPlotsProvider('farm-1')).value, hasLength(1));
    expect(farms.lastPlotId, 'plot-1');
  });

  test('refreshes me after deleting a plot', () async {
    final FakeFarmsRepository farms = FakeFarmsRepository(
      farms: <Farm>[sampleFarm()],
      plots: <String, List<Plot>>{
        'farm-1': <Plot>[samplePlot()],
      },
    );
    final FakeMeRepository me = FakeMeRepository(sampleMeData());
    final ProviderContainer container = await buildTestContainer(
      meRepository: me,
      farmsRepository: farms,
    );
    await container.read(farmPlotsProvider('farm-1').future);
    await container.read(meProvider.future);
    final int before = me.getMeCalls;

    await container
        .read(farmPlotsProvider('farm-1').notifier)
        .deletePlot('plot-1');

    expect(me.getMeCalls, before + 1);
    expect(container.read(farmPlotsProvider('farm-1')).value, isEmpty);
  });

  test('creates and deletes a farm while refreshing the list', () async {
    final FakeFarmsRepository farms = FakeFarmsRepository();
    final ProviderContainer container = await buildTestContainer(
      meRepository: FakeMeRepository(sampleMeData()),
      farmsRepository: farms,
    );
    await container.read(farmsProvider.future);

    await container
        .read(farmsProvider.notifier)
        .createFarm('farm-1', 'Ferme', village: 'Saga', adminAreaId: 1);

    expect(container.read(farmsProvider).value, hasLength(1));

    await container.read(farmsProvider.notifier).deleteFarm('farm-1');

    expect(container.read(farmsProvider).value, isEmpty);
  });
}
