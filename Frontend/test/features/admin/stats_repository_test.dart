import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartagri/core/network/api_exception.dart';
import 'package:smartagri/features/admin/data/stats_repository.dart';
import 'package:smartagri/features/admin/domain/overview.dart';
import 'package:smartagri/features/admin/domain/yield_cell.dart';

import '../../core/network/fake_http_adapter.dart';
import 'fake_stats_repository.dart';

Dio buildDio(FakeHttpAdapter adapter) {
  return Dio(BaseOptions(baseUrl: 'http://test.local'))
    ..httpClientAdapter = adapter;
}

Map<String, dynamic> overviewPayload() {
  return <String, dynamic>{
    'active_users_30d': 1250,
    'diagnostics_30d': 340,
    'tracked_area_ha': 12500.0,
    'adoption': <Map<String, dynamic>>[
      <String, dynamic>{
        'region': <String, dynamic>{'id': 1, 'name_fr': 'Niamey'},
        'masked': false,
        'users': 20,
        'plots': 40,
      },
    ],
  };
}

Map<String, dynamic> yieldsPayload() {
  return <String, dynamic>{
    'items': <Map<String, dynamic>>[
      <String, dynamic>{
        'crop': <String, dynamic>{'id': 1, 'code': 'MIL', 'name_fr': 'Mil'},
        'region': <String, dynamic>{'id': 1, 'name_fr': 'Maradi'},
        'season_year': 2026,
        'season_type': 'rainy',
        'masked': false,
        'cycles': 12,
        'farmers': 5,
        'avg_yield_kg_per_ha': 1250.0,
        'min_yield_kg_per_ha': 900.0,
        'max_yield_kg_per_ha': 1600.0,
      },
    ],
  };
}

void main() {
  test('loads the overview from the admin endpoint', () async {
    final FakeHttpAdapter adapter = FakeHttpAdapter(
      (RequestOptions options) async => jsonResponse(200, overviewPayload()),
    );
    final StatsRepository repository = StatsRepository(dio: buildDio(adapter));

    final Overview overview = await repository.getOverview();

    expect(adapter.requests.single.method, 'GET');
    expect(adapter.requests.single.path, '/admin/stats/overview');
    expect(overview.activeUsers30d, 1250);
    expect(overview.adoption.single.regionName, 'Niamey');
  });

  test('sends only the selected yield filters', () async {
    final FakeHttpAdapter adapter = FakeHttpAdapter(
      (RequestOptions options) async => jsonResponse(200, yieldsPayload()),
    );
    final StatsRepository repository = StatsRepository(dio: buildDio(adapter));

    await repository.getYields();
    expect(adapter.requests.last.queryParameters, isEmpty);

    await repository.getYields(cropId: 1);
    expect(adapter.requests.last.queryParameters, <String, dynamic>{
      'crop_id': 1,
    });

    final List<YieldCell> cells = await repository.getYields(
      cropId: 1,
      regionId: 2,
      seasonYear: 2026,
      seasonType: SeasonType.dry,
    );
    expect(adapter.requests.last.path, '/admin/stats/yields');
    expect(adapter.requests.last.queryParameters, <String, dynamic>{
      'crop_id': 1,
      'region_id': 2,
      'season_year': 2026,
      'season_type': 'dry',
    });
    expect(cells.single.cropName, 'Mil');
  });

  test('turns a 403 into an administration access error', () async {
    final FakeHttpAdapter adapter = FakeHttpAdapter(
      (RequestOptions options) async =>
          errorResponse(403, 'FORBIDDEN', 'Accès refusé pour ce rôle.'),
    );
    final StatsRepository repository = StatsRepository(dio: buildDio(adapter));

    await expectLater(
      repository.getOverview(),
      throwsA(
        isA<ApiException>()
            .having((ApiException error) => error.statusCode, 'status', 403)
            .having(
              (ApiException error) => error.message,
              'message',
              'Accès réservé à l\'administration.',
            ),
      ),
    );
  });

  test(
    'the providers pass the filter notifier values to the repository',
    () async {
      final FakeStatsRepository repository = FakeStatsRepository(
        yields: <YieldCell>[sampleYieldCell()],
      );
      final ProviderContainer container = ProviderContainer(
        overrides: [statsRepositoryProvider.overrideWithValue(repository)],
      );
      addTearDown(container.dispose);

      await container.read(overviewProvider.future);
      expect(repository.overviewCalls, 1);

      container.read(yieldsFilterProvider.notifier).setCrop(3);
      container.read(yieldsFilterProvider.notifier).setRegion(2);
      container.read(yieldsFilterProvider.notifier).setYear(2025);
      container.read(yieldsFilterProvider.notifier).setSeason(SeasonType.dry);
      await container.read(yieldsProvider.future);

      final RecordedYieldsQuery query = repository.yieldsCalls.last;
      expect(query.cropId, 3);
      expect(query.regionId, 2);
      expect(query.seasonYear, 2025);
      expect(query.seasonType, SeasonType.dry);
    },
  );
}
