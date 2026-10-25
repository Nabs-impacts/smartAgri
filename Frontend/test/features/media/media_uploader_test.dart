import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartagri/features/media/data/media_repository.dart';
import 'package:smartagri/features/media/data/media_uploader.dart';

import '../../core/network/recording_adapter.dart';
import 'media_test_utils.dart';

UploadTicket ticket({
  String id = 'media-1',
  String method = 'PUT',
  String? url = 'http://storage.local/upload',
  Map<String, String>? headers,
  bool alreadyUploaded = false,
}) {
  return UploadTicket(
    media: MediaItem.fromJson(mediaJson(id: id)),
    method: method,
    url: url,
    headers:
        headers ??
        const <String, String>{
          'Content-Type': 'image/jpeg',
          'Content-Length': '1234',
        },
    alreadyUploaded: alreadyUploaded,
  );
}

Dio storageDio(RecordingAdapter adapter) {
  return Dio()..httpClientAdapter = adapter;
}

void main() {
  test(
    'requests a ticket, puts the exact bytes and headers, then completes',
    () async {
      final FakeMediaRepository repository = FakeMediaRepository(
        tickets: <UploadTicket>[ticket()],
        completedId: 'server-media',
      );
      final RecordingAdapter storage = RecordingAdapter(
        (RequestOptions options, RecordedRequest request) async =>
            body(200, null),
      );
      final MediaUploader uploader = MediaUploader(
        repository: repository,
        storageClient: storageDio(storage),
        wait: (Duration duration) async {},
      );
      final PendingPhoto photo = PendingPhoto(
        mediaId: 'media-1',
        image: sampleCompressedImage(),
      );

      final String id = await uploader.uploadImage(photo, plotId: 'plot-1');

      expect(id, 'server-media');
      expect(repository.requestCalls, 1);
      expect(repository.lastId, 'media-1');
      expect(repository.lastKind, 'image');
      expect(repository.lastMimeType, 'image/jpeg');
      expect(repository.lastSizeBytes, photo.image.sizeBytes);
      expect(repository.lastSha256, photo.image.sha256);
      expect(repository.lastWidth, 8);
      expect(repository.lastHeight, 6);
      expect(repository.lastPlotId, 'plot-1');
      expect(repository.lastIdempotencyKey, 'media-1');
      expect(repository.completeCalls, 1);
      expect(repository.lastCompleteId, 'media-1');

      final RecordedRequest put = storage.requests.single;
      expect(put.method, 'PUT');
      expect(put.path, contains('/upload'));
      expect(put.headers['Content-Type'], 'image/jpeg');
      expect(put.headers['Content-Length'], '${photo.image.sizeBytes}');
      expect(put.headers.containsKey('Authorization'), isFalse);
      expect(put.data, isA<Uint8List>());
      expect(put.data, photo.image.bytes);
    },
  );

  test('authenticates the API but never the storage request', () async {
    final RecordingAdapter api = RecordingAdapter(
      (RequestOptions options, RecordedRequest request) async =>
          body(201, uploadResponse()),
    );
    final Dio apiClient = Dio(BaseOptions(baseUrl: 'http://api.local/api/v1'))
      ..httpClientAdapter = api;
    apiClient.interceptors.add(
      InterceptorsWrapper(
        onRequest: (RequestOptions options, RequestInterceptorHandler handler) {
          options.headers['Authorization'] = 'Bearer token';
          handler.next(options);
        },
      ),
    );
    final RecordingAdapter storage = RecordingAdapter(
      (RequestOptions options, RecordedRequest request) async =>
          body(200, null),
    );
    final MediaUploader uploader = MediaUploader(
      repository: MediaRepository(dio: apiClient),
      storageClient: storageDio(storage),
      wait: (Duration duration) async {},
    );

    await uploader.uploadImage(
      PendingPhoto(mediaId: 'media-1', image: sampleCompressedImage()),
    );

    expect(api.requests.first.headers['Authorization'], 'Bearer token');
    expect(
      storage.requests.single.headers.containsKey('Authorization'),
      isFalse,
    );
  });

  test(
    'returns the server identifier without uploading an already stored image',
    () async {
      final FakeMediaRepository repository = FakeMediaRepository(
        tickets: <UploadTicket>[
          ticket(id: 'server-media', alreadyUploaded: true),
        ],
      );
      final RecordingAdapter storage = RecordingAdapter(
        (RequestOptions options, RecordedRequest request) async =>
            body(200, null),
      );
      final MediaUploader uploader = MediaUploader(
        repository: repository,
        storageClient: storageDio(storage),
        wait: (Duration duration) async {},
      );

      final String id = await uploader.uploadImage(
        PendingPhoto(mediaId: 'media-1', image: sampleCompressedImage()),
      );

      expect(id, 'server-media');
      expect(storage.requests, isEmpty);
      expect(repository.completeCalls, 0);
    },
  );

  test(
    'retries network and 5xx failures with 1, 3 and 7 second waits',
    () async {
      final FakeMediaRepository repository = FakeMediaRepository(
        tickets: <UploadTicket>[ticket()],
      );
      int calls = 0;
      final RecordingAdapter storage = RecordingAdapter((
        RequestOptions options,
        RecordedRequest request,
      ) async {
        calls++;
        if (calls <= 3) {
          return body(503, <String, dynamic>{'error': 'unavailable'});
        }
        return body(200, null);
      });
      final List<Duration> waits = <Duration>[];
      final MediaUploader uploader = MediaUploader(
        repository: repository,
        storageClient: storageDio(storage),
        wait: (Duration duration) async => waits.add(duration),
      );

      await uploader.uploadImage(
        PendingPhoto(mediaId: 'media-1', image: sampleCompressedImage()),
      );

      expect(storage.requests, hasLength(4));
      expect(waits, const <Duration>[
        Duration(seconds: 1),
        Duration(seconds: 3),
        Duration(seconds: 7),
      ]);
      expect(repository.completeCalls, 1);
    },
  );

  test('does not retry a client error other than an expired URL', () async {
    final FakeMediaRepository repository = FakeMediaRepository(
      tickets: <UploadTicket>[ticket()],
    );
    final RecordingAdapter storage = RecordingAdapter(
      (RequestOptions options, RecordedRequest request) async =>
          body(400, <String, dynamic>{'error': 'bad request'}),
    );
    final MediaUploader uploader = MediaUploader(
      repository: repository,
      storageClient: storageDio(storage),
      wait: (Duration duration) async {},
    );

    await expectLater(
      uploader.uploadImage(
        PendingPhoto(mediaId: 'media-1', image: sampleCompressedImage()),
      ),
      throwsA(isA<DioException>()),
    );
    expect(storage.requests, hasLength(1));
    expect(repository.completeCalls, 0);
  });

  test('refreshes the ticket once after a 403 and retries the PUT', () async {
    final FakeMediaRepository repository = FakeMediaRepository(
      tickets: <UploadTicket>[
        ticket(url: 'http://storage.local/expired'),
        ticket(url: 'http://storage.local/fresh'),
      ],
    );
    int calls = 0;
    final RecordingAdapter storage = RecordingAdapter((
      RequestOptions options,
      RecordedRequest request,
    ) async {
      calls++;
      if (calls == 1) {
        return body(403, <String, dynamic>{'error': 'expired'});
      }
      return body(200, null);
    });
    final MediaUploader uploader = MediaUploader(
      repository: repository,
      storageClient: storageDio(storage),
      wait: (Duration duration) async {},
    );

    await uploader.uploadImage(
      PendingPhoto(mediaId: 'media-1', image: sampleCompressedImage()),
    );

    expect(repository.requestCalls, 2);
    expect(storage.requests, hasLength(2));
    expect(storage.requests.last.path, contains('/fresh'));
    expect(repository.completeCalls, 1);
  });

  test('refreshes the ticket only once for repeated 403 responses', () async {
    final FakeMediaRepository repository = FakeMediaRepository(
      tickets: <UploadTicket>[ticket(), ticket()],
    );
    final RecordingAdapter storage = RecordingAdapter(
      (RequestOptions options, RecordedRequest request) async =>
          body(403, <String, dynamic>{'error': 'expired'}),
    );
    final MediaUploader uploader = MediaUploader(
      repository: repository,
      storageClient: storageDio(storage),
      wait: (Duration duration) async {},
    );

    await expectLater(
      uploader.uploadImage(
        PendingPhoto(mediaId: 'media-1', image: sampleCompressedImage()),
      ),
      throwsA(isA<DioException>()),
    );
    expect(repository.requestCalls, 2);
    expect(storage.requests, hasLength(2));
  });

  test('rejects a multipart ticket with a clear error', () async {
    final FakeMediaRepository repository = FakeMediaRepository(
      tickets: <UploadTicket>[ticket(method: 'multipart', url: null)],
    );
    final RecordingAdapter storage = RecordingAdapter(
      (RequestOptions options, RecordedRequest request) async =>
          body(200, null),
    );
    final MediaUploader uploader = MediaUploader(
      repository: repository,
      storageClient: storageDio(storage),
      wait: (Duration duration) async {},
    );

    expect(
      () => uploader.uploadImage(
        PendingPhoto(mediaId: 'media-1', image: sampleCompressedImage()),
      ),
      throwsA(
        isA<MediaUploadException>().having(
          (MediaUploadException error) => error.message,
          'message',
          contains('multipart'),
        ),
      ),
    );
    expect(storage.requests, isEmpty);
  });

  test(
    'stops immediately when the cancel token is already cancelled',
    () async {
      final FakeMediaRepository repository = FakeMediaRepository(
        tickets: <UploadTicket>[ticket()],
      );
      final RecordingAdapter storage = RecordingAdapter(
        (RequestOptions options, RecordedRequest request) async =>
            body(200, null),
      );
      final MediaUploader uploader = MediaUploader(
        repository: repository,
        storageClient: storageDio(storage),
        wait: (Duration duration) async {},
      );
      final CancelToken token = CancelToken();
      token.cancel();

      await expectLater(
        uploader.uploadImage(
          PendingPhoto(mediaId: 'media-1', image: sampleCompressedImage()),
          cancelToken: token,
        ),
        throwsA(
          isA<DioException>().having(
            (DioException error) => error.type,
            'type',
            DioExceptionType.cancel,
          ),
        ),
      );
      expect(repository.requestCalls, 0);
      expect(storage.requests, isEmpty);
    },
  );
}
