import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:image/image.dart' as img;
import 'package:smartagri/core/media/image_compressor.dart';
import 'package:smartagri/features/media/data/media_repository.dart';

Map<String, dynamic> mediaJson({
  String id = 'media-1',
  String kind = 'image',
  String mimeType = 'image/jpeg',
  int sizeBytes = 1234,
  int width = 1024,
  int height = 768,
  String? url,
  String uploadStatus = 'uploaded',
}) {
  return <String, dynamic>{
    'id': id,
    'owner_id': 'owner-1',
    'plot_id': null,
    'crop_cycle_id': null,
    'kind': kind,
    'mime_type': mimeType,
    'size_bytes': sizeBytes,
    'width': width,
    'height': height,
    'duration_s': null,
    'sha256': 'a' * 64,
    'location': null,
    'captured_at': null,
    'upload_status': uploadStatus,
    'created_at': '2026-10-24T10:00:00Z',
    'url': url,
  };
}

Map<String, dynamic> uploadResponse({
  String id = 'media-1',
  bool alreadyUploaded = false,
  String method = 'PUT',
  String? url = 'http://storage.local/upload',
  Map<String, String>? headers,
}) {
  return <String, dynamic>{
    'media': mediaJson(id: id),
    'upload': alreadyUploaded
        ? null
        : <String, dynamic>{
            'method': method,
            'url': url,
            'headers':
                headers ??
                <String, String>{
                  'Content-Type': 'image/jpeg',
                  'Content-Length': '1234',
                },
            'expires_in': 900,
            'upload_id': null,
            'part_size': null,
            'parts': null,
          },
    'already_uploaded': alreadyUploaded,
  };
}

CompressedImage sampleCompressedImage([String seed = 'image']) {
  final img.Image image = img.Image(width: 8, height: 6);
  img.fill(image, color: img.ColorRgb8(20, 90, 40));
  image.textData = <String, String>{'seed': seed};
  final List<int> bytes = img.encodeJpg(image, quality: 70);
  return CompressedImage(
    bytes: Uint8List.fromList(bytes),
    width: image.width,
    height: image.height,
    sha256: 'b' * 64,
  );
}

class FakeMediaRepository extends MediaRepository {
  FakeMediaRepository({
    List<UploadTicket>? tickets,
    this.completedId = 'media-1',
  }) : tickets = tickets ?? <UploadTicket>[],
       super(dio: Dio());

  final List<UploadTicket> tickets;
  String completedId;
  int requestCalls = 0;
  int completeCalls = 0;
  int deleteCalls = 0;
  String? lastId;
  String? lastKind;
  String? lastMimeType;
  int? lastSizeBytes;
  String? lastSha256;
  int? lastWidth;
  int? lastHeight;
  String? lastPlotId;
  String? lastIdempotencyKey;
  String? lastCompleteId;
  String? lastDeletedId;

  @override
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
    lastId = id;
    lastKind = kind;
    lastMimeType = mimeType;
    lastSizeBytes = sizeBytes;
    lastSha256 = sha256;
    lastWidth = width;
    lastHeight = height;
    lastPlotId = plotId;
    lastIdempotencyKey = idempotencyKey;
    final int index = requestCalls < tickets.length
        ? requestCalls
        : tickets.length - 1;
    final UploadTicket ticket = tickets[index];
    requestCalls++;
    return ticket;
  }

  @override
  Future<MediaItem> completeUpload(String id) async {
    completeCalls++;
    lastCompleteId = id;
    return MediaItem.fromJson(mediaJson(id: completedId));
  }

  @override
  Future<void> deleteMedia(String id) async {
    deleteCalls++;
    lastDeletedId = id;
  }
}
