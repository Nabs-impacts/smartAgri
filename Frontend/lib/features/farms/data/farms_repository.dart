import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/network/network_providers.dart';
import '../domain/farm.dart';
import '../domain/plot.dart';

const Object unchanged = Object();

abstract interface class FarmsRepository {
  Future<List<Farm>> listFarms();

  Future<Farm> createFarm(
    String id,
    String name, {
    String? village,
    int? adminAreaId,
  });

  Future<Farm> updateFarm(
    String id, {
    Object? name = unchanged,
    Object? village = unchanged,
    Object? adminAreaId = unchanged,
  });

  Future<void> deleteFarm(String id);

  Future<List<Plot>> listPlots(String farmId);

  Future<Plot> createPlot(
    String farmId,
    String id,
    String name, {
    double? areaHa,
    SoilType? soilType,
    IrrigationType? irrigation,
  });

  Future<Plot> getPlot(String id);

  Future<Plot> updatePlot(
    String id, {
    Object? name = unchanged,
    Object? areaHa = unchanged,
    Object? soilType = unchanged,
    Object? irrigation = unchanged,
  });

  Future<void> deletePlot(String id);
}

class HttpFarmsRepository implements FarmsRepository {
  HttpFarmsRepository({required this.dio});

  final Dio dio;

  @override
  Future<List<Farm>> listFarms() async {
    try {
      return await _list<Farm>('/farms', Farm.fromJson);
    } on DioException catch (error) {
      throw ApiException.fromDioException(error);
    }
  }

  @override
  Future<Farm> createFarm(
    String id,
    String name, {
    String? village,
    int? adminAreaId,
  }) async {
    try {
      final Response<dynamic> response = await dio.post<dynamic>(
        '/farms',
        data: <String, dynamic>{
          'id': id,
          'name': name,
          'village': ?village,
          'admin_area_id': ?adminAreaId,
        },
      );
      return Farm.fromJson(_asMap(response.data));
    } on DioException catch (error) {
      throw ApiException.fromDioException(error);
    }
  }

  @override
  Future<Farm> updateFarm(
    String id, {
    Object? name = unchanged,
    Object? village = unchanged,
    Object? adminAreaId = unchanged,
  }) async {
    final Map<String, dynamic> body = <String, dynamic>{
      if (!identical(name, unchanged)) 'name': name,
      if (!identical(village, unchanged)) 'village': village,
      if (!identical(adminAreaId, unchanged)) 'admin_area_id': adminAreaId,
    };
    try {
      final Response<dynamic> response = await dio.patch<dynamic>(
        '/farms/$id',
        data: body,
      );
      return Farm.fromJson(_asMap(response.data));
    } on DioException catch (error) {
      throw ApiException.fromDioException(error);
    }
  }

  @override
  Future<void> deleteFarm(String id) async {
    try {
      await dio.delete<dynamic>('/farms/$id');
    } on DioException catch (error) {
      throw ApiException.fromDioException(error);
    }
  }

  @override
  Future<List<Plot>> listPlots(String farmId) async {
    try {
      return await _list<Plot>('/farms/$farmId/plots', Plot.fromJson);
    } on DioException catch (error) {
      throw ApiException.fromDioException(error);
    }
  }

  @override
  Future<Plot> createPlot(
    String farmId,
    String id,
    String name, {
    double? areaHa,
    SoilType? soilType,
    IrrigationType? irrigation,
  }) async {
    try {
      final Response<dynamic> response = await dio.post<dynamic>(
        '/farms/$farmId/plots',
        data: <String, dynamic>{
          'id': id,
          'name': name,
          'area_ha': ?areaHa,
          if (soilType != null) 'soil_type': soilType.apiValue,
          if (irrigation != null) 'irrigation': irrigation.apiValue,
        },
      );
      return Plot.fromJson(_asMap(response.data));
    } on DioException catch (error) {
      throw ApiException.fromDioException(error);
    }
  }

  @override
  Future<Plot> getPlot(String id) async {
    try {
      final Response<dynamic> response = await dio.get<dynamic>('/plots/$id');
      return Plot.fromJson(_asMap(response.data));
    } on DioException catch (error) {
      throw ApiException.fromDioException(error);
    }
  }

  @override
  Future<Plot> updatePlot(
    String id, {
    Object? name = unchanged,
    Object? areaHa = unchanged,
    Object? soilType = unchanged,
    Object? irrigation = unchanged,
  }) async {
    final Map<String, dynamic> body = <String, dynamic>{
      if (!identical(name, unchanged)) 'name': name,
      if (!identical(areaHa, unchanged)) 'area_ha': areaHa,
      if (!identical(soilType, unchanged))
        'soil_type': soilType is SoilType ? soilType.apiValue : soilType,
      if (!identical(irrigation, unchanged))
        'irrigation': irrigation is IrrigationType
            ? irrigation.apiValue
            : irrigation,
    };
    try {
      final Response<dynamic> response = await dio.patch<dynamic>(
        '/plots/$id',
        data: body,
      );
      return Plot.fromJson(_asMap(response.data));
    } on DioException catch (error) {
      throw ApiException.fromDioException(error);
    }
  }

  @override
  Future<void> deletePlot(String id) async {
    try {
      await dio.delete<dynamic>('/plots/$id');
    } on DioException catch (error) {
      throw ApiException.fromDioException(error);
    }
  }

  Future<List<T>> _list<T>(
    String path,
    T Function(Map<String, dynamic>) fromJson,
  ) async {
    final List<T> result = <T>[];
    String? cursor;
    bool hasNext = true;
    while (hasNext) {
      final Response<dynamic> response = await dio.get<dynamic>(
        path,
        queryParameters: <String, dynamic>{'limit': 100, 'cursor': ?cursor},
      );
      final Object? data = response.data;
      if (data is List) {
        result.addAll(
          data.whereType<Map>().map(
            (Map item) => fromJson(Map<String, dynamic>.from(item)),
          ),
        );
        hasNext = false;
      } else if (data is Map) {
        final Map<String, dynamic> map = Map<String, dynamic>.from(data);
        final Object? items = map['items'];
        if (items is List) {
          result.addAll(
            items.whereType<Map>().map(
              (Map item) => fromJson(Map<String, dynamic>.from(item)),
            ),
          );
        }
        final Object? next = map['next_cursor'];
        if (next is String && next.isNotEmpty && next != cursor) {
          cursor = next;
        } else {
          hasNext = false;
        }
      } else {
        hasNext = false;
      }
    }
    return result;
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

final Provider<FarmsRepository> farmsRepositoryProvider =
    Provider<FarmsRepository>(
      (Ref ref) => HttpFarmsRepository(dio: ref.watch(apiClientProvider)),
    );
