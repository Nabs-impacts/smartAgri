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

class Quota {
  const Quota({
    required this.metric,
    required this.limit,
    required this.used,
    required this.remaining,
  });

  final String metric;
  final int limit;
  final int used;
  final int remaining;

  bool get isUnlimited => limit < 0;

  factory Quota.fromJson(Map<String, dynamic> json) {
    return Quota(
      metric: json['metric'] as String? ?? '',
      limit: (json['limit'] as num?)?.toInt() ?? -1,
      used: (json['used'] as num?)?.toInt() ?? 0,
      remaining: (json['remaining'] as num?)?.toInt() ?? 0,
    );
  }
}

class MePlan {
  const MePlan({
    required this.code,
    required this.name,
    required this.audience,
    required this.billingModel,
  });

  final String code;
  final String name;
  final String audience;
  final String billingModel;

  factory MePlan.fromJson(Map<String, dynamic> json) {
    return MePlan(
      code: json['code'] as String? ?? '',
      name: json['name'] as String? ?? '',
      audience: json['audience'] as String? ?? '',
      billingModel: json['billing_model'] as String? ?? '',
    );
  }
}

class MeData {
  const MeData({required this.user, required this.quotas, this.plan});

  final UserProfile user;
  final List<Quota> quotas;
  final MePlan? plan;

  factory MeData.fromJson(Map<String, dynamic> json) {
    final Object? user = json['user'];
    final Object? rawQuotas = json['quotas'];
    final Object? rawPlan = json['effective_plan'];
    return MeData(
      user: UserProfile.fromJson(
        user is Map ? Map<String, dynamic>.from(user) : <String, dynamic>{},
      ),
      quotas: rawQuotas is List
          ? rawQuotas
                .whereType<Map>()
                .map(
                  (Map item) => Quota.fromJson(Map<String, dynamic>.from(item)),
                )
                .toList()
          : <Quota>[],
      plan: rawPlan is Map
          ? MePlan.fromJson(Map<String, dynamic>.from(rawPlan))
          : null,
    );
  }
}

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
    if (session != SessionState.authenticated) {
      return null;
    }
    return _fetch();
  }

  Future<MeData> _fetch() {
    return ref.read(meRepositoryProvider).getMe();
  }

  Future<void> refresh() async {
    if (ref.read(sessionControllerProvider) != SessionState.authenticated) {
      return;
    }
    if (state.value == null) {
      state = const AsyncLoading<MeData?>();
      state = await AsyncValue.guard<MeData?>(_fetch);
      return;
    }
    try {
      final MeData data = await _fetch();
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
