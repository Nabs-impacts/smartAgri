import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartagri/core/media/image_compressor.dart';
import 'package:smartagri/core/network/api_exception.dart';
import 'package:smartagri/features/diagnostics/data/diagnostics_history_provider.dart';
import 'package:smartagri/features/diagnostics/data/diagnostics_repository.dart';
import 'package:smartagri/features/diagnostics/domain/diagnostic.dart';
import 'package:smartagri/features/diagnostics/domain/diagnostic_status.dart';
import 'package:smartagri/features/diagnostics/domain/diagnostic_summary.dart';
import 'package:smartagri/features/diagnostics/presentation/diagnostic_flow_controller.dart';
import 'package:smartagri/features/media/data/media_repository.dart';
import 'package:smartagri/features/media/data/media_uploader.dart';

import '../media/media_test_utils.dart';
import 'diagnostic_test_utils.dart';

class FakeCompressor implements ImageCompressor {
  FakeCompressor({this.error});

  final Object? error;
  int calls = 0;

  @override
  Future<CompressedImage> compress(Uint8List bytes) async {
    calls++;
    if (error != null) {
      throw error!;
    }
    return sampleCompressedImage();
  }
}

class FakeUploader extends MediaUploader {
  FakeUploader({this.failures = 0})
    : super(
        repository: MediaRepository(dio: Dio()),
        storageClient: Dio(),
      );

  int failures;
  int calls = 0;
  String? lastMediaId;
  String? lastPlotId;

  @override
  Future<String> uploadImage(
    PendingPhoto photo, {
    String? plotId,
    CancelToken? cancelToken,
    UploadProgressCallback? onProgress,
  }) async {
    calls++;
    lastMediaId = photo.mediaId;
    lastPlotId = plotId;
    if (failures > 0) {
      failures--;
      throw const ApiException(
        code: ApiException.unknownErrorCode,
        message: 'Envoi impossible.',
      );
    }
    onProgress?.call(photo.image.sizeBytes, photo.image.sizeBytes);
    return 'server-${photo.mediaId}';
  }
}

class FakeDiagnosticsRepository extends DiagnosticsRepository {
  FakeDiagnosticsRepository({this.failures = 0, this.quotaFailure = false})
    : super(dio: Dio());

  int failures;
  bool quotaFailure;
  int createCalls = 0;
  int listCalls = 0;
  String? lastId;
  String? lastIdempotencyKey;
  List<String>? lastMediaIds;
  int? lastCropId;
  String? lastPlotId;

  @override
  Future<DiagnosticsPage> list({
    String? cursor,
    int limit = 20,
    String? plotId,
    DiagnosticStatus? status,
  }) async {
    listCalls++;
    return const DiagnosticsPage(items: <DiagnosticSummary>[]);
  }

  @override
  Future<Diagnostic> create({
    required String id,
    required List<String> mediaIds,
    required String idempotencyKey,
    int? cropId,
    String? plotId,
  }) async {
    createCalls++;
    lastId = id;
    lastIdempotencyKey = idempotencyKey;
    lastMediaIds = List<String>.of(mediaIds);
    lastCropId = cropId;
    lastPlotId = plotId;
    if (quotaFailure) {
      throw const ApiException(
        statusCode: 429,
        code: 'QUOTA_EXCEEDED',
        message: 'Quota atteint.',
      );
    }
    if (failures > 0) {
      failures--;
      throw const ApiException(
        code: ApiException.unknownErrorCode,
        message: 'Création impossible.',
      );
    }
    return sampleDiagnostic(status: DiagnosticStatus.pending);
  }
}

ProviderContainer buildContainer({
  required FakeCompressor compressor,
  required FakeUploader uploader,
  required FakeDiagnosticsRepository repository,
}) {
  final ProviderContainer container = ProviderContainer(
    overrides: [
      imageCompressorProvider.overrideWithValue(compressor),
      mediaUploaderProvider.overrideWithValue(uploader),
      diagnosticsRepositoryProvider.overrideWithValue(repository),
    ],
  );
  addTearDown(container.dispose);
  container.listen<DiagnosticFlowState>(
    diagnosticFlowProvider,
    (DiagnosticFlowState? previous, DiagnosticFlowState next) {},
    fireImmediately: true,
  );
  return container;
}

void main() {
  test('uploads with the same ids after an upload failure', () async {
    final FakeCompressor compressor = FakeCompressor();
    final FakeUploader uploader = FakeUploader(failures: 1);
    final FakeDiagnosticsRepository repository = FakeDiagnosticsRepository();
    final ProviderContainer container = buildContainer(
      compressor: compressor,
      uploader: uploader,
      repository: repository,
    );
    final DiagnosticFlowController flow = container.read(
      diagnosticFlowProvider.notifier,
    );

    await flow.addPhoto(Uint8List.fromList(<int>[1, 2, 3]));
    expect(compressor.calls, 1);
    expect(
      container.read(diagnosticFlowProvider).photos.single.status,
      FlowPhotoStatus.ready,
    );

    final DiagnosticFlowState initial = container.read(diagnosticFlowProvider);
    flow.selectCrop(3);
    flow.selectPlot('plot-1');

    await flow.submit();

    expect(uploader.calls, 1);
    expect(repository.createCalls, 0);
    expect(container.read(diagnosticFlowProvider).error, isNotNull);
    expect(
      container.read(diagnosticFlowProvider).photos.single.status,
      FlowPhotoStatus.failed,
    );

    await flow.submit();

    expect(uploader.calls, 2);
    expect(uploader.lastMediaId, initial.photos.single.mediaId);
    expect(uploader.lastPlotId, 'plot-1');
    expect(repository.createCalls, 1);
    expect(repository.lastId, initial.diagnosticId);
    expect(repository.lastIdempotencyKey, initial.idempotencyKey);
    expect(repository.lastMediaIds, <String>[
      'server-${initial.photos.single.mediaId}',
    ]);
    expect(repository.lastCropId, 3);
    expect(repository.lastPlotId, 'plot-1');
    expect(container.read(diagnosticFlowProvider).created, isNotNull);
  });

  test('invalidates the history after creating a diagnostic', () async {
    final FakeDiagnosticsRepository repository = FakeDiagnosticsRepository();
    final ProviderContainer container = buildContainer(
      compressor: FakeCompressor(),
      uploader: FakeUploader(),
      repository: repository,
    );
    await container.read(diagnosticsHistoryProvider.future);
    final int before = repository.listCalls;
    final DiagnosticFlowController flow = container.read(
      diagnosticFlowProvider.notifier,
    );

    await flow.addPhoto(Uint8List.fromList(<int>[1, 2, 3]));
    await flow.submit();
    await container.read(diagnosticsHistoryProvider.future);

    expect(container.read(diagnosticFlowProvider).created, isNotNull);
    expect(repository.listCalls, before + 1);
  });

  test('retries the creation without uploading again', () async {
    final FakeUploader uploader = FakeUploader();
    final FakeDiagnosticsRepository repository = FakeDiagnosticsRepository(
      failures: 1,
    );
    final ProviderContainer container = buildContainer(
      compressor: FakeCompressor(),
      uploader: uploader,
      repository: repository,
    );
    final DiagnosticFlowController flow = container.read(
      diagnosticFlowProvider.notifier,
    );

    await flow.addPhoto(Uint8List.fromList(<int>[1, 2, 3]));
    final DiagnosticFlowState initial = container.read(diagnosticFlowProvider);

    await flow.submit();

    expect(uploader.calls, 1);
    expect(repository.createCalls, 1);
    expect(container.read(diagnosticFlowProvider).created, isNull);
    expect(
      container.read(diagnosticFlowProvider).photos.single.status,
      FlowPhotoStatus.uploaded,
    );

    await flow.submit();

    expect(uploader.calls, 1);
    expect(repository.createCalls, 2);
    expect(repository.lastId, initial.diagnosticId);
    expect(repository.lastIdempotencyKey, initial.idempotencyKey);
    expect(container.read(diagnosticFlowProvider).created, isNotNull);
  });

  test('flags an exhausted quota and blocks submission', () async {
    final FakeDiagnosticsRepository repository = FakeDiagnosticsRepository(
      quotaFailure: true,
    );
    final ProviderContainer container = buildContainer(
      compressor: FakeCompressor(),
      uploader: FakeUploader(),
      repository: repository,
    );
    final DiagnosticFlowController flow = container.read(
      diagnosticFlowProvider.notifier,
    );

    await flow.addPhoto(Uint8List.fromList(<int>[1, 2, 3]));
    await flow.submit();

    final DiagnosticFlowState state = container.read(diagnosticFlowProvider);
    expect(state.quotaExceeded, isTrue);
    expect(state.canSubmit, isFalse);
    expect(state.error?.isQuotaExceeded, isTrue);
  });

  test('marks a photo as failed when compression fails', () async {
    final ProviderContainer container = buildContainer(
      compressor: FakeCompressor(
        error: const ImageProcessingException('Format invalide.'),
      ),
      uploader: FakeUploader(),
      repository: FakeDiagnosticsRepository(),
    );
    final DiagnosticFlowController flow = container.read(
      diagnosticFlowProvider.notifier,
    );

    await flow.addPhoto(Uint8List.fromList(<int>[1, 2, 3]));

    final FlowPhoto photo = container
        .read(diagnosticFlowProvider)
        .photos
        .single;
    expect(photo.status, FlowPhotoStatus.failed);
    expect(photo.error, 'Format invalide.');
    expect(container.read(diagnosticFlowProvider).canSubmit, isFalse);
  });
}
