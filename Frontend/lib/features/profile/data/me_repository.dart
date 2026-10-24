import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/i18n/app_language.dart';
import '../../../core/i18n/language_controller.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/network/network_providers.dart';
import '../../../core/session/session_controller.dart';
import '../../../core/session/session_state.dart';
import '../../auth/domain/user_profile.dart';
import '../domain/me_data.dart';
import 'me_cache.dart';

export '../domain/me_data.dart';

class MeRepository {
  MeRepository({required this.dio});

  final Dio dio;

  Future<MeData> getMe() async {
    try {
      final Response<dynamic> response = await dio.get<dynamic>('/users/me');
      return MeData.fromJson(_asMap(response.data));
    } on DioException catch (error) {
      throw ApiException.fromDioException(error);
    }
  }

  Future<void> updateLanguage(AppLanguage language) async {
    try {
      await dio.patch<dynamic>(
        '/users/me',
        data: <String, dynamic>{'language': language.apiCode},
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

class MeStaleController extends Notifier<bool> {
  @override
  bool build() => false;

  void set(bool value) {
    state = value;
  }
}

class MeController extends AsyncNotifier<MeData?> {
  String? _knownUserId;

  @override
  Future<MeData?> build() async {
    final SessionState session = ref.watch(sessionControllerProvider);
    ref.listen<AppLanguage>(languageControllerProvider, (
      AppLanguage? previous,
      AppLanguage next,
    ) {
      if (previous != null && previous != next) {
        unawaited(updateLanguage(next));
      }
    });
    final MeCache cache = ref.read(meCacheProvider);
    if (session != SessionState.authenticated) {
      await cache.clear();
      _knownUserId = null;
      return null;
    }
    final MeData? cached = await cache.read(userId: _knownUserId);
    if (cached != null) {
      _knownUserId = cached.user.id;
      unawaited(_refreshInBackground(cache));
      return cached;
    }
    final MeData data = await _fetch();
    await cache.write(data);
    _knownUserId = data.user.id;
    return data;
  }

  Future<MeData> _fetch() {
    return ref.read(meRepositoryProvider).getMe();
  }

  Future<void> _refreshInBackground(MeCache cache) async {
    try {
      final MeData data = await _fetch();
      await cache.write(data);
      _knownUserId = data.user.id;
      if (ref.mounted) {
        ref.read(meStaleProvider.notifier).set(false);
        state = AsyncData<MeData?>(data);
      }
    } catch (_) {
      if (ref.mounted) {
        ref.read(meStaleProvider.notifier).set(true);
      }
    }
  }

  Future<void> refresh() async {
    if (ref.read(sessionControllerProvider) != SessionState.authenticated) {
      return;
    }
    final MeCache cache = ref.read(meCacheProvider);
    if (state.value == null) {
      state = const AsyncLoading<MeData?>();
      final AsyncValue<MeData> result = await AsyncValue.guard<MeData>(_fetch);
      if (result.hasValue) {
        await cache.write(result.requireValue);
        _knownUserId = result.requireValue.user.id;
        ref.read(meStaleProvider.notifier).set(false);
      }
      state = result;
      return;
    }
    try {
      final MeData data = await _fetch();
      await cache.write(data);
      _knownUserId = data.user.id;
      if (ref.mounted) {
        ref.read(meStaleProvider.notifier).set(false);
        state = AsyncData<MeData?>(data);
      }
    } catch (_) {
      if (ref.mounted) {
        ref.read(meStaleProvider.notifier).set(true);
      }
    }
  }

  Future<void> updateLanguage(AppLanguage language) async {
    if (ref.read(sessionControllerProvider) != SessionState.authenticated) {
      return;
    }
    try {
      await ref.read(meRepositoryProvider).updateLanguage(language);
    } catch (_) {}
  }
}

final Provider<MeRepository> meRepositoryProvider = Provider<MeRepository>(
  (Ref ref) => MeRepository(dio: ref.watch(apiClientProvider)),
);

final NotifierProvider<MeStaleController, bool> meStaleProvider =
    NotifierProvider<MeStaleController, bool>(MeStaleController.new);

final AsyncNotifierProvider<MeController, MeData?> meProvider =
    AsyncNotifierProvider<MeController, MeData?>(
      MeController.new,
      retry: (int retryCount, Object error) => null,
    );

final Provider<UserProfile?> currentUserProvider = Provider<UserProfile?>(
  (Ref ref) => ref.watch(meProvider).value?.user,
);
