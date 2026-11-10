import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:smartagri/core/database/app_database.dart';
import 'package:smartagri/core/sync/outbox.dart';
import 'package:smartagri/features/farms/data/farms_repository.dart';
import 'package:smartagri/features/farms/domain/farm.dart';
import 'package:smartagri/features/farms/domain/farms_exception.dart';
import 'package:smartagri/features/farms/domain/plot.dart';
import 'package:smartagri/features/farms/domain/plot_geometry.dart';

class Harness {
  Harness(this.database, this.outbox, this.repository);

  final AppDatabase database;
  final Outbox outbox;
  final LocalFarmsRepository repository;

  Future<void> close() async {
    await outbox.dispose();
    await database.close();
  }
}

Harness buildHarness() {
  final AppDatabase database = inMemoryAppDatabase();
  final Outbox outbox = Outbox(
    database,
    now: () => DateTime.utc(2026, 11, 8, 10),
  );
  return Harness(
    database,
    outbox,
    LocalFarmsRepository(database: database, outbox: outbox),
  );
}

Map<String, dynamic> payloadOf(PendingChangeRow row) {
  return jsonDecode(row.payload) as Map<String, dynamic>;
}

PlotGeometry sampleGeometry() {
  return PlotGeometry(<LatLng>[
    const LatLng(13.5, 2.1),
    const LatLng(13.5, 2.101),
    const LatLng(13.501, 2.101),
    const LatLng(13.501, 2.1),
  ]);
}

void main() {
  test('creates a plot with a geometry and a locally computed area', () async {
    final Harness harness = buildHarness();
    addTearDown(harness.close);
    await harness.database.upsertFarm('farm-1', 'Ferme');
    final PlotGeometry geometry = sampleGeometry();

    final Plot plot = await harness.repository.createPlot(
      'farm-1',
      'plot-1',
      'Nord',
      areaHa: 99,
      geometry: geometry,
    );

    final List<PendingChangeRow> outbox = await harness.database.getOutbox();
    final Map<String, dynamic> payload = payloadOf(outbox.single);
    expect(payload['geom'], geometry.toGeoJson());
    expect(payload['area_ha'], geometry.areaHectares());
    expect(plot.geometry, isNotNull);
    expect(plot.areaHa, geometry.areaHectares());
    final PlotRow? row = await harness.database.getPlot('plot-1');
    expect(row?.geom, jsonEncode(geometry.toGeoJson()));
    expect(row?.areaHa, geometry.areaHectares());
  });

  test('keeps the geometry when another field changes', () async {
    final Harness harness = buildHarness();
    addTearDown(harness.close);
    await harness.database.upsertFarm('farm-1', 'Ferme');
    final PlotGeometry geometry = sampleGeometry();
    await harness.repository.createPlot(
      'farm-1',
      'plot-1',
      'Nord',
      geometry: geometry,
    );

    final Plot plot = await harness.repository.updatePlot(
      'plot-1',
      name: 'Sud',
    );

    final List<PendingChangeRow> outbox = await harness.database.getOutbox();
    final Map<String, dynamic> payload = payloadOf(outbox.single);
    expect(payload['geom'], geometry.toGeoJson());
    expect(payload['area_ha'], geometry.areaHectares());
    expect(plot.name, 'Sud');
    expect(plot.geometry, isNotNull);
    expect((await harness.database.getPlot('plot-1'))?.geom, isNotNull);
  });

  test('deletes the geometry and sends the manual area', () async {
    final Harness harness = buildHarness();
    addTearDown(harness.close);
    await harness.database.upsertFarm('farm-1', 'Ferme');
    await harness.repository.createPlot(
      'farm-1',
      'plot-1',
      'Nord',
      geometry: sampleGeometry(),
    );

    final Plot plot = await harness.repository.updatePlot(
      'plot-1',
      geometry: null,
      areaHa: 4,
    );

    final List<PendingChangeRow> outbox = await harness.database.getOutbox();
    final Map<String, dynamic> payload = payloadOf(outbox.single);
    expect(payload['geom'], isNull);
    expect(payload['area_ha'], 4);
    expect(plot.geometry, isNull);
    expect(plot.areaHa, 4);
    expect((await harness.database.getPlot('plot-1'))?.geom, isNull);
  });

  test('refuses an invalid geometry before writing anything', () async {
    final Harness harness = buildHarness();
    addTearDown(harness.close);
    await harness.database.upsertFarm('farm-1', 'Ferme');
    final PlotGeometry invalid = PlotGeometry(<LatLng>[
      const LatLng(13.5, 2.1),
      const LatLng(13.5, 2.2),
    ]);

    await expectLater(
      harness.repository.createPlot(
        'farm-1',
        'plot-1',
        'Nord',
        geometry: invalid,
      ),
      throwsA(
        isA<FarmsDomainException>().having(
          (FarmsDomainException error) => error.code,
          'code',
          'invalid_geometry',
        ),
      ),
    );

    expect(await harness.database.getOutbox(), isEmpty);
    expect(await harness.database.getPlot('plot-1'), isNull);
  });

  test('creates, keeps and deletes the farm location', () async {
    final Harness harness = buildHarness();
    addTearDown(harness.close);
    final Map<String, dynamic> location = pointToGeoJson(
      const LatLng(13.5, 2.1),
    );

    final Farm farm = await harness.repository.createFarm(
      'farm-1',
      'Ferme',
      location: location,
    );

    Map<String, dynamic> payload = payloadOf(
      (await harness.database.getOutbox()).single,
    );
    expect(payload['location'], location);
    expect(farm.location, location);
    expect((await harness.database.getFarm('farm-1'))?.location, isNotNull);

    await harness.repository.updateFarm('farm-1', name: 'Nouvelle');
    payload = payloadOf((await harness.database.getOutbox()).single);
    expect(payload['location'], location);

    final Farm cleared = await harness.repository.updateFarm(
      'farm-1',
      location: null,
    );
    payload = payloadOf((await harness.database.getOutbox()).single);
    expect(payload['location'], isNull);
    expect(cleared.location, isNull);
    expect((await harness.database.getFarm('farm-1'))?.location, isNull);
  });

  test('refuses a farm location outside WGS84 bounds', () async {
    final Harness harness = buildHarness();
    addTearDown(harness.close);

    await expectLater(
      harness.repository.createFarm(
        'farm-1',
        'Ferme',
        location: <String, dynamic>{
          'type': 'Point',
          'coordinates': <double>[200, 13.5],
        },
      ),
      throwsA(
        isA<FarmsDomainException>().having(
          (FarmsDomainException error) => error.code,
          'code',
          'invalid_location',
        ),
      ),
    );

    expect(await harness.database.getOutbox(), isEmpty);
    expect(await harness.database.getFarm('farm-1'), isNull);
  });
}
