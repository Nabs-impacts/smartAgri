import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartagri/core/network/api_exception.dart';
import 'package:smartagri/features/diagnostics/data/diagnostics_repository.dart';
import 'package:smartagri/features/diagnostics/domain/diagnostic.dart';
import 'package:smartagri/features/diagnostics/domain/diagnostic_status.dart';
import 'package:smartagri/features/diagnostics/domain/diagnostic_summary.dart';

import '../../core/network/recording_adapter.dart';
import 'diagnostic_models_test.dart';

Dio buildDio(RecordingAdapter adapter) {
  return Dio(BaseOptions(baseUrl: 'http://test.local/api/v1'))
    ..httpClientAdapter = adapter;
}

Map<String, dynamic> summaryJson({
  String id = 'diag-1',
  String status = 'done',
  String? severity = 'high',
  Object? confidence = '0.92',
}) {
  return <String, dynamic>{
    'id': id,
    'status': status,
    'error': null,
    'confidence': confidence,
    'severity': severity,
    'crop_id': 3,
    'plot_id': 'plot-1',
    'crop_cycle_id': null,
    'source': 'server',
    'user_note': null,
    'location': null,
    'created_at': '2026-10-24T10:00:00Z',
    'updated_at': '2026-10-24T10:00:05Z',
    'completed_at': '2026-10-24T10:00:05Z',
  };
}

void main() {
  test('lists diagnostics with the backend pagination parameters', () async {
    final RecordingAdapter adapter = RecordingAdapter(
      (RequestOptions options, RecordedRequest request) async =>
          body(200, <String, dynamic>{
            'items': <Map<String, dynamic>>[
              summaryJson(),
              summaryJson(
                id: 'diag-2',
                status: 'needs_review',
                severity: 'medium',
                confidence: 0.7,
              ),
            ],
            'next_cursor': 'cursor-2',
          }),
    );
    final DiagnosticsRepository repository = DiagnosticsRepository(
      dio: buildDio(adapter),
    );

    final DiagnosticsPage page = await repository.list(
      cursor: 'cursor-1',
      limit: 5,
      plotId: 'plot-1',
      status: DiagnosticStatus.needsReview,
    );

    final RecordedRequest request = adapter.requests.single;
    expect(request.method, 'GET');
    expect(request.path, '/diagnostics');
    expect(request.queryParameters, <String, dynamic>{
      'limit': 5,
      'cursor': 'cursor-1',
      'plot_id': 'plot-1',
      'status': 'needs_review',
    });
    expect(page.items, hasLength(2));
    expect(page.items.first.id, 'diag-1');
    expect(page.items.first.status, DiagnosticStatus.done);
    expect(page.items.first.severity?.name, 'high');
    expect(page.items.first.confidence, 0.92);
    expect(page.items.first.plotId, 'plot-1');
    expect(page.items.first.labelName, isNull);
    expect(page.items.first.thumbnailUrl, isNull);
    expect(page.items.last.status, DiagnosticStatus.needsReview);
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
    final DiagnosticsRepository repository = DiagnosticsRepository(
      dio: buildDio(adapter),
    );

    final DiagnosticsPage page = await repository.list();

    expect(adapter.requests.single.queryParameters, <String, dynamic>{
      'limit': 20,
    });
    expect(page.items, isEmpty);
    expect(page.nextCursor, isNull);
  });

  test('creates a diagnostic with the exact idempotent body', () async {
    final RecordingAdapter adapter = RecordingAdapter(
      (RequestOptions options, RecordedRequest request) async =>
          body(202, diagnosticJson(status: 'pending')),
    );
    final DiagnosticsRepository repository = DiagnosticsRepository(
      dio: buildDio(adapter),
    );

    final Diagnostic diagnostic = await repository.create(
      id: 'diag-1',
      mediaIds: <String>['media-1', 'media-2'],
      idempotencyKey: 'idem-1',
    );

    final RecordedRequest request = adapter.requests.single;
    expect(request.method, 'POST');
    expect(request.path, '/diagnostics');
    expect(request.headers['Idempotency-Key'], 'idem-1');
    expect(request.data, <String, dynamic>{
      'id': 'diag-1',
      'media_ids': <String>['media-1', 'media-2'],
    });
    expect(diagnostic.id, 'diag-1');
    expect(diagnostic.status.isTerminal, isFalse);
  });

  test('sends the optional crop and plot identifiers', () async {
    final RecordingAdapter adapter = RecordingAdapter(
      (RequestOptions options, RecordedRequest request) async =>
          body(200, diagnosticJson(status: 'pending')),
    );
    final DiagnosticsRepository repository = DiagnosticsRepository(
      dio: buildDio(adapter),
    );

    await repository.create(
      id: 'diag-1',
      mediaIds: <String>['media-1'],
      cropId: 3,
      plotId: 'plot-1',
      idempotencyKey: 'idem-1',
    );

    expect(adapter.requests.single.data, <String, dynamic>{
      'id': 'diag-1',
      'media_ids': <String>['media-1'],
      'crop_id': 3,
      'plot_id': 'plot-1',
    });
  });

  test('reads, retries and deletes a diagnostic by id', () async {
    final RecordingAdapter adapter = RecordingAdapter((
      RequestOptions options,
      RecordedRequest request,
    ) async {
      if (options.method == 'DELETE') {
        return body(204, null);
      }
      return body(200, diagnosticJson());
    });
    final DiagnosticsRepository repository = DiagnosticsRepository(
      dio: buildDio(adapter),
    );

    final Diagnostic diagnostic = await repository.get('diag-1');
    final Diagnostic retried = await repository.retry('diag-1');
    await repository.delete('diag-1');

    expect(diagnostic.id, 'diag-1');
    expect(retried.id, 'diag-1');
    expect(adapter.requests[0].method, 'GET');
    expect(adapter.requests[0].path, '/diagnostics/diag-1');
    expect(adapter.requests[1].method, 'POST');
    expect(adapter.requests[1].path, '/diagnostics/diag-1/retry');
    expect(adapter.requests[2].method, 'DELETE');
    expect(adapter.requests[2].path, '/diagnostics/diag-1');
  });

  test('sends recommendation feedback with the optional fields', () async {
    final RecordingAdapter adapter = RecordingAdapter(
      (RequestOptions options, RecordedRequest request) async =>
          body(200, <String, dynamic>{}),
    );
    final DiagnosticsRepository repository = DiagnosticsRepository(
      dio: buildDio(adapter),
    );

    await repository.sendFeedback(
      'rec-1',
      helpful: true,
      applied: false,
      comment: 'Utile',
    );

    final RecordedRequest request = adapter.requests.single;
    expect(request.method, 'POST');
    expect(request.path, '/recommendations/rec-1/feedback');
    expect(request.data, <String, dynamic>{
      'helpful': true,
      'applied': false,
      'comment': 'Utile',
    });
  });

  test('omits empty optional feedback fields', () async {
    final RecordingAdapter adapter = RecordingAdapter(
      (RequestOptions options, RecordedRequest request) async =>
          body(200, <String, dynamic>{}),
    );
    final DiagnosticsRepository repository = DiagnosticsRepository(
      dio: buildDio(adapter),
    );

    await repository.sendFeedback('rec-1', helpful: false);

    expect(adapter.requests.single.data, <String, dynamic>{'helpful': false});
  });

  test('maps API errors', () async {
    final RecordingAdapter adapter = RecordingAdapter(
      (RequestOptions options, RecordedRequest request) async =>
          body(429, <String, dynamic>{
            'error': <String, dynamic>{
              'code': 'QUOTA_EXCEEDED',
              'message': 'Quota',
              'details': <String, dynamic>{'limit': 10},
            },
          }),
    );
    final DiagnosticsRepository repository = DiagnosticsRepository(
      dio: buildDio(adapter),
    );

    expect(
      () => repository.create(
        id: 'diag-1',
        mediaIds: <String>['media-1'],
        idempotencyKey: 'idem-1',
      ),
      throwsA(
        isA<ApiException>().having(
          (ApiException error) => error.isQuotaExceeded,
          'isQuotaExceeded',
          isTrue,
        ),
      ),
    );
  });
}
