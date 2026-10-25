import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/app_config.dart';
import '../session/session_events.dart';
import '../storage/token_store.dart';
import 'auth_interceptor.dart';
import 'error_interceptor.dart';

final Provider<Dio> refreshDioProvider = Provider<Dio>((Ref ref) {
  final Dio dio = Dio(
    BaseOptions(
      baseUrl: AppConfig.apiBaseUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 30),
      contentType: Headers.jsonContentType,
      responseType: ResponseType.json,
    ),
  );
  dio.interceptors.removeImplyContentTypeInterceptor();
  return dio;
});

final Provider<Dio> apiClientProvider = Provider<Dio>((Ref ref) {
  final Dio dio = Dio(
    BaseOptions(
      baseUrl: AppConfig.apiBaseUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 30),
      contentType: Headers.jsonContentType,
      responseType: ResponseType.json,
      headers: const <String, String>{'Accept': 'application/json'},
    ),
  );
  dio.interceptors.removeImplyContentTypeInterceptor();
  dio.interceptors.add(
    AuthInterceptor(
      dio: dio,
      refreshDio: ref.watch(refreshDioProvider),
      tokenStore: ref.watch(tokenStoreProvider),
      events: ref.watch(sessionEventsProvider),
    ),
  );
  dio.interceptors.add(ErrorInterceptor());
  return dio;
});

final Provider<Dio> storageClientProvider = Provider<Dio>((Ref ref) {
  final Dio dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 30),
      sendTimeout: const Duration(seconds: 60),
    ),
  );
  dio.interceptors.removeImplyContentTypeInterceptor();
  return dio;
});
