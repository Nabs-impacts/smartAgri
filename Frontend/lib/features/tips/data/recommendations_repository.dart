import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/network/network_providers.dart';
import '../domain/recommendation.dart';

class RecommendationsRepository {
  RecommendationsRepository({required this.dio});

  final Dio dio;

  Future<RecommendationsPage> list({
    String? cursor,
    int limit = 20,
    String? plotId,
    String? cropCycleId,
  }) async {
    try {
      final Response<dynamic> response = await dio.get<dynamic>(
        '/recommendations',
        queryParameters: <String, dynamic>{
          'limit': limit,
          'cursor': ?cursor,
          'plot_id': ?plotId,
          'crop_cycle_id': ?cropCycleId,
        },
      );
      return RecommendationsPage.fromJson(_asMap(response.data));
    } on DioException catch (error) {
      throw ApiException.fromDioException(error);
    }
  }

  Future<Recommendation> get(String id) async {
    try {
      final Response<dynamic> response = await dio.get<dynamic>(
        '/recommendations/$id',
      );
      return Recommendation.fromJson(_asMap(response.data));
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

final Provider<RecommendationsRepository> recommendationsRepositoryProvider =
    Provider<RecommendationsRepository>(
      (Ref ref) => RecommendationsRepository(dio: ref.watch(apiClientProvider)),
    );
