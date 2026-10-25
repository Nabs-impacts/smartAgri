import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/media/image_compressor.dart';
import '../../../core/network/network_providers.dart';
import 'media_repository.dart';

class PendingPhoto {
  const PendingPhoto({required this.mediaId, required this.image});

  final String mediaId;
  final CompressedImage image;
}

class MediaUploadException implements Exception {
  const MediaUploadException(this.message);

  final String message;

  @override
  String toString() => message;
}

typedef UploadProgressCallback = void Function(int sent, int total);

class MediaUploader {
  MediaUploader({
    required this.repository,
    required this.storageClient,
    this.retryDelays = const <Duration>[
      Duration(seconds: 1),
      Duration(seconds: 3),
      Duration(seconds: 7),
    ],
    Future<void> Function(Duration duration)? wait,
  }) : _wait = wait ?? _delayed;

  final MediaRepository repository;
  final Dio storageClient;
  final List<Duration> retryDelays;
  final Future<void> Function(Duration duration) _wait;

  Future<String> uploadImage(
    PendingPhoto photo, {
    String? plotId,
    CancelToken? cancelToken,
    UploadProgressCallback? onProgress,
  }) async {
    _throwIfCancelled(cancelToken);
    UploadTicket ticket = await _requestTicket(photo, plotId);
    if (ticket.alreadyUploaded) {
      return ticket.media.id;
    }
    _validateTicket(ticket);
    bool refreshed = false;
    int retry = 0;
    while (true) {
      _throwIfCancelled(cancelToken);
      try {
        await storageClient.put<dynamic>(
          ticket.url!,
          data: photo.image.bytes,
          options: Options(headers: Map<String, String>.of(ticket.headers)),
          cancelToken: cancelToken,
          onSendProgress: onProgress,
        );
        break;
      } on DioException catch (error) {
        if (CancelToken.isCancel(error)) {
          rethrow;
        }
        if (error.response?.statusCode == 403 && !refreshed) {
          refreshed = true;
          ticket = await _requestTicket(photo, plotId);
          if (ticket.alreadyUploaded) {
            return ticket.media.id;
          }
          _validateTicket(ticket);
          continue;
        }
        if (!_isRetryable(error) || retry >= retryDelays.length) {
          rethrow;
        }
        await _wait(retryDelays[retry]);
        retry++;
      }
    }
    final MediaItem completed = await repository.completeUpload(
      ticket.media.id,
    );
    return completed.id;
  }

  Future<UploadTicket> _requestTicket(PendingPhoto photo, String? plotId) {
    return repository.requestUpload(
      id: photo.mediaId,
      kind: 'image',
      mimeType: photo.image.mimeType,
      sizeBytes: photo.image.sizeBytes,
      sha256: photo.image.sha256,
      width: photo.image.width,
      height: photo.image.height,
      plotId: plotId,
      idempotencyKey: photo.mediaId,
    );
  }

  void _validateTicket(UploadTicket ticket) {
    if (ticket.isMultipart) {
      throw const MediaUploadException(
        "L'envoi multipart n'est pas pris en charge pour les photos.",
      );
    }
    if (ticket.method.toUpperCase() != 'PUT') {
      throw const MediaUploadException("Méthode d'envoi non prise en charge.");
    }
    if (ticket.url == null || ticket.url!.isEmpty) {
      throw const MediaUploadException("L'URL d'envoi est manquante.");
    }
  }

  bool _isRetryable(DioException error) {
    if (error.type == DioExceptionType.badResponse) {
      final int? status = error.response?.statusCode;
      return status != null && status >= 500;
    }
    switch (error.type) {
      case DioExceptionType.connectionError:
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.unknown:
        return true;
      case DioExceptionType.cancel:
      case DioExceptionType.badCertificate:
      case DioExceptionType.badResponse:
      case DioExceptionType.transformTimeout:
        return false;
    }
  }

  void _throwIfCancelled(CancelToken? cancelToken) {
    if (cancelToken?.isCancelled ?? false) {
      throw DioException(
        requestOptions: RequestOptions(),
        type: DioExceptionType.cancel,
        error: cancelToken?.cancelError,
      );
    }
  }

  static Future<void> _delayed(Duration duration) {
    return Future<void>.delayed(duration);
  }
}

final Provider<MediaUploader> mediaUploaderProvider = Provider<MediaUploader>(
  (Ref ref) => MediaUploader(
    repository: ref.watch(mediaRepositoryProvider),
    storageClient: ref.watch(storageClientProvider),
  ),
);
