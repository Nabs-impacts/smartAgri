import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/i18n/language_controller.dart';
import '../../auth/domain/user_profile.dart';
import '../domain/me_data.dart';

class MeCache {
  const MeCache({required this.preferences});

  static const String storageKey = 'me_cache_v1';

  final SharedPreferences preferences;

  Future<void> write(MeData data) async {
    final String raw = jsonEncode(<String, dynamic>{
      'cached_at': DateTime.now().toUtc().toIso8601String(),
      'user': <String, dynamic>{
        'id': data.user.id,
        'phone': data.user.phone,
        'full_name': data.user.fullName,
        'role': data.user.role,
        'email': data.user.email,
        'language': data.user.language,
      },
      'quotas': data.quotas
          .map(
            (Quota quota) => <String, dynamic>{
              'metric': quota.metric,
              'limit': quota.limit,
              'used': quota.used,
              'remaining': quota.remaining,
            },
          )
          .toList(),
      'plan': data.plan == null
          ? null
          : <String, dynamic>{
              'code': data.plan!.code,
              'name': data.plan!.name,
              'audience': data.plan!.audience,
              'billing_model': data.plan!.billingModel,
            },
    });
    await preferences.setString(storageKey, raw);
  }

  Future<MeData?> read({String? userId}) async {
    final String? raw = preferences.getString(storageKey);
    if (raw == null) {
      return null;
    }
    try {
      final Object? decoded = jsonDecode(raw);
      if (decoded is! Map) {
        return null;
      }
      final Map<String, dynamic> map = Map<String, dynamic>.from(decoded);
      final Object? user = map['user'];
      if (user is! Map) {
        return null;
      }
      final Map<String, dynamic> userMap = Map<String, dynamic>.from(user);
      if (userId != null && userMap['id'] != userId) {
        return null;
      }
      final Object? plan = map['plan'];
      final Object? quotas = map['quotas'];
      return MeData(
        user: UserProfile(
          id: userMap['id'] as String? ?? '',
          phone: userMap['phone'] as String? ?? '',
          fullName: userMap['full_name'] as String? ?? '',
          role: userMap['role'] as String? ?? '',
          email: userMap['email'] as String?,
          language: userMap['language'] as String?,
        ),
        quotas: quotas is List
            ? quotas
                  .whereType<Map>()
                  .map(
                    (Map item) =>
                        Quota.fromJson(Map<String, dynamic>.from(item)),
                  )
                  .toList()
            : <Quota>[],
        plan: plan is Map
            ? MePlan.fromJson(Map<String, dynamic>.from(plan))
            : null,
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> clear() async {
    await preferences.remove(storageKey);
  }
}

final Provider<MeCache> meCacheProvider = Provider<MeCache>(
  (Ref ref) => MeCache(preferences: ref.watch(sharedPreferencesProvider)),
);
