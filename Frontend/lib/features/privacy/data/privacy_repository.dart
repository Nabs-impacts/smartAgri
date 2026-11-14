import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/config/app_config.dart';
import '../../../core/haptics/app_haptics.dart';
import '../../../core/i18n/language_controller.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/network/network_providers.dart';
import '../../../core/session/session_controller.dart';
import '../../../core/theme/theme_mode_controller.dart';
import '../../../core/storage/token_store.dart';
import '../../auth/data/pending_consents_store.dart';
import '../../auth/domain/consent_choice.dart';
import '../../profile/data/me_cache.dart';

class DataExport {
  const DataExport({required this.bytes, required this.fileName});

  final Uint8List bytes;
  final String fileName;
}

class ConsentRecord {
  const ConsentRecord({
    required this.type,
    required this.version,
    required this.accepted,
    this.date,
  });

  final ConsentType type;
  final String version;
  final bool accepted;
  final DateTime? date;

  static ConsentRecord? fromJson(Map<String, dynamic> json) {
    final Object? typeValue = json['type'];
    if (typeValue is! String) {
      return null;
    }
    ConsentType? type;
    for (final ConsentType candidate in ConsentType.values) {
      if (candidate.apiValue == typeValue) {
        type = candidate;
        break;
      }
    }
    if (type == null) {
      return null;
    }
    final Object? rawDate = json['date'] ?? json['created_at'];
    return ConsentRecord(
      type: type,
      version: json['version'] as String? ?? '',
      accepted: json['accepted'] as bool? ?? false,
      date: rawDate is String ? DateTime.tryParse(rawDate) : null,
    );
  }
}

class PrivacyRepository {
  PrivacyRepository({
    required this.dio,
    required this.tokenStore,
    required this.meCache,
    required this.pendingConsentsStore,
    required this.preferences,
    required this.onSignedOut,
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  static const String deleteConfirmation = 'SUPPRIMER MON COMPTE';
  static const String ownerConflictCode = 'ACCOUNT_OWNER_CONFLICT';
  static const String ownerConflictMessage =
      "Vous êtes le seul propriétaire d'une organisation qui compte d'autres membres. Transférez ou supprimez-la avant de supprimer votre compte.";

  final Dio dio;
  final TokenStore tokenStore;
  final MeCache meCache;
  final PendingConsentsStore pendingConsentsStore;
  final SharedPreferences preferences;
  final Future<void> Function() onSignedOut;
  final DateTime Function() _now;

  Future<DataExport> exportData() async {
    try {
      final Response<dynamic> response = await dio.get<dynamic>(
        '/users/me/export',
        options: Options(responseType: ResponseType.bytes),
      );
      final Object? data = response.data;
      final Uint8List bytes;
      if (data is Uint8List) {
        bytes = data;
      } else if (data is List<int>) {
        bytes = Uint8List.fromList(data);
      } else {
        bytes = Uint8List(0);
      }
      return DataExport(bytes: bytes, fileName: _fileName(_now()));
    } on DioException catch (error) {
      throw ApiException.fromDioException(error);
    }
  }

  Future<List<ConsentRecord>> getConsents() async {
    try {
      final Response<dynamic> response = await dio.get<dynamic>(
        '/users/me/consents',
      );
      final Object? data = response.data;
      if (data is! List) {
        return <ConsentRecord>[];
      }
      return data
          .whereType<Map>()
          .map(
            (Map item) =>
                ConsentRecord.fromJson(Map<String, dynamic>.from(item)),
          )
          .whereType<ConsentRecord>()
          .toList(growable: true);
    } on DioException catch (error) {
      throw ApiException.fromDioException(error);
    }
  }

  Future<void> setConsent(ConsentType type, bool accepted) async {
    try {
      await dio.post<dynamic>(
        '/users/me/consents',
        data: <String, dynamic>{
          'type': type.apiValue,
          'version': AppConfig.consentVersion,
          'accepted': accepted,
        },
      );
    } on DioException catch (error) {
      throw ApiException.fromDioException(error);
    }
  }

  Future<void> deleteAccount(String confirmation) async {
    try {
      await dio.delete<dynamic>(
        '/users/me',
        data: <String, dynamic>{'confirmation': confirmation},
      );
    } on DioException catch (error) {
      final ApiException exception = ApiException.fromDioException(error);
      if (exception.statusCode == 409 || exception.code == 'CONFLICT') {
        throw const ApiException(
          statusCode: 409,
          code: ownerConflictCode,
          message: ownerConflictMessage,
        );
      }
      throw exception;
    }
    await _clearLocalData();
    await onSignedOut();
  }

  Future<void> _clearLocalData() async {
    await tokenStore.clear();
    await meCache.clear();
    await pendingConsentsStore.clear();
    final List<String> keys = preferences
        .getKeys()
        .where(
          (String key) =>
              key != LanguageController.storageKey &&
              key != ThemeModeController.storageKey &&
              key != HapticsController.storageKey,
        )
        .toList();
    for (final String key in keys) {
      await preferences.remove(key);
    }
  }

  String _fileName(DateTime date) {
    final String year = date.year.toString().padLeft(4, '0');
    final String month = date.month.toString().padLeft(2, '0');
    final String day = date.day.toString().padLeft(2, '0');
    return 'gonata-donnees-$year-$month-$day.json';
  }
}

final Provider<PrivacyRepository> privacyRepositoryProvider =
    Provider<PrivacyRepository>((Ref ref) {
      return PrivacyRepository(
        dio: ref.watch(apiClientProvider),
        tokenStore: ref.watch(tokenStoreProvider),
        meCache: ref.watch(meCacheProvider),
        pendingConsentsStore: ref.watch(pendingConsentsStoreProvider),
        preferences: ref.watch(sharedPreferencesProvider),
        onSignedOut: () =>
            ref.read(sessionControllerProvider.notifier).signedOut(),
      );
    });
