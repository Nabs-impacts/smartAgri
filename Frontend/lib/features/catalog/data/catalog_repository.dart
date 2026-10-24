import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/i18n/language_controller.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/network/network_providers.dart';
import '../domain/admin_area.dart';
import '../domain/crop.dart';

class CatalogRepository {
  CatalogRepository({required this.dio, required this.preferences});

  static const String cropsKey = 'catalog_crops_v1';
  static const String adminAreasKey = 'catalog_admin_areas_v1';

  final Dio dio;
  final SharedPreferences preferences;

  Future<List<Crop>> getCrops() async {
    final List<Crop>? cached = await readCachedCrops();
    if (cached != null) {
      unawaited(_refreshCropsSilently());
      return cached;
    }
    return refreshCrops();
  }

  Future<List<Crop>?> readCachedCrops() {
    return _readCache<Crop>(cropsKey, Crop.fromJson);
  }

  Future<List<Crop>> refreshCrops() async {
    try {
      final List<Map<String, dynamic>> items = await _fetchItems('/crops');
      final List<Crop> crops = items.map(Crop.fromJson).toList();
      await _writeCache(
        cropsKey,
        crops.map((Crop crop) => crop.toJson()).toList(),
      );
      return crops;
    } on ApiException {
      final List<Crop>? cached = await readCachedCrops();
      if (cached != null) {
        return cached;
      }
      rethrow;
    }
  }

  Future<List<AdminArea>> getAdminAreas() async {
    final List<AdminArea>? cached = await readCachedAdminAreas();
    if (cached != null) {
      unawaited(_refreshAdminAreasSilently());
      return cached;
    }
    return refreshAdminAreas();
  }

  Future<List<AdminArea>?> readCachedAdminAreas() {
    return _readCache<AdminArea>(adminAreasKey, AdminArea.fromJson);
  }

  Future<List<AdminArea>> refreshAdminAreas() async {
    try {
      final List<Map<String, dynamic>> items = await _fetchItems(
        '/admin-areas',
      );
      final List<AdminArea> areas = items.map(AdminArea.fromJson).toList();
      await _writeCache(
        adminAreasKey,
        areas.map((AdminArea area) => area.toJson()).toList(),
      );
      return areas;
    } on ApiException {
      final List<AdminArea>? cached = await readCachedAdminAreas();
      if (cached != null) {
        return cached;
      }
      rethrow;
    }
  }

  Future<void> _refreshCropsSilently() async {
    try {
      await refreshCrops();
    } catch (_) {}
  }

  Future<void> _refreshAdminAreasSilently() async {
    try {
      await refreshAdminAreas();
    } catch (_) {}
  }

  Future<List<Map<String, dynamic>>> _fetchItems(String path) async {
    try {
      final List<Map<String, dynamic>> result = <Map<String, dynamic>>[];
      int page = 1;
      bool hasNext = true;
      while (hasNext) {
        final Response<dynamic> response = await dio.get<dynamic>(
          path,
          queryParameters: <String, dynamic>{'page': page},
        );
        final Object? data = response.data;
        if (data is List) {
          result.addAll(_asMaps(data));
          hasNext = false;
        } else if (data is Map) {
          final Map<String, dynamic> map = Map<String, dynamic>.from(data);
          final List<dynamic>? items = _listFrom(map);
          if (items == null) {
            hasNext = false;
          } else {
            result.addAll(_asMaps(items));
            final Object? next = map['next'] ?? map['next_page'];
            if (next is int && next > page) {
              page = next;
            } else if (map['has_next'] == true || map['hasNext'] == true) {
              page++;
            } else {
              hasNext = false;
            }
          }
        } else {
          hasNext = false;
        }
      }
      return result;
    } on DioException catch (error) {
      throw ApiException.fromDioException(error);
    }
  }

  List<dynamic>? _listFrom(Map<String, dynamic> map) {
    for (final String key in <String>['items', 'results', 'data']) {
      final Object? value = map[key];
      if (value is List) {
        return value;
      }
    }
    return null;
  }

  List<Map<String, dynamic>> _asMaps(List<dynamic> items) {
    return items
        .whereType<Map>()
        .map((Map item) => Map<String, dynamic>.from(item))
        .toList();
  }

  Future<List<T>?> _readCache<T>(
    String key,
    T Function(Map<String, dynamic>) fromJson,
  ) async {
    final String? raw = preferences.getString(key);
    if (raw == null) {
      return null;
    }
    try {
      final Object? decoded = jsonDecode(raw);
      if (decoded is! Map) {
        return null;
      }
      final Object? items = decoded['items'];
      if (items is! List) {
        return null;
      }
      return items
          .whereType<Map>()
          .map((Map item) => fromJson(Map<String, dynamic>.from(item)))
          .toList();
    } catch (_) {
      return null;
    }
  }

  Future<void> _writeCache(String key, List<Map<String, dynamic>> items) async {
    final String raw = jsonEncode(<String, dynamic>{
      'cached_at': DateTime.now().toUtc().toIso8601String(),
      'items': items,
    });
    await preferences.setString(key, raw);
  }
}

class CropsController extends AsyncNotifier<List<Crop>> {
  @override
  Future<List<Crop>> build() async {
    final CatalogRepository repository = ref.watch(catalogRepositoryProvider);
    final List<Crop>? cached = await repository.readCachedCrops();
    if (cached != null) {
      unawaited(_refresh(repository));
      return cached;
    }
    return repository.getCrops();
  }

  Future<void> _refresh(CatalogRepository repository) async {
    try {
      final List<Crop> crops = await repository.refreshCrops();
      if (ref.mounted) {
        state = AsyncData<List<Crop>>(crops);
      }
    } catch (_) {}
  }

  Future<void> refresh() async {
    try {
      final List<Crop> crops = await ref
          .read(catalogRepositoryProvider)
          .refreshCrops();
      if (ref.mounted) {
        state = AsyncData<List<Crop>>(crops);
      }
    } catch (error, stackTrace) {
      if (ref.mounted && state.value == null) {
        state = AsyncError<List<Crop>>(error, stackTrace);
      }
    }
  }
}

class AdminAreasController extends AsyncNotifier<List<AdminArea>> {
  @override
  Future<List<AdminArea>> build() async {
    final CatalogRepository repository = ref.watch(catalogRepositoryProvider);
    final List<AdminArea>? cached = await repository.readCachedAdminAreas();
    if (cached != null) {
      unawaited(_refresh(repository));
      return cached;
    }
    return repository.getAdminAreas();
  }

  Future<void> _refresh(CatalogRepository repository) async {
    try {
      final List<AdminArea> areas = await repository.refreshAdminAreas();
      if (ref.mounted) {
        state = AsyncData<List<AdminArea>>(areas);
      }
    } catch (_) {}
  }

  Future<void> refresh() async {
    try {
      final List<AdminArea> areas = await ref
          .read(catalogRepositoryProvider)
          .refreshAdminAreas();
      if (ref.mounted) {
        state = AsyncData<List<AdminArea>>(areas);
      }
    } catch (error, stackTrace) {
      if (ref.mounted && state.value == null) {
        state = AsyncError<List<AdminArea>>(error, stackTrace);
      }
    }
  }
}

final Provider<CatalogRepository> catalogRepositoryProvider =
    Provider<CatalogRepository>(
      (Ref ref) => CatalogRepository(
        dio: ref.watch(apiClientProvider),
        preferences: ref.watch(sharedPreferencesProvider),
      ),
    );

final AsyncNotifierProvider<CropsController, List<Crop>> cropsProvider =
    AsyncNotifierProvider<CropsController, List<Crop>>(
      CropsController.new,
      retry: (int retryCount, Object error) => null,
    );

final AsyncNotifierProvider<AdminAreasController, List<AdminArea>>
adminAreasProvider =
    AsyncNotifierProvider<AdminAreasController, List<AdminArea>>(
      AdminAreasController.new,
      retry: (int retryCount, Object error) => null,
    );
