import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartagri/core/database/app_database.dart';
import 'package:smartagri/core/sync/outbox.dart';
import 'package:smartagri/core/sync/sync_service.dart';
import 'package:smartagri/features/farms/data/farms_repository.dart';

import '../network/recording_adapter.dart';

class GeometryHarness {
  GeometryHarness({
    required this.database,
    required this.service,
    required this.outbox,
    required this.repository,
    required this.adapter,
    required this.pushes,
  });

  final AppDatabase database;
  final SyncService service;
  final Outbox outbox;
  final LocalFarmsRepository repository;
  final RecordingAdapter adapter;
  final List<Map<String, dynamic>> pushes;

  Future<void> close() async {
    await outbox.dispose();
    await database.close();
  }
}

List<Map<String, dynamic>> changesOf(RecordedRequest request) {
  final Object? data = request.data;
  if (data is! Map) {
    return <Map<String, dynamic>>[];
  }
  final Object? changes = data['changes'];
  if (changes is! List) {
    return <Map<String, dynamic>>[];
  }
  return changes
      .whereType<Map>()
      .map((Map item) => Map<String, dynamic>.from(item))
      .toList();
}

Map<String, dynamic> appliedResults(List<Map<String, dynamic>> changes) {
  return <String, dynamic>{
    'results': changes
        .map(
          (Map<String, dynamic> change) => <String, dynamic>{
            'id': change['id'],
            'entity': change['entity'],
            'status': 'applied',
            'server_updated_at': '2026-11-08T10:00:05Z',
            'error': null,
          },
        )
        .toList(),
  };
}

GeometryHarness buildHarness(
  Future<ResponseBody> Function(RequestOptions, RecordedRequest) pull,
) {
  final AppDatabase database = inMemoryAppDatabase();
  final List<Map<String, dynamic>> pushes = <Map<String, dynamic>>[];
  final RecordingAdapter adapter = RecordingAdapter((
    RequestOptions options,
    RecordedRequest request,
  ) async {
    if (options.path == '/sync/push') {
      final List<Map<String, dynamic>> changes = changesOf(request);
      pushes.addAll(changes);
      return body(200, appliedResults(changes));
    }
    return pull(options, request);
  });
  final Dio dio = Dio(BaseOptions(baseUrl: 'http://test.local/api/v1'));
  dio.httpClientAdapter = adapter;
  final DateTime now = DateTime.utc(2026, 11, 8, 10);
  final Outbox outbox = Outbox(database, now: () => now);
  return GeometryHarness(
    database: database,
    service: SyncService(
      database: database,
      dio: dio,
      outbox: outbox,
      now: () => now,
    ),
    outbox: outbox,
    repository: LocalFarmsRepository(database: database, outbox: outbox),
    adapter: adapter,
    pushes: pushes,
  );
}

Future<ResponseBody> pullOnce(
  Map<String, dynamic> change,
  RequestOptions options,
  RecordedRequest request,
) async {
  return body(200, <String, dynamic>{
    'changes': <Map<String, dynamic>>[change],
    'next_cursor': null,
    'has_more': false,
  });
}

Future<ResponseBody> emptyPull(
  RequestOptions options,
  RecordedRequest request,
) async {
  return body(200, <String, dynamic>{
    'changes': <dynamic>[],
    'next_cursor': null,
    'has_more': false,
  });
}

const Map<String, dynamic> plotGeom = <String, dynamic>{
  'type': 'Polygon',
  'coordinates': <dynamic>[
    <dynamic>[
      <dynamic>[2.1, 13.5],
      <dynamic>[2.2, 13.5],
      <dynamic>[2.2, 13.6],
      <dynamic>[2.1, 13.5],
    ],
  ],
};

const Map<String, dynamic> farmLocation = <String, dynamic>{
  'type': 'Point',
  'coordinates': <dynamic>[2.1, 13.5],
};

Map<String, dynamic> plotChange(Object? geom) {
  return <String, dynamic>{
    'entity': 'plot',
    'id': 'p1',
    'data': <String, dynamic>{
      'farm_id': 'f1',
      'name': 'Parcelle',
      'area_ha': 2.5,
      'geom': geom,
      'soil_type': 'loam',
      'irrigation': 'drip',
    },
    'updated_at': '2026-11-08T09:00:00Z',
    'deleted_at': null,
  };
}

Map<String, dynamic> farmChange(Object? location) {
  return <String, dynamic>{
    'entity': 'farm',
    'id': 'f1',
    'data': <String, dynamic>{
      'name': 'Ferme',
      'village': 'Saga',
      'admin_area_id': 1,
      'location': location,
    },
    'updated_at': '2026-11-08T09:00:00Z',
    'deleted_at': null,
  };
}

void main() {
  test('a pulled plot keeps its geom when its name changes', () async {
    int pulls = 0;
    final GeometryHarness harness = buildHarness((
      RequestOptions options,
      RecordedRequest request,
    ) async {
      pulls++;
      if (pulls == 1) {
        return pullOnce(plotChange(plotGeom), options, request);
      }
      return emptyPull(options, request);
    });
    addTearDown(harness.close);

    await harness.service.syncNow();
    final PlotRow? pulled = await harness.database.getPlot('p1');
    expect(pulled?.geom, jsonEncode(plotGeom));

    await harness.repository.updatePlot('p1', name: 'Nouveau nom');
    await harness.service.syncNow();

    final Map<String, dynamic> pushed = harness.pushes.last;
    final Map<String, dynamic> data = pushed['data'] as Map<String, dynamic>;
    expect(data['geom'], plotGeom);
  });

  test('a pulled farm keeps its location when its name changes', () async {
    int pulls = 0;
    final GeometryHarness harness = buildHarness((
      RequestOptions options,
      RecordedRequest request,
    ) async {
      pulls++;
      if (pulls == 1) {
        return pullOnce(farmChange(farmLocation), options, request);
      }
      return emptyPull(options, request);
    });
    addTearDown(harness.close);

    await harness.service.syncNow();
    final FarmRow? pulled = await harness.database.getFarm('f1');
    expect(pulled?.location, jsonEncode(farmLocation));

    await harness.repository.updateFarm('f1', name: 'Nouveau nom');
    await harness.service.syncNow();

    final Map<String, dynamic> pushed = harness.pushes.last;
    final Map<String, dynamic> data = pushed['data'] as Map<String, dynamic>;
    expect(data['location'], farmLocation);
  });

  test('a local creation sends a null geom and a null location', () async {
    final GeometryHarness harness = buildHarness(emptyPull);
    addTearDown(harness.close);

    await harness.repository.createFarm('f1', 'Ferme');
    await harness.repository.createPlot('f1', 'p1', 'Parcelle');

    final List<PendingChangeRow> outbox = await harness.database.getOutbox();
    final Map<String, dynamic> farm = jsonDecode(
      outbox.firstWhere((PendingChangeRow row) => row.entity == 'farm').payload,
    ) as Map<String, dynamic>;
    final Map<String, dynamic> plot = jsonDecode(
      outbox.firstWhere((PendingChangeRow row) => row.entity == 'plot').payload,
    ) as Map<String, dynamic>;
    expect(farm['location'], isNull);
    expect(plot['geom'], isNull);
  });

  test('a later pull without a geom clears the local geom', () async {
    int pulls = 0;
    final GeometryHarness harness = buildHarness((
      RequestOptions options,
      RecordedRequest request,
    ) async {
      pulls++;
      if (pulls == 1) {
        return pullOnce(plotChange(plotGeom), options, request);
      }
      return pullOnce(plotChange(null), options, request);
    });
    addTearDown(harness.close);

    await harness.service.syncNow();
    expect((await harness.database.getPlot('p1'))?.geom, jsonEncode(plotGeom));

    await harness.service.syncNow();
    expect((await harness.database.getPlot('p1'))?.geom, isNull);
  });

  test('a pulled upsert clears a local soft delete', () async {
    final GeometryHarness harness = buildHarness((
      RequestOptions options,
      RecordedRequest request,
    ) async {
      return pullOnce(farmChange(farmLocation), options, request);
    });
    addTearDown(harness.close);
    await harness.database.upsertFarm(
      'f1',
      'Locale',
      updatedAt: DateTime.utc(2026, 11, 8, 9),
    );
    await harness.database.softDeleteFarm('f1');

    await harness.service.syncNow();

    final FarmRow? row = await harness.database.getFarm('f1');
    expect(row?.deletedAt, isNull);
    expect(row?.name, 'Ferme');
  });

  test('migrates a version 1 database and clears the cursor history', () async {
    final Directory directory = await Directory.systemTemp.createTemp(
      'smartagri_migration',
    );
    addTearDown(() => directory.delete(recursive: true));
    final File file = File('${directory.path}/smartagri.sqlite');

    final AppDatabase version1 = AppDatabase.forTesting(NativeDatabase(file));
    await version1.customStatement('ALTER TABLE farms DROP COLUMN location');
    await version1.customStatement('ALTER TABLE plots DROP COLUMN geom');
    await version1.customStatement('PRAGMA user_version = 1');
    await version1.writeMeta('cursor_history', 'ancien-curseur');
    await version1.close();

    final AppDatabase migrated = AppDatabase.forTesting(NativeDatabase(file));
    addTearDown(migrated.close);

    final farmColumns = await migrated
        .customSelect("PRAGMA table_info('farms')")
        .get();
    final plotColumns = await migrated
        .customSelect("PRAGMA table_info('plots')")
        .get();
    expect(
      farmColumns.map((row) => row.read<String>('name')),
      contains('location'),
    );
    expect(
      plotColumns.map((row) => row.read<String>('name')),
      contains('geom'),
    );
    expect(await migrated.readMeta('cursor_history'), isNull);
  });
}
