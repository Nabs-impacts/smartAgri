import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/network/network_providers.dart';
import '../domain/overview.dart';
import '../domain/yield_cell.dart';

class StatsRepository {
  StatsRepository({required this.dio});

  final Dio dio;

  Future<Overview> getOverview() async {
    try {
      final Response<dynamic> response = await dio.get<dynamic>(
        '/admin/stats/overview',
      );
      return Overview.fromJson(_asMap(response.data));
    } on DioException catch (error) {
      throw _translate(error);
    }
  }

  Future<List<YieldCell>> getYields({
    int? cropId,
    int? regionId,
    int? seasonYear,
    SeasonType? seasonType,
  }) async {
    final Map<String, dynamic> query = <String, dynamic>{};
    if (cropId != null) {
      query['crop_id'] = cropId;
    }
    if (regionId != null) {
      query['region_id'] = regionId;
    }
    if (seasonYear != null) {
      query['season_year'] = seasonYear;
    }
    if (seasonType != null) {
      query['season_type'] = seasonType.apiCode;
    }
    try {
      final Response<dynamic> response = await dio.get<dynamic>(
        '/admin/stats/yields',
        queryParameters: query.isEmpty ? null : query,
      );
      final Map<String, dynamic> data = _asMap(response.data);
      final Object? items = data['items'];
      if (items is List) {
        return items
            .whereType<Map>()
            .map(
              (Map item) => YieldCell.fromJson(Map<String, dynamic>.from(item)),
            )
            .toList();
      }
      return <YieldCell>[];
    } on DioException catch (error) {
      throw _translate(error);
    }
  }

  ApiException _translate(DioException error) {
    final ApiException exception = ApiException.fromDioException(error);
    if (exception.statusCode == 403) {
      return const ApiException(
        statusCode: 403,
        code: 'FORBIDDEN',
        message: 'Accès réservé à l\'administration.',
      );
    }
    return exception;
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

class YieldsFilter {
  const YieldsFilter({
    this.cropId,
    this.regionId,
    this.seasonYear,
    this.seasonType,
  });

  final int? cropId;
  final int? regionId;
  final int? seasonYear;
  final SeasonType? seasonType;

  @override
  bool operator ==(Object other) {
    return other is YieldsFilter &&
        other.cropId == cropId &&
        other.regionId == regionId &&
        other.seasonYear == seasonYear &&
        other.seasonType == seasonType;
  }

  @override
  int get hashCode => Object.hash(cropId, regionId, seasonYear, seasonType);
}

class YieldsFilterController extends Notifier<YieldsFilter> {
  @override
  YieldsFilter build() => const YieldsFilter();

  void setCrop(int? cropId) {
    state = YieldsFilter(
      cropId: cropId,
      regionId: state.regionId,
      seasonYear: state.seasonYear,
      seasonType: state.seasonType,
    );
  }

  void setRegion(int? regionId) {
    state = YieldsFilter(
      cropId: state.cropId,
      regionId: regionId,
      seasonYear: state.seasonYear,
      seasonType: state.seasonType,
    );
  }

  void setYear(int? seasonYear) {
    state = YieldsFilter(
      cropId: state.cropId,
      regionId: state.regionId,
      seasonYear: seasonYear,
      seasonType: state.seasonType,
    );
  }

  void setSeason(SeasonType? seasonType) {
    state = YieldsFilter(
      cropId: state.cropId,
      regionId: state.regionId,
      seasonYear: state.seasonYear,
      seasonType: seasonType,
    );
  }
}

final Provider<StatsRepository> statsRepositoryProvider =
    Provider<StatsRepository>(
      (Ref ref) => StatsRepository(dio: ref.watch(apiClientProvider)),
    );

final NotifierProvider<YieldsFilterController, YieldsFilter>
yieldsFilterProvider = NotifierProvider<YieldsFilterController, YieldsFilter>(
  YieldsFilterController.new,
);

final FutureProvider<Overview> overviewProvider = FutureProvider<Overview>(
  (Ref ref) => ref.watch(statsRepositoryProvider).getOverview(),
  retry: (int retryCount, Object error) => null,
);

final FutureProvider<List<YieldCell>> yieldsProvider =
    FutureProvider<List<YieldCell>>((Ref ref) {
      final YieldsFilter filter = ref.watch(yieldsFilterProvider);
      return ref
          .watch(statsRepositoryProvider)
          .getYields(
            cropId: filter.cropId,
            regionId: filter.regionId,
            seasonYear: filter.seasonYear,
            seasonType: filter.seasonType,
          );
    }, retry: (int retryCount, Object error) => null);
