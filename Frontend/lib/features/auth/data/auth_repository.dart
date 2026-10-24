import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/network/network_providers.dart';
import '../../../core/phone/niger_phone.dart';
import '../../../core/session/session_controller.dart';
import '../../../core/storage/token_store.dart';
import '../domain/auth_purpose.dart';
import '../domain/auth_session.dart';
import '../domain/consent_choice.dart';

class AuthRepository {
  AuthRepository({
    required this.dio,
    required this.tokenStore,
    required this.onSignedOut,
  });

  final Dio dio;
  final TokenStore tokenStore;
  final Future<void> Function() onSignedOut;

  Future<AuthSession> login({
    required String phone,
    required String password,
  }) async {
    final Map<String, dynamic> data = await _post(
      '/auth/login',
      <String, dynamic>{'phone': _normalizePhone(phone), 'password': password},
    );
    return AuthSession.fromJson(data);
  }

  Future<String> register({
    required String phone,
    required String fullName,
    String language = 'fr',
    String? password,
  }) async {
    final Map<String, dynamic> data = await _post(
      '/auth/register',
      <String, dynamic>{
        'phone': _normalizePhone(phone),
        'full_name': fullName,
        'language': language,
        if (password != null && password.isNotEmpty) 'password': password,
      },
    );
    final Object? message = data['message'];
    return message is String ? message : '';
  }

  Future<void> requestOtp({
    required String phone,
    required AuthPurpose purpose,
  }) async {
    await _post('/auth/otp/request', <String, dynamic>{
      'phone': _normalizePhone(phone),
      'purpose': purpose.apiValue,
    });
  }

  Future<AuthSession> verifyOtp({
    required String phone,
    required String code,
    required AuthPurpose purpose,
  }) async {
    final Map<String, dynamic> data = await _post(
      '/auth/otp/verify',
      <String, dynamic>{
        'phone': _normalizePhone(phone),
        'code': code,
        'purpose': purpose.apiValue,
      },
    );
    return AuthSession.fromJson(data);
  }

  Future<void> resetPassword({
    required String phone,
    required String code,
    required String newPassword,
  }) async {
    await _post('/auth/password/reset', <String, dynamic>{
      'phone': _normalizePhone(phone),
      'code': code,
      'new_password': newPassword,
    });
  }

  Future<void> logout() async {
    final AuthTokens? tokens = await tokenStore.read();
    try {
      if (tokens != null) {
        await dio.post<dynamic>(
          '/auth/logout',
          data: <String, dynamic>{'refresh_token': tokens.refreshToken},
        );
      }
    } catch (_) {
    } finally {
      await onSignedOut();
    }
  }

  Future<void> acceptConsents(List<ConsentChoice> choices) async {
    for (final ConsentChoice choice in choices) {
      await _post('/users/me/consents', <String, dynamic>{
        'type': choice.type.apiValue,
        'version': AppConfig.consentVersion,
        'accepted': choice.accepted,
      });
    }
  }

  Future<Map<String, dynamic>> _post(
    String path,
    Map<String, dynamic> body,
  ) async {
    try {
      final Response<dynamic> response = await dio.post<dynamic>(
        path,
        data: body,
      );
      return _asMap(response.data);
    } on DioException catch (error) {
      throw ApiException.fromDioException(error);
    }
  }

  String _normalizePhone(String phone) {
    final String? normalized = NigerPhone.normalize(phone);
    if (normalized == null) {
      throw const ApiException(
        code: 'INVALID_PHONE',
        message: 'Veuillez saisir un numéro de téléphone valide.',
      );
    }
    return normalized;
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

final Provider<AuthRepository> authRepositoryProvider =
    Provider<AuthRepository>(
      (Ref ref) => AuthRepository(
        dio: ref.watch(apiClientProvider),
        tokenStore: ref.watch(tokenStoreProvider),
        onSignedOut: () =>
            ref.read(sessionControllerProvider.notifier).signedOut(),
      ),
    );
