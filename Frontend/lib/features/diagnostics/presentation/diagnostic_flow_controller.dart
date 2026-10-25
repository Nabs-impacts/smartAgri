import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/media/image_compressor.dart';
import '../../../core/network/api_exception.dart';
import '../../media/data/media_uploader.dart';
import '../data/diagnostics_repository.dart';
import '../domain/diagnostic.dart';

enum FlowPhotoStatus { compressing, ready, uploading, uploaded, failed }

class FlowPhoto {
  const FlowPhoto({
    required this.mediaId,
    this.image,
    this.status = FlowPhotoStatus.compressing,
    this.progress = 0,
    this.error,
    this.serverMediaId,
  });

  final String mediaId;
  final CompressedImage? image;
  final FlowPhotoStatus status;
  final double progress;
  final String? error;
  final String? serverMediaId;

  Uint8List? get bytes => image?.bytes;

  bool get isReady => status != FlowPhotoStatus.compressing && image != null;

  FlowPhoto copyWith({
    CompressedImage? image,
    FlowPhotoStatus? status,
    double? progress,
    Object? error = _unset,
    Object? serverMediaId = _unset,
  }) {
    return FlowPhoto(
      mediaId: mediaId,
      image: image ?? this.image,
      status: status ?? this.status,
      progress: progress ?? this.progress,
      error: identical(error, _unset) ? this.error : error as String?,
      serverMediaId: identical(serverMediaId, _unset)
          ? this.serverMediaId
          : serverMediaId as String?,
    );
  }
}

const Object _unset = Object();

class DiagnosticFlowState {
  const DiagnosticFlowState({
    required this.diagnosticId,
    required this.idempotencyKey,
    this.photos = const <FlowPhoto>[],
    this.cropId,
    this.plotId,
    this.submitting = false,
    this.error,
    this.quotaExceeded = false,
    this.created,
  });

  final String diagnosticId;
  final String idempotencyKey;
  final List<FlowPhoto> photos;
  final int? cropId;
  final String? plotId;
  final bool submitting;
  final ApiException? error;
  final bool quotaExceeded;
  final Diagnostic? created;

  bool get canSubmit {
    if (submitting || quotaExceeded) {
      return false;
    }
    return photos.any(
      (FlowPhoto photo) =>
          photo.status != FlowPhotoStatus.compressing && photo.image != null,
    );
  }

  bool get canAddPhoto => photos.length < 3;

  List<FlowPhoto> get uploadablePhotos =>
      photos.where((FlowPhoto photo) => photo.image != null).toList();

  double get globalProgress {
    final List<FlowPhoto> items = uploadablePhotos;
    if (items.isEmpty) {
      return 0;
    }
    double total = 0;
    for (final FlowPhoto photo in items) {
      if (photo.status == FlowPhotoStatus.uploaded) {
        total += 1;
      } else if (photo.status == FlowPhotoStatus.uploading) {
        total += photo.progress;
      } else if (photo.status == FlowPhotoStatus.ready ||
          photo.status == FlowPhotoStatus.failed) {
        total += 0;
      }
    }
    return (total / items.length).clamp(0, 1);
  }

  DiagnosticFlowState copyWith({
    List<FlowPhoto>? photos,
    Object? cropId = _unset,
    Object? plotId = _unset,
    bool? submitting,
    Object? error = _unset,
    bool? quotaExceeded,
    Object? created = _unset,
  }) {
    return DiagnosticFlowState(
      diagnosticId: diagnosticId,
      idempotencyKey: idempotencyKey,
      photos: photos ?? this.photos,
      cropId: identical(cropId, _unset) ? this.cropId : cropId as int?,
      plotId: identical(plotId, _unset) ? this.plotId : plotId as String?,
      submitting: submitting ?? this.submitting,
      error: identical(error, _unset) ? this.error : error as ApiException?,
      quotaExceeded: quotaExceeded ?? this.quotaExceeded,
      created: identical(created, _unset)
          ? this.created
          : created as Diagnostic?,
    );
  }
}

class DiagnosticFlowController extends Notifier<DiagnosticFlowState> {
  final Uuid _uuid = const Uuid();
  CancelToken? _cancelToken;

  @override
  DiagnosticFlowState build() {
    ref.onDispose(() {
      _cancelToken?.cancel();
    });
    return DiagnosticFlowState(
      diagnosticId: _uuid.v4(),
      idempotencyKey: _uuid.v4(),
    );
  }

  void selectCrop(int? cropId) {
    state = state.copyWith(cropId: cropId);
  }

  void selectPlot(String? plotId) {
    state = state.copyWith(plotId: plotId);
  }

  Future<void> addPhoto(Uint8List bytes) async {
    if (!state.canAddPhoto) {
      return;
    }
    final String mediaId = _uuid.v4();
    state = state.copyWith(
      photos: <FlowPhoto>[
        ...state.photos,
        FlowPhoto(mediaId: mediaId),
      ],
      error: null,
    );
    try {
      final CompressedImage image = await ref
          .read(imageCompressorProvider)
          .compress(bytes);
      if (!ref.mounted) {
        return;
      }
      _updatePhoto(
        mediaId,
        (FlowPhoto photo) => photo.copyWith(
          image: image,
          status: FlowPhotoStatus.ready,
          progress: 0,
          error: null,
        ),
      );
    } on ImageProcessingException catch (error) {
      if (ref.mounted) {
        _updatePhoto(
          mediaId,
          (FlowPhoto photo) => photo.copyWith(
            status: FlowPhotoStatus.failed,
            error: error.message,
          ),
        );
      }
    } catch (_) {
      if (ref.mounted) {
        _updatePhoto(
          mediaId,
          (FlowPhoto photo) => photo.copyWith(
            status: FlowPhotoStatus.failed,
            error: 'Impossible de traiter cette photo.',
          ),
        );
      }
    }
  }

  void removePhoto(String mediaId) {
    if (state.submitting) {
      return;
    }
    state = state.copyWith(
      photos: state.photos
          .where((FlowPhoto photo) => photo.mediaId != mediaId)
          .toList(),
      error: null,
    );
  }

  Future<void> submit() async {
    if (!state.canSubmit) {
      return;
    }
    final CancelToken token = CancelToken();
    _cancelToken = token;
    state = state.copyWith(submitting: true, error: null, quotaExceeded: false);
    for (final FlowPhoto photo in state.photos) {
      if (photo.status == FlowPhotoStatus.uploaded &&
          photo.serverMediaId != null) {
        continue;
      }
      if (photo.image == null) {
        continue;
      }
      _updatePhoto(
        photo.mediaId,
        (FlowPhoto item) => item.copyWith(
          status: FlowPhotoStatus.uploading,
          progress: 0,
          error: null,
        ),
      );
      try {
        final String serverId = await ref
            .read(mediaUploaderProvider)
            .uploadImage(
              PendingPhoto(mediaId: photo.mediaId, image: photo.image!),
              plotId: state.plotId,
              cancelToken: token,
              onProgress: (int sent, int total) {
                if (!ref.mounted) {
                  return;
                }
                final double progress = total <= 0 ? 0 : sent / total;
                _updatePhoto(
                  photo.mediaId,
                  (FlowPhoto item) => item.copyWith(
                    status: FlowPhotoStatus.uploading,
                    progress: progress.clamp(0, 1),
                  ),
                );
              },
            );
        if (!ref.mounted) {
          return;
        }
        _updatePhoto(
          photo.mediaId,
          (FlowPhoto item) => item.copyWith(
            status: FlowPhotoStatus.uploaded,
            progress: 1,
            serverMediaId: serverId,
            error: null,
          ),
        );
      } on DioException catch (error) {
        if (CancelToken.isCancel(error) || token.isCancelled) {
          if (ref.mounted) {
            state = state.copyWith(submitting: false);
          }
          return;
        }
        if (ref.mounted) {
          _updatePhoto(
            photo.mediaId,
            (FlowPhoto item) => item.copyWith(
              status: FlowPhotoStatus.failed,
              error: error.message ?? 'Impossible d’envoyer cette photo.',
            ),
          );
          state = state.copyWith(
            submitting: false,
            error: const ApiException(
              code: ApiException.unknownErrorCode,
              message: 'Une erreur est survenue. Veuillez réessayer.',
            ),
          );
        }
        return;
      } on ApiException catch (error) {
        if (!ref.mounted) {
          return;
        }
        _updatePhoto(
          photo.mediaId,
          (FlowPhoto item) => item.copyWith(
            status: FlowPhotoStatus.failed,
            error: error.message,
          ),
        );
        state = state.copyWith(submitting: false, error: error);
        return;
      }
    }
    final List<String> mediaIds = state.photos
        .map((FlowPhoto photo) => photo.serverMediaId)
        .whereType<String>()
        .toList();
    try {
      final Diagnostic diagnostic = await ref
          .read(diagnosticsRepositoryProvider)
          .create(
            id: state.diagnosticId,
            mediaIds: mediaIds,
            cropId: state.cropId,
            plotId: state.plotId,
            idempotencyKey: state.idempotencyKey,
          );
      if (ref.mounted) {
        state = state.copyWith(submitting: false, created: diagnostic);
      }
    } on ApiException catch (error) {
      if (ref.mounted) {
        state = state.copyWith(
          submitting: false,
          error: error,
          quotaExceeded: error.isQuotaExceeded,
        );
      }
    }
  }

  void cancelUploads() {
    _cancelToken?.cancel();
    if (ref.mounted) {
      state = state.copyWith(submitting: false);
    }
  }

  void _updatePhoto(
    String mediaId,
    FlowPhoto Function(FlowPhoto photo) update,
  ) {
    state = state.copyWith(
      photos: state.photos
          .map(
            (FlowPhoto photo) =>
                photo.mediaId == mediaId ? update(photo) : photo,
          )
          .toList(),
    );
  }
}

final Provider<ImageCompressor> imageCompressorProvider =
    Provider<ImageCompressor>((Ref ref) => const IsolateImageCompressor());

final NotifierProvider<DiagnosticFlowController, DiagnosticFlowState>
diagnosticFlowProvider =
    NotifierProvider.autoDispose<DiagnosticFlowController, DiagnosticFlowState>(
      DiagnosticFlowController.new,
    );
