import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartagri/core/network/api_exception.dart';
import 'package:smartagri/features/media/data/media_repository.dart';

import '../../core/network/recording_adapter.dart';
import 'media_test_utils.dart';

Dio buildDio(RecordingAdapter adapter) {
  return Dio(BaseOptions(baseUrl: 'http://test.local/api/v1'))
    ..httpClientAdapter = adapter;
}

void main() {
  test(
    'requests an upload with the exact body, id and idempotency key',
    () async {
      final RecordingAdapter adapter = RecordingAdapter(
        (RequestOptions options, RecordedRequest request) async =>
            body(201, uploadResponse()),
      );
      final MediaRepository repository = MediaRepository(
        dio: buildDio(adapter),
      );

      final UploadTicket ticket = await repository.requestUpload(
        id: 'media-1',
        kind: 'image',
        mimeType: 'image/jpeg',
        sizeBytes: 1234,
        sha256: 'a' * 64,
        width: 1024,
        height: 768,
        plotId: 'plot-1',
        idempotencyKey: 'idem-1',
      );

      final RecordedRequest request = adapter.requests.single;
      expect(request.method, 'POST');
      expect(request.path, '/media/uploads');
      expect(request.headers['Idempotency-Key'], 'idem-1');
      expect(request.data, <String, dynamic>{
        'id': 'media-1',
        'kind': 'image',
        'mime_type': 'image/jpeg',
        'size_bytes': 1234,
        'sha256': 'a' * 64,
        'width': 1024,
        'height': 768,
        'plot_id': 'plot-1',
      });
      expect(ticket.media.id, 'media-1');
      expect(ticket.method, 'PUT');
      expect(ticket.url, 'http://storage.local/upload');
      expect(ticket.headers['Content-Type'], 'image/jpeg');
      expect(ticket.headers['Content-Length'], '1234');
      expect(ticket.alreadyUploaded, isFalse);
    },
  );

  test('omits the plot id when none is provided', () async {
    final RecordingAdapter adapter = RecordingAdapter(
      (RequestOptions options, RecordedRequest request) async =>
          body(201, uploadResponse()),
    );
    final MediaRepository repository = MediaRepository(dio: buildDio(adapter));

    await repository.requestUpload(
      id: 'media-1',
      kind: 'image',
      mimeType: 'image/jpeg',
      sizeBytes: 10,
      sha256: 'a' * 64,
      width: 1,
      height: 1,
      idempotencyKey: 'idem-1',
    );

    expect(
      Map<String, dynamic>.from(adapter.requests.single.data! as Map),
      isNot(contains('plot_id')),
    );
  });

  test('reads the already uploaded response without an upload block', () async {
    final RecordingAdapter adapter = RecordingAdapter(
      (RequestOptions options, RecordedRequest request) async =>
          body(200, uploadResponse(alreadyUploaded: true)),
    );
    final MediaRepository repository = MediaRepository(dio: buildDio(adapter));

    final UploadTicket ticket = await repository.requestUpload(
      id: 'media-1',
      kind: 'image',
      mimeType: 'image/jpeg',
      sizeBytes: 10,
      sha256: 'a' * 64,
      width: 1,
      height: 1,
      idempotencyKey: 'idem-1',
    );

    expect(ticket.alreadyUploaded, isTrue);
    expect(ticket.url, isNull);
    expect(ticket.headers, isEmpty);
    expect(ticket.media.id, 'media-1');
  });

  test('completes and deletes a media by id', () async {
    final RecordingAdapter adapter = RecordingAdapter((
      RequestOptions options,
      RecordedRequest request,
    ) async {
      if (options.method == 'DELETE') {
        return body(204, null);
      }
      return body(200, mediaJson(id: options.path.split('/')[2]));
    });
    final MediaRepository repository = MediaRepository(dio: buildDio(adapter));

    final MediaItem completed = await repository.completeUpload('media-9');
    await repository.deleteMedia('media-9');

    expect(completed.id, 'media-9');
    expect(adapter.requests.first.method, 'POST');
    expect(adapter.requests.first.path, '/media/media-9/complete');
    expect(adapter.requests.last.method, 'DELETE');
    expect(adapter.requests.last.path, '/media/media-9');
  });

  test('maps API errors', () async {
    final RecordingAdapter adapter = RecordingAdapter(
      (RequestOptions options, RecordedRequest request) async =>
          body(409, <String, dynamic>{
            'error': <String, dynamic>{
              'code': 'CONFLICT',
              'message': 'Conflit',
              'details': null,
            },
          }),
    );
    final MediaRepository repository = MediaRepository(dio: buildDio(adapter));

    expect(
      () => repository.completeUpload('media-9'),
      throwsA(
        isA<ApiException>().having(
          (ApiException error) => error.statusCode,
          'statusCode',
          409,
        ),
      ),
    );
  });
}
