import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smartagri/core/network/api_exception.dart';
import 'package:smartagri/features/catalog/data/catalog_repository.dart';
import 'package:smartagri/features/catalog/domain/admin_area.dart';
import 'package:smartagri/features/catalog/domain/crop.dart';

import '../../core/network/fake_http_adapter.dart';

Map<String, dynamic> cropJson(int id, String name) {
  return <String, dynamic>{
    'id': id,
    'code': 'crop_$id',
    'name_fr': name,
    'name_ha': null,
    'name_dje': null,
    'category': 'cereal',
    'cycle_days': 90,
  };
}

Map<String, dynamic> areaJson(int id, String name) {
  return <String, dynamic>{
    'id': id,
    'parent_id': null,
    'level': 'region',
    'name': name,
    'code': 'R$id',
  };
}

String cachePayload(List<Map<String, dynamic>> items) {
  return jsonEncode(<String, dynamic>{
    'cached_at': '2026-10-20T10:00:00Z',
    'items': items,
  });
}

Dio buildDio(FakeHttpAdapter adapter) {
  return Dio(BaseOptions(baseUrl: 'http://test.local'))
    ..httpClientAdapter = adapter;
}

void main() {
  test('returns the cache immediately when it exists', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      CatalogRepository.cropsKey: cachePayload(<Map<String, dynamic>>[
        cropJson(1, 'Mil'),
      ]),
    });
    final SharedPreferences preferences = await SharedPreferences.getInstance();
    final FakeHttpAdapter adapter = FakeHttpAdapter(
      (RequestOptions options) async =>
          jsonResponse(200, <Map<String, dynamic>>[cropJson(1, 'Mil frais')]),
    );
    final CatalogRepository repository = CatalogRepository(
      dio: buildDio(adapter),
      preferences: preferences,
    );

    final List<Crop> crops = await repository.getCrops();

    expect(crops.single.nameFr, 'Mil');
    await Future<void>.delayed(const Duration(milliseconds: 10));
    expect(adapter.requests, hasLength(1));
  });

  test('fetches the network and stores the cache when it is absent', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final SharedPreferences preferences = await SharedPreferences.getInstance();
    final FakeHttpAdapter adapter = FakeHttpAdapter(
      (RequestOptions options) async =>
          jsonResponse(200, <Map<String, dynamic>>[cropJson(2, 'Sorgho')]),
    );
    final CatalogRepository repository = CatalogRepository(
      dio: buildDio(adapter),
      preferences: preferences,
    );

    final List<Crop> crops = await repository.getCrops();

    expect(crops.single.nameFr, 'Sorgho');
    final String? raw = preferences.getString(CatalogRepository.cropsKey);
    expect(raw, isNotNull);
    final Map<String, dynamic> decoded =
        jsonDecode(raw!) as Map<String, dynamic>;
    expect(decoded['cached_at'], isA<String>());
    expect((decoded['items'] as List).single['name_fr'], 'Sorgho');
  });

  test('returns the cache when the refresh network call fails', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      CatalogRepository.cropsKey: cachePayload(<Map<String, dynamic>>[
        cropJson(1, 'Mil'),
      ]),
    });
    final SharedPreferences preferences = await SharedPreferences.getInstance();
    final FakeHttpAdapter adapter = FakeHttpAdapter(
      (RequestOptions options) async => throw DioException(
        requestOptions: options,
        type: DioExceptionType.connectionError,
      ),
    );
    final CatalogRepository repository = CatalogRepository(
      dio: buildDio(adapter),
      preferences: preferences,
    );

    final List<Crop> crops = await repository.refreshCrops();

    expect(crops.single.nameFr, 'Mil');
  });

  test('rethrows when there is no cache and the network fails', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final SharedPreferences preferences = await SharedPreferences.getInstance();
    final FakeHttpAdapter adapter = FakeHttpAdapter(
      (RequestOptions options) async => throw DioException(
        requestOptions: options,
        type: DioExceptionType.connectionError,
      ),
    );
    final CatalogRepository repository = CatalogRepository(
      dio: buildDio(adapter),
      preferences: preferences,
    );

    await expectLater(repository.getCrops(), throwsA(isA<ApiException>()));
  });

  test('refreshes the data and replaces the cache', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      CatalogRepository.cropsKey: cachePayload(<Map<String, dynamic>>[
        cropJson(1, 'Ancien'),
      ]),
    });
    final SharedPreferences preferences = await SharedPreferences.getInstance();
    final FakeHttpAdapter adapter = FakeHttpAdapter(
      (RequestOptions options) async =>
          jsonResponse(200, <Map<String, dynamic>>[cropJson(1, 'Nouveau')]),
    );
    final CatalogRepository repository = CatalogRepository(
      dio: buildDio(adapter),
      preferences: preferences,
    );

    final List<Crop> crops = await repository.refreshCrops();

    expect(crops.single.nameFr, 'Nouveau');
    expect(
      preferences.getString(CatalogRepository.cropsKey),
      contains('Nouveau'),
    );
  });

  test('combines paginated envelopes and parses admin areas', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final SharedPreferences preferences = await SharedPreferences.getInstance();
    final FakeHttpAdapter adapter = FakeHttpAdapter((
      RequestOptions options,
    ) async {
      if (options.path == '/admin-areas') {
        return jsonResponse(200, <Map<String, dynamic>>[areaJson(1, 'Niamey')]);
      }
      final int page = (options.queryParameters['page'] as int?) ?? 1;
      if (page == 1) {
        return jsonResponse(200, <String, dynamic>{
          'items': <Map<String, dynamic>>[cropJson(1, 'Mil')],
          'has_next': true,
        });
      }
      return jsonResponse(200, <String, dynamic>{
        'items': <Map<String, dynamic>>[cropJson(2, 'Sorgho')],
        'has_next': false,
      });
    });
    final CatalogRepository repository = CatalogRepository(
      dio: buildDio(adapter),
      preferences: preferences,
    );

    final List<Crop> crops = await repository.getCrops();
    final List<AdminArea> areas = await repository.getAdminAreas();

    expect(crops.map((Crop crop) => crop.code), <String>['crop_1', 'crop_2']);
    expect(areas.single.name, 'Niamey');
  });
}
