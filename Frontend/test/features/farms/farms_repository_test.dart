import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartagri/core/network/api_exception.dart';
import 'package:smartagri/features/farms/data/farms_repository.dart';
import 'package:smartagri/features/farms/domain/farm.dart';
import 'package:smartagri/features/farms/domain/plot.dart';

import '../../core/network/fake_http_adapter.dart';

Map<String, dynamic> farmJson(
  String id,
  String name, {
  String? village,
  int? adminAreaId,
}) {
  return <String, dynamic>{
    'id': id,
    'owner_id': 'owner-1',
    'organization_id': null,
    'name': name,
    'village': village,
    'admin_area_id': adminAreaId,
    'location': null,
    'created_at': '2026-10-20T10:00:00Z',
    'updated_at': '2026-10-21T10:00:00Z',
  };
}

Map<String, dynamic> plotJson(
  String id,
  String farmId,
  String name, {
  Object? areaHa,
  String? soilType,
  String? irrigation,
}) {
  return <String, dynamic>{
    'id': id,
    'farm_id': farmId,
    'name': name,
    'area_ha': areaHa,
    'geom': null,
    'soil_type': soilType,
    'irrigation': irrigation,
    'created_at': '2026-10-20T10:00:00Z',
    'updated_at': '2026-10-21T10:00:00Z',
  };
}

Dio buildDio(FakeHttpAdapter adapter) {
  return Dio(BaseOptions(baseUrl: 'http://test.local'))
    ..httpClientAdapter = adapter;
}

Map<String, dynamic> requestData(RequestSnapshot request) {
  return Map<String, dynamic>.from(request.data as Map);
}

void main() {
  test('parses a decimal area received as a string or a number', () {
    final Plot fromString = Plot.fromJson(
      plotJson('plot-1', 'farm-1', 'Nord', areaHa: '2.50'),
    );
    final Plot fromNumber = Plot.fromJson(
      plotJson('plot-2', 'farm-1', 'Sud', areaHa: 3),
    );
    final Plot fromComma = Plot.fromJson(
      plotJson('plot-3', 'farm-1', 'Est', areaHa: '1,75'),
    );

    expect(fromString.areaHa, 2.5);
    expect(fromNumber.areaHa, 3.0);
    expect(fromComma.areaHa, 1.75);
  });

  test('parses the soil and irrigation enums', () {
    final Plot plot = Plot.fromJson(
      plotJson(
        'plot-1',
        'farm-1',
        'Nord',
        soilType: 'laterite',
        irrigation: 'gravity',
      ),
    );
    final Plot unknown = Plot.fromJson(
      plotJson('plot-2', 'farm-1', 'Sud', soilType: 'unknown'),
    );

    expect(plot.soilType, SoilType.laterite);
    expect(plot.irrigation, IrrigationType.gravity);
    expect(unknown.soilType, isNull);
    expect(unknown.irrigation, isNull);
  });

  test('reads every farm page with the cursor', () async {
    final FakeHttpAdapter adapter = FakeHttpAdapter((
      RequestOptions options,
    ) async {
      if (options.queryParameters['cursor'] == null) {
        return jsonResponse(200, <String, dynamic>{
          'items': <Map<String, dynamic>>[farmJson('farm-1', 'Ferme 1')],
          'next_cursor': 'cursor-2',
        });
      }
      return jsonResponse(200, <String, dynamic>{
        'items': <Map<String, dynamic>>[farmJson('farm-2', 'Ferme 2')],
        'next_cursor': null,
      });
    });
    final HttpFarmsRepository repository = HttpFarmsRepository(
      dio: buildDio(adapter),
    );

    final List<Farm> farms = await repository.listFarms();

    expect(farms.map((Farm farm) => farm.id), <String>['farm-1', 'farm-2']);
    expect(adapter.requests, hasLength(2));
    expect(adapter.requests.first.queryParameters['limit'], 100);
    expect(
      adapter.requests.first.queryParameters.containsKey('cursor'),
      isFalse,
    );
    expect(adapter.requests.last.queryParameters['cursor'], 'cursor-2');
  });

  test('creates a farm with its id and provided fields only', () async {
    final FakeHttpAdapter adapter = FakeHttpAdapter(
      (RequestOptions options) async =>
          jsonResponse(201, farmJson('farm-1', 'Ferme')),
    );
    final HttpFarmsRepository repository = HttpFarmsRepository(
      dio: buildDio(adapter),
    );

    await repository.createFarm(
      'farm-1',
      'Ferme',
      village: 'Saga',
      adminAreaId: 1,
    );
    await repository.createFarm('farm-2', 'Autre');

    final Map<String, dynamic> complete = requestData(adapter.requests.first);
    final Map<String, dynamic> minimal = requestData(adapter.requests.last);
    expect(complete, <String, dynamic>{
      'id': 'farm-1',
      'name': 'Ferme',
      'village': 'Saga',
      'admin_area_id': 1,
    });
    expect(minimal, <String, dynamic>{'id': 'farm-2', 'name': 'Autre'});
  });

  test('patches only the modified farm fields', () async {
    final FakeHttpAdapter adapter = FakeHttpAdapter(
      (RequestOptions options) async =>
          jsonResponse(200, farmJson('farm-1', 'Ferme')),
    );
    final HttpFarmsRepository repository = HttpFarmsRepository(
      dio: buildDio(adapter),
    );

    await repository.updateFarm('farm-1', name: 'Nouveau nom');
    await repository.updateFarm('farm-1', village: null);

    expect(requestData(adapter.requests.first), <String, dynamic>{
      'name': 'Nouveau nom',
    });
    expect(requestData(adapter.requests.last), <String, dynamic>{
      'village': null,
    });
  });

  test('creates a plot with the id, decimal area and enums', () async {
    final FakeHttpAdapter adapter = FakeHttpAdapter(
      (RequestOptions options) async =>
          jsonResponse(201, plotJson('plot-1', 'farm-1', 'Nord', areaHa: 2.5)),
    );
    final HttpFarmsRepository repository = HttpFarmsRepository(
      dio: buildDio(adapter),
    );

    await repository.createPlot(
      'farm-1',
      'plot-1',
      'Nord',
      areaHa: 2.5,
      soilType: SoilType.loam,
      irrigation: IrrigationType.drip,
    );

    expect(requestData(adapter.requests.single), <String, dynamic>{
      'id': 'plot-1',
      'name': 'Nord',
      'area_ha': 2.5,
      'soil_type': 'loam',
      'irrigation': 'drip',
    });
  });

  test('patches only the modified plot fields', () async {
    final FakeHttpAdapter adapter = FakeHttpAdapter(
      (RequestOptions options) async =>
          jsonResponse(200, plotJson('plot-1', 'farm-1', 'Nord')),
    );
    final HttpFarmsRepository repository = HttpFarmsRepository(
      dio: buildDio(adapter),
    );

    await repository.updatePlot('plot-1', name: 'Sud');
    await repository.updatePlot(
      'plot-1',
      areaHa: null,
      soilType: SoilType.clay,
    );

    expect(requestData(adapter.requests.first), <String, dynamic>{
      'name': 'Sud',
    });
    expect(requestData(adapter.requests.last), <String, dynamic>{
      'area_ha': null,
      'soil_type': 'clay',
    });
  });

  test('reads a plot and sends errors as ApiException', () async {
    final FakeHttpAdapter adapter = FakeHttpAdapter((
      RequestOptions options,
    ) async {
      if (options.path == '/plots/plot-1') {
        return jsonResponse(
          200,
          plotJson('plot-1', 'farm-1', 'Nord', areaHa: '2.50'),
        );
      }
      return errorResponse(404, 'NOT_FOUND', 'Parcelle introuvable.');
    });
    final HttpFarmsRepository repository = HttpFarmsRepository(
      dio: buildDio(adapter),
    );

    final Plot plot = await repository.getPlot('plot-1');

    expect(plot.areaHa, 2.5);
    await expectLater(
      repository.getPlot('plot-2'),
      throwsA(
        isA<ApiException>()
            .having((ApiException error) => error.code, 'code', 'NOT_FOUND')
            .having(
              (ApiException error) => error.statusCode,
              'statusCode',
              404,
            ),
      ),
    );
  });

  test('lists the plots of a farm', () async {
    final FakeHttpAdapter adapter = FakeHttpAdapter(
      (RequestOptions options) async => jsonResponse(200, <String, dynamic>{
        'items': <Map<String, dynamic>>[
          plotJson('plot-1', 'farm-1', 'Nord', areaHa: '2.5'),
        ],
        'next_cursor': null,
      }),
    );
    final HttpFarmsRepository repository = HttpFarmsRepository(
      dio: buildDio(adapter),
    );

    final List<Plot> plots = await repository.listPlots('farm-1');

    expect(plots.single.id, 'plot-1');
    expect(adapter.requests.single.path, '/farms/farm-1/plots');
  });
}
