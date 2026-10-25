import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/network/network_providers.dart';

class MediaItem {
  const MediaItem({
    required this.id,
    required this.kind,
    required this.mimeType,
    required this.sizeBytes,
    required this.sha256,
    this.width,
    this.height,
    this.url,
    this.uploadStatus,
  });

  final String id;
  final String kind;
  final String mimeType;
  final int sizeBytes;
  final String sha256;
  final int? width;
  final int? height;
  final String? url;
  final String? uploadStatus;

  factory MediaItem.fromJson(Map<String, dynamic> json) {
    return MediaItem(
      id: json['id'] as String? ?? '',
      kind: json['kind'] as String? ?? '',
      mimeType: json['mime_type'] as String? ?? '',
      sizeBytes: (json['size_bytes'] as num?)?.toInt() ?? 0,
      sha256: json['sha256'] as String? ?? '',
      width: (json['width'] as num?)?.toInt(),
      height: (json['height'] as num?)?.toInt(),
      url: json['url'] as String?,
      uploadStatus: json['upload_status'] as String?,
    );
  }
}

class UploadTicket {
  const UploadTicket({
    required this.media,
    required this.method,
    required this.headers,
    this.url,
    this.alreadyUploaded = false,
  });

  final MediaItem media;
  final String method;
  final String? url;
  final Map<String, String> headers;
  final bool alreadyUploaded;

  bool get isMultipart => method.toLowerCase() == 'multipart';
}

class MediaRepository {
  MediaRepository({required this.dio});

  final Dio dio;

  Future<UploadTicket> requestUpload({
    required String id,
    required String kind,
    required String mimeType,
    required int sizeBytes,
    required String sha256,
    required int width,
    required int height,
    required String idempotencyKey,
    String? plotId,
  }) async {
    try {
      final Response<dynamic> response = await dio.post<dynamic>(
        '/media/uploads',
        data: <String, dynamic>{
          'id': id,
          'kind': kind,
          'mime_type': mimeType,
          'size_bytes': sizeBytes,
          'sha256': sha256,
          'width': width,
          'height': height,
          'plot_id': ?plotId,
        },
        options: Options(
          headers: <String, String>{'Idempotency-Key': idempotencyKey},
        ),
      );
      final Map<String, dynamic> body = _asMap(response.data);
      final Object? rawMedia = body['media'];
      final Object? rawUpload = body['upload'];
      final Map<String, dynamic> upload = rawUpload is Map
          ? Map<String, dynamic>.from(rawUpload)
          : <String, dynamic>{};
      return UploadTicket(
        media: MediaItem.fromJson(
          rawMedia is Map
              ? Map<String, dynamic>.from(rawMedia)
              : <String, dynamic>{},
        ),
        method: upload['method'] as String? ?? '',
        url: upload['url'] as String?,
        headers: _headers(upload['headers']),
        alreadyUploaded: body['already_uploaded'] == true,
      );
    } on DioException catch (error) {
      throw ApiException.fromDioException(error);
    }
  }

  Future<MediaItem> completeUpload(String id) async {
    try {
      final Response<dynamic> response = await dio.post<dynamic>(
        '/media/$id/complete',
        data: <String, dynamic>{},
      );
      return MediaItem.fromJson(_asMap(response.data));
    } on DioException catch (error) {
      throw ApiException.fromDioException(error);
    }
  }

  Future<void> deleteMedia(String id) async {
    try {
      await dio.delete<dynamic>('/media/$id');
    } on DioException catch (error) {
      throw ApiException.fromDioException(error);
    }
  }

  Map<String, dynamic> _asMap(Object? data) {
    if (data is Map<String, dynamic>) {
      return data;
    }
    if (data is Map) {
      return Map<String, dynamic>.from(data);
    }
    return <String, dynamic>{};
  }

  Map<String, String> _headers(Object? value) {
    if (value is! Map) {
      return <String, String>{};
    }
    return value.map(
      (Object? key, Object? item) =>
          MapEntry<String, String>(key.toString(), item.toString()),
    );
  }
}

final Provider<MediaRepository> mediaRepositoryProvider =
    Provider<MediaRepository>(
      (Ref ref) => MediaRepository(dio: ref.watch(apiClientProvider)),
    );
