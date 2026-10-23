import 'package:dio/dio.dart';

import '../session/session_events.dart';
import '../storage/token_store.dart';

class AuthInterceptor extends Interceptor {
  AuthInterceptor({
    required this.dio,
    required this.refreshDio,
    required this.tokenStore,
    required this.events,
  });

  static const String _retryKey = 'auth_retried';

  final Dio dio;
  final Dio refreshDio;
  final TokenStore tokenStore;
  final SessionEvents events;
  Future<AuthTokens?>? _refreshFuture;

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    if (!_isAuthRoute(options.path)) {
      final AuthTokens? tokens = await tokenStore.read();
      if (tokens != null) {
        options.headers['Authorization'] = 'Bearer ${tokens.accessToken}';
      }
    }
    handler.next(options);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final RequestOptions options = err.requestOptions;
    final bool canRetry =
        err.response?.statusCode == 401 &&
        !_isAuthRoute(options.path) &&
        options.extra[_retryKey] != true;
    if (!canRetry) {
      handler.next(err);
      return;
    }

    try {
      final AuthTokens? tokens = await _refreshTokens();
      if (tokens == null) {
        handler.next(err);
        return;
      }
      options.extra = <String, dynamic>{...options.extra, _retryKey: true};
      options.headers['Authorization'] = 'Bearer ${tokens.accessToken}';
      final Response<dynamic> response = await dio.fetch<dynamic>(options);
      handler.resolve(response);
    } on DioException catch (refreshError) {
      handler.next(refreshError);
    }
  }

  Future<AuthTokens?> _refreshTokens() {
    final Future<AuthTokens?>? existing = _refreshFuture;
    if (existing != null) {
      return existing;
    }
    final Future<AuthTokens?> future = _performRefresh();
    _refreshFuture = future;
    future.then<void>(
      (AuthTokens? tokens) => _clearRefresh(future),
      onError: (Object error, StackTrace stackTrace) => _clearRefresh(future),
    );
    return future;
  }

  void _clearRefresh(Future<AuthTokens?> future) {
    if (identical(_refreshFuture, future)) {
      _refreshFuture = null;
    }
  }

  Future<AuthTokens?> _performRefresh() async {
    final AuthTokens? current = await tokenStore.read();
    if (current == null) {
      return null;
    }
    try {
      final Response<dynamic> response = await refreshDio.post<dynamic>(
        '/auth/refresh',
        data: <String, dynamic>{'refresh_token': current.refreshToken},
      );
      final Object? data = response.data;
      if (data is! Map) {
        return null;
      }
      final Object? access = data['access_token'];
      final Object? refresh = data['refresh_token'];
      if (access is! String || refresh is! String) {
        return null;
      }
      final Object? expiresIn = data['expires_in'];
      final int expires = expiresIn is num ? expiresIn.toInt() : 0;
      await tokenStore.save(
        access,
        refresh,
        expires,
        remember: tokenStore.isPersistent,
      );
      final AuthTokens? updated = await tokenStore.read();
      return updated;
    } on DioException catch (error) {
      final int? status = error.response?.statusCode;
      if (status == 401 || status == 403) {
        await tokenStore.clear();
        events.emitSessionExpired();
        return null;
      }
      rethrow;
    }
  }

  bool _isAuthRoute(String path) {
    final String resolved = Uri.tryParse(path)?.path ?? path;
    return resolved.contains('/auth/');
  }
}
