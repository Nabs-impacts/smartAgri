import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/network/network_providers.dart';
import '../domain/diagnostic.dart';
import '../domain/diagnostic_status.dart';
import '../domain/diagnostic_summary.dart';

class DiagnosticsRepository {
  DiagnosticsRepository({required this.dio});

  final Dio dio;

  Future<DiagnosticsPage> list({
    String? cursor,
    int limit = 20,
    String? plotId,
    DiagnosticStatus? status,
  }) async {
    try {
      final Response<dynamic> response = await dio.get<dynamic>(
        '/diagnostics',
        queryParameters: <String, dynamic>{
          'limit': limit,
          'cursor': ?cursor,
          'plot_id': ?plotId,
          'status': ?status?.apiValue,
        },
      );
      return DiagnosticsPage.fromJson(_asMap(response.data));
    } on DioException catch (error) {
      throw ApiException.fromDioException(error);
    }
  }

  Future<Diagnostic> create({
    required String id,
    required List<String> mediaIds,
    required String idempotencyKey,
    int? cropId,
    String? plotId,
  }) async {
    try {
      final Response<dynamic> response = await dio.post<dynamic>(
        '/diagnostics',
        data: <String, dynamic>{
          'id': id,
          'media_ids': mediaIds,
          'crop_id': ?cropId,
          'plot_id': ?plotId,
        },
        options: Options(
          headers: <String, String>{'Idempotency-Key': idempotencyKey},
        ),
      );
      return Diagnostic.fromJson(_asMap(response.data));
    } on DioException catch (error) {
      throw ApiException.fromDioException(error);
    }
  }

  Future<Diagnostic> get(String id) async {
    try {
      final Response<dynamic> response = await dio.get<dynamic>(
        '/diagnostics/$id',
      );
      return Diagnostic.fromJson(_asMap(response.data));
    } on DioException catch (error) {
      throw ApiException.fromDioException(error);
    }
  }

  Future<Diagnostic> retry(String id) async {
    try {
      final Response<dynamic> response = await dio.post<dynamic>(
        '/diagnostics/$id/retry',
      );
      return Diagnostic.fromJson(_asMap(response.data));
    } on DioException catch (error) {
      throw ApiException.fromDioException(error);
    }
  }

  Future<void> delete(String id) async {
    try {
      await dio.delete<dynamic>('/diagnostics/$id');
    } on DioException catch (error) {
      throw ApiException.fromDioException(error);
    }
  }

  Future<void> sendFeedback(
    String recommendationId, {
    required bool helpful,
    bool? applied,
    String? comment,
  }) async {
    try {
      await dio.post<dynamic>(
        '/recommendations/$recommendationId/feedback',
        data: <String, dynamic>{
          'helpful': helpful,
          'applied': ?applied,
          'comment': ?comment,
        },
      );
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
}

final Provider<DiagnosticsRepository> diagnosticsRepositoryProvider =
    Provider<DiagnosticsRepository>(
      (Ref ref) => DiagnosticsRepository(dio: ref.watch(apiClientProvider)),
    );
