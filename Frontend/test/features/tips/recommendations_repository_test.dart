import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartagri/core/network/api_exception.dart';
import 'package:smartagri/features/tips/data/recommendations_repository.dart';
import 'package:smartagri/features/tips/domain/recommendation.dart';

import '../../core/network/recording_adapter.dart';

Dio buildDio(RecordingAdapter adapter) {
  return Dio(BaseOptions(baseUrl: 'http://test.local/api/v1'))
    ..httpClientAdapter = adapter;
}

Map<String, dynamic> recommendationJson({
  String id = 'rec-1',
  String status = 'published',
  String? diagnosticId = 'diag-1',
}) {
  return <String, dynamic>{
    'id': id,
    'diagnostic_id': diagnosticId,
    'plot_id': 'plot-1',
    'crop_cycle_id': 'cycle-1',
    'source': 'llm',
    'language': 'fr',
    'title': 'Traiter le mildiou',
    'body': 'Retirez les feuilles atteintes.',
    'steps': <Map<String, dynamic>>[
      <String, dynamic>{
        'category': 'treatment',
        'text': 'Retirer les feuilles',
      },
      <String, dynamic>{
        'category': 'treatment',
        'text': 'Appliquer le produit',
      },
    ],
    'citations': <String>[],
    'status': status,
    'validated_by': null,
    'created_at': '2026-11-10T09:30:00Z',
  };
}

void main() {
  test('lists recommendations with the pagination parameters', () async {
    final RecordingAdapter adapter = RecordingAdapter(
      (RequestOptions options, RecordedRequest request) async =>
          body(200, <String, dynamic>{
            'items': <Map<String, dynamic>>[
              recommendationJson(),
              recommendationJson(id: 'rec-2', status: 'draft'),
            ],
            'next_cursor': 'cursor-2',
          }),
    );
    final RecommendationsRepository repository = RecommendationsRepository(
      dio: buildDio(adapter),
    );

    final RecommendationsPage page = await repository.list(
      cursor: 'cursor-1',
      limit: 5,
      plotId: 'plot-1',
      cropCycleId: 'cycle-1',
    );

    final RecordedRequest request = adapter.requests.single;
    expect(request.method, 'GET');
    expect(request.path, '/recommendations');
    expect(request.queryParameters, <String, dynamic>{
      'limit': 5,
      'cursor': 'cursor-1',
      'plot_id': 'plot-1',
      'crop_cycle_id': 'cycle-1',
    });
    expect(page.items, hasLength(1));
    expect(page.items.single.id, 'rec-1');
    expect(page.items.single.diagnosticId, 'diag-1');
    expect(page.items.single.steps, hasLength(2));
    expect(page.items.single.steps.first.text, 'Retirer les feuilles');
    expect(page.items.single.createdAt, DateTime.utc(2026, 11, 10, 9, 30));
    expect(page.nextCursor, 'cursor-2');
  });

  test('lists the first page with the default limit', () async {
    final RecordingAdapter adapter = RecordingAdapter(
      (RequestOptions options, RecordedRequest request) async =>
          body(200, <String, dynamic>{
            'items': <Map<String, dynamic>>[],
            'next_cursor': null,
          }),
    );
    final RecommendationsRepository repository = RecommendationsRepository(
      dio: buildDio(adapter),
    );

    final RecommendationsPage page = await repository.list();

    expect(adapter.requests.single.queryParameters, <String, dynamic>{
      'limit': 20,
    });
    expect(page.items, isEmpty);
    expect(page.nextCursor, isNull);
  });

  test('loads a single recommendation', () async {
    final RecordingAdapter adapter = RecordingAdapter(
      (RequestOptions options, RecordedRequest request) async =>
          body(200, recommendationJson(id: 'rec-9')),
    );
    final RecommendationsRepository repository = RecommendationsRepository(
      dio: buildDio(adapter),
    );

    final Recommendation recommendation = await repository.get('rec-9');

    expect(adapter.requests.single.path, '/recommendations/rec-9');
    expect(recommendation.id, 'rec-9');
    expect(recommendation.body, 'Retirez les feuilles atteintes.');
  });

  test('throws a typed error on failure', () async {
    final RecordingAdapter adapter = RecordingAdapter(
      (RequestOptions options, RecordedRequest request) async =>
          body(503, <String, dynamic>{
            'error': <String, dynamic>{
              'code': 'UNAVAILABLE',
              'message': 'Service indisponible',
            },
          }),
    );
    final RecommendationsRepository repository = RecommendationsRepository(
      dio: buildDio(adapter),
    );

    expect(() => repository.list(), throwsA(isA<ApiException>()));
  });
}
