import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartagri/core/network/api_exception.dart';
import 'package:smartagri/features/diagnostics/data/diagnostics_repository.dart';
import 'package:smartagri/features/diagnostics/domain/diagnostic.dart';

import '../../core/network/recording_adapter.dart';
import 'diagnostic_models_test.dart';

Dio buildDio(RecordingAdapter adapter) {
  return Dio(BaseOptions(baseUrl: 'http://test.local/api/v1'))
    ..httpClientAdapter = adapter;
}

void main() {
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
